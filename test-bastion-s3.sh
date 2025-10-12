#!/bin/bash

# This script helps you quickly connect to the bastion host and test S3 access
# Run this from your local machine

if [ $# -lt 2 ]; then
    echo "Usage: $0 <stack-name> <path-to-ssh-key>"
    echo "Example: $0 my-stack ~/.ssh/my-key.pem"
    exit 1
fi

STACK_NAME="$1"
SSH_KEY="$2"
REGION="us-east-1"

echo "=========================================="
echo "Bastion S3 Access Test Helper"
echo "=========================================="
echo ""

# Get bastion host IP and bucket name
echo "Fetching stack information..."
BASTION_IP=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`BastionHostPublicIP`].OutputValue' \
  --output text \
  --region $REGION)

if [ -z "$BASTION_IP" ]; then
    echo "Error: Could not get Bastion Host IP from stack $STACK_NAME"
    exit 1
fi

echo "Bastion Host IP: $BASTION_IP"
echo ""

# Get environment name to construct bucket name
ENV_NAME=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Parameters[?ParameterKey==`EnvironmentName`].ParameterValue' \
  --output text \
  --region $REGION)

BUCKET_NAME="${ENV_NAME}-website-bucket"
echo "Expected S3 Bucket: $BUCKET_NAME"
echo ""

# Create a test script to run on the bastion
TEST_SCRIPT=$(cat << 'EOFSCRIPT'
#!/bin/bash

BUCKET_NAME="BUCKET_NAME_PLACEHOLDER"

echo "=========================================="
echo "Installing AWS CLI if needed..."
echo "=========================================="
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    sudo apt-get update -y
    sudo apt install unzip -y
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
else
    echo "AWS CLI already installed"
fi

echo ""
echo "=========================================="
echo "Verifying IAM Role"
echo "=========================================="
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
ROLE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)

if [ -n "$ROLE" ]; then
    echo "✓ IAM Role attached: $ROLE"
else
    echo "✗ No IAM Role attached!"
    exit 1
fi

echo ""
echo "=========================================="
echo "Testing S3 Access"
echo "=========================================="

# Test 1: List bucket
echo ""
echo "Test 1: Listing bucket contents..."
if aws s3 ls s3://$BUCKET_NAME/ 2>&1; then
    echo "✓ List bucket: SUCCESS"
else
    echo "✗ List bucket: FAILED"
fi

# Test 2: Upload file
echo ""
echo "Test 2: Uploading test file..."
TEST_FILE="bastion-test-$(date +%s).txt"
echo "Test from bastion host at $(date)" > /tmp/$TEST_FILE
if aws s3 cp /tmp/$TEST_FILE s3://$BUCKET_NAME/$TEST_FILE 2>&1; then
    echo "✓ Upload file: SUCCESS"
    UPLOAD_SUCCESS=true
else
    echo "✗ Upload file: FAILED"
    UPLOAD_SUCCESS=false
fi

# Test 3: Download file
if [ "$UPLOAD_SUCCESS" = true ]; then
    echo ""
    echo "Test 3: Downloading test file..."
    if aws s3 cp s3://$BUCKET_NAME/$TEST_FILE /tmp/downloaded-$TEST_FILE 2>&1; then
        echo "✓ Download file: SUCCESS"
        echo "File content:"
        cat /tmp/downloaded-$TEST_FILE
    else
        echo "✗ Download file: FAILED"
    fi
    
    # Test 4: Delete file
    echo ""
    echo "Test 4: Deleting test file..."
    if aws s3 rm s3://$BUCKET_NAME/$TEST_FILE 2>&1; then
        echo "✓ Delete file: SUCCESS"
    else
        echo "✗ Delete file: FAILED"
    fi
fi

# Cleanup
rm -f /tmp/$TEST_FILE /tmp/downloaded-$TEST_FILE

echo ""
echo "=========================================="
echo "Testing Complete!"
echo "=========================================="
echo ""
echo "You can manually test with:"
echo "  aws s3 ls s3://$BUCKET_NAME/"
echo "  aws s3 cp <file> s3://$BUCKET_NAME/"
echo "  aws s3 cp s3://$BUCKET_NAME/<file> <local-file>"
echo ""
EOFSCRIPT
)

# Replace placeholder with actual bucket name
TEST_SCRIPT="${TEST_SCRIPT//BUCKET_NAME_PLACEHOLDER/$BUCKET_NAME}"

echo "Connecting to bastion host and running S3 tests..."
echo "=========================================="
echo ""

# Connect and run the test
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$BASTION_IP "bash -s" << EOF
$TEST_SCRIPT
EOF

echo ""
echo "=========================================="
echo "Test completed!"
echo ""
echo "To manually connect to the bastion host:"
echo "  ssh -i $SSH_KEY ubuntu@$BASTION_IP"
echo "=========================================="

