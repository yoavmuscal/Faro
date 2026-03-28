"""
LLM abstraction layer.
Primary: K2 Think V2 (MBZUAI) via OpenAI-compatible API.
Fallback 1: Google Gemini (gemini-2.5-flash).
Fallback 2: Claude claude-sonnet-4-6 if both fail.
"""
import os
import asyncio
import httpx

K2_TIMEOUT_SECONDS = 8


async def _call_k2(system: str, user: str) -> str:
    api_key = os.environ["K2_API_KEY"]
    base_url = os.environ.get("K2_BASE_URL", "https://api.mbzuai.ac.ae/v1")

    payload = {
        "model": "k2-think-v2",
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": 0.1,
    }
    async with httpx.AsyncClient(timeout=K2_TIMEOUT_SECONDS) as client:
        resp = await client.post(
            f"{base_url}/chat/completions",
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
            json=payload,
        )
        resp.raise_for_status()
        return resp.json()["choices"][0]["message"]["content"]


async def _call_claude_fallback(system: str, user: str) -> str:
    import anthropic
    client = anthropic.AsyncAnthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    msg = await client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=2048,
        system=system,
        messages=[{"role": "user", "content": user}],
    )
    return msg.content[0].text


async def _call_gemini_fallback(system: str, user: str) -> str:
    from google import genai
    from google.genai import types
    
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


async def chat_with_fallback(system: str, user: str) -> str:
    """Try K2; if it times out or errors, fall back to Gemini then Claude."""
    try:
        return await asyncio.wait_for(_call_k2(system, user), timeout=K2_TIMEOUT_SECONDS)
    except Exception:
        try:
            return await _call_gemini_fallback(system, user)
        except Exception:
            return await _call_claude_fallback(system, user)
