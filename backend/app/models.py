from sqlalchemy import Column, String, DateTime, BigInteger
from sqlalchemy.orm import declarative_base
from datetime import datetime, timezone

Base = declarative_base()

class FileObject(Base):
    __tablename__ = 'files'
    id = Column(String(12), primary_key=True, index=True)  # short share id
    original_filename = Column(String(512), nullable=False)
    s3_key = Column(String(1024), nullable=False, unique=True)
    content_type = Column(String(255), nullable=True)
    size_bytes = Column(BigInteger, nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
