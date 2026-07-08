from pydantic_settings import BaseSettings
from typing import Optional

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
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"

settings = Settings()
