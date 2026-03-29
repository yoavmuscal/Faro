import os
import logging
from typing import Optional
from motor.motor_asyncio import AsyncIOMotorClient

logger = logging.getLogger(__name__)

_client: Optional[AsyncIOMotorClient] = None
_use_memory_store = False
_memory_sessions: dict[str, dict] = {}
_memory_audio: dict[str, bytes] = {}
_memory_store_logged = False


def _prefer_memory_store() -> bool:
    return _use_memory_store or not os.environ.get("MONGODB_URI")


def _enable_memory_store(reason: str) -> None:
    global _use_memory_store, _memory_store_logged
    _use_memory_store = True
    if not _memory_store_logged:
        logger.warning("Falling back to in-memory storage: %s", reason)
        _memory_store_logged = True


def get_client() -> AsyncIOMotorClient:
    global _client, _use_memory_store
    if _prefer_memory_store():
        raise RuntimeError("MongoDB not configured; using in-memory store")
    if _client is None:
        uri = os.environ["MONGODB_URI"]
        _client = AsyncIOMotorClient(uri)
    return _client


def get_db():
    global _use_memory_store
    if _prefer_memory_store():
        return None
    return get_client()[os.environ.get("MONGODB_DB", "faro")]


async def save_session(session_id: str, data: dict) -> None:
    if _prefer_memory_store():
        existing = _memory_sessions.get(session_id, {})
        existing.update(data)
        _memory_sessions[session_id] = existing
        return
    db = get_db()
    try:
        await db.sessions.update_one(
            {"session_id": session_id},
            {"$set": data},
            upsert=True,
        )
    except Exception as exc:
        _enable_memory_store(str(exc))
        existing = _memory_sessions.get(session_id, {})
        existing.update(data)
        _memory_sessions[session_id] = existing


async def get_session(session_id: str) -> Optional[dict]:
    if _prefer_memory_store():
        session = _memory_sessions.get(session_id)
        return dict(session) if session is not None else None
    db = get_db()
    try:
        return await db.sessions.find_one({"session_id": session_id}, {"_id": 0})
    except Exception as exc:
        _enable_memory_store(str(exc))
        session = _memory_sessions.get(session_id)
        return dict(session) if session is not None else None


async def save_audio(session_id: str, audio_bytes: bytes) -> None:
    if _prefer_memory_store():
        _memory_audio[session_id] = audio_bytes
        return
    db = get_db()
    import base64
    try:
        await db.audio.update_one(
            {"session_id": session_id},
            {"$set": {"session_id": session_id, "data": base64.b64encode(audio_bytes).decode()}},
            upsert=True,
        )
    except Exception as exc:
        _enable_memory_store(str(exc))
        _memory_audio[session_id] = audio_bytes


async def get_audio(session_id: str) -> Optional[bytes]:
    if _prefer_memory_store():
        return _memory_audio.get(session_id)
    db = get_db()
    try:
        doc = await db.audio.find_one({"session_id": session_id})
        if doc and doc.get("data"):
            import base64
            return base64.b64decode(doc["data"])
    except Exception as exc:
        _enable_memory_store(str(exc))
        return _memory_audio.get(session_id)
    return None


async def close():
    global _client
    if _client:
        _client.close()
        _client = None
