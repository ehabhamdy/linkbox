#!/bin/bash

# Read the image URI from the build artifacts
cd /opt/linkbox-backend

if [ -f imagedefinitions.json ]; then
    IMAGE_URI=$(cat imagedefinitions.json | grep -o '"ImageURI":"[^"]*' | grep -o '[^"]*$')
    echo "Using image: $IMAGE_URI"
else
    echo "Error: imagedefinitions.json not found"
    exit 1
fi

# Get AWS region
AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $IMAGE_URI

# Pull the new image
echo "Pulling Docker image..."
docker pull $IMAGE_URI

# Get environment variables from Parameter Store or use defaults
S3_BUCKET_NAME=${S3_BUCKET_NAME:-"linkbox-uploads"}
DATABASE_URL=${DATABASE_URL:-"postgresql://user:pass@localhost:5432/linkbox"}

# Start the new container
echo "Starting new container..."
docker run -d \
    --name linkbox-backend \
    -p 80:80 \
    -e S3_BUCKET_NAME=$S3_BUCKET_NAME \
    -e AWS_REGION=$AWS_REGION \
    -e DATABASE_URL=$DATABASE_URL \
    --restart unless-stopped \
    $IMAGE_URI

# Verify container is running
sleep 10
if [ $(docker ps -q -f name=linkbox-backend) ]; then
    echo "Application started successfully"
else
    echo "Error: Application failed to start"
    docker logs linkbox-backend
    exit 1
fi