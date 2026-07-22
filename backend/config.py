from typing import Optional
from pathlib import Path

from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    firebase_credentials_path: str = "./firebase-credentials.json"
    firebase_database_url: Optional[str] = None
    firebase_storage_bucket: Optional[str] = None
    supabase_url: Optional[str] = None
    supabase_service_role_key: Optional[str] = None
    supabase_storage_bucket: str = "driver-documents"
    api_port: int = 8000
    api_host: str = "0.0.0.0"
    allow_custom_token_auth: bool = True
    seed_firebase_data: bool = False
    geoapify_api_key: Optional[str] = None
    resend_api_key: Optional[str] = None
    resend_from_email: Optional[str] = None
    email_strict_send: bool = False
    smtp_host: Optional[str] = None
    smtp_port: int = 587
    smtp_username: Optional[str] = None
    smtp_password: Optional[str] = None
    smtp_from_email: Optional[str] = None
    smtp_use_tls: bool = True
    
    class Config:
        env_file = Path(__file__).with_name(".env")
        env_file_encoding = "utf-8"
        extra = "ignore"

settings = Settings()
