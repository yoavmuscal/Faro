"""Auth0 JWT verification (RS256 via JWKS). Disabled when AUTH0_DOMAIN or AUTH0_AUDIENCE is unset."""

from __future__ import annotations

import logging
import os
from functools import lru_cache
from typing import Any, List, Optional, Union
from urllib.parse import urlparse

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient
from starlette.websockets import WebSocket

logger = logging.getLogger(__name__)

security = HTTPBearer(auto_error=False)


def _normalize_auth0_domain(raw: str) -> str:
    """Accept host only or full URL; strip https://, paths (e.g. /api/v2/), trailing slashes."""
    raw = (raw or "").strip()
    if not raw:
        return ""
    if "://" in raw:
        host = (urlparse(raw).hostname or "").strip()
        return host.lower()
    return raw.split("/")[0].strip().lower()


AUTH0_DOMAIN = _normalize_auth0_domain(os.environ.get("AUTH0_DOMAIN", ""))
AUTH0_AUDIENCE = os.environ.get("AUTH0_AUDIENCE", "").strip()


def _audience_variants() -> list[str]:
    """Auth0 API identifiers may or may not use a trailing slash; tokens must match exactly."""
    aud = AUTH0_AUDIENCE.strip()
    if not aud:
        return []
    variants = {aud}
    if aud.endswith("/"):
        variants.add(aud.rstrip("/"))
    else:
        variants.add(aud + "/")
    return list(variants)


def auth_enabled() -> bool:
    return bool(AUTH0_DOMAIN and AUTH0_AUDIENCE)


@lru_cache(maxsize=1)
def _jwks_client() -> PyJWKClient:
    url = f"https://{AUTH0_DOMAIN}/.well-known/jwks.json"
    return PyJWKClient(url, cache_keys=True)


def verify_auth0_access_token(token: str) -> dict[str, Any]:
    if not auth_enabled():
        return {}
    audiences = _audience_variants()
    if not audiences:
        return {}
    try:
        signing_key = _jwks_client().get_signing_key_from_jwt(token)
        # PyJWT: pass iterable so either `https://id` or `https://id/` matches the `aud` claim.
        aud_param: Union[str, List[str]] = audiences[0] if len(audiences) == 1 else audiences
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=aud_param,
            issuer=f"https://{AUTH0_DOMAIN}/",
            leeway=30,
        )
        return dict(payload)
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(status_code=401, detail="Token expired") from exc
    except jwt.InvalidTokenError as exc:
        raise HTTPException(status_code=401, detail=f"Invalid token: {exc}") from exc
    except Exception as exc:
        logger.exception("JWT verification failed")
        raise HTTPException(status_code=401, detail="Invalid token") from exc


async def require_auth(
    creds: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> dict[str, Any]:
    if not auth_enabled():
        return {}
    if creds is None or creds.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Authorization Bearer token required")
    return verify_auth0_access_token(creds.credentials)


def ws_bearer_token(authorization_header: Optional[str]) -> Optional[str]:
    if not authorization_header:
        return None
    parts = authorization_header.split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return None
    return parts[1].strip()


async def ensure_websocket_allowed(websocket: WebSocket) -> bool:
    """After `accept()`, validate Bearer token or close with 4401. Returns False if closed."""
    if not auth_enabled():
        return True
    token = ws_bearer_token(websocket.headers.get("authorization"))
    if not token:
        await websocket.close(code=4401, reason="Unauthorized")
        return False
    try:
        verify_auth0_access_token(token)
        return True
    except HTTPException:
        await websocket.close(code=4401, reason="Unauthorized")
        return False
