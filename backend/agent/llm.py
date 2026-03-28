"""
LLM abstraction layer.
Primary: Google Gemini (gemini-2.5-flash) via MLH API keys.
"""
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
