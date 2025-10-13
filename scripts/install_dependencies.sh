#!/bin/bash

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    yum update -y
    amazon-linux-extras install docker -y || yum install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -a -G docker ec2-user
fi

# Install AWS CLI if not already installed
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    yum install -y aws-cli
fi

# Create application directory
mkdir -p /opt/linkbox-backend
chown ec2-user:ec2-user /opt/linkbox-backend

echo "Dependencies installed successfully"