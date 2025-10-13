#!/bin/bash

# Helper script to get the latest Amazon Linux 2 AMI ID for your region

REGION=${1:-$(aws configure get region)}

echo "Getting latest Amazon Linux 2 AMI ID for region: $REGION"

AMI_ID=$(aws ec2 describe-images \
    --region "$REGION" \
    --owners amazon \
    --filters \
        "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
        "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].[ImageId,Description]' \
    --output text)

echo ""
echo "Latest AMI ID: $(echo "$AMI_ID" | awk '{print $1}')"
echo "Description:   $(echo "$AMI_ID" | cut -f2-)"
echo ""
echo "Use this AMI ID in your deployment command."

