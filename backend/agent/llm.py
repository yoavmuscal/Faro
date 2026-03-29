"""
LLM routing helpers.
Primary: Gemini 3 Flash Preview.
Fallback: Gemini 2.5 Flash.
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import time
from typing import Any, Callable, TypeVar

try:
    from google import genai
    from google.genai import types
except ImportError:  # pragma: no cover - exercised only when dependency is missing
    genai = None
    types = None


logger = logging.getLogger(__name__)

T = TypeVar("T")

PRIMARY_MODEL = os.environ.get("GEMINI_PRIMARY_MODEL", "gemini-3-flash-preview")
FALLBACK_MODEL = os.environ.get("GEMINI_FALLBACK_MODEL", "gemini-2.5-flash")
DEFAULT_TEMPERATURE = float(os.environ.get("GEMINI_TEMPERATURE", "0.1"))
DEFAULT_JSON_TIMEOUT_SECONDS = float(os.environ.get("GEMINI_JSON_TIMEOUT_SECONDS", "18"))
DEFAULT_TEXT_TIMEOUT_SECONDS = float(os.environ.get("GEMINI_TEXT_TIMEOUT_SECONDS", "16"))


class GeminiRoutingError(RuntimeError):
    def __init__(self, message: str, attempts: list[dict[str, Any]]):
        super().__init__(message)
        self.attempts = attempts


class _AttemptFailure(RuntimeError):
    def __init__(self, kind: str, message: str):
        super().__init__(message)
        self.kind = kind


def _require_client():
    if genai is None or types is None:
        raise RuntimeError(
            "google-genai is not installed. Install backend requirements before running Gemini-backed steps."
        )
    return genai.Client(), types


def _coerce_block_reason(response: Any) -> str | None:
    prompt_feedback = getattr(response, "prompt_feedback", None)
    if prompt_feedback is None:
        return None
    block_reason = getattr(prompt_feedback, "block_reason", None)
    if not block_reason:
        return None
    if isinstance(block_reason, str):
        return block_reason
    name = getattr(block_reason, "name", None)
    return name or str(block_reason)


async def _generate_once(
    *,
    model: str,
    system: str,
    user: str,
    timeout_seconds: float,
    response_mime_type: str | None,
) -> tuple[str, int]:
    client, genai_types = _require_client()
    config_kwargs: dict[str, Any] = {
        "system_instruction": system,
        "temperature": DEFAULT_TEMPERATURE,
    }
    if response_mime_type:
        config_kwargs["response_mime_type"] = response_mime_type

    started = time.perf_counter()
    try:
        response = await asyncio.wait_for(
            client.aio.models.generate_content(
                model=model,
                contents=user,
                config=genai_types.GenerateContentConfig(**config_kwargs),
            ),
            timeout=timeout_seconds,
        )
    except asyncio.TimeoutError as exc:
        raise _AttemptFailure(
            "timeout",
            f"Model {model} timed out after {timeout_seconds:.0f}s",
        ) from exc
    except Exception as exc:
        raise _AttemptFailure("transport_error", f"Model {model} request failed: {exc}") from exc

    latency_ms = int((time.perf_counter() - started) * 1000)
    text = getattr(response, "text", None)
    if text is None or not str(text).strip():
        block_reason = _coerce_block_reason(response)
        if block_reason:
            raise _AttemptFailure(
                "blocked_response",
                f"Model {model} returned no text (block reason: {block_reason})",
            )
        raise _AttemptFailure("empty_response", f"Model {model} returned an empty response")
    return str(text).strip(), latency_ms


def _build_attempt_meta(
    *,
    model: str,
    latency_ms: int | None,
    parse_ok: bool,
    validation_ok: bool,
    fallback_reason: str | None,
    error_kind: str | None = None,
    error_message: str | None = None,
) -> dict[str, Any]:
    return {
        "model": model,
        "latency_ms": latency_ms,
        "parse_ok": parse_ok,
        "validation_ok": validation_ok,
        "fallback_reason": fallback_reason,
        "error_kind": error_kind,
        "error_message": error_message,
    }


async def generate_text_with_fallback(
    *,
    system: str,
    user: str,
    timeout_seconds: float = DEFAULT_TEXT_TIMEOUT_SECONDS,
) -> tuple[str, dict[str, Any]]:
    attempts: list[dict[str, Any]] = []
    fallback_reason: str | None = None

    for model in (PRIMARY_MODEL, FALLBACK_MODEL):
        try:
            text, latency_ms = await _generate_once(
                model=model,
                system=system,
                user=user,
                timeout_seconds=timeout_seconds,
                response_mime_type=None,
            )
            attempt = _build_attempt_meta(
                model=model,
                latency_ms=latency_ms,
                parse_ok=True,
                validation_ok=True,
                fallback_reason=fallback_reason,
            )
            attempts.append(attempt)
            return text, {
                "model_used": model,
                "fallback_reason": fallback_reason,
                "latency_ms": latency_ms,
                "parse_ok": True,
                "validation_ok": True,
                "attempts": attempts,
            }
        except _AttemptFailure as exc:
            attempts.append(
                _build_attempt_meta(
                    model=model,
                    latency_ms=None,
                    parse_ok=False,
                    validation_ok=False,
                    fallback_reason=fallback_reason,
                    error_kind=exc.kind,
                    error_message=str(exc),
                )
            )
            fallback_reason = exc.kind

    raise GeminiRoutingError(
        "Both Gemini models failed to produce plain text output.",
        attempts,
    )


async def generate_validated_json_with_fallback(
    *,
    system: str,
    user: str,
    validator: Callable[[Any], T],
    timeout_seconds: float = DEFAULT_JSON_TIMEOUT_SECONDS,
) -> tuple[T, dict[str, Any]]:
    attempts: list[dict[str, Any]] = []
    fallback_reason: str | None = None

    for model in (PRIMARY_MODEL, FALLBACK_MODEL):
        parse_ok = False
        validation_ok = False
        latency_ms: int | None = None

        try:
            raw_text, latency_ms = await _generate_once(
                model=model,
                system=system,
                user=user,
                timeout_seconds=timeout_seconds,
                response_mime_type="application/json",
            )
            try:
                parsed = parse_json_response(raw_text)
                parse_ok = True
            except ValueError as exc:
                raise _AttemptFailure("parse_error", str(exc)) from exc

            try:
                validated = validator(parsed)
                validation_ok = True
            except Exception as exc:
                raise _AttemptFailure("validation_error", str(exc)) from exc

            attempt = _build_attempt_meta(
                model=model,
                latency_ms=latency_ms,
                parse_ok=parse_ok,
                validation_ok=validation_ok,
                fallback_reason=fallback_reason,
            )
            attempts.append(attempt)
            return validated, {
                "model_used": model,
                "fallback_reason": fallback_reason,
                "latency_ms": latency_ms,
                "parse_ok": parse_ok,
                "validation_ok": validation_ok,
                "attempts": attempts,
            }
        except _AttemptFailure as exc:
            attempts.append(
                _build_attempt_meta(
                    model=model,
                    latency_ms=latency_ms,
                    parse_ok=parse_ok,
                    validation_ok=validation_ok,
                    fallback_reason=fallback_reason,
                    error_kind=exc.kind,
                    error_message=str(exc),
                )
            )
            fallback_reason = exc.kind
            logger.warning(
                "Gemini attempt failed for model %s: %s (%s)",
                model,
                exc,
                exc.kind,
            )

    raise GeminiRoutingError(
        "Both Gemini models failed to produce valid structured output.",
        attempts,
    )


async def chat_with_fallback(system: str, user: str) -> str:
    """
    Backwards-compatible plain-text helper retained for downstream callers.
    """
    text, _ = await generate_text_with_fallback(system=system, user=user)
    return text


def parse_json_response(raw: str):
    """
    Parse JSON from an LLM response that may include markdown/code fences.
    """
    text = (raw or "").strip()
    if not text:
        raise ValueError("Empty LLM response")

    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    fence_match = re.search(r"```(?:json)?\s*([\s\S]*?)```", text, re.IGNORECASE)
    if fence_match:
        candidate = fence_match.group(1).strip()
        if not candidate:
            raise ValueError("LLM returned an empty JSON code block")
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            pass

    first_obj = text.find("{")
    first_arr = text.find("[")
    starts = [pos for pos in (first_obj, first_arr) if pos != -1]
    if not starts:
        raise ValueError("No JSON object/array found in LLM response")

    start = min(starts)
    end_obj = text.rfind("}")
    end_arr = text.rfind("]")
    end = max(end_obj, end_arr)
    if end < start:
        raise ValueError("Malformed JSON boundaries in LLM response")

    candidate = text[start : end + 1].strip()
    if not candidate:
        raise ValueError("Extracted JSON fragment was empty")
    try:
        return json.loads(candidate)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in LLM response: {exc}") from exc
