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
print_info "Infrastructure deployment complete! Stack outputs:"
echo "$OUTPUTS" | jq -r '.[] | "  \(.OutputKey): \(.OutputValue)"'

# Extract key outputs
PIPELINE_NAME=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="PipelineName") | .OutputValue')
ALB_DNS=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="ALBDNSName") | .OutputValue')

echo ""
print_info "Monitoring CI/CD Pipeline..."
print_warning "The pipeline will automatically build and deploy the backend Docker image."

if [ -z "$PIPELINE_NAME" ]; then
    print_error "Could not retrieve pipeline name from stack outputs"
    exit 1
fi

# Wait a few seconds for the pipeline to be ready
sleep 5

# Get the latest pipeline execution
print_info "Fetching pipeline execution status..."
EXECUTION_ID=$(aws codepipeline get-pipeline-state --name "$PIPELINE_NAME" --query 'stageStates[0].latestExecution.pipelineExecutionId' --output text 2>/dev/null || echo "")

if [ -z "$EXECUTION_ID" ] || [ "$EXECUTION_ID" == "None" ]; then
    print_warning "No pipeline execution found yet. The pipeline may start shortly."
    print_info "Waiting for pipeline to start..."
    
    # Wait up to 5 minutes for pipeline to start
    for i in {1..30}; do
        sleep 10
        EXECUTION_ID=$(aws codepipeline get-pipeline-state --name "$PIPELINE_NAME" --query 'stageStates[0].latestExecution.pipelineExecutionId' --output text 2>/dev/null || echo "")
        if [ ! -z "$EXECUTION_ID" ] && [ "$EXECUTION_ID" != "None" ]; then
            print_info "Pipeline execution started: $EXECUTION_ID"
            break
        fi
        echo -n "."
    done
    echo ""
fi

if [ -z "$EXECUTION_ID" ] || [ "$EXECUTION_ID" == "None" ]; then
    print_warning "Pipeline has not started automatically."
    print_info "You may need to trigger it manually by pushing a commit to GitHub."
else
    print_info "Monitoring pipeline execution: $EXECUTION_ID"
    print_warning "This may take 10-15 minutes..."
    
    # Monitor pipeline execution
    while true; do
        PIPELINE_STATE=$(aws codepipeline get-pipeline-state --name "$PIPELINE_NAME")
        
        # Get overall pipeline status
        PIPELINE_STATUS=$(echo "$PIPELINE_STATE" | jq -r '.stageStates[0].latestExecution.status' 2>/dev/null || echo "Unknown")
        
        # Get status of each stage
        SOURCE_STATUS=$(echo "$PIPELINE_STATE" | jq -r '.stageStates[] | select(.stageName=="Source") | .latestExecution.status' 2>/dev/null)
        BUILD_STATUS=$(echo "$PIPELINE_STATE" | jq -r '.stageStates[] | select(.stageName=="Build") | .latestExecution.status' 2>/dev/null)
        DEPLOY_STATUS=$(echo "$PIPELINE_STATE" | jq -r '.stageStates[] | select(.stageName=="Deploy") | .latestExecution.status' 2>/dev/null)
        
        echo "  Source: $SOURCE_STATUS | Build: $BUILD_STATUS | Deploy: $DEPLOY_STATUS"
        
        # Check if pipeline is complete
        if [ "$DEPLOY_STATUS" == "Succeeded" ]; then
            print_info "Pipeline execution completed successfully!"
            break
        elif [ "$DEPLOY_STATUS" == "Failed" ] || [ "$BUILD_STATUS" == "Failed" ] || [ "$SOURCE_STATUS" == "Failed" ]; then
            print_error "Pipeline execution failed!"
            print_info "Check the AWS CodePipeline console for details:"
            echo "  https://console.aws.amazon.com/codesuite/codepipeline/pipelines/$PIPELINE_NAME/view"
            exit 1
        fi
        
        sleep 30
    done
fi

echo ""
print_info "==================================================================="
print_info "Backend Deployment Complete!"
print_info "==================================================================="
echo ""
print_info "Backend API URL (ALB):"
echo "  http://$ALB_DNS"
echo ""
print_info "Test the API:"
echo "  curl http://$ALB_DNS/health"
echo ""
print_info "Next Steps:"
echo "  1. Deploy the frontend by running: ./deploy-frontend.sh"
echo "     (Frontend deployment is still manual)"
echo ""
echo "  2. Access the CodePipeline console to view pipeline details:"
echo "     https://console.aws.amazon.com/codesuite/codepipeline/pipelines/$PIPELINE_NAME/view"
echo ""
print_info "Future deployments:"
echo "  - Backend: Push to GitHub branch '$GITHUB_BRANCH' (automatic via pipeline)"
echo "  - Frontend: Run ./deploy-frontend.sh (manual)"
echo ""
