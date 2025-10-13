from functools import lru_cache
from pydantic import AnyUrl
from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    environment: str = "dev"
    aws_region: str = "us-east-1"
    s3_bucket_name: str = "linkbox-dev-bucket"
    database_url: AnyUrl = "postgresql://linkbox_user:linkbox_password@localhost:5432/linkbox_dev"  # type: ignore
    presigned_expiry_seconds: int = 3600
    max_upload_bytes: int = 10 * 1024 * 1024  # 10MB
    cloudfront_download_domain: Optional[str] = None  # e.g. dxxxxx.cloudfront.net

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": False,
    }

@lru_cache
def get_settings() -> Settings:
    return Settings()
