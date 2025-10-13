#!/bin/bash
set -e

# LinkBox Frontend Deployment Script
# Builds and deploys the React/Vue frontend to S3 + CloudFront

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Default stack name
STACK_NAME=${1:-linkbox-master}

print_info "LinkBox Frontend Deployment"
print_info "Stack Name: $STACK_NAME"
echo ""

# Check if we're in the right directory
if [ ! -d "../frontend" ]; then
    print_error "Cannot find frontend directory. Please run this script from the infrastructure/ directory"
    exit 1
fi

# Step 1: Get stack outputs
print_step "1/5 - Getting CloudFormation stack outputs..."

# Check if stack exists
if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" &> /dev/null; then
    print_error "Stack '$STACK_NAME' not found. Deploy infrastructure first."
    exit 1
fi

FRONTEND_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text)

if [ -z "$FRONTEND_BUCKET" ] || [ "$FRONTEND_BUCKET" == "None" ]; then
    print_error "Could not retrieve FrontendBucketName from stack outputs"
    print_warning "Make sure the FrontendStack has been deployed successfully"
    exit 1
fi

print_info "Frontend Bucket: $FRONTEND_BUCKET"

# Get CloudFront distribution ID (need to query the nested stack)
print_info "Getting CloudFront distribution ID..."

# Try to get from main stack outputs first
CLOUDFRONT_DOMAIN=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDomain`].OutputValue' \
  --output text)

if [ -z "$CLOUDFRONT_DOMAIN" ] || [ "$CLOUDFRONT_DOMAIN" == "None" ]; then
    print_error "Could not retrieve CloudFront domain from stack outputs"
    exit 1
fi

print_info "CloudFront Domain: $CLOUDFRONT_DOMAIN"

# Get the distribution ID from the domain
CLOUDFRONT_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?DomainName=='$CLOUDFRONT_DOMAIN'].Id" \
  --output text)

if [ -z "$CLOUDFRONT_ID" ]; then
    print_warning "Could not find CloudFront distribution ID automatically"
    print_warning "Cache invalidation will be skipped"
else
    print_info "CloudFront Distribution ID: $CLOUDFRONT_ID"
fi

echo ""

# Step 2: Install dependencies
print_step "2/5 - Installing frontend dependencies..."
cd ../frontend

if [ ! -f "package.json" ]; then
    print_error "package.json not found in frontend directory"
    exit 1
fi

print_info "Running npm install..."
npm install

echo ""

# Step 3: Build frontend
print_step "3/5 - Building frontend..."
print_info "Running npm run build..."
npm run build

# Check if build directory exists
if [ ! -d "dist" ]; then
    print_error "Build failed - dist/ directory not found"
    print_warning "Check your build command and vite.config.ts"
    exit 1
fi

print_info "Build completed successfully"
echo ""

# Step 4: Deploy to S3
print_step "4/5 - Deploying to S3..."
print_info "Syncing files to s3://$FRONTEND_BUCKET/"

aws s3 sync dist/ s3://$FRONTEND_BUCKET/ \
  --delete \
  --cache-control "public, max-age=31536000, immutable" \
  --exclude "index.html" \
  --exclude "*.map"

# Upload index.html separately with no-cache (for SPA updates)
if [ -f "dist/index.html" ]; then
    aws s3 cp dist/index.html s3://$FRONTEND_BUCKET/index.html \
      --cache-control "no-cache, no-store, must-revalidate" \
      --metadata-directive REPLACE
fi

print_info "S3 sync completed"
echo ""

# Step 5: Invalidate CloudFront cache
if [ ! -z "$CLOUDFRONT_ID" ]; then
    print_step "5/5 - Invalidating CloudFront cache..."
    print_info "Creating invalidation for all paths (/*)"
    
    INVALIDATION_ID=$(aws cloudfront create-invalidation \
      --distribution-id "$CLOUDFRONT_ID" \
      --paths "/*" \
      --query 'Invalidation.Id' \
      --output text)
    
    print_info "Invalidation created: $INVALIDATION_ID"
    print_warning "Cache invalidation can take 5-15 minutes to complete"
else
    print_step "5/5 - Skipping CloudFront invalidation (distribution ID not found)"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
print_info "✅ Frontend deployment completed successfully!"
echo "════════════════════════════════════════════════════════════════"
echo ""
print_info "🌐 Your application is available at:"
echo "    https://$CLOUDFRONT_DOMAIN"
echo ""
print_info "📦 Deployment summary:"
echo "    - Frontend bucket: $FRONTEND_BUCKET"
echo "    - CloudFront domain: $CLOUDFRONT_DOMAIN"
if [ ! -z "$CLOUDFRONT_ID" ]; then
    echo "    - CloudFront ID: $CLOUDFRONT_ID"
    echo "    - Cache invalidation: In progress (5-15 min)"
fi
echo ""
print_warning "Note: If you don't see changes immediately:"
echo "    - Wait for CloudFront cache invalidation to complete"
echo "    - Try hard refresh in browser (Cmd+Shift+R / Ctrl+Shift+R)"
echo "    - Check browser console for any errors"
echo ""
print_info "📝 To update backend API endpoint in frontend:"
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
  --output text 2>/dev/null || echo "N/A")
if [ ! -z "$ALB_DNS" ] && [ "$ALB_DNS" != "N/A" ]; then
    echo "    - API URL: http://$ALB_DNS/api"
    echo "    - Via CloudFront: https://$CLOUDFRONT_DOMAIN/api"
fi
echo ""

