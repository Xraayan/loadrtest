from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from firebase_admin import auth
import secrets
import time

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


def _ensure_supabase_auth_claim(uid: str) -> None:
    """Prepare Firebase users for future Supabase Third-Party Auth."""
    user = auth.get_user(uid)
    claims = user.custom_claims or {}
    if claims.get("role") != "authenticated":
        auth.set_custom_user_claims(uid, {**claims, "role": "authenticated"})

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
            # Create new user
            user = auth.create_user(phone_number=f"+91{phone}")
            uid = user.uid

        _ensure_supabase_auth_claim(uid)
        _ensure_supabase_profile(uid, phone)
        
        # Generate custom token for Flutter app
        custom_token = auth.create_custom_token(uid)
        token = custom_token.decode("utf-8")
        store_custom_token(token, uid)
        
        # Clean up OTP
        del otp_store[phone]
        
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
