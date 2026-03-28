"""
ElevenLabs Conversational AI integration.
Handles agent creation/retrieval and converting transcripts into IntakeRequests.
"""
import os
import json
import logging
from typing import Optional
import httpx
from models import ConvTranscriptTurn
from .llm import chat_with_fallback, parse_json_response

logger = logging.getLogger(__name__)

AGENT_PROMPT = """You are Faro, a friendly commercial insurance broker. Your goal is to collect 5 key pieces of information from small business owners:
1. Business name
2. What the business does (description)
3. Number of employees
4. The US State they operate in
5. Approximate annual revenue

Ask these questions naturally and conversationally, one at a time. If they give multiple pieces of info at once, skip asking about those.
Be concise. Do not explain insurance coverages yet; your ONLY job right now is just gathering these 5 facts. Once you have all 5, thank them and say "I'll analyze your coverage needs now." and end the conversation.
"""

# Store the dynamically created agent ID so we don't spam the API during local dev without an env var.
_cached_agent_id = None

async def get_or_create_agent_id() -> str:
    global _cached_agent_id

    env_agent_id = os.environ.get("ELEVENLABS_CONV_AGENT_ID", "").strip()
    if env_agent_id:
        return env_agent_id

    if _cached_agent_id:
        return _cached_agent_id

    api_key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not api_key:
        raise ValueError("ELEVENLABS_API_KEY is not set.")

    url = "https://api.elevenlabs.io/v1/convai/agents/create"
    headers = {
        "xi-api-key": api_key,
        "Content-Type": "application/json"
    }
    payload = {
        "name": "Faro Intake Agent",
        "conversation_config": {
            "agent": {
                "prompt": {"prompt": AGENT_PROMPT},
                "first_message": "Hi, I'm Faro. I can help set up your commercial insurance profile. To start, what's the name of your business?",
                "language": "en"
            }
        }
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        # Use simple POST if /create is correct, otherwise standard /agents
        try:
            r = await client.post(url, headers=headers, json=payload)
            r.raise_for_status()
            data = r.json()
            _cached_agent_id = data.get("agent_id")
            if not _cached_agent_id:
                raise ValueError("ElevenLabs create agent response missing agent_id.")
            logger.warning(f"Created new Conv Agent: {_cached_agent_id}. Add to .env: ELEVENLABS_CONV_AGENT_ID={_cached_agent_id}")
            return _cached_agent_id
        except httpx.HTTPStatusError as e:
            # Fallback to older endpoint if needed
            r = await client.post("https://api.elevenlabs.io/v1/convai/agents", headers=headers, json=payload)
            r.raise_for_status()
            _cached_agent_id = r.json().get("agent_id")
            if not _cached_agent_id:
                raise ValueError("ElevenLabs create agent response missing agent_id.")
            logger.warning(f"Created new Conv Agent: {_cached_agent_id}. Add to .env: ELEVENLABS_CONV_AGENT_ID={_cached_agent_id}")
            return _cached_agent_id


async def create_conversation_token(session_id: str) -> str:
    """Returns a signed ElevenLabs WebSocket URL for the iOS client."""
    agent_id = await get_or_create_agent_id()
    api_key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not api_key:
        raise ValueError("ELEVENLABS_API_KEY is not set.")

    url = f"https://api.elevenlabs.io/v1/convai/conversation/get_signed_url?agent_id={agent_id}"
    headers = {"xi-api-key": api_key}

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            r = await client.get(url, headers=headers)
            r.raise_for_status()
            signed = r.json().get("signed_url")
            if signed:
                return signed
            logger.warning("get_signed_url returned no signed_url; falling back to unsigned wss URL.")
        except httpx.HTTPError as e:
            logger.warning("Could not get signed URL (%s), returning raw WebSocket URL...", e)
        return f"wss://api.elevenlabs.io/v1/convai/conversation?agent_id={agent_id}"


async def extract_intake_from_transcript(transcript: list[ConvTranscriptTurn]) -> dict:
    """Uses Gemini to parse the unstructured conversation into the 5 structured intake fields."""

    system_prompt = """You extract structured fields from an insurance intake conversation transcript.
You must output ONLY raw, strictly valid JSON that matches this schema exactly, with NO markdown code blocks, NO triple backticks, and NO wrapping text:
{
    "business_name": "String",
    "description": "String",
    "employee_count": Integer,
    "state": "String (2-letter code if possible)",
    "annual_revenue": Float
}
If a field wasn't mentioned, guess a reasonable default or leave blank."""

    # Format transcript
    transcript_text = "\n".join([f"{t.role.upper()}: {t.message}" for t in transcript])

    user_prompt = f"Transcript:\n{transcript_text}\n\nExtract the JSON now:"

    raw_response = await chat_with_fallback(system=system_prompt, user=user_prompt)
    data = parse_json_response(raw_response)

    # Ensure all expected fields exist with basic typing
    return {
        "business_name": str(data.get("business_name", "Unknown Business")),
        "description": str(data.get("description", "Not specified in transcript")),
        "employee_count": int(data.get("employee_count") or 1),
        "state": str(data.get("state", "NY")),
        "annual_revenue": float(data.get("annual_revenue") or 0.0)
    }
