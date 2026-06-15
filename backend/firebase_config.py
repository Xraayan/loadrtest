import firebase_admin
from firebase_admin import credentials, db, auth
from config import settings
import os

# Initialize Firebase
def init_firebase():
    try:
        if not firebase_admin._apps:
            credentials_path = settings.firebase_credentials_path
            
            if not os.path.exists(credentials_path):
                print(f"  Firebase credentials not found at {credentials_path}")
                print("To enable Firebase:")
                print("1. Create a Firebase project at https://firebase.google.com/")
                print("2. Download service account key from Project Settings")
                print("3. Save as 'firebase-credentials.json' in the backend folder")
                print("4. Update .env with your Firebase URLs")
                print("\nProceeding without Firebase for now...\n")
                return False
            
            cred = credentials.Certificate(credentials_path)
            firebase_admin.initialize_app(cred, {
                'databaseURL': settings.firebase_database_url
            })
            print("✓ Firebase initialized successfully\n")
            return True
    except Exception as e:
        print(f"  Firebase initialization failed: {str(e)}")
        print("Proceeding without Firebase for now...\n")
        return False

# Get Firebase references
def get_db():
    return db.reference()

def get_auth():
    return auth

# Helper functions
def create_user(phone: str, password: str):
    """Create Firebase user with phone and password"""
    try:
        user = auth.create_user(
            phone_number=f"+91{phone}",
            password=password
        )
        return user.uid
    except Exception as e:
        raise Exception(f"Error creating user: {str(e)}")

def verify_password(uid: str, password: str):
    """Verify user password (use sign in with email/password instead)"""
    pass

def get_user_by_phone(phone: str):
    """Get user by phone number"""
    try:
        user = auth.get_user_by_phone_number(f"+91{phone}")
        return user.uid
    except auth.UserNotFoundError:
        return None
