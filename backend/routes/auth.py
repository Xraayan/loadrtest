from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from firebase_admin import auth, db
import secrets
import time

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
            # Store user data in Firebase RTDB
            db.reference(f"users/{uid}").set({
                "phone": phone,
                "created_at": int(time.time()),
                "profile_complete": False
            })
        
        # Generate custom token for Flutter app
        custom_token = auth.create_custom_token(uid)
        
        # Clean up OTP
        del otp_store[phone]
        
        return {
            "message": "OTP verified",
            "uid": uid,
            "token": custom_token.decode('utf-8')
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
        return {"token": custom_token.decode('utf-8')}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
