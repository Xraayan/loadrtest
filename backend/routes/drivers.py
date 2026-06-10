from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from firebase_admin import db
from typing import Optional

router = APIRouter()

class DriverProfile(BaseModel):
    name: str
    email: Optional[str] = None
    vehicle_number: Optional[str] = None
    license_number: Optional[str] = None
    current_location: Optional[dict] = None

@router.get("/{uid}")
def get_driver(uid: str):
    """Get driver profile"""
    try:
        driver_ref = db.reference(f"users/{uid}")
        driver = driver_ref.get()
        if not driver:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Driver not found")
        return driver
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.put("/{uid}")
def update_driver(uid: str, driver: DriverProfile):
    """Update driver profile"""
    try:
        driver_ref = db.reference(f"users/{uid}")
        driver_ref.update(driver.dict(exclude_unset=True))
        return {"message": "Driver profile updated"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.post("/{uid}/location")
def update_location(uid: str, location: dict):
    """Update driver's current location"""
    try:
        location_ref = db.reference(f"users/{uid}/current_location")
        location_ref.set(location)
        return {"message": "Location updated"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
