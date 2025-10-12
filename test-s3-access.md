# Testing S3 Access from Bastion Host

## Changes Made

✅ Added `IamInstanceProfile: !Ref WebAppInstanceProfile` to the BastionHost
✅ Fixed S3 IAM permissions to properly access objects in the bucket
✅ Added `s3:ListBucket`, `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` permissions

## Deploy the Changes

First, create a changeset to preview the changes:

```bash
./changeset.sh <your-stack-name> servers-and-security-groups/servers.yml servers-and-security-groups/servers-parameters.json
```

This will show you that the BastionHost will be replaced (due to IAM profile change) and the IAM role will be updated.

## Testing S3 Access from Bastion Host

### Step 1: Connect to the Bastion Host

Get the Bastion Host public IP from the stack outputs:

```bash
# Get the Bastion Host public IP
BASTION_IP=$(aws cloudformation describe-stacks \
  --stack-name <your-stack-name> \
  --query 'Stacks[0].Outputs[?OutputKey==`BastionHostPublicIP`].OutputValue' \
  --output text \
  --region us-east-1)

echo "Bastion Host IP: $BASTION_IP"

# SSH into the bastion host
ssh -i /path/to/your-key.pem ubuntu@$BASTION_IP
```

### Step 2: Install AWS CLI (if not already installed)

Once connected to the bastion host:

```bash
# Update package manager
sudo apt-get update -y

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip -y
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

### Step 3: Verify IAM Role is Attached

Check that the instance has the correct IAM role:

```bash
# Get instance metadata to verify IAM role
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/

# This should return the role name, something like: <EnvironmentName>-web-servers
```

### Step 4: Test S3 Access

Now test various S3 operations:

#### List the bucket contents

```bash
# Replace with your actual bucket name
BUCKET_NAME="<your-environment-name>-website-bucket"

# List bucket contents
aws s3 ls s3://$BUCKET_NAME/
```

#### Upload a test file to S3

```bash
# Create a test file
echo "Hello from Bastion Host - $(date)" > test-file.txt

# Upload to S3
aws s3 cp test-file.txt s3://$BUCKET_NAME/test-file.txt

# Verify upload
aws s3 ls s3://$BUCKET_NAME/test-file.txt
```

#### Download a file from S3

```bash
# Download the file we just uploaded
aws s3 cp s3://$BUCKET_NAME/test-file.txt downloaded-test-file.txt

# Verify content
cat downloaded-test-file.txt
```

#### Test with AWS CLI S3API (more detailed)

```bash
# List buckets (this might fail if not in the policy)
aws s3api list-buckets

# Get bucket location
aws s3api get-bucket-location --bucket $BUCKET_NAME

# List objects in the bucket
aws s3api list-objects-v2 --bucket $BUCKET_NAME

# Upload using s3api
echo "Test content" > s3api-test.txt
aws s3api put-object --bucket $BUCKET_NAME --key s3api-test.txt --body s3api-test.txt

# Get object
aws s3api get-object --bucket $BUCKET_NAME --key s3api-test.txt downloaded-s3api-test.txt

# View content
cat downloaded-s3api-test.txt
```

#### Delete test files (optional)

```bash
# Delete test files from S3
aws s3 rm s3://$BUCKET_NAME/test-file.txt
aws s3 rm s3://$BUCKET_NAME/s3api-test.txt

# Verify deletion
aws s3 ls s3://$BUCKET_NAME/
```

### Step 5: Check IAM Permissions (Troubleshooting)

If you encounter permission errors:

```bash
# Check the current IAM role
aws sts get-caller-identity

# Test a specific S3 action
aws s3api head-bucket --bucket $BUCKET_NAME

# View IAM role policies (requires additional permissions)
ROLE_NAME="<your-environment-name>-web-servers"
aws iam get-role --role-name $ROLE_NAME
aws iam list-role-policies --role-name $ROLE_NAME
aws iam get-role-policy --role-name $ROLE_NAME --policy-name s3
```

## Quick Test Script

You can create and run this script on the bastion host:

```bash
cat << 'EOF' > test-s3.sh
#!/bin/bash

BUCKET_NAME="${1:-<your-environment-name>-website-bucket}"

echo "=========================================="
echo "Testing S3 Access"
echo "Bucket: $BUCKET_NAME"
echo "=========================================="
echo ""

echo "1. Testing bucket listing..."
if aws s3 ls s3://$BUCKET_NAME/; then
    echo "✓ List bucket: SUCCESS"
else
    echo "✗ List bucket: FAILED"
fi
echo ""

echo "2. Testing file upload..."
TEST_FILE="bastion-test-$(date +%s).txt"
echo "Test from bastion at $(date)" > $TEST_FILE
if aws s3 cp $TEST_FILE s3://$BUCKET_NAME/$TEST_FILE; then
    echo "✓ Upload file: SUCCESS"
else
    echo "✗ Upload file: FAILED"
    exit 1
fi
echo ""

echo "3. Testing file download..."
if aws s3 cp s3://$BUCKET_NAME/$TEST_FILE downloaded-$TEST_FILE; then
    echo "✓ Download file: SUCCESS"
    echo "File content:"
    cat downloaded-$TEST_FILE
else
    echo "✗ Download file: FAILED"
fi
echo ""

echo "4. Testing file deletion..."
if aws s3 rm s3://$BUCKET_NAME/$TEST_FILE; then
    echo "✓ Delete file: SUCCESS"
else
    echo "✗ Delete file: FAILED"
fi
echo ""

# Cleanup
rm -f $TEST_FILE downloaded-$TEST_FILE

echo "=========================================="
echo "All tests completed!"
echo "=========================================="
EOF

chmod +x test-s3.sh
./test-s3.sh
```

## Expected Results

If everything is configured correctly, you should see:

✅ **List bucket**: Shows bucket contents (or empty if no files)
✅ **Upload file**: Successfully uploads the test file
✅ **Download file**: Successfully downloads and displays the content
✅ **Delete file**: Successfully removes the test file

## Common Errors and Solutions

### Error: "Unable to locate credentials"
- **Solution**: Wait a few moments after instance launch for IAM role to attach, or verify the instance profile is attached

### Error: "Access Denied"
- **Solution**: Check that the IAM policy includes the correct permissions and the bucket ARN with `/*` suffix

### Error: "NoSuchBucket"
- **Solution**: Verify the bucket name matches the one created by CloudFormation

### Instance needs restart after IAM profile attachment
- **Note**: When you add an IAM instance profile to an existing instance via CloudFormation, the instance will be replaced automatically

## Using EC2 Instance Connect (Alternative to SSH)

If you don't want to use SSH keys:

```bash
# Get instance ID
INSTANCE_ID=$(aws cloudformation describe-stacks \
  --stack-name <your-stack-name> \
  --query 'Stacks[0].Outputs[?OutputKey==`BastionHostID`].OutputValue' \
  --output text \
  --region us-east-1)

# Connect using EC2 Instance Connect
aws ec2-instance-connect ssh --instance-id $INSTANCE_ID --region us-east-1
```

## Additional Notes

- The bastion host now has the same S3 permissions as the web application servers
- This allows you to upload/download files for testing or maintenance
- The bucket has versioning enabled, so deleted files can be recovered
- The bucket has a 30-day lifecycle policy for object expiration

