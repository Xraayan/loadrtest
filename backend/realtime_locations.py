from firebase_config import get_db


def sync_driver_location(uid: str, data: dict) -> bool:
    """Mirror the latest driver location into Firebase Realtime Database."""
    payload = {
        "driver_uid": uid,
        "latitude": data.get("latitude"),
        "longitude": data.get("longitude"),
        "is_active": data.get("is_active", True),
        "updated_at": data.get("updated_at"),
    }
    try:
        get_db().child("driver_locations").child(uid).set(payload)
        return True
    except Exception as exc:
        print(f"Firebase driver location sync failed for {uid}: {exc}")
        return False
