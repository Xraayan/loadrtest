import json
import os

import firebase_admin
from firebase_admin import auth, credentials, db

from config import settings


def init_firebase():
    """Initialize Firebase Admin for auth."""
    try:
        if firebase_admin._apps:
            return True

        if settings.firebase_credentials_json:
            firebase_info = json.loads(settings.firebase_credentials_json)
            cred = credentials.Certificate(firebase_info)
        else:
            credentials_path = settings.firebase_credentials_path
            if not os.path.exists(credentials_path):
                print(f"Firebase credentials not found at {credentials_path}")
                print("Proceeding without Firebase for now.\n")
                return False
            cred = credentials.Certificate(credentials_path)

        firebase_admin.initialize_app(
            cred,
            {"databaseURL": settings.firebase_database_url},
        )
        print("Firebase initialized successfully\n")
        return True
    except Exception as e:
        print(f"Firebase initialization failed: {str(e)}")
        print("Proceeding without Firebase for now.\n")
        return False


def get_db():
    return db.reference()


def get_auth():
    return auth


def create_user(phone: str, password: str):
    """Create Firebase user with phone and password."""
    try:
        user = auth.create_user(phone_number=f"+91{phone}", password=password)
        return user.uid
    except Exception as e:
        raise Exception(f"Error creating user: {str(e)}")


def verify_password(uid: str, password: str):
    """Verify user password."""
    return None


def get_user_by_phone(phone: str):
    """Get user by phone number."""
    try:
        user = auth.get_user_by_phone_number(f"+91{phone}")
        return user.uid
    except auth.UserNotFoundError:
        return None
