from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from firebase_admin import db
import time

router = APIRouter()

class LocationUpdate(BaseModel):
    latitude: float
    longitude: float

@router.post("/update")
def update_location(uid: str, location: LocationUpdate):
    """Update driver's current location"""
    try:
        location_ref = db.reference(f"users/{uid}/current_location")
        location_ref.set({
            "latitude": location.latitude,
            "longitude": location.longitude,
            "updated_at": int(time.time())
        })
        return {"message": "Location updated"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.get("/{uid}")
def get_location(uid: str):
    """Get driver's current location"""
    try:
        location_ref = db.reference(f"users/{uid}/current_location")
        location = location_ref.get()
        if not location:
            return {"message": "Location not available"}
        return location
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
