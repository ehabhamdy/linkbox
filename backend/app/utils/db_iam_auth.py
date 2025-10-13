"""
RDS IAM Database Authentication Helper

This module provides helper functions to connect to RDS PostgreSQL using IAM authentication.
Instead of using a password, EC2 instances generate a temporary auth token using their IAM role.

Benefits:
- No passwords to manage
- Tokens auto-expire (15 minutes)
- More secure (uses IAM role)
- All access logged to CloudTrail
"""

import boto3
from typing import Optional
import logging

logger = logging.getLogger(__name__)


def generate_iam_auth_token(
    db_endpoint: str,
    port: int,
    db_user: str,
    region: Optional[str] = None
) -> str:
    """
    Generate an IAM authentication token for RDS.
    
    Args:
        db_endpoint: RDS endpoint (e.g., xxx.rds.amazonaws.com)
        port: Database port (usually 5432 for PostgreSQL)
        db_user: Database username to authenticate as
        region: AWS region (auto-detected if None)
    
    Returns:
        Temporary auth token (valid for 15 minutes)
    
    Raises:
        ClientError: If unable to generate token
    
    Example:
        >>> token = generate_iam_auth_token(
        ...     'mydb.rds.amazonaws.com',
        ...     5432,
        ...     'linkbox_iam_user',
        ...     'us-east-1'
        ... )
        >>> # Use token as password in connection string
        >>> conn_str = f"postgresql://{user}:{token}@{endpoint}:5432/linkbox"
    """
    try:
        if region is None:
            # Auto-detect region from instance metadata
            session = boto3.Session()
            region = session.region_name or 'us-east-1'
        
        logger.info(f"Generating IAM auth token for {db_user}@{db_endpoint}")
        
        client = boto3.client('rds', region_name=region)
        
        token = client.generate_db_auth_token(
            DBHostname=db_endpoint,
            Port=port,
            DBUsername=db_user,
            Region=region
        )
        
        logger.info("IAM auth token generated successfully")
        return token
        
    except Exception as e:
        logger.error(f"Failed to generate IAM auth token: {e}")
        raise


def build_iam_connection_string(
    db_endpoint: str,
    db_name: str,
    db_user: str,
    port: int = 5432,
    region: Optional[str] = None,
    ssl_mode: str = 'require'
) -> str:
    """
    Build a PostgreSQL connection string using IAM authentication.
    
    Args:
        db_endpoint: RDS endpoint
        db_name: Database name
        db_user: IAM-enabled database user
        port: Database port (default: 5432)
        region: AWS region (auto-detected if None)
        ssl_mode: SSL mode (default: 'require')
    
    Returns:
        PostgreSQL connection string with IAM token
    
    Example:
        >>> conn_str = build_iam_connection_string(
        ...     'mydb.rds.amazonaws.com',
        ...     'linkbox',
        ...     'linkbox_iam_user'
        ... )
        >>> # Use with SQLAlchemy
        >>> engine = create_engine(conn_str)
    """
    # Generate token
    token = generate_iam_auth_token(db_endpoint, port, db_user, region)
    
    # Build connection string
    # Note: Token is used as the password
    conn_str = (
        f"postgresql://{db_user}:{token}@{db_endpoint}:{port}/{db_name}"
        f"?sslmode={ssl_mode}"
    )
    
    return conn_str


def is_iam_auth_enabled() -> bool:
    """
    Check if IAM authentication is enabled (based on environment).
    
    Returns:
        True if IAM auth should be used, False otherwise
    """
    import os
    
    # Use IAM auth if explicitly enabled or in production
    use_iam = os.getenv('USE_IAM_DB_AUTH', '').lower() in ('true', '1', 'yes')
    is_production = os.getenv('ENVIRONMENT', '').lower() == 'production'
    
    return use_iam or is_production

