#!/bin/bash
set -e

# LinkBox Infrastructure Deployment Script
# This script uploads nested CloudFormation templates to S3 and deploys the master stack

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required parameters are provided
if [ "$#" -lt 5 ]; then
    echo "Usage: $0 <templates-bucket-name> <stack-name> <ami-id> <github-repo> <github-token>"
    echo ""
    echo "Example:"
    echo "  $0 my-cfn-templates linkbox-master ami-0abcdef1234567890 username/repo-name ghp_xxxxxxxxxxxx"
    echo ""
    echo "Required parameters:"
    echo "  templates-bucket-name  - S3 bucket to store CloudFormation templates"
    echo "  stack-name            - Name for the master CloudFormation stack"
    echo "  ami-id               - Amazon Linux 2 AMI ID for EC2 instances"
    echo "  github-repo          - GitHub repository (format: username/repo-name)"
    echo "  github-token         - GitHub personal access token"
    echo ""
    echo "Optional environment variables:"
    echo "  ENVIRONMENT_NAME     - Environment name (default: linkbox)"
    echo "  DB_USERNAME          - Database username (default: linkbox)"
    echo "  DB_PASSWORD          - Database password (will prompt if not set)"
    echo "  GITHUB_BRANCH        - GitHub branch (default: main)"
    exit 1
fi

TEMPLATES_BUCKET=$1
STACK_NAME=$2
AMI_ID=$3
GITHUB_REPO=$4
GITHUB_TOKEN=$5

# Set defaults for optional parameters
ENVIRONMENT_NAME=${ENVIRONMENT_NAME:-linkbox}
DB_USERNAME=${DB_USERNAME:-linkbox}
GITHUB_BRANCH=${GITHUB_BRANCH:-main}

# Prompt for DB password if not set
if [ -z "$DB_PASSWORD" ]; then
    echo -n "Enter database password: "
    read -s DB_PASSWORD
    echo
fi

# Validate DB password
if [ ${#DB_PASSWORD} -lt 8 ]; then
    print_error "Database password must be at least 8 characters long"
    exit 1
fi

print_info "Starting deployment with the following configuration:"
echo "  Templates Bucket:   $TEMPLATES_BUCKET"
echo "  Stack Name:         $STACK_NAME"
echo "  Environment Name:   $ENVIRONMENT_NAME"
echo "  AMI ID:             $AMI_ID"
echo "  GitHub Repo:        $GITHUB_REPO"
echo "  GitHub Branch:      $GITHUB_BRANCH"
echo "  DB Username:        $DB_USERNAME"
echo ""

# Check if bucket exists, create if not
print_info "Checking if S3 bucket exists..."
if aws s3 ls "s3://$TEMPLATES_BUCKET" 2>&1 | grep -q 'NoSuchBucket'; then
    print_warning "Bucket does not exist. Creating..."
    aws s3 mb "s3://$TEMPLATES_BUCKET"
    print_info "Bucket created successfully"
else
    print_info "Bucket exists"
fi

# Upload nested stack templates to S3
print_info "Uploading CloudFormation templates to S3..."
for template in 01-network.yml 02-database.yml 03-backend.yml 04-frontend.yml 05-cicd.yml; do
    print_info "  Uploading $template..."
    aws s3 cp "$template" "s3://$TEMPLATES_BUCKET/$template"
done
print_info "All templates uploaded successfully"

# Validate the main stack template
print_info "Validating main stack template..."
aws cloudformation validate-template --template-body file://main.yml > /dev/null
print_info "Template validation successful"

# Check if stack already exists
STACK_EXISTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" 2>&1 || true)

if echo "$STACK_EXISTS" | grep -q "does not exist"; then
    print_info "Creating new stack: $STACK_NAME"
    
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://main.yml \
        --parameters \
            ParameterKey=EnvironmentName,ParameterValue="$ENVIRONMENT_NAME" \
            ParameterKey=TemplatesBucketName,ParameterValue="$TEMPLATES_BUCKET" \
            ParameterKey=AmiId,ParameterValue="$AMI_ID" \
            ParameterKey=ECRImageUrl,ParameterValue="placeholder:latest" \
            ParameterKey=DBUsername,ParameterValue="$DB_USERNAME" \
            ParameterKey=DBPassword,ParameterValue="$DB_PASSWORD" \
            ParameterKey=GitHubRepo,ParameterValue="$GITHUB_REPO" \
            ParameterKey=GitHubBranch,ParameterValue="$GITHUB_BRANCH" \
            ParameterKey=GitHubToken,ParameterValue="$GITHUB_TOKEN" \
        --capabilities CAPABILITY_IAM \
        --tags \
            Key=Project,Value=LinkBox \
            Key=Environment,Value="$ENVIRONMENT_NAME" \
            Key=ManagedBy,Value=CloudFormation
    
    print_info "Stack creation initiated. Waiting for completion..."
    print_warning "This will take 15-20 minutes. You can monitor progress in the AWS Console."
    
    aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME"
    
    print_info "Stack created successfully!"
else
    print_info "Stack exists. Updating stack: $STACK_NAME"
    
    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://main.yml \
        --parameters \
            ParameterKey=EnvironmentName,ParameterValue="$ENVIRONMENT_NAME" \
            ParameterKey=TemplatesBucketName,ParameterValue="$TEMPLATES_BUCKET" \
            ParameterKey=AmiId,ParameterValue="$AMI_ID" \
            ParameterKey=ECRImageUrl,ParameterValue="placeholder:latest" \
            ParameterKey=DBUsername,ParameterValue="$DB_USERNAME" \
            ParameterKey=DBPassword,ParameterValue="$DB_PASSWORD" \
            ParameterKey=GitHubRepo,ParameterValue="$GITHUB_REPO" \
            ParameterKey=GitHubBranch,ParameterValue="$GITHUB_BRANCH" \
            ParameterKey=GitHubToken,ParameterValue="$GITHUB_TOKEN" \
        --capabilities CAPABILITY_IAM \
        --tags \
            Key=Project,Value=LinkBox \
            Key=Environment,Value="$ENVIRONMENT_NAME" \
            Key=ManagedBy,Value=CloudFormation \
        || true
    
    UPDATE_STATUS=$?
    if [ $UPDATE_STATUS -eq 0 ]; then
        print_info "Stack update initiated. Waiting for completion..."
        aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME"
        print_info "Stack updated successfully!"
    else
        print_warning "No updates to perform or update failed. Check AWS Console for details."
    fi
fi

# Get stack outputs
print_info "Retrieving stack outputs..."
OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs' --output json)

echo ""
print_info "Deployment complete! Stack outputs:"
echo "$OUTPUTS" | jq -r '.[] | "  \(.OutputKey): \(.OutputValue)"'

echo ""
print_info "Next steps:"
echo "  1. Build and push your Docker image to ECR"
echo "  2. Deploy your frontend to S3/CloudFront"
echo "  3. Trigger the CI/CD pipeline by pushing to GitHub"
echo ""
print_info "Useful commands:"
ECR_URI=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="ECRRepositoryURI") | .OutputValue')
if [ ! -z "$ECR_URI" ]; then
    echo "  # Login to ECR:"
    echo "  aws ecr get-login-password --region \$AWS_REGION | docker login --username AWS --password-stdin $ECR_URI"
    echo ""
    echo "  # Build and push backend image:"
    echo "  docker build -t $ECR_URI:latest ./backend"
    echo "  docker push $ECR_URI:latest"
fi

