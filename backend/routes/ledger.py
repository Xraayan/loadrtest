from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import CurrentUser, get_current_user, require_current_user_uid
from supabase_config import get_supabase

router = APIRouter()


PAID_STATUSES = {"completed", "paid"}
ACTIVE_STATUSES = {"accepted", "pending", "in_progress"}


@router.get("/{uid}")
def get_ledger(uid: str, current_user: CurrentUser = Depends(get_current_user)):
    """Get earnings ledger summary and trip entries."""
    require_current_user_uid(uid, current_user)
    try:
        response = (
            get_supabase()
            .table("trips")
            .select("*")
            .eq("driver_uid", uid)
            .order("created_at", desc=True)
            .execute()
        )
        trips = response.data or []
        summary = {
            "total_earned": 0,
            "pending_amount": 0,
            "completed_trips": 0,
            "active_trips": 0,
        }
        entries = []

        for trip in trips:
            amount = float(trip.get("amount") or 0)
            trip_status = trip.get("status", "pending")
            if trip_status in PAID_STATUSES:
                summary["total_earned"] += amount
                summary["completed_trips"] += 1
            elif trip_status in ACTIVE_STATUSES:
                summary["pending_amount"] += amount
                summary["active_trips"] += 1

            entries.append(
                {
                    "trip_id": trip.get("id"),
                    "title": f"{trip.get('pickup_location')} to {trip.get('dropoff_location')}",
                    "amount": amount,
                    "status": trip_status,
                    "created_at": trip.get("created_at"),
                }
            )

        return {"uid": uid, "summary": summary, "entries": entries}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

