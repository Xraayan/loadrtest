import time
import base64
import json
from typing import Any, Dict, Optional


CUSTOM_TOKEN_TTL_SECONDS = 3600
_issued_custom_tokens: Dict[str, Dict[str, Any]] = {}


def store_custom_token(token: str, uid: str) -> None:
    _issued_custom_tokens[token] = {
        "uid": uid,
        "expires_at": time.time() + CUSTOM_TOKEN_TTL_SECONDS,
    }


def get_custom_token_user(token: str) -> Optional[Dict[str, Any]]:
    token_data = _issued_custom_tokens.get(token)
    if token_data:
        if time.time() > token_data["expires_at"]:
            del _issued_custom_tokens[token]
            return None

        return {
            "uid": token_data["uid"],
            "claims": {
                "uid": token_data["uid"],
                "auth_source": "dev_custom_token",
            },
        }

    payload = _decode_unverified_jwt_payload(token)
    uid = payload.get("uid") if payload else None
    if not uid:
        return None

    return {
        "uid": uid,
        "claims": {
            "uid": uid,
            "auth_source": "dev_unverified_custom_token",
        },
    }


def _decode_unverified_jwt_payload(token: str) -> Optional[Dict[str, Any]]:
    """Decode Firebase custom token payload for demo auth only."""
    try:
        parts = token.split(".")
        if len(parts) != 3:
            return None

        payload = parts[1]
        payload += "=" * (-len(payload) % 4)
        decoded = base64.urlsafe_b64decode(payload.encode("utf-8"))
        return json.loads(decoded.decode("utf-8"))
    except Exception:
        return None
