import hashlib
import json
import smtplib
import secrets
import time
from email.message import EmailMessage
from typing import Optional, Tuple
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from fastapi import APIRouter, HTTPException, status
from firebase_admin import auth
from pydantic import BaseModel

from config import settings
from dev_auth import store_custom_token
from supabase_config import get_supabase

router = APIRouter()


class SignInRequest(BaseModel):
    email: Optional[str] = None
    phone: Optional[str] = None


class OTPVerifyRequest(BaseModel):
    email: Optional[str] = None
    phone: Optional[str] = None
    otp: str


class SignInResponse(BaseModel):
    message: str
    otp: Optional[str] = None


# Store OTPs temporarily (in production, use Redis)
otp_store = {}
otp_rate_store = {}
_OTP_WINDOW_SECONDS = 15 * 60
_OTP_MAX_REQUESTS = 3
_OTP_COOLDOWN_SECONDS = 30


def _email_from_request(email: Optional[str]) -> str:
    value = (email or "").strip().lower()
    if not value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email is required",
        )
    if "@" not in value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Enter a valid email address",
        )
    return value


def _phone_from_request(phone: Optional[str]) -> Optional[str]:
    value = (phone or "").strip()
    if not value:
        return None
    digits = "".join(ch for ch in value if ch.isdigit())
    if len(digits) < 10 or len(digits) > 15:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Enter a valid phone number",
        )
    return digits


def _check_otp_rate_limit(email: str) -> None:
    now = time.time()
    recent = [
        sent_at
        for sent_at in otp_rate_store.get(email, [])
        if now - sent_at < _OTP_WINDOW_SECONDS
    ]
    if recent and now - recent[-1] < _OTP_COOLDOWN_SECONDS:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Please wait before requesting another OTP",
        )
    if len(recent) >= _OTP_MAX_REQUESTS:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many OTP requests. Try again later.",
        )
    recent.append(now)
    otp_rate_store[email] = recent


def _ensure_supabase_profile(uid: str, email: str, phone: Optional[str] = None) -> None:
    profile = {
        "firebase_uid": uid,
        "email": email,
        "profile_complete": False,
        "onboarding_next": "role-selection",
    }
    if phone:
        profile["phone"] = phone
    get_supabase().table("profiles").upsert(
        profile,
        on_conflict="firebase_uid",
    ).execute()


def _try_ensure_supabase_profile(uid: str, email: str, phone: Optional[str] = None) -> None:
    try:
        _ensure_supabase_profile(uid, email, phone)
    except Exception as e:
        print(f"Skipping Supabase profile sync for dev auth: {e}")


def _ensure_supabase_auth_claim(uid: str) -> None:
    """Prepare Firebase users for future Supabase Third-Party Auth."""
    user = auth.get_user(uid)
    claims = user.custom_claims or {}
    if claims.get("role") != "authenticated":
        auth.set_custom_user_claims(uid, {**claims, "role": "authenticated"})


def _dev_uid_for_email(email: str) -> str:
    digest = hashlib.sha256(email.encode("utf-8")).hexdigest()[:24]
    return f"dev_{digest}"


def _create_dev_auth_session(email: str) -> Tuple[str, str]:
    uid = _dev_uid_for_email(email)
    token = f"dev_{secrets.token_urlsafe(32)}"
    store_custom_token(token, uid)
    return uid, token


def _dev_auth_response(email: str, phone: Optional[str] = None) -> dict:
    uid, token = _create_dev_auth_session(email)
    _try_ensure_supabase_profile(uid, email, phone)
    otp_store.pop(email, None)
    return {
        "message": "OTP verified with dev auth",
        "uid": uid,
        "token": token,
        "email": email,
        "phone": phone,
    }


def _send_otp_email(email: str, otp: str) -> bool:
    if settings.resend_api_key and settings.resend_from_email:
        try:
            payload = json.dumps(
                {
                    "from": settings.resend_from_email,
                    "to": [email],
                    "subject": "Your LoadR OTP",
                    "html": f"<p>Your LoadR OTP is <strong>{otp}</strong>.</p><p>It expires in 5 minutes.</p>",
                }
            ).encode("utf-8")
            request = Request(
                "https://api.resend.com/emails",
                data=payload,
                headers={
                    "Authorization": f"Bearer {settings.resend_api_key}",
                    "Content-Type": "application/json",
                },
                method="POST",
            )
            with urlopen(request, timeout=10):
                pass
            return True
        except HTTPError as e:
            detail = e.read().decode("utf-8", errors="ignore") or str(e)
            if not settings.email_strict_send:
                print(f"Resend rejected OTP email for {email}: {detail}")
                print(f"OTP for {email}: {otp}")
                return False
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Email service rejected the OTP: {detail}",
            )
        except URLError as e:
            if not settings.email_strict_send:
                print(f"Email service unavailable for {email}: {e.reason}")
                print(f"OTP for {email}: {otp}")
                return False
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Email service unavailable: {e.reason}",
            )

    if not settings.smtp_host or not settings.smtp_from_email:
        print(f"OTP for {email}: {otp}")
        return False

    message = EmailMessage()
    message["Subject"] = "Your LoadR OTP"
    message["From"] = settings.smtp_from_email
    message["To"] = email
    message.set_content(f"Your LoadR OTP is {otp}. It expires in 5 minutes.")

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=30) as smtp:
            if settings.smtp_use_tls:
                smtp.starttls()
            if settings.smtp_username and settings.smtp_password:
                smtp.login(settings.smtp_username, settings.smtp_password)
            smtp.send_message(message)
        return True
    except (OSError, smtplib.SMTPException) as error:
        if settings.email_strict_send:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Email service unavailable: {error}",
            ) from error
        print(f"Email service unavailable for {email}: {error}")
        print(f"OTP for {email}: {otp}")
        return False


@router.post("/signin")
def sign_in(request: SignInRequest):
    """Send OTP to email."""
    try:
        email = _email_from_request(request.email)
        phone = _phone_from_request(request.phone)
        _check_otp_rate_limit(email)
        otp = str(secrets.randbelow(10000)).zfill(4)
        
        otp_store[email] = {
            "otp": otp,
            "timestamp": time.time(),
            "attempts": 0,
            "phone": phone,
        }
        
        sent = _send_otp_email(email, otp)
        
        if not sent and not settings.allow_custom_token_auth:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Email service is not configured",
            )

        return {
            "message": "OTP sent successfully",
            "email": email,
            "phone": phone,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/verify-otp")
def verify_otp(request: OTPVerifyRequest):
    """Verify OTP and create/get user"""
    try:
        email = _email_from_request(request.email)
        phone = _phone_from_request(request.phone)
        otp = request.otp
        
        if email not in otp_store:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="OTP not found")
        
        otp_data = otp_store[email]
        
        if time.time() - otp_data["timestamp"] > 300:
            del otp_store[email]
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="OTP expired")
        
        if otp_data["otp"] != otp:
            otp_data["attempts"] += 1
            if otp_data["attempts"] >= 3:
                del otp_store[email]
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Too many attempts")
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP")
        
        try:
            user = auth.get_user_by_email(email)
            uid = user.uid
        except auth.UserNotFoundError:
            try:
                user = auth.create_user(email=email)
                uid = user.uid
            except Exception:
                if not settings.allow_custom_token_auth:
                    raise
                return _dev_auth_response(email, phone)
        except Exception:
            if not settings.allow_custom_token_auth:
                raise
            return _dev_auth_response(email, phone)

        try:
            _ensure_supabase_auth_claim(uid)
            _ensure_supabase_profile(uid, email, phone)

            custom_token = auth.create_custom_token(uid)
            token = custom_token.decode("utf-8")
            store_custom_token(token, uid)
        except Exception:
            if not settings.allow_custom_token_auth:
                raise
            return _dev_auth_response(email, phone)
        
        otp_store.pop(email, None)
        
        return {
            "message": "OTP verified",
            "uid": uid,
            "token": token,
            "email": email,
            "phone": phone,
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
