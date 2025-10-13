#!/bin/bash
set -e

# Setup IAM Database User for RDS PostgreSQL
# This script creates a database user that authenticates using IAM instead of a password
# Run this once after RDS is created

echo "Setting up IAM database user for RDS..."

# Get parameters
ENVIRONMENT_NAME=${1:-linkbox}
REGION=${2:-us-east-1}

echo "Environment: $ENVIRONMENT_NAME"
echo "Region: $REGION"

# Get DB configuration from SSM
DB_ENDPOINT=$(aws ssm get-parameter \
    --name "/${ENVIRONMENT_NAME}/db-endpoint" \
    --region $REGION \
    --query Parameter.Value \
    --output text)

DB_NAME=$(aws ssm get-parameter \
    --name "/${ENVIRONMENT_NAME}/db-name" \
    --region $REGION \
    --query Parameter.Value \
    --output text)

DB_MASTER_USER=$(aws ssm get-parameter \
    --name "/${ENVIRONMENT_NAME}/db-username" \
    --region $REGION \
    --query Parameter.Value \
    --output text)

DB_MASTER_PASSWORD=$(aws ssm get-parameter \
    --name "/${ENVIRONMENT_NAME}/db-password" \
    --with-decryption \
    --region $REGION \
    --query Parameter.Value \
    --output text)

IAM_DB_USER="${ENVIRONMENT_NAME}_iam_user"

echo "Database endpoint: $DB_ENDPOINT"
echo "Database name: $DB_NAME"
echo "IAM user to create: $IAM_DB_USER"

# Create IAM database user using master credentials
echo "Connecting to database with master credentials..."

export PGPASSWORD=$DB_MASTER_PASSWORD

psql -h $DB_ENDPOINT -U $DB_MASTER_USER -d $DB_NAME << EOF
-- Create IAM authenticated user
CREATE USER ${IAM_DB_USER} WITH LOGIN;

-- Grant rds_iam role (required for IAM authentication)
GRANT rds_iam TO ${IAM_DB_USER};

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${IAM_DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${IAM_DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${IAM_DB_USER};

-- Allow future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${IAM_DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${IAM_DB_USER};

-- Verify
\du ${IAM_DB_USER}
EOF

unset PGPASSWORD

echo "✅ IAM database user created successfully!"
echo ""
echo "User: $IAM_DB_USER"
echo "Authentication: IAM (no password)"
echo ""
echo "To use this user, your EC2 instances will:"
echo "1. Generate an auth token using their IAM role"
echo "2. Connect to RDS using the token (valid for 15 minutes)"
echo "3. No password required!"

