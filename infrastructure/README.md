# LinkBox Infrastructure

CloudFormation templates for deploying the LinkBox file sharing application on AWS.

> **📘 For complete deployment guide, see:** [Main README](../README.md)
>
> This document contains infrastructure-specific technical details and reference information.

---

## 📁 Architecture

This infrastructure uses **nested CloudFormation stacks** for modularity:

```
main.yml (Master Stack)
├── 01-network.yml      → VPC, Subnets, NAT Gateway, Route Tables
├── 02-database.yml     → RDS PostgreSQL, Security Groups
├── 03-backend.yml      → ALB, ASG, EC2, ECR, S3 Uploads
├── 04-frontend.yml     → S3 Static Hosting, CloudFront CDN
└── 05-cicd.yml         → CodePipeline, CodeBuild, CodeDeploy (Backend only)

Deployment Scripts:
├── deploy.sh           → Deploy infrastructure (all stacks)
├── deploy-frontend.sh  → Deploy frontend to S3/CloudFront (manual)
├── quick-update.sh     → Fast stack updates (existing parameters)
├── update-stack.sh     → Full stack updates (change parameters)
└── get-ami-id.sh       → Get latest Amazon Linux 2 AMI
```

**Note:** Backend has automated CI/CD via CodePipeline. Frontend requires manual deployment using `deploy-frontend.sh`.

---

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** configured with credentials
2. **S3 bucket** for CloudFormation templates (will be created if doesn't exist)
3. **GitHub personal access token** ([Create one here](https://github.com/settings/tokens))
   - Required scopes: `repo`, `admin:repo_hook`

### Deployment

#### Option 1: Automated Script (Recommended)

```bash
cd infrastructure

# Get the latest Amazon Linux 2 AMI ID
./get-ami-id.sh

# Deploy the stack
./deploy.sh \
  linkbox-cfn-templates \           # S3 bucket name (will be created)
  linkbox-master \                  # CloudFormation stack name
  ami-091d7d61336a4c68f \          # AMI ID from previous command
  your-username/your-repo-name \   # GitHub repository
  ghp_xxxxxxxxxxxxxxxxxxxx          # GitHub token

# Enter database password when prompted
```

#### Option 2: Manual Deployment

```bash
# 1. Get latest AMI ID
./get-ami-id.sh

# 2. Create/verify S3 bucket exists
aws s3 mb s3://linkbox-cfn-templates

# 3. Upload templates
aws s3 sync . s3://linkbox-cfn-templates/ --exclude "*" --include "*.yml" --exclude "main.yml"

# 4. Deploy master stack
aws cloudformation create-stack \
  --stack-name linkbox-master \
  --template-body file://main.yml \
  --parameters \
    ParameterKey=TemplatesBucketName,ParameterValue=linkbox-cfn-templates \
    ParameterKey=AmiId,ParameterValue=ami-0abcdef1234567890 \
    ParameterKey=DBPassword,ParameterValue=YourSecurePassword123! \
    ParameterKey=GitHubRepo,ParameterValue=username/repo-name \
    ParameterKey=GitHubToken,ParameterValue=ghp_xxxxxxxxxxxx \
  --capabilities CAPABILITY_IAM

# 5. Wait for completion (15-20 minutes)
aws cloudformation wait stack-create-complete --stack-name linkbox-master
```

## 📋 Parameters Reference

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `EnvironmentName` | Environment prefix for resources | `linkbox` | No |
| `TemplatesBucketName` | S3 bucket containing nested templates | - | **Yes** |
| `AmiId` | Amazon Linux 2 AMI ID | - | **Yes** |
| `ECRImageUrl` | ECR image URL (placeholder ok initially) | `placeholder:latest` | No |
| `DBUsername` | Database master username | `linkbox` | No |
| `DBPassword` | Database master password | - | **Yes** |
| `GitHubRepo` | GitHub repository (user/repo) | - | **Yes** |
| `GitHubBranch` | GitHub branch to deploy | `main` | No |
| `GitHubToken` | GitHub personal access token | - | **Yes** |

## 📦 What Gets Created

### Network Stack (01-network.yml)
- VPC (10.20.0.0/16)
- 2 Public Subnets (Multi-AZ)
- 2 Private Subnets (Multi-AZ)
- Internet Gateway
- NAT Gateway (single, for cost optimization)
- Route Tables

**Estimated Cost:** ~$32/month (NAT Gateway)

### Database Stack (02-database.yml)
- RDS PostgreSQL 15 (db.t4g.micro)
- Database: `linkbox`
- Encrypted storage (20GB)
- Automated backups (7-day retention)
- Security Group
- SSM Parameter for endpoint

**Estimated Cost:** ~$15/month

### Backend Stack (03-backend.yml)
- Application Load Balancer
- Auto Scaling Group (1-2 instances)
- EC2 instances (t3.micro)
- ECR repository for Docker images
- S3 bucket for file uploads (with lifecycle)
- IAM roles and instance profiles
- Security Groups

**Estimated Cost:** ~$25/month (EC2 + ALB)

### Frontend Stack (04-frontend.yml)
- S3 bucket (static website hosting)
- CloudFront distribution
- Origin Access Identity (OAI)
- Custom error responses (SPA routing)

**Estimated Cost:** ~$1-5/month (depends on traffic)

### CI/CD Stack (05-cicd.yml)
- CodePipeline (3 stages)
- CodeBuild project
- CodeDeploy application
- GitHub webhook integration
- S3 artifacts bucket

**Estimated Cost:** ~$1-3/month (mostly free tier)

**Total Estimated Monthly Cost:** ~$75-80/month

## 🔐 Security Features

✅ **Network Security**
- Private subnets for RDS and EC2 instances
- Security groups with least privilege
- NAT Gateway for outbound traffic only

✅ **Data Security**
- RDS encryption at rest (AES-256)
- S3 bucket encryption (AES-256)
- Backup retention enabled
- No public database access

✅ **IAM Security**
- Least privilege policies
- Resource-specific permissions (no wildcards)
- SSM Parameter Store for sensitive configs

✅ **Operational Security**
- CloudWatch logging enabled
- Resource tagging for audit trails
- Versioned S3 buckets
- Automated security scanning (ECR)

## 📊 Monitoring

After deployment, check:

**CloudFormation Console:**
- Verify all 5 nested stacks show `CREATE_COMPLETE`

**CloudWatch Logs:**
- `/aws/codebuild/*` - Build logs
- `/aws/linkbox/*` - Application logs (after first deploy)

**Resource Health:**
```bash
# Check stack status
aws cloudformation describe-stacks --stack-name linkbox-master

# Check target group health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check RDS status
aws rds describe-db-instances --db-instance-identifier <db-identifier>
```

## 🛠️ Post-Deployment Steps

### 1. Build and Push Backend Image

```bash
# Get ECR repository URI from stack outputs
ECR_URI=$(aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryURI`].OutputValue' \
  --output text)

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_URI

# Build and push
cd ../backend
docker build -t $ECR_URI:latest .
docker push $ECR_URI:latest
```

### 2. Deploy Frontend

**Option A: Using Deployment Script (Recommended)**

```bash
cd infrastructure

# Deploy with default stack name (linkbox-master)
./deploy-frontend.sh

# Or specify custom stack name
./deploy-frontend.sh my-stack-name
```

The script will:
- ✅ Retrieve S3 bucket and CloudFront info from stack
- ✅ Install dependencies (npm install)
- ✅ Build frontend (npm run build)
- ✅ Deploy to S3 with optimal cache headers
- ✅ Invalidate CloudFront cache
- ✅ Display the application URL

**Option B: Manual Deployment**

```bash
# Get CloudFront bucket name from stack outputs
FRONTEND_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text)

# Build frontend
cd ../frontend
npm install
npm run build

# Deploy to S3
aws s3 sync dist/ s3://$FRONTEND_BUCKET/ --delete

# Invalidate CloudFront cache
CLOUDFRONT_DOMAIN=$(aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDomain`].OutputValue' \
  --output text)

CLOUDFRONT_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?DomainName=='$CLOUDFRONT_DOMAIN'].Id" \
  --output text)

aws cloudfront create-invalidation \
  --distribution-id $CLOUDFRONT_ID \
  --paths "/*"
```

### 3. Update Frontend Configuration

Before deploying the frontend, update the API endpoint in your frontend code:

```bash
# Get the CloudFront domain
CLOUDFRONT_DOMAIN=$(aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDomain`].OutputValue' \
  --output text)

echo "API Endpoint: https://$CLOUDFRONT_DOMAIN/api"
```

Update your frontend configuration file (e.g., `frontend/.env` or `frontend/src/config.ts`) with this API URL.

### 4. Access Your Application

```bash
# Get application URLs
aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].Outputs'
```

- **Frontend:** `https://<cloudfront-domain>`
- **API:** `https://<cloudfront-domain>/api/`
- **Backend ALB:** `http://<alb-dns-name>`

## 🔄 Updates and Maintenance

### Update Stack

```bash
# Re-run the deploy script with same parameters
./deploy.sh <same-parameters>

# Or update manually
aws cloudformation update-stack \
  --stack-name linkbox-master \
  --template-body file://main.yml \
  --parameters <same-parameters> \
  --capabilities CAPABILITY_IAM
```

### Update Nested Template

If you modify a nested template (e.g., `03-backend.yml`):

```bash
# Upload updated template
aws s3 cp 03-backend.yml s3://linkbox-cfn-templates/

# Update the main stack (will detect nested changes)
./deploy.sh <same-parameters>
```

## 🗑️ Cleanup

**⚠️ Warning:** This will delete all resources including data!

```bash
# Delete the main stack (will cascade to nested stacks)
aws cloudformation delete-stack --stack-name linkbox-master

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name linkbox-master

# Manually delete S3 buckets (they might have content)
aws s3 rb s3://linkbox-uploads --force
aws s3 rb s3://linkbox-frontend-<random> --force
aws s3 rb s3://linkbox-pipeline-artifacts-<account-id> --force
aws s3 rb s3://linkbox-cfn-templates --force
```

## 📚 Learning Resources

This infrastructure demonstrates:

1. **Nested Stacks** - Modular CloudFormation architecture
2. **Cross-Stack References** - Using Exports/Imports
3. **Multi-tier Architecture** - Frontend, Backend, Database separation
4. **Security Best Practices** - Least privilege, encryption, private subnets
5. **CI/CD Patterns** - Automated build and deployment
6. **High Availability** - Multi-AZ deployment (when scaled)

## 🐛 Troubleshooting

### Stack creation fails

```bash
# Check stack events
aws cloudformation describe-stack-events --stack-name linkbox-master

# Check nested stack failures
aws cloudformation describe-stacks --stack-name linkbox-backend
```

### Backend instances unhealthy

```bash
# Check instance logs
aws logs tail /aws/linkbox/backend --follow

# Check user data execution
aws ssm send-command \
  --instance-ids <instance-id> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cat /var/log/cloud-init-output.log"]'
```

### Database connection issues

- Verify security group rules allow port 5432
- Check SSM parameter has correct endpoint
- Verify DB credentials in UserData

### CI/CD pipeline fails

```bash
# Check CodeBuild logs
aws logs tail /aws/codebuild/linkbox-backend-build --follow

# Check CodeDeploy deployment
aws deploy get-deployment --deployment-id <deployment-id>
```

## 📝 Notes

- **Single NAT Gateway** - For cost savings; not HA
- **HTTP Only** - No SSL/TLS certificate configured
- **GitHub V1** - Using OAuth tokens (V2 with CodeStar recommended for production)
- **Small Instances** - t3.micro/db.t4g.micro for learning/development

## 📞 Support

See `INFRASTRUCTURE-FIXES.md` for detailed documentation of all security fixes and best practices applied.

---

**Ready to deploy! 🚀**

