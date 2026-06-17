from datetime import datetime, timezone
import os
import time

from fastapi import APIRouter, File, HTTPException, UploadFile, status

from config import settings
from onboarding import update_onboarding_progress
from supabase_config import get_supabase

router = APIRouter()


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.post("/upload")
async def upload_document(
    uid: str,
    file: UploadFile = File(...),
    doc_type: str = "license",
):
    """Upload driver document to Supabase Storage."""
    try:
        contents = await file.read()
        _, extension = os.path.splitext(file.filename or "")
        extension = extension or ".pdf"
        storage_path = f"{uid}/{doc_type}_{int(time.time())}{extension}"

        get_supabase().storage.from_(settings.supabase_storage_bucket).upload(
            path=storage_path,
            file=contents,
            file_options={
                "content-type": file.content_type or "application/octet-stream",
                "upsert": "false",
            },
        )

        metadata = {
            "driver_uid": uid,
            "doc_type": doc_type,
            "storage_path": storage_path,
            "status": "pending",
            "uploaded_at": _now(),
        }
        response = get_supabase().table("documents").insert(metadata).execute()
        document = response.data[0] if response.data else metadata
        onboarding = update_onboarding_progress(uid, {"documents_uploaded": True})

        return {
            "message": "Document uploaded successfully",
            "filename": storage_path,
            "document": document,
            "onboarding": onboarding,
        }
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/{uid}")
def get_documents(uid: str):
    """Get all documents for driver."""
    try:
        response = (
            get_supabase()
            .table("documents")
            .select("*")
            .eq("driver_uid", uid)
            .order("uploaded_at", desc=True)
            .execute()
        )
        return response.data or []
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.patch("/{uid}/verify/{doc_id}")
def verify_document(uid: str, doc_id: str, status_update: str = "verified"):
    """Verify or reject document."""
    try:
        updates = {"status": status_update}
        if status_update == "verified":
            updates["verified_at"] = _now()

        response = (
            get_supabase()
            .table("documents")
            .update(updates)
            .eq("id", doc_id)
            .eq("driver_uid", uid)
            .execute()
        )
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Document not found",
            )
        return {"message": "Document status updated", "document": response.data[0]}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
