#!/bin/bash

# ==============================================================================
# CloudFormation Stack Update Script
# ==============================================================================
# Updates an existing LinkBox CloudFormation stack
#
# Usage:
#   ./update-stack.sh [stack-name] [templates-bucket]
#
# Examples:
#   ./update-stack.sh linkbox-master linkbox-cfn-templates
#   ./update-stack.sh                  # Uses defaults
# ==============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️ ${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# ==============================================================================
# Configuration
# ==============================================================================

STACK_NAME="${1:-linkbox-master}"
TEMPLATES_BUCKET="${2:-linkbox-cfn-templates}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

print_header "CloudFormation Stack Update"

print_info "Configuration:"
echo "  Stack Name:       $STACK_NAME"
echo "  Templates Bucket: $TEMPLATES_BUCKET"
echo "  Region:           $REGION"
echo ""

# ==============================================================================
# Validate Prerequisites
# ==============================================================================

print_info "Validating prerequisites..."

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured or invalid."
    exit 1
fi

# Check if stack exists
if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" &> /dev/null; then
    print_error "Stack '$STACK_NAME' does not exist. Use deploy.sh to create it."
    exit 1
fi

# Check if S3 bucket exists
if ! aws s3 ls "s3://$TEMPLATES_BUCKET" &> /dev/null; then
    print_error "S3 bucket '$TEMPLATES_BUCKET' does not exist."
    exit 1
fi

print_success "Prerequisites validated"

# ==============================================================================
# Get Current Stack Parameters
# ==============================================================================

print_info "Retrieving current stack parameters..."

CURRENT_PARAMS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Parameters' \
    --output json)

print_success "Retrieved current parameters"

# ==============================================================================
# Upload Templates to S3
# ==============================================================================

print_header "Uploading Templates"

TEMPLATES=(
    "main.yml"
    "01-network.yml"
    "02-database.yml"
    "03-backend.yml"
    "04-frontend.yml"
    "05-cicd.yml"
)

print_info "Uploading templates to s3://$TEMPLATES_BUCKET/"

for template in "${TEMPLATES[@]}"; do
    if [ -f "$template" ]; then
        print_info "  Uploading $template..."
        aws s3 cp "$template" "s3://$TEMPLATES_BUCKET/$template" --quiet
        print_success "  $template uploaded"
    else
        print_warning "  $template not found, skipping..."
    fi
done

print_success "All templates uploaded"

# ==============================================================================
# Update Options
# ==============================================================================

print_header "Update Options"

echo "What would you like to update?"
echo ""
echo "1) Infrastructure only (use existing parameters)"
echo "2) Infrastructure + change parameters"
echo "3) Cancel"
echo ""
read -p "Enter your choice (1-3): " UPDATE_CHOICE

case $UPDATE_CHOICE in
    1)
        print_info "Updating with existing parameters..."
        UPDATE_TYPE="existing"
        ;;
    2)
        print_info "You can update parameters..."
        UPDATE_TYPE="custom"
        ;;
    3)
        print_warning "Update cancelled by user"
        exit 0
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

# ==============================================================================
# Build Parameter String
# ==============================================================================

if [ "$UPDATE_TYPE" = "existing" ]; then
    # Use all previous values
    PARAMS=""
    for param in $(echo "$CURRENT_PARAMS" | jq -r '.[].ParameterKey'); do
        PARAMS="$PARAMS ParameterKey=$param,UsePreviousValue=true"
    done
else
    # Ask for parameter updates
    print_header "Parameter Update"
    
    PARAMS=""
    
    # Environment Name
    CURRENT_ENV=$(echo "$CURRENT_PARAMS" | jq -r '.[] | select(.ParameterKey=="EnvironmentName") | .ParameterValue')
    read -p "Environment Name [$CURRENT_ENV]: " NEW_ENV
    NEW_ENV="${NEW_ENV:-$CURRENT_ENV}"
    if [ "$NEW_ENV" = "$CURRENT_ENV" ]; then
        PARAMS="$PARAMS ParameterKey=EnvironmentName,UsePreviousValue=true"
    else
        PARAMS="$PARAMS ParameterKey=EnvironmentName,ParameterValue=$NEW_ENV"
    fi
    
    # Templates Bucket
    CURRENT_BUCKET=$(echo "$CURRENT_PARAMS" | jq -r '.[] | select(.ParameterKey=="TemplatesBucketName") | .ParameterValue')
    read -p "Templates Bucket Name [$CURRENT_BUCKET]: " NEW_BUCKET
    NEW_BUCKET="${NEW_BUCKET:-$CURRENT_BUCKET}"
    if [ "$NEW_BUCKET" = "$CURRENT_BUCKET" ]; then
        PARAMS="$PARAMS ParameterKey=TemplatesBucketName,UsePreviousValue=true"
    else
        PARAMS="$PARAMS ParameterKey=TemplatesBucketName,ParameterValue=$NEW_BUCKET"
    fi
    
    # AMI ID
    echo ""
    read -p "Update AMI ID? (y/N): " UPDATE_AMI
    if [[ "$UPDATE_AMI" =~ ^[Yy]$ ]]; then
        # Get latest AMI
        LATEST_AMI=$(aws ssm get-parameters \
            --names /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 \
            --query 'Parameters[0].Value' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$LATEST_AMI" ]; then
            print_info "Latest Amazon Linux 2 AMI: $LATEST_AMI"
            read -p "Use this AMI? (Y/n): " USE_LATEST
            if [[ ! "$USE_LATEST" =~ ^[Nn]$ ]]; then
                PARAMS="$PARAMS ParameterKey=AmiId,ParameterValue=$LATEST_AMI"
            else
                read -p "Enter AMI ID: " CUSTOM_AMI
                PARAMS="$PARAMS ParameterKey=AmiId,ParameterValue=$CUSTOM_AMI"
            fi
        else
            read -p "Enter AMI ID: " CUSTOM_AMI
            PARAMS="$PARAMS ParameterKey=AmiId,ParameterValue=$CUSTOM_AMI"
        fi
    else
        PARAMS="$PARAMS ParameterKey=AmiId,UsePreviousValue=true"
    fi
    
    # ECR Image URL
    PARAMS="$PARAMS ParameterKey=ECRImageUrl,UsePreviousValue=true"
    
    # Database credentials
    echo ""
    read -p "Update database password? (y/N): " UPDATE_DB_PASS
    if [[ "$UPDATE_DB_PASS" =~ ^[Yy]$ ]]; then
        read -s -p "Enter new database password: " NEW_DB_PASS
        echo ""
        PARAMS="$PARAMS ParameterKey=DBPassword,ParameterValue=$NEW_DB_PASS"
        PARAMS="$PARAMS ParameterKey=DBUsername,UsePreviousValue=true"
    else
        PARAMS="$PARAMS ParameterKey=DBPassword,UsePreviousValue=true"
        PARAMS="$PARAMS ParameterKey=DBUsername,UsePreviousValue=true"
    fi
    
    # GitHub settings
    echo ""
    read -p "Update GitHub settings? (y/N): " UPDATE_GITHUB
    if [[ "$UPDATE_GITHUB" =~ ^[Yy]$ ]]; then
        read -p "GitHub Repo (owner/repo): " NEW_GITHUB_REPO
        read -p "GitHub Branch [main]: " NEW_GITHUB_BRANCH
        NEW_GITHUB_BRANCH="${NEW_GITHUB_BRANCH:-main}"
        read -s -p "GitHub Token: " NEW_GITHUB_TOKEN
        echo ""
        
        PARAMS="$PARAMS ParameterKey=GitHubRepo,ParameterValue=$NEW_GITHUB_REPO"
        PARAMS="$PARAMS ParameterKey=GitHubBranch,ParameterValue=$NEW_GITHUB_BRANCH"
        PARAMS="$PARAMS ParameterKey=GitHubToken,ParameterValue=$NEW_GITHUB_TOKEN"
    else
        PARAMS="$PARAMS ParameterKey=GitHubRepo,UsePreviousValue=true"
        PARAMS="$PARAMS ParameterKey=GitHubBranch,UsePreviousValue=true"
        PARAMS="$PARAMS ParameterKey=GitHubToken,UsePreviousValue=true"
    fi
fi

# ==============================================================================
# Confirmation
# ==============================================================================

print_header "Confirmation"

echo "You are about to update the following stack:"
echo ""
echo "  Stack Name:       $STACK_NAME"
echo "  Region:           $REGION"
echo "  Template URL:     https://$TEMPLATES_BUCKET.s3.amazonaws.com/main.yml"
echo ""

if [ "$UPDATE_TYPE" = "existing" ]; then
    echo "  Update Type:      Using all existing parameters"
else
    echo "  Update Type:      Custom parameters"
fi

echo ""
read -p "Do you want to proceed with the update? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_warning "Update cancelled by user"
    exit 0
fi

# ==============================================================================
# Update Stack
# ==============================================================================

print_header "Updating Stack"

print_info "Starting CloudFormation stack update..."

TEMPLATE_URL="https://$TEMPLATES_BUCKET.s3.amazonaws.com/main.yml"

if aws cloudformation update-stack \
    --stack-name "$STACK_NAME" \
    --template-url "$TEMPLATE_URL" \
    --parameters $PARAMS \
    --capabilities CAPABILITY_IAM \
    --region "$REGION" &> /dev/null; then
    
    print_success "Update initiated successfully"
    
    # ==============================================================================
    # Monitor Update Progress
    # ==============================================================================
    
    print_info "Monitoring stack update progress..."
    print_info "This may take 10-20 minutes..."
    echo ""
    
    # Wait for update to complete
    if aws cloudformation wait stack-update-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION" 2>/dev/null; then
        
        print_header "Update Successful"
        print_success "Stack '$STACK_NAME' has been updated successfully!"
        
        # Get stack outputs
        print_info "Stack outputs:"
        aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --query 'Stacks[0].Outputs[*].{Key:OutputKey,Value:OutputValue}' \
            --output table \
            --region "$REGION"
        
        echo ""
        print_success "Update completed successfully!"
        
    else
        print_error "Stack update failed or was cancelled"
        print_info "Check the CloudFormation console for details:"
        echo "  https://console.aws.amazon.com/cloudformation/home?region=$REGION#/stacks"
        exit 1
    fi
    
else
    ERROR_MSG=$(aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-url "$TEMPLATE_URL" \
        --parameters $PARAMS \
        --capabilities CAPABILITY_IAM \
        --region "$REGION" 2>&1 || true)
    
    if echo "$ERROR_MSG" | grep -q "No updates are to be performed"; then
        print_warning "No updates are required - stack is already up to date"
        exit 0
    else
        print_error "Failed to update stack"
        echo "$ERROR_MSG"
        exit 1
    fi
fi

# ==============================================================================
# Post-Update Actions
# ==============================================================================

print_header "Post-Update Actions"

echo "Consider the following actions after update:"
echo ""
echo "1. Redeploy Application (if backend code changed):"
echo "   aws codepipeline start-pipeline-execution --name linkbox-backend-pipeline"
echo ""
echo "2. Redeploy Frontend (if frontend code changed):"
echo "   ./deploy-frontend.sh"
echo ""
echo "3. Check Target Group Health:"
echo "   aws elbv2 describe-target-health --target-group-arn <target-group-arn>"
echo ""
echo "4. Test Application:"
echo "   ALB_DNS=\$(aws cloudformation describe-stacks \\"
echo "     --stack-name $STACK_NAME \\"
echo "     --query 'Stacks[0].Outputs[?OutputKey==\`ALBDNSName\`].OutputValue' \\"
echo "     --output text)"
echo "   curl http://\$ALB_DNS/health"
echo ""

print_success "Stack update script completed!"

