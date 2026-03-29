"""
Step 4 — Explainer
Output: plain_english_summary, voice_url (/audio/{session_id} when ElevenLabs + DB succeed).
"""
import json
import logging
import os
import re
import httpx
import database as db
from models import (
    IntakeRequest,
    normalize_coverage_requirements_payload,
    normalize_risk_profile_payload,
)
from ..llm import GeminiRoutingError, generate_text_with_fallback

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are explaining insurance to a small business owner who has never dealt with commercial insurance before.
Use simple, direct language. No jargon. Short sentences. Be reassuring, not overwhelming.
Focus on what each policy actually protects them from in clear, real-world terms."""

USER_PROMPT_TEMPLATE = """Write a plain-English summary of this business's insurance needs.

Business: {business_name}
Industry: {industry}
Risk context: {risk_context}

Near-term (required or recommended):
{coverage_json}

Growth / later (projected triggers, if any):
{projected_json}

Write to the owner using "you" / "your business". One opening sentence, then required, then recommended, then projected if any, then one closing line on next steps.
Under 200 words, flowing prose (no bullets). This will be read aloud."""

ELEVENLABS_TTS_URL = "https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
_DEFAULT_MAX_TTS_CHARS = 4000


def _strip_wrappers(raw: str) -> str:
    text = raw.strip()
    m = re.match(r"^```(?:\w*)?\s*\n?(.*?)\n?```\s*$", text, re.DOTALL | re.IGNORECASE)
    if m:
        text = m.group(1).strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        text = text[1:-1].strip()
    return text


def _truncate_tts(text: str, max_chars: int) -> str:
    if len(text) <= max_chars:
        return text
    cut = text[: max_chars + 1]
    dot = cut.rfind(". ")
    if dot > max_chars // 2:
        return cut[: dot + 1].strip()
    return text[:max_chars].rstrip() + "…"


def _join_policy_names(policies: list[str]) -> str:
    if not policies:
        return ""
    if len(policies) == 1:
        return policies[0]
    if len(policies) == 2:
        return f"{policies[0]} and {policies[1]}"
    return f"{', '.join(policies[:-1])}, and {policies[-1]}"


def _build_fallback_summary(intake: IntakeRequest, rows) -> str:
    required = [item.type for item in rows if item.category.value == "required"]
    recommended = [item.type for item in rows if item.category.value == "recommended"]
    projected = [item.type for item in rows if item.category.value == "projected"]

    sentences = [
        f"For {intake.business_name}, your coverage review is ready."
    ]
    if required:
        sentences.append(
            f"You should prioritize {_join_policy_names(required[:3])} because these cover the most immediate risks in your business."
        )
    if recommended:
        sentences.append(
            f"It also makes sense to consider {_join_policy_names(recommended[:3])} to reduce common liability and operational gaps."
        )
    if projected:
        sentences.append(
            f"As you grow, keep {_join_policy_names(projected[:2])} in mind for future changes in operations or headcount."
        )
    if not any((required, recommended, projected)):
        sentences.append(
            "We could not confidently map policy types yet, so the safest next step is to rerun the analysis with more business detail."
        )
    sentences.append("Review the coverage dashboard for the specific recommendations and next steps.")
    return " ".join(sentence.strip() for sentence in sentences if sentence.strip())


async def synthesize_speech(session_id: str, text: str) -> str:
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key or not text.strip():
        return ""

    max_c = int(os.environ.get("ELEVENLABS_MAX_CHARS", str(_DEFAULT_MAX_TTS_CHARS)))
    tts_body = _truncate_tts(text, max_c)
    vid = os.environ.get("ELEVENLABS_VOICE_ID", "21m00Tcm4TlvDq8ikWAM").strip()
    mid = os.environ.get("ELEVENLABS_MODEL_ID", "eleven_multilingual_v2").strip()

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            r = await client.post(
                ELEVENLABS_TTS_URL.format(voice_id=vid),
                headers={"xi-api-key": key, "Accept": "audio/mpeg", "Content-Type": "application/json"},
                json={
                    "text": tts_body,
                    "model_id": mid,
                    "voice_settings": {"stability": 0.5, "similarity_boost": 0.75},
                },
            )
            r.raise_for_status()
            audio = r.content
    except Exception as e:
        logger.warning("ElevenLabs TTS failed for session %s: %s", session_id, e)
        return ""

    if not audio:
        return ""
    await db.save_audio(session_id, audio)
    return f"/audio/{session_id}"


async def run(state: dict) -> dict:
    intake = IntakeRequest.model_validate(state["intake"])
    sid = state["session_id"]
    risk = (
        normalize_risk_profile_payload(state["risk_profile"], intake=intake)
        if state.get("risk_profile") is not None
        else None
    )
    cov_filter = state.get("coverage_apply_evidence_filter", True)
    rows = normalize_coverage_requirements_payload(
        state.get("coverage_requirements") or [],
        intake=intake,
        risk_profile=risk,
        apply_evidence_filter=cov_filter,
    )

    now = [
        c.model_dump(mode="json")
        for c in rows
        if c.category.value in ("required", "recommended")
    ]
    later = [
        c.model_dump(mode="json")
        for c in rows
        if c.category.value == "projected"
    ]

    industry = (
        (risk.industry if risk else None)
        or intake.description[:120]
        or "General business"
    ).strip()
    ctx = ((risk.reasoning_summary if risk else None) or "See coverage lists below.").strip()

    prompt = USER_PROMPT_TEMPLATE.format(
        business_name=intake.business_name,
        industry=industry,
        risk_context=ctx,
        coverage_json=json.dumps(now, indent=2) if now else "(none listed)",
        projected_json=json.dumps(later, indent=2) if later else "(none)",
    )
    degraded = False
    try:
        summary_text, llm_meta = await generate_text_with_fallback(
            system=SYSTEM_PROMPT,
            user=prompt,
        )
        summary = _strip_wrappers(summary_text)
    except GeminiRoutingError as exc:
        degraded = True
        summary = _build_fallback_summary(intake, rows)
        llm_meta = {
            "model_used": None,
            "fallback_reason": "text_generation_failed",
            "latency_ms": None,
            "parse_ok": True,
            "validation_ok": True,
            "attempts": exc.attempts,
            "degraded": True,
            "error_message": str(exc),
        }
    voice_url = await synthesize_speech(sid, summary)
    llm_meta["voice_generated"] = bool(voice_url)
    llm_meta["degraded"] = degraded or llm_meta.get("degraded", False)

    analysis_meta = dict(state.get("analysis_meta") or {})
    analysis_meta["explainer"] = llm_meta

    return {
        **state,
        "plain_english_summary": summary,
        "voice_url": voice_url,
        "analysis_meta": analysis_meta,
    }
