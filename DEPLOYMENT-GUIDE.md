# LinkBox Deployment Guide

Complete step-by-step guide to deploy the LinkBox application on AWS.

---

## 📋 Prerequisites Checklist

- [ ] AWS CLI installed and configured with credentials
- [ ] AWS account with appropriate permissions
- [ ] Node.js and npm installed (for frontend)
- [ ] Docker installed (for local backend testing)
- [ ] GitHub personal access token ([Create here](https://github.com/settings/tokens))
  - Required scopes: `repo`, `admin:repo_hook`
- [ ] Basic understanding of AWS services (VPC, EC2, RDS, S3, CloudFront)

---

## 🚀 Deployment Steps

### Phase 1: Infrastructure Deployment (~20 minutes)

#### Step 1: Get AMI ID

```bash
cd infrastructure

# Get the latest Amazon Linux 2 AMI for your region
./get-ami-id.sh

# Copy the AMI ID (e.g., ami-091d7d61336a4c68f)
```

#### Step 2: Deploy Infrastructure

```bash
# Run the deployment script
./deploy.sh \
  linkbox-cfn-templates \           # S3 bucket for templates (will be created)
  linkbox-master \                  # Stack name
  ami-091d7d61336a4c68f \          # AMI ID from step 1
  your-github-username/repo-name \  # Your GitHub repo
  ghp_xxxxxxxxxxxxxxxxxxxx          # GitHub token

# Enter database password when prompted (min 8 characters)
# Example: MySecurePass123!
```

**What this deploys:**
- ✅ VPC with public/private subnets across 2 AZs
- ✅ RDS PostgreSQL database (linkbox)
- ✅ Application Load Balancer
- ✅ Auto Scaling Group with EC2 instances
- ✅ S3 bucket for file uploads
- ✅ S3 bucket for frontend hosting
- ✅ CloudFront CDN distribution
- ✅ ECR repository for Docker images
- ✅ CodePipeline for backend CI/CD

**Wait for completion** - The script will wait for all stacks to deploy (~15-20 minutes).

#### Step 3: Verify Infrastructure

```bash
# Check stack status
aws cloudformation describe-stacks --stack-name linkbox-master \
  --query 'Stacks[0].StackStatus' --output text

# Should show: CREATE_COMPLETE

# Get all outputs
aws cloudformation describe-stacks --stack-name linkbox-master \
  --query 'Stacks[0].Outputs' --output table
```

---

### Phase 2: Backend Deployment (~5-10 minutes)

#### Step 4: Build and Push Backend Docker Image

```bash
# Get ECR repository URI
ECR_URI=$(aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryURI`].OutputValue' \
  --output text)

echo "ECR Repository: $ECR_URI"

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_URI

# Build Docker image
cd ../backend
docker build -t $ECR_URI:latest .

# Push to ECR
docker push $ECR_URI:latest

echo "✅ Backend image pushed to ECR"
```

#### Step 5: Deploy Backend to EC2

```bash
# Option A: Trigger via git push (automated)
git add .
git commit -m "Initial deployment"
git push origin main
# This will trigger CodePipeline automatically

# Option B: Trigger pipeline manually
aws codepipeline start-pipeline-execution \
  --name linkbox-backend-pipeline
```

**Monitor deployment:**
```bash
# Watch CodePipeline progress
aws codepipeline get-pipeline-state --name linkbox-backend-pipeline

# Watch CodeBuild logs
aws logs tail /aws/codebuild/linkbox-backend-build --follow

# Check target health (wait for "healthy" status)
ALB_TG=$(aws elbv2 describe-target-groups \
  --query 'TargetGroups[?contains(TargetGroupName, `linkbox`)].TargetGroupArn' \
  --output text)

aws elbv2 describe-target-health --target-group-arn $ALB_TG
```

#### Step 6: Test Backend API

```bash
# Get ALB DNS name
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
  --output text)

# Test health endpoint
curl http://$ALB_DNS/health

# Should return: {"status":"ok"}
```

---

### Phase 3: Frontend Deployment (~5 minutes)

#### Step 7: Configure Frontend API Endpoint

```bash
# Get CloudFront domain
CLOUDFRONT_DOMAIN=$(aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDomain`].OutputValue' \
  --output text)

echo "Frontend URL: https://$CLOUDFRONT_DOMAIN"
echo "API Endpoint: https://$CLOUDFRONT_DOMAIN/api"
```

Update your frontend configuration:

**Option A: Using .env file**
```bash
# Create frontend/.env
cd ../frontend
cat > .env << EOF
VITE_API_URL=https://$CLOUDFRONT_DOMAIN/api
EOF
```

**Option B: Edit config file directly**
```typescript
// frontend/src/config.ts
export const config = {
  apiUrl: 'https://<cloudfront-domain>/api'
}
```

#### Step 8: Deploy Frontend

```bash
cd ../infrastructure

# Deploy frontend (automated script)
./deploy-frontend.sh

# Or with custom stack name
./deploy-frontend.sh linkbox-master
```

**What this does:**
- ✅ Installs npm dependencies
- ✅ Builds frontend (npm run build)
- ✅ Uploads to S3 bucket
- ✅ Sets optimal cache headers
- ✅ Invalidates CloudFront cache
- ✅ Displays application URL

**Wait for CloudFront invalidation** (~5-15 minutes for cache to clear globally)

#### Step 9: Access Your Application

```bash
# Get application URL
echo "🌐 Application URL: https://$CLOUDFRONT_DOMAIN"

# Open in browser
open "https://$CLOUDFRONT_DOMAIN"
# or
xdg-open "https://$CLOUDFRONT_DOMAIN"  # Linux
```

---

## 🔄 Development Workflow

### Updating Backend

Backend updates are **fully automated** via CodePipeline:

```bash
# 1. Make code changes
cd backend
# ... edit files ...

# 2. Commit and push
git add .
git commit -m "Update backend feature"
git push origin main

# 3. CodePipeline automatically:
#    - Pulls code from GitHub
#    - Builds Docker image
#    - Pushes to ECR
#    - Deploys to EC2 instances
#    - Runs health checks

# 4. Monitor deployment
aws codepipeline get-pipeline-state --name linkbox-backend-pipeline
```

### Updating Frontend

Frontend updates are **manual** using the deployment script:

```bash
# 1. Make code changes
cd frontend
# ... edit files ...

# 2. Optional: Commit changes
git add .
git commit -m "Update frontend UI"
git push origin main

# 3. Deploy frontend manually
cd ../infrastructure
./deploy-frontend.sh

# 4. Wait for CloudFront invalidation (5-15 min)
# 5. Hard refresh browser (Cmd+Shift+R / Ctrl+Shift+R)
```

---

## 🐛 Troubleshooting

### Infrastructure Deployment Failed

```bash
# Check stack events for errors
aws cloudformation describe-stack-events \
  --stack-name linkbox-master \
  --max-items 20

# Check nested stack status
aws cloudformation list-stacks \
  --query 'StackSummaries[?contains(StackName, `linkbox`)].{Name:StackName,Status:StackStatus}'

# Delete and retry if needed
aws cloudformation delete-stack --stack-name linkbox-master
# Wait for deletion, then run deploy.sh again
```

### Backend Not Healthy

```bash
# Check EC2 instance logs
aws ssm start-session --target <instance-id>
# Or use AWS Console → EC2 → Connect

# View Docker logs
sudo docker logs $(sudo docker ps -q)

# Check user data execution
sudo cat /var/log/cloud-init-output.log

# Verify database connection
nc -zv <db-endpoint> 5432
```

### Database Connection Failed

```bash
# Verify security group rules
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*linkbox*" \
  --query 'SecurityGroups[].{Name:GroupName,Rules:IpPermissions}'

# Check SSM parameter
aws ssm get-parameter --name /linkbox/db-endpoint

# Test from EC2 instance
aws ssm send-command \
  --instance-ids <instance-id> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["nc -zv <db-endpoint> 5432"]'
```

### Frontend Not Loading

```bash
# Check S3 bucket contents
FRONTEND_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text)

aws s3 ls s3://$FRONTEND_BUCKET/ --recursive

# Check CloudFront distribution status
CLOUDFRONT_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='linkbox CloudFront Distribution'].Id" \
  --output text)

aws cloudfront get-distribution --id $CLOUDFRONT_ID \
  --query 'Distribution.Status'

# Check invalidation status
aws cloudfront list-invalidations --distribution-id $CLOUDFRONT_ID
```

### CodePipeline Failed

```bash
# Get pipeline execution status
aws codepipeline list-pipeline-executions \
  --pipeline-name linkbox-backend-pipeline \
  --max-items 1

# View CodeBuild logs
aws logs tail /aws/codebuild/linkbox-backend-build --follow

# Get CodeDeploy deployment details
aws deploy list-deployments \
  --application-name linkbox-backend-app \
  --max-items 1

DEPLOYMENT_ID=$(aws deploy list-deployments \
  --application-name linkbox-backend-app \
  --query 'deployments[0]' \
  --output text)

aws deploy get-deployment --deployment-id $DEPLOYMENT_ID
```

---

## 🗑️ Cleanup (Delete Everything)

**⚠️ WARNING:** This will permanently delete all resources and data!

```bash
# 1. Empty S3 buckets (required before deletion)
aws s3 rm s3://linkbox-uploads --recursive
aws s3 rm s3://<frontend-bucket-name> --recursive
aws s3 rm s3://linkbox-pipeline-artifacts-<account-id> --recursive

# 2. Delete main stack (cascades to nested stacks)
aws cloudformation delete-stack --stack-name linkbox-master

# 3. Wait for deletion (~10-15 minutes)
aws cloudformation wait stack-delete-complete --stack-name linkbox-master

# 4. Delete S3 buckets
aws s3 rb s3://linkbox-uploads
aws s3 rb s3://<frontend-bucket-name>
aws s3 rb s3://linkbox-pipeline-artifacts-<account-id>

# 5. Delete templates bucket
aws s3 rb s3://linkbox-cfn-templates --force

echo "✅ All resources deleted"
```

---

## 📊 Cost Monitoring

Monitor your AWS costs:

```bash
# Get current month spend
aws ce get-cost-and-usage \
  --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --filter file://cost-filter.json

# List resources by tag
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=LinkBox \
  --query 'ResourceTagMappingList[].ResourceARN'
```

**Expected Monthly Costs:**
- NAT Gateway: ~$32
- EC2 (t3.micro): ~$15-30
- RDS (db.t4g.micro): ~$15
- ALB: ~$16
- S3 + CloudFront: ~$1-5
- **Total: ~$80-100/month**

---

## 📚 Additional Resources

- **Infrastructure Diagram**: `infrastructure-diagram.md` - Visual architecture
- **Infrastructure Fixes**: `infrastructure/INFRASTRUCTURE-FIXES.md` - Security improvements
- **Infrastructure README**: `infrastructure/README.md` - Detailed reference
- **CI/CD Setup**: `CICD-SETUP.md` - Pipeline configuration

---

## ✅ Deployment Checklist

Use this checklist to track your deployment progress:

### Infrastructure
- [ ] Got latest AMI ID
- [ ] Ran infrastructure deployment script
- [ ] Verified all stacks show CREATE_COMPLETE
- [ ] Saved CloudFormation outputs

### Backend
- [ ] Built Docker image
- [ ] Pushed image to ECR
- [ ] Triggered CodePipeline
- [ ] Verified instances are healthy
- [ ] Tested /health endpoint

### Frontend
- [ ] Updated API endpoint configuration
- [ ] Ran frontend deployment script
- [ ] Verified files in S3 bucket
- [ ] Waited for CloudFront invalidation
- [ ] Tested application in browser

### Verification
- [ ] Can access frontend via CloudFront URL
- [ ] Can make API requests
- [ ] Can upload files
- [ ] Can retrieve files
- [ ] Checked CloudWatch logs for errors

---

**Need Help?**
- Check the troubleshooting section above
- Review AWS CloudFormation events
- Check CloudWatch Logs
- Verify security group rules
- Ensure all outputs are available

**Happy Deploying! 🚀**

