from typing import Any, Dict, Optional

from fastapi import Header, HTTPException, status
from firebase_admin import auth
from pydantic import BaseModel

from config import settings
from dev_auth import get_custom_token_user


class CurrentUser(BaseModel):
    uid: str
    phone_number: Optional[str] = None
    claims: Dict[str, Any]


def get_current_user(authorization: Optional[str] = Header(default=None)) -> CurrentUser:
    """Verify a Firebase ID token from the Authorization header."""
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
        )

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header must be Bearer <token>",
        )

    try:
        decoded_token = auth.verify_id_token(token)
    except Exception:
        if settings.allow_custom_token_auth:
            dev_user = get_custom_token_user(token)
            if dev_user:
                return CurrentUser(
                    uid=dev_user["uid"],
                    phone_number=None,
                    claims=dev_user["claims"],
                )

        detail = (
            "Invalid or expired Firebase token"
            if settings.allow_custom_token_auth
            else "Invalid or expired Firebase ID token"
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
        )

    uid = decoded_token.get("uid")
    if not uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase token is missing uid",
        )

    return CurrentUser(
        uid=uid,
        phone_number=decoded_token.get("phone_number"),
        claims=decoded_token,
    )


def require_current_user_uid(uid: str, current_user: CurrentUser) -> None:
    """Ensure a path/query uid belongs to the authenticated Firebase user."""
    if uid != current_user.uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only access your own account data",
        )
