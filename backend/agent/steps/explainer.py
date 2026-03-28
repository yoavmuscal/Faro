"""
Step 4 — Explainer
Input:  submission packet + coverage requirements
Output: plain-English summary string + ElevenLabs audio URL
Model:  K2 Think V2 (with Claude fallback) + ElevenLabs TTS
"""
import os
import httpx
import json
from ..llm import chat_with_fallback

SYSTEM_PROMPT = """You are explaining insurance to a small business owner who has never dealt with commercial insurance before.
Use simple, direct language. No jargon. Short sentences. Be reassuring, not overwhelming.
Focus on what each policy actually protects them from in real-world scenarios."""

USER_PROMPT_TEMPLATE = """Write a plain-English summary of this business's insurance needs.

Business: {business_name}
Coverage requirements:
{coverage_json}

Write as if you are talking directly to the owner. Use "you" and "your business".
Structure it as:
1. One opening sentence about the overall picture ("Your {business type} has [X] coverage needs...")
2. For each REQUIRED coverage: one sentence on what it covers in plain English
3. For each RECOMMENDED coverage: one sentence, framed as "We also recommend..."
4. One closing sentence about next steps

Keep it under 200 words. No bullet points — flowing prose that reads naturally when spoken aloud.
This text will be converted to speech."""


async def synthesize_speech(session_id: str, text: str) -> str:
    """Mock audio synthesis since ElevenLabs is disabled."""
    # We return an empty string so the iOS app knows there's no audio to play, bypassing DB/API.
    return ""


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
