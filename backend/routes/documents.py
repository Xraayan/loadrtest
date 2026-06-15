from fastapi import APIRouter, HTTPException, status, UploadFile, File
from firebase_admin import db, storage
import time
import os

router = APIRouter()

@router.post("/upload")
async def upload_document(uid: str, file: UploadFile = File(...), doc_type: str = "license"):
    """Upload driver document"""
    try:
        # Read file
        contents = await file.read()
        
        # Create unique filename
        filename = f"documents/{uid}/{doc_type}_{int(time.time())}.pdf"
        
        # Upload to Firebase Storage
        bucket = storage.bucket()
        blob = bucket.blob(filename)
        blob.upload_from_string(contents)
        
        # Store metadata in RTDB
        doc_ref = db.reference(f"users/{uid}/documents")
        doc_ref.push().set({
            "type": doc_type,
            "filename": filename,
            "uploaded_at": int(time.time()),
            "status": "pending"
        })
        
        return {
            "message": "Document uploaded successfully",
            "filename": filename
        }
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.get("/{uid}")
def get_documents(uid: str):
    """Get all documents for driver"""
    try:
        doc_ref = db.reference(f"users/{uid}/documents")
        documents = doc_ref.get()
        if not documents:
            return []
        return list(documents.values())
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.patch("/{uid}/verify/{doc_id}")
def verify_document(uid: str, doc_id: str, status_update: str = "verified"):
    """Verify/reject document"""
    try:
        doc_ref = db.reference(f"users/{uid}/documents/{doc_id}")
        doc_ref.update({"status": status_update})
        return {"message": "Document status updated"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
