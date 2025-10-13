#!/bin/bash
set -e

echo "Starting LinkBox backend deployment..."

# Change to application directory
cd /opt/linkbox-backend

# Load environment name if exists
if [ -f .env ]; then
    export $(cat .env | xargs)
fi

if [ -f imagedefinitions.json ]; then
    IMAGE_URI=$(cat imagedefinitions.json | grep -o '"ImageURI":"[^"]*' | grep -o '[^"]*$')
    echo "Using image: $IMAGE_URI"
else
    echo "Error: imagedefinitions.json not found"
    exit 1
fi

# Get AWS region and environment
AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
ENVIRONMENT_NAME=${ENVIRONMENT_NAME:-linkbox}

echo "AWS Region: $AWS_REGION"
echo "Environment: $ENVIRONMENT_NAME"

# Get configuration from SSM Parameter Store
echo "Reading configuration from Parameter Store..."

DB_ENDPOINT=$(aws ssm get-parameter \
    --name "/${ENVIRONMENT_NAME}/db-endpoint" \
    --region $AWS_REGION \
    --query Parameter.Value \
    --output text)

DB_NAME=$(aws ssm get-parameter \
    --name "/${ENVIRONMENT_NAME}/db-name" \
    --region $AWS_REGION \
    --query Parameter.Value \
    --output text)

DB_USERNAME=$(aws ssm get-parameter \
    --name "/${ENVIRONMENT_NAME}/db-username" \
    --region $AWS_REGION \
    --query Parameter.Value \
    --output text)

DB_PASSWORD=$(aws ssm get-parameter \
    --name "/${ENVIRONMENT_NAME}/db-password" \
    --with-decryption \
    --region $AWS_REGION \
    --query Parameter.Value \
    --output text)

# Construct DATABASE_URL
DATABASE_URL="postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_ENDPOINT}:5432/${DB_NAME}"

# Get S3 bucket name (can override from environment)
S3_BUCKET_NAME=${S3_BUCKET_NAME:-"${ENVIRONMENT_NAME}-uploads"}

echo "Configuration loaded:"
echo "  - DB Endpoint: $DB_ENDPOINT"
echo "  - DB Name: $DB_NAME"
echo "  - S3 Bucket: $S3_BUCKET_NAME"

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(echo $IMAGE_URI | cut -d'/' -f1)

# Pull the new image
echo "Pulling Docker image: $IMAGE_URI"
docker pull $IMAGE_URI

# Start the new container
echo "Starting new container..."
docker run -d \
    --name linkbox-backend \
    -p 80:80 \
    -e ENVIRONMENT=production \
    -e AWS_REGION=$AWS_REGION \
    -e S3_BUCKET_NAME=$S3_BUCKET_NAME \
    -e DATABASE_URL=$DATABASE_URL \
    --restart unless-stopped \
    $IMAGE_URI

# Wait and verify container is running
echo "Waiting for application to start..."
sleep 10

if [ $(docker ps -q -f name=linkbox-backend) ]; then
    echo "✅ Application started successfully"
    
    # Test health endpoint
    sleep 5
    if curl -f http://localhost:80/health > /dev/null 2>&1; then
        echo "✅ Health check passed"
    else
        echo "⚠️  Warning: Health check failed, but container is running"
        docker logs --tail 50 linkbox-backend
    fi
else
    echo "❌ Error: Application failed to start"
    docker logs linkbox-backend
    exit 1
fi