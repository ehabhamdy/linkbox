from functools import lru_cache
from pydantic import AnyUrl
from pydantic_settings import BaseSettings
from typing import Optional
import os

class Settings(BaseSettings):
    environment: str = "dev"
    aws_region: str = "us-east-1"
    s3_bucket_name: str = "linkbox-dev-bucket"
    database_url: AnyUrl = "postgresql://linkbox_user:linkbox_password@localhost:5432/linkbox_dev"  # type: ignore
    presigned_expiry_seconds: int = 3600
    max_upload_bytes: int = 10 * 1024 * 1024  # 10MB
    cloudfront_download_domain: Optional[str] = None  # e.g. dxxxxx.cloudfront.net
    
    # IAM Database Authentication
    use_iam_db_auth: bool = False  # Set to True to use IAM auth
    db_iam_user: Optional[str] = None  # IAM-enabled database user (e.g., linkbox_iam_user)
    db_endpoint: Optional[str] = None  # RDS endpoint (for IAM auth)
    db_name: Optional[str] = None  # Database name (for IAM auth)
    db_port: int = 5432  # Database port

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": False,
    }

@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    
    # Override database_url with IAM auth if enabled
    if settings.use_iam_db_auth and settings.environment == "production":
        from ..utils.db_iam_auth import build_iam_connection_string
        
        # Build connection string with IAM token
        if settings.db_endpoint and settings.db_name and settings.db_iam_user:
            settings.database_url = build_iam_connection_string(
                db_endpoint=settings.db_endpoint,
                db_name=settings.db_name,
                db_user=settings.db_iam_user,
                port=settings.db_port,
                region=settings.aws_region
            )  # type: ignore
    
    return settings
