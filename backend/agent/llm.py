"""
LLM abstraction layer.
Primary: Google Gemini (gemini-2.5-flash) via MLH API keys.
"""
import json
import re

from google import genai
from google.genai import types


async def chat_with_fallback(system: str, user: str) -> str:
    """Sends the prompt to Gemini. Retained function name for downstream compatibility."""
    # Reads GEMINI_API_KEY from the environment automatically
    client = genai.Client()
    response = await client.aio.models.generate_content(
        model='gemini-2.5-flash',
        contents=user,
        config=types.GenerateContentConfig(
            system_instruction=system,
        )
    )
    return response.text


def parse_json_response(raw: str):
    """
    Parse JSON from an LLM response that may include markdown/code fences.
    """
    text = (raw or "").strip()
    if not text:
        raise ValueError("Empty LLM response")

    # Fast path when response is already strict JSON.
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Common case: fenced markdown block.
    fence_match = re.search(r"```(?:json)?\s*([\s\S]*?)```", text, re.IGNORECASE)
    if fence_match:
        candidate = fence_match.group(1).strip()
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            pass

    # Fallback: take substring between first JSON opener and last closer.
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
    return json.loads(candidate)
