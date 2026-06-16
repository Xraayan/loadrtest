from fastapi import APIRouter, Depends, HTTPException, status
from firebase_admin import db

from dependencies import CurrentUser, get_current_user, require_current_user_uid

router = APIRouter()


PAID_STATUSES = {"completed", "paid"}
ACTIVE_STATUSES = {"accepted", "pending", "in_progress"}


@router.get("/{uid}")
def get_ledger(uid: str, current_user: CurrentUser = Depends(get_current_user)):
    """Get earnings ledger summary and trip entries."""
    require_current_user_uid(uid, current_user)
    try:
        all_trips = db.reference("trips").get()
        if not all_trips:
            return {
                "uid": uid,
                "summary": {
                    "total_earned": 0,
                    "pending_amount": 0,
                    "completed_trips": 0,
                    "active_trips": 0,
                },
                "entries": [],
            }

        entries = []
        summary = {
            "total_earned": 0,
            "pending_amount": 0,
            "completed_trips": 0,
            "active_trips": 0,
        }

        for trip_id, trip in all_trips.items():
            if trip.get("driver_id") != uid:
                continue

            amount = float(trip.get("amount") or 0)
            trip_status = trip.get("status", "pending")
            if trip_status in PAID_STATUSES:
                summary["total_earned"] += amount
                summary["completed_trips"] += 1
            elif trip_status in ACTIVE_STATUSES:
                summary["pending_amount"] += amount
                summary["active_trips"] += 1

            entries.append({
                "trip_id": trip_id,
                "title": trip.get("title") or f"{trip.get('pickup_location')} to {trip.get('dropoff_location')}",
                "amount": amount,
                "status": trip_status,
                "created_at": trip.get("created_at"),
            })

        entries.sort(key=lambda item: item.get("created_at") or 0, reverse=True)
        return {"uid": uid, "summary": summary, "entries": entries}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
