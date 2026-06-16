import time
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
    if not token_data:
        return None

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
