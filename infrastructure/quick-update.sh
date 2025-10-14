#!/bin/bash

# ==============================================================================
# Quick Stack Update Script
# ==============================================================================
# Quickly updates infrastructure without changing parameters
#
# Usage:
#   ./quick-update.sh [stack-name] [templates-bucket]
#
# Example:
#   ./quick-update.sh linkbox-master linkbox-cfn-templates
# ==============================================================================

set -e

# Configuration
STACK_NAME="${1:-linkbox-master}"
TEMPLATES_BUCKET="${2:-linkbox-cfn-templates}"

echo "🔄 Quick Stack Update"
echo "===================="
echo "Stack: $STACK_NAME"
echo "Bucket: $TEMPLATES_BUCKET"
echo ""

# Upload all templates
echo "📤 Uploading templates to S3..."
aws s3 cp main.yml s3://$TEMPLATES_BUCKET/main.yml
aws s3 cp 01-network.yml s3://$TEMPLATES_BUCKET/01-network.yml
aws s3 cp 02-database.yml s3://$TEMPLATES_BUCKET/02-database.yml
aws s3 cp 03-backend.yml s3://$TEMPLATES_BUCKET/03-backend.yml
aws s3 cp 04-frontend.yml s3://$TEMPLATES_BUCKET/04-frontend.yml
aws s3 cp 05-cicd.yml s3://$TEMPLATES_BUCKET/05-cicd.yml
echo "✅ Templates uploaded"
echo ""

# Get current parameters
echo "📋 Using existing parameters..."
PARAMS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Parameters[*].ParameterKey' \
    --output text)

PARAM_STRING=""
for param in $PARAMS; do
    PARAM_STRING="$PARAM_STRING ParameterKey=$param,UsePreviousValue=true"
done

# Update stack
echo "🚀 Updating CloudFormation stack..."
aws cloudformation update-stack \
    --stack-name $STACK_NAME \
    --template-url https://$TEMPLATES_BUCKET.s3.amazonaws.com/main.yml \
    --parameters $PARAM_STRING \
    --capabilities CAPABILITY_IAM

echo "✅ Update initiated"
echo ""
echo "⏳ Waiting for stack update to complete (this may take 10-20 minutes)..."

# Wait for completion
if aws cloudformation wait stack-update-complete --stack-name $STACK_NAME 2>/dev/null; then
    echo ""
    echo "✅ Stack updated successfully!"
    echo ""
    echo "📊 Stack outputs:"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --query 'Stacks[0].Outputs[*].{Key:OutputKey,Value:OutputValue}' \
        --output table
else
    echo ""
    echo "❌ Stack update failed!"
    echo "Check the CloudFormation console for details"
    exit 1
fi

