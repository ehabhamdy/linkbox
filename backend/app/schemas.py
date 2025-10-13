from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class PresignRequest(BaseModel):
    filename: str
    content_type: str
    size_bytes: Optional[int] = None

class PresignResponse(BaseModel):
    upload_url: str
    form_fields: dict
    file_id: str
    download_url: str

class FileRecord(BaseModel):
    id: str
    original_filename: str
    s3_key: str
    content_type: Optional[str]
    size_bytes: Optional[int]
    created_at: datetime

    class Config:
        orm_mode = True
