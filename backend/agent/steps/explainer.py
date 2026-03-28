"""
Step 4 — Explainer
Input:  submission packet + coverage requirements
Output: plain-English summary string + voice playback URL (/audio/{session_id})
TTS:    ElevenLabs when ELEVENLABS_API_KEY is set; audio stored in MongoDB for GET /audio/{session_id}.
"""
import os
import logging

import httpx
import json

import database as db
from ..llm import chat_with_fallback

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are explaining insurance to a small business owner who has never dealt with commercial insurance before.
Use simple, direct language. No jargon. Short sentences. Be reassuring, not overwhelming.
Focus on what each policy actually protects them from in clear, real-world terms."""

USER_PROMPT_TEMPLATE = """Write a plain-English summary of this business's insurance needs.

Business: {business_name}
Coverage requirements:
{coverage_json}

Write as if you are talking directly to the owner. Use "you" and "your business".
Structure it as:
1. One opening sentence about the overall picture ("Your business type has [X] coverage needs...")
2. For each REQUIRED coverage: one sentence on what it covers in plain English
3. For each RECOMMENDED coverage: one sentence, framed as "We also recommend..."
4. One closing sentence about next steps

Keep it under 200 words. No bullet points — flowing prose that reads naturally when spoken aloud.
This text will be converted to speech."""

ELEVENLABS_TTS_URL = "https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"


async def synthesize_speech(session_id: str, text: str) -> str:
    """
    Generate MP3 via ElevenLabs, store in MongoDB, return relative URL for the iOS app
    (prepends API base URL when the path starts with /).
    """
    api_key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not api_key or not text.strip():
        return ""

    voice_id = os.environ.get("ELEVENLABS_VOICE_ID", "21m00Tcm4TlvDq8ikWAM").strip()
    model_id = os.environ.get("ELEVENLABS_MODEL_ID", "eleven_multilingual_v2").strip()
    url = ELEVENLABS_TTS_URL.format(voice_id=voice_id)

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(
                url,
                headers={
                    "xi-api-key": api_key,
                    "Accept": "audio/mpeg",
                    "Content-Type": "application/json",
                },
                json={
                    "text": text,
                    "model_id": model_id,
                },
            )
            response.raise_for_status()
            audio_bytes = response.content
    except Exception as e:
        logger.warning("ElevenLabs TTS failed for session %s: %s", session_id, e)
        return ""

    if not audio_bytes:
        return ""

    await db.save_audio(session_id, audio_bytes)
    return f"/audio/{session_id}"


async def run(state: dict) -> dict:
    intake = state["intake"]
    session_id = state["session_id"]
    coverage_required = [
        c for c in state["coverage_requirements"]
        if c["category"] in ("required", "recommended")
    ]

    prompt = USER_PROMPT_TEMPLATE.format(
        business_name=intake["business_name"],
        coverage_json=json.dumps(coverage_required, indent=2),
    )
    summary = await chat_with_fallback(system=SYSTEM_PROMPT, user=prompt)
    voice_url = await synthesize_speech(session_id, summary)

    return {**state, "plain_english_summary": summary, "voice_url": voice_url}
