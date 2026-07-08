from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from firebase_admin import auth
import hashlib
import secrets
import time
from typing import Tuple

from config import settings
from dev_auth import store_custom_token
from supabase_config import get_supabase

router = APIRouter()

class SignInRequest(BaseModel):
    phone: str

class OTPVerifyRequest(BaseModel):
    phone: str
    otp: str

class SignInResponse(BaseModel):
    message: str
    otp: str = None

# Store OTPs temporarily (in production, use Redis)
otp_store = {}


def _ensure_supabase_profile(uid: str, phone: str) -> None:
    get_supabase().table("profiles").upsert(
        {
            "firebase_uid": uid,
            "phone": phone,
            "profile_complete": False,
            "onboarding_next": "role-selection",
        },
        on_conflict="firebase_uid",
    ).execute()


def _try_ensure_supabase_profile(uid: str, phone: str) -> None:
    try:
        _ensure_supabase_profile(uid, phone)
    except Exception as e:
        print(f"Skipping Supabase profile sync for dev auth: {e}")


def _ensure_supabase_auth_claim(uid: str) -> None:
    """Prepare Firebase users for future Supabase Third-Party Auth."""
    user = auth.get_user(uid)
    claims = user.custom_claims or {}
    if claims.get("role") != "authenticated":
        auth.set_custom_user_claims(uid, {**claims, "role": "authenticated"})


def _dev_uid_for_phone(phone: str) -> str:
    digest = hashlib.sha256(phone.encode("utf-8")).hexdigest()[:24]
    return f"dev_{digest}"


def _create_dev_auth_session(phone: str) -> Tuple[str, str]:
    uid = _dev_uid_for_phone(phone)
    token = f"dev_{secrets.token_urlsafe(32)}"
    store_custom_token(token, uid)
    return uid, token


def _dev_auth_response(phone: str) -> dict:
    uid, token = _create_dev_auth_session(phone)
    _try_ensure_supabase_profile(uid, phone)
    otp_store.pop(phone, None)
    return {
        "message": "OTP verified with dev auth",
        "uid": uid,
        "token": token,
    }

@router.post("/signin")
def sign_in(request: SignInRequest):
    """Send OTP to phone number"""
    try:
        phone = request.phone
        # Generate 4-digit OTP
        otp = str(secrets.randbelow(10000)).zfill(4)
        
        # Store OTP with timestamp (valid for 5 minutes)
        otp_store[phone] = {
            "otp": otp,
            "timestamp": time.time(),
            "attempts": 0
        }
        
        # TODO: Send OTP via SMS service (Twilio, AWS SNS, etc.)
        print(f"OTP for {phone}: {otp}")
        
        return {
            "message": "OTP sent successfully",
            "otp": otp
        }
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.post("/verify-otp")
def verify_otp(request: OTPVerifyRequest):
    """Verify OTP and create/get user"""
    try:
        phone = request.phone
        otp = request.otp
        
        # Check if OTP exists and is valid
        if phone not in otp_store:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="OTP not found")
        
        otp_data = otp_store[phone]
        
        # Check if OTP expired (5 minutes)
        if time.time() - otp_data["timestamp"] > 300:
            del otp_store[phone]
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="OTP expired")
        
        # Check if OTP matches
        if otp_data["otp"] != otp:
            otp_data["attempts"] += 1
            if otp_data["attempts"] >= 3:
                del otp_store[phone]
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Too many attempts")
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP")
        
        # OTP verified, create or get user
        try:
            # Try to get existing user
            user = auth.get_user_by_phone_number(f"+91{phone}")
            uid = user.uid
        except auth.UserNotFoundError:
            try:
                # Create new user
                user = auth.create_user(phone_number=f"+91{phone}")
                uid = user.uid
            except Exception:
                if not settings.allow_custom_token_auth:
                    raise
                return _dev_auth_response(phone)
        except Exception:
            if not settings.allow_custom_token_auth:
                raise
            return _dev_auth_response(phone)

        try:
            _ensure_supabase_auth_claim(uid)
            _ensure_supabase_profile(uid, phone)

            # Generate custom token for Flutter app
            custom_token = auth.create_custom_token(uid)
            token = custom_token.decode("utf-8")
            store_custom_token(token, uid)
        except Exception:
            if not settings.allow_custom_token_auth:
                raise
            return _dev_auth_response(phone)
        
        # Clean up OTP
        otp_store.pop(phone, None)
        
        return {
            "message": "OTP verified",
            "uid": uid,
            "token": token
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.post("/refresh-token")
def refresh_token(uid: str):
    """Generate new custom token"""
    try:
        custom_token = auth.create_custom_token(uid)
        token = custom_token.decode("utf-8")
        store_custom_token(token, uid)
        return {"token": token}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
