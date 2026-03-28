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
from models import validate_coverage_requirements_payload, validate_risk_profile_payload
from ..llm import chat_with_fallback

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


async def synthesize_speech(session_id: str, text: str) -> str:
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key or not text.strip():
        return ""

    max_c = int(os.environ.get("ELEVENLABS_MAX_CHARS", str(_DEFAULT_MAX_TTS_CHARS)))
    tts_body = _truncate_tts(text, max_c)
    vid = os.environ.get("ELEVENLABS_VOICE_ID", "21m00Tcm4TlvDq8ikWAM").strip()
    mid = os.environ.get("ELEVENLABS_MODEL_ID", "eleven_multilingual_v2").strip()

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
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
    intake = state["intake"]
    sid = state["session_id"]
    risk = (
        validate_risk_profile_payload(state["risk_profile"])
        if state.get("risk_profile") is not None
        else None
    )
    rows = validate_coverage_requirements_payload(state.get("coverage_requirements") or [])

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
        or (intake.get("description") or "")[:120]
        or "General business"
    ).strip()
    ctx = ((risk.reasoning_summary if risk else None) or "See coverage lists below.").strip()

    prompt = USER_PROMPT_TEMPLATE.format(
        business_name=intake["business_name"],
        industry=industry,
        risk_context=ctx,
        coverage_json=json.dumps(now, indent=2) if now else "(none listed)",
        projected_json=json.dumps(later, indent=2) if later else "(none)",
    )
    summary = _strip_wrappers(await chat_with_fallback(system=SYSTEM_PROMPT, user=prompt))
    voice_url = await synthesize_speech(sid, summary)

    return {**state, "plain_english_summary": summary, "voice_url": voice_url}
