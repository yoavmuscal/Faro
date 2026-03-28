import os
from motor.motor_asyncio import AsyncIOMotorClient
from typing import Optional

_client: Optional[AsyncIOMotorClient] = None


def get_client() -> AsyncIOMotorClient:
    global _client
    if _client is None:
        uri = os.environ["MONGODB_URI"]
        _client = AsyncIOMotorClient(uri)
    return _client


def get_db():
    return get_client()[os.environ.get("MONGODB_DB", "faro")]


async def save_session(session_id: str, data: dict) -> None:
    db = get_db()
    await db.sessions.update_one(
        {"session_id": session_id},
        {"$set": data},
        upsert=True,
    )


async def get_session(session_id: str) -> Optional[dict]:
    db = get_db()
    return await db.sessions.find_one({"session_id": session_id}, {"_id": 0})


async def save_audio(session_id: str, audio_bytes: bytes) -> None:
    db = get_db()
    import base64
    await db.audio.update_one(
        {"session_id": session_id},
        {"$set": {"session_id": session_id, "data": base64.b64encode(audio_bytes).decode()}},
        upsert=True,
    )


async def get_audio(session_id: str) -> Optional[bytes]:
    db = get_db()
    doc = await db.audio.find_one({"session_id": session_id})
    if doc and doc.get("data"):
        import base64
        return base64.b64decode(doc["data"])
    return None


async def close():
    global _client
    if _client:
        _client.close()
        _client = None
