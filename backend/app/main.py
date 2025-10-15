import os
from fastapi import FastAPI, HTTPException, APIRouter
from fastapi.middleware.cors import CORSMiddleware
import boto3
from botocore.exceptions import ClientError
from .core.config import get_settings
from .schemas import PresignRequest, PresignResponse, FileRecord
from .utils.id import generate_short_id
from .db import session_scope
from . import models
from sqlalchemy import inspect
from .db import _engine

settings = get_settings()

s3_client = boto3.client('s3', region_name=settings.aws_region)

app = FastAPI(title="LinkBox API", version="0.1.0")
api_router = APIRouter(prefix="/api")

# Allow simple CORS (CloudFront + local dev)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten later
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup():
    # Create tables if not exist (simple bootstrap; for prod use migrations)
    models.Base.metadata.create_all(bind=_engine)
    inspector = inspect(_engine)
    if 'files' not in inspector.get_table_names():
        models.Base.metadata.create_all(bind=_engine)

@api_router.get("/health")
async def health():
    return {"status": "ok"}

@api_router.post("/generate-presigned-url", response_model=PresignResponse)
async def generate_presigned_url(req: PresignRequest):
    file_id = generate_short_id(6)
    s3_key = f"uploads/{file_id}-{req.filename}"

    conditions = [
        {"Content-Type": req.content_type},
        ["content-length-range", 0, settings.max_upload_bytes]
    ]

    fields = {
        "Content-Type": req.content_type
    }

    try:
        presigned = s3_client.generate_presigned_post(
            Bucket=settings.s3_bucket_name,
            Key=s3_key,
            Fields=fields,
            Conditions=conditions,
            ExpiresIn=settings.presigned_expiry_seconds
        )
    except ClientError as e:
        raise HTTPException(status_code=500, detail="Failed to create presigned URL") from e

    # Persist metadata (size may be unknown until client sends; accept provided size hint)
    with session_scope() as session:
        record = models.FileObject(
            id=file_id,
            original_filename=req.filename,
            s3_key=s3_key,
            content_type=req.content_type,
            size_bytes=req.size_bytes,
        )
        session.add(record)

    # Generate presigned download URL (temporary, expires in 5 minutes)
    try:
        download_url = s3_client.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': settings.s3_bucket_name,
                'Key': s3_key
            },
            ExpiresIn=300  # 5 minutes
        )
    except ClientError as e:
        # Fallback to file ID based URL
        download_url = f"/api/files/{file_id}/download"

    return PresignResponse(
        upload_url=presigned['url'],
        form_fields=presigned['fields'],
        file_id=file_id,
        download_url=download_url,
    )

@api_router.get("/files/{file_id}", response_model=FileRecord)
async def get_file_metadata(file_id: str):
    from sqlalchemy import select
    from .db import SessionLocal
    with SessionLocal() as session:
        result = session.execute(select(models.FileObject).where(models.FileObject.id == file_id)).scalars().first()
        if not result:
            raise HTTPException(status_code=404, detail="Not found")
        return result

@api_router.get("/files/{file_id}/download")
async def get_download_url(file_id: str):
    """Generate a fresh presigned download URL for a file"""
    from sqlalchemy import select
    from .db import SessionLocal
    from fastapi.responses import RedirectResponse
    
    with SessionLocal() as session:
        result = session.execute(select(models.FileObject).where(models.FileObject.id == file_id)).scalars().first()
        if not result:
            raise HTTPException(status_code=404, detail="File not found")
        
        # Generate presigned URL
        try:
            download_url = s3_client.generate_presigned_url(
                'get_object',
                Params={
                    'Bucket': settings.s3_bucket_name,
                    'Key': result.s3_key
                },
                ExpiresIn=3600  # 1 hour for on-demand downloads
            )
            # Redirect to the presigned URL
            return RedirectResponse(url=download_url)
        except ClientError as e:
            raise HTTPException(status_code=500, detail="Failed to generate download URL") from e

# Include the API router
app.include_router(api_router)
