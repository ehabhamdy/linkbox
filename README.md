# LinkBox - AWS File Sharing Application

A cloud-native file sharing application built with FastAPI, React, and deployed on AWS using Infrastructure as Code.

---

## 📚 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Guide](#deployment-guide)
  - [1. Infrastructure Setup](#1-infrastructure-setup)
  - [2. Backend Deployment](#2-backend-deployment)
  - [3. Frontend Deployment](#3-frontend-deployment)
- [Local Development](#local-development)
- [CI/CD Pipeline](#cicd-pipeline)
- [Configuration](#configuration)
- [Stack Updates](#stack-updates)
- [Monitoring & Troubleshooting](#monitoring--troubleshooting)
- [Cost Estimation](#cost-estimation)
- [Security](#security)
- [Cleanup](#cleanup)

---

## Architecture Overview

### High-Level Architecture

```
Users (HTTPS)
    ↓
CloudFront CDN
    ↓
    ├─→ S3 (Static Frontend)
    └─→ ALB → EC2 (Backend API) → RDS PostgreSQL
              ↓
          S3 (File Uploads)
```

### Infrastructure Stack

```
main.yml (Master Stack)
├── 01-network.yml      → VPC, Subnets, NAT, Routes
├── 02-database.yml     → RDS PostgreSQL, Security
├── 03-backend.yml      → ALB, ASG, EC2, ECR, S3
├── 04-frontend.yml     → S3, CloudFront CDN
└── 05-cicd.yml         → CodePipeline, CodeBuild, CodeDeploy
```

### Key Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Frontend** | React + Vite | Static web application |
| **Backend** | FastAPI + Python | REST API |
| **Database** | PostgreSQL (RDS) | Persistent storage |
| **Storage** | S3 | File uploads |
| **CDN** | CloudFront | Content delivery |
| **Compute** | EC2 (Auto Scaling) | Application hosting |
| **Container** | Docker + ECR | Application packaging |
| **Load Balancer** | ALB | Traffic distribution |
| **CI/CD** | CodePipeline + CodeBuild + CodeDeploy | Automation |

---

## Features

### Application Features
- ✅ File upload with presigned URLs
- ✅ Short link generation
- ✅ File metadata storage
- ✅ Secure file access
- ✅ RESTful API

### Infrastructure Features
- ✅ Multi-AZ deployment (high availability ready)
- ✅ Auto Scaling for backend
- ✅ CloudFront CDN for global distribution
- ✅ Automated CI/CD pipeline
- ✅ Infrastructure as Code (CloudFormation)
- ✅ Security best practices (encryption, private subnets, IAM)

---

## Prerequisites

### Required Tools
- **AWS CLI** (v2.x) - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Docker** - For local development and image building
- **Node.js & npm** (v18+) - For frontend
- **Git** - Version control

### AWS Requirements
- AWS Account with administrative access
- AWS CLI configured with credentials:
  ```bash
  aws configure
  # Enter your AWS Access Key ID, Secret Access Key, and default region
  ```

### GitHub Setup
- GitHub account and repository
- Personal access token with scopes:
  - `repo` (Full control of private repositories)
  - `admin:repo_hook` (Full control of repository hooks)
  - [Create token here](https://github.com/settings/tokens)

### Knowledge Prerequisites
- Basic understanding of AWS services (VPC, EC2, RDS, S3)
- Familiarity with Docker and containers
- Basic command line proficiency

---

## Quick Start

Deploy the entire application in under 30 minutes:

```bash
# 1. Clone repository
git clone https://github.com/your-username/linkbox.git
cd linkbox

# 2. Get latest Amazon Linux 2 AMI
cd infrastructure
./get-ami-id.sh
# Copy the AMI ID shown (e.g., ami-091d7d61336a4c68f)

# 3. Deploy infrastructure (takes ~20 minutes)
./deploy.sh \
  linkbox-cfn-templates \                    # S3 bucket for templates
  linkbox-master \                           # Stack name
  ami-091d7d61336a4c68f \                   # AMI ID from step 2
  your-github-username/linkbox \            # Your GitHub repo
  ghp_xxxxxxxxxxxxxxxxxxxx                  # GitHub token

# When prompted, enter a secure database password (min 8 characters)

# 4. Deploy frontend (takes ~5 minutes)
./deploy-frontend.sh

# 5. Access your application
# URLs will be displayed at the end of deployment
```

---

## Deployment Guide

### 1. Infrastructure Setup

#### Step 1.1: Get AMI ID

```bash
cd infrastructure
./get-ami-id.sh
```

This fetches the latest Amazon Linux 2 AMI for your region. Copy the AMI ID shown.

#### Step 1.2: Deploy All Stacks

**Using the automated script (Recommended):**

```bash
./deploy.sh \
  linkbox-cfn-templates \           # S3 bucket name (created if doesn't exist)
  linkbox-master \                  # CloudFormation stack name
  ami-091d7d61336a4c68f \          # AMI ID from step 1.1
  username/repo-name \              # GitHub repository (owner/repo)
  ghp_xxxxxxxxxxxxxxxxxxxx          # GitHub personal access token

# Script will prompt for database password
```

**What this deploys:**
- ✅ VPC with public/private subnets (Multi-AZ)
- ✅ RDS PostgreSQL database (private subnet)
- ✅ Application Load Balancer
- ✅ Auto Scaling Group with EC2 instances
- ✅ S3 buckets (uploads + frontend)
- ✅ CloudFront distribution
- ✅ ECR repository for Docker images
- ✅ Complete CI/CD pipeline (CodePipeline, CodeBuild, CodeDeploy)

**Time:** 15-20 minutes

#### Step 1.3: Verify Deployment

```bash
# Check stack status
aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].StackStatus'
# Should return: CREATE_COMPLETE

# Get all outputs
aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].Outputs' \
  --output table
```

---

### 2. Backend Deployment

The backend deployment is **fully automated** through the CI/CD pipeline.

#### Step 2.1: Trigger Initial Deployment

**Option A: Push to GitHub (Automatic)**
```bash
git add .
git commit -m "Initial deployment"
git push origin main
# Pipeline automatically triggers
```

**Option B: Manual Trigger**
```bash
aws codepipeline start-pipeline-execution \
  --name linkbox-backend-pipeline
```

#### Step 2.2: Monitor Deployment

```bash
# Watch pipeline progress
aws codepipeline get-pipeline-state \
  --name linkbox-backend-pipeline \
  --query 'stageStates[*].{Stage:stageName,Status:latestExecution.status}' \
  --output table

# Watch CodeBuild logs (detailed)
aws logs tail /aws/codebuild/linkbox-backend-build --follow

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --query 'TargetGroups[?contains(TargetGroupName,`linkbox`)].TargetGroupArn' \
    --output text) \
  --query 'TargetHealthDescriptions[*].{Instance:Target.Id,Health:TargetHealth.State}'
```

#### Step 2.3: Test Backend API

```bash
# Get ALB DNS
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
  --output text)

# Test health endpoint
curl http://$ALB_DNS/health
# Expected response: {"status":"ok"}
```

**Time:** 5-10 minutes

---

### 3. Frontend Deployment

Frontend deployment is **manual** using the provided script.

#### Step 3.1: Configure API Endpoint (Optional)

If you want to customize the API endpoint:

```bash
# Create frontend/.env
cd frontend
cat > .env << EOF
VITE_API_URL=https://<cloudfront-domain>/api
EOF
```

Or edit `frontend/src/config.ts` directly.

#### Step 3.2: Deploy Frontend

```bash
cd infrastructure

# Deploy with default stack name
./deploy-frontend.sh

# Or with custom stack name
./deploy-frontend.sh my-stack-name
```

**What the script does:**
1. ✅ Retrieves S3 bucket and CloudFront info from CloudFormation
2. ✅ Installs npm dependencies
3. ✅ Builds production bundle (`npm run build`)
4. ✅ Syncs files to S3 with optimal cache headers
5. ✅ Invalidates CloudFront cache
6. ✅ Displays application URL

**Time:** 5 minutes + CloudFront propagation (5-15 minutes)

#### Step 3.3: Access Application

```bash
# Get application URL
CLOUDFRONT_DOMAIN=$(aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDomain`].OutputValue' \
  --output text)

echo "🌐 Application: https://$CLOUDFRONT_DOMAIN"

# Open in browser
open "https://$CLOUDFRONT_DOMAIN"
```

---

## Local Development

### Backend Development

#### Quick Start

```bash
# 1. Start PostgreSQL
cd backend
docker-compose up -d db

# 2. Install dependencies
pip install uv
uv sync

# 3. Run backend
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Access:**
- API: http://localhost:8000
- API Docs: http://localhost:8000/docs
- Health: http://localhost:8000/health

#### Default Database Configuration

```yaml
Host:     localhost
Port:     5432
Database: linkbox_dev
Username: linkbox_user
Password: linkbox_password
```

Connection String:
```
postgresql://linkbox_user:linkbox_password@localhost:5432/linkbox_dev
```

#### Database Management

```bash
# Access PostgreSQL with psql
docker-compose exec db psql -U linkbox_user -d linkbox_dev

# View tables
\dt

# Reset database
docker-compose down -v
docker-compose up -d db
```

#### Run Tests

```bash
# All tests
uv run pytest

# With coverage
uv run pytest --cov=app --cov-report=html

# Specific test
uv run pytest tests/test_api.py -v
```

### Frontend Development

```bash
cd frontend

# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

**Access:** http://localhost:5173

---

## CI/CD Pipeline

### Pipeline Architecture

```
GitHub (Push) → CodePipeline → CodeBuild → CodeDeploy → EC2
      ↓              ↓             ↓            ↓
   Webhook      Orchestrate    Build Docker   Deploy to
                               Push to ECR     Instances
```

### Pipeline Stages

| Stage | Tool | Actions |
|-------|------|---------|
| **Source** | CodePipeline | Pull code from GitHub (webhook-triggered) |
| **Build** | CodeBuild | Build Docker image, push to ECR, create artifacts |
| **Deploy** | CodeDeploy | Deploy to EC2 Auto Scaling Group via appspec.yml |

### How It Works

**On every push to `main` branch:**

1. **GitHub webhook** triggers CodePipeline
2. **CodeBuild** executes:
   - Logs into ECR
   - Builds Docker image from `backend/`
   - Tags with git commit hash
   - Pushes to ECR
   - Creates deployment artifacts
3. **CodeDeploy** executes on each EC2 instance:
   - Runs `scripts/stop_application.sh` (stop old container)
   - Runs `scripts/install_dependencies.sh` (install Docker, AWS CLI)
   - Copies files to `/opt/linkbox-backend`
   - Runs `scripts/start_application.sh` (start new container)
4. **Health checks** verify deployment
5. **Done!** New version is live

### Key Files

| File | Purpose | Location |
|------|---------|----------|
| `appspec.yml` | CodeDeploy configuration | Repository root |
| `buildspec-backend.yml` | CodeBuild build steps | `cicd/` |
| `install_dependencies.sh` | Install Docker, AWS CLI | `scripts/` |
| `start_application.sh` | Start application container | `scripts/` |
| `stop_application.sh` | Stop old container | `scripts/` |

### Manual Pipeline Trigger

```bash
# Trigger deployment manually
aws codepipeline start-pipeline-execution \
  --name linkbox-backend-pipeline

# Check pipeline status
aws codepipeline get-pipeline-state \
  --name linkbox-backend-pipeline
```

### GitHub Webhook Setup (Optional)

If webhook isn't auto-configured:

```bash
# Get webhook URL
WEBHOOK_URL=$(aws codepipeline list-webhooks \
  --query 'webhooks[?definition.name==`linkbox-github-webhook`].url' \
  --output text)

echo "Webhook URL: $WEBHOOK_URL"
```

Add to GitHub: Settings → Webhooks → Add webhook
- Payload URL: (paste webhook URL)
- Content type: `application/json`
- Secret: Your GitHub token
- Events: Just the push event

### GitHub V2 with CodeStar Connections

**Recommended for Production:** GitHub V2 with CodeStar Connections is more secure and provides better integration than V1 OAuth tokens.

#### Benefits of GitHub V2

- ✅ **No Personal Access Tokens** - More secure credential management
- ✅ **Fine-grained Permissions** - Better access control
- ✅ **OAuth App Integration** - Native GitHub authentication
- ✅ **Automatic Token Rotation** - AWS manages credentials
- ✅ **Better Auditing** - CloudTrail logs connection usage

#### Prerequisites

- GitHub repository
- AWS Console access
- Admin permissions in your GitHub account/organization

#### Step 1: Create CodeStar Connection

**Via AWS Console:**

1. Navigate to AWS CodePipeline Console
2. Go to **Settings** → **Connections**
3. Click **Create connection**
4. Select **GitHub** as the provider
5. Enter a connection name (e.g., `linkbox-github-connection`)
6. Click **Connect to GitHub**
7. Authorize AWS Connector for GitHub (one-time)
8. Install the AWS Connector app on your repository or organization
9. Copy the **Connection ARN** (e.g., `arn:aws:codestar-connections:us-east-1:123456789012:connection/abc123...`)

**Via AWS CLI:**

```bash
# Create the connection (this initiates the setup)
aws codestar-connections create-connection \
  --provider-type GitHub \
  --connection-name linkbox-github-connection

# Note: You still need to complete the handshake via the AWS Console
# The connection will be in PENDING state until completed
```

#### Step 2: Complete the GitHub Authorization

1. In the AWS Console, find your connection (Status: **PENDING**)
2. Click **Update pending connection**
3. Click **Install a new app** or select an existing installation
4. Authorize the AWS Connector for GitHub app
5. Grant access to your repository
6. Connection status should change to **Available**

#### Step 3: Modify CloudFormation Template

Update `infrastructure/05-cicd.yml` to use GitHub V2:

**Add new parameter:**

```yaml
Parameters:
  # ... existing parameters ...
  
  # Replace GitHubToken with CodeStarConnectionArn
  CodeStarConnectionArn:
    Type: String
    Description: ARN of the CodeStar Connection for GitHub (e.g., arn:aws:codestar-connections:region:account:connection/id)
```

**Update CodePipeline IAM Role:**

Add CodeStar Connections permissions:

```yaml
CodePipelineServiceRole:
  Type: AWS::IAM::Role
  Properties:
    # ... existing properties ...
    Policies:
      - PolicyName: CodePipelinePolicy
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
            # ... existing statements ...
            
            # Add this new statement for CodeStar Connections
            - Effect: Allow
              Action:
                - codestar-connections:UseConnection
              Resource: !Ref CodeStarConnectionArn
```

**Update Pipeline Source Stage:**

Replace GitHub V1 with V2:

```yaml
Stages:
  - Name: Source
    Actions:
      - Name: SourceAction
        ActionTypeId:
          Category: Source
          Owner: AWS          # Changed from ThirdParty
          Provider: CodeStarSourceConnection  # Changed from GitHub
          Version: '1'
        Configuration:
          ConnectionArn: !Ref CodeStarConnectionArn
          FullRepositoryId: !Ref GitHubRepo  # Format: owner/repo
          BranchName: !Ref GitHubBranch
          OutputArtifactFormat: CODE_ZIP  # or CODEBUILD_CLONE_REF
        OutputArtifacts:
          - Name: SourceOutput
```

**Remove GitHub Webhook:**

Delete the `GitHubWebhook` resource (not needed with V2):

```yaml
# Remove this entire resource
# GitHubWebhook:
#   Type: AWS::CodePipeline::Webhook
#   ...
```

#### Step 4: Deploy with CodeStar Connection

**Update your deployment script:**

```bash
cd infrastructure

# Deploy with CodeStar Connection ARN instead of GitHub token
./deploy.sh \
  linkbox-cfn-templates \
  linkbox-master \
  ami-091d7d61336a4c68f \
  your-username/repo-name \
  arn:aws:codestar-connections:us-east-1:123456789012:connection/abc123...
```

**Or update existing stack:**

```bash
aws cloudformation update-stack \
  --stack-name linkbox-master \
  --template-url https://s3.amazonaws.com/linkbox-cfn-templates/main.yml \
  --parameters \
    ParameterKey=CodeStarConnectionArn,ParameterValue=arn:aws:codestar-connections:... \
  --capabilities CAPABILITY_IAM
```

#### Step 5: Verify the Setup

```bash
# Check connection status
aws codestar-connections get-connection \
  --connection-arn arn:aws:codestar-connections:us-east-1:123456789012:connection/abc123...

# Expected output:
# {
#   "Connection": {
#     "ConnectionName": "linkbox-github-connection",
#     "ConnectionArn": "arn:...",
#     "ProviderType": "GitHub",
#     "ConnectionStatus": "AVAILABLE"
#   }
# }

# Test pipeline trigger
git add .
git commit -m "Test GitHub V2 trigger"
git push origin main

# Watch pipeline execution
aws codepipeline get-pipeline-state --name linkbox-backend-pipeline
```

#### Troubleshooting

**Connection shows PENDING:**
- Complete the GitHub OAuth flow in AWS Console
- Install AWS Connector app on your repository

**Pipeline fails with "Access Denied":**
- Verify CodePipeline role has `codestar-connections:UseConnection` permission
- Check that Connection ARN is correct in template

**Pipeline not triggering on push:**
- V2 connections use CloudWatch Events (automatic)
- No webhook configuration needed
- Check CloudTrail for connection usage logs

**Repository not accessible:**
- Ensure AWS Connector app has access to your repository
- Go to GitHub Settings → Applications → AWS Connector → Configure
- Grant repository access

#### Migration from V1 to V2

If you're already using GitHub V1:

1. Create CodeStar Connection (keep V1 active)
2. Update CloudFormation template with both parameters
3. Deploy stack update
4. Test pipeline with V2
5. Remove GitHub token parameter and V1 configuration
6. Delete GitHub webhook in repository settings (optional)

#### Security Best Practices

- ✅ Use CodeStar Connections (V2) for production
- ✅ Grant minimum repository access (specific repos, not all)
- ✅ Regularly audit connection permissions
- ✅ Use CloudTrail to monitor connection usage
- ✅ Rotate connections periodically
- ⚠️ Never commit Connection ARNs in public repositories (use SSM Parameter Store)

---

## Configuration

### Infrastructure Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `EnvironmentName` | Resource prefix | `linkbox` | No |
| `TemplatesBucketName` | S3 bucket for templates | - | Yes |
| `AmiId` | Amazon Linux 2 AMI ID | - | Yes |
| `DBUsername` | Database username | `linkbox` | No |
| `DBPassword` | Database password | - | Yes |
| `GitHubRepo` | Repository (owner/repo) | - | Yes |
| `GitHubBranch` | Branch to deploy | `main` | No |
| `GitHubToken` | Personal access token | - | Yes |

### Backend Environment Variables

**Production (AWS):**
- Configured via SSM Parameter Store
- Loaded by `scripts/start_application.sh`
- No manual configuration needed

**Local Development:**
Create `backend/.env`:
```bash
ENVIRONMENT=dev
AWS_REGION=us-east-1
S3_BUCKET_NAME=linkbox-uploads
DATABASE_URL=postgresql://linkbox_user:linkbox_password@localhost:5432/linkbox_dev
PRESIGNED_EXPIRY_SECONDS=3600
MAX_UPLOAD_BYTES=10485760
```

### Frontend Environment Variables

Create `frontend/.env`:
```bash
VITE_API_URL=https://<cloudfront-domain>/api
```

---

## Stack Updates

### Update Infrastructure Templates

Use the provided update scripts when you modify infrastructure code.

#### Quick Update (Keep Existing Parameters)

```bash
cd infrastructure
chmod +x quick-update.sh  # First time only

./quick-update.sh
# Uploads templates and updates stack with existing parameters
# Time: 10-20 minutes
```

#### Full Update (Change Parameters)

```bash
cd infrastructure
chmod +x update-stack.sh  # First time only

./update-stack.sh
# Interactive prompts to update parameters
# Can update AMI, passwords, GitHub settings, etc.
```

**Available scripts:**
- `quick-update.sh` - Fast update with existing settings
- `update-stack.sh` - Full interactive update
- `update-frontend.sh` - Manual frontend redeployment

**See:** `infrastructure/UPDATE-GUIDE.md` for detailed instructions

### Update Application Code

**Backend:** Automatic via CI/CD
```bash
# Make changes
git add .
git commit -m "Update backend feature"
git push origin main
# Pipeline automatically deploys
```

**Frontend:** Manual deployment
```bash
# Make changes
git add .
git commit -m "Update frontend UI"
git push origin main

# Deploy frontend
cd infrastructure
./deploy-frontend.sh
```

---

## Monitoring & Troubleshooting

### Check Stack Status

```bash
# Overall status
aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].StackStatus'

# View all outputs
aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].Outputs' \
  --output table

# Stack events (recent issues)
aws cloudformation describe-stack-events \
  --stack-name linkbox-master \
  --max-items 20
```

### Monitor CI/CD Pipeline

```bash
# Pipeline status
aws codepipeline get-pipeline-state \
  --name linkbox-backend-pipeline

# CodeBuild logs
aws logs tail /aws/codebuild/linkbox-backend-build --follow

# CodeDeploy deployments
aws deploy list-deployments \
  --application-name linkbox-backend-app \
  --max-items 5
```

### Check Application Health

```bash
# Target group health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=LinkBox" \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,State:State.Name,IP:PrivateIpAddress}'

# RDS database
aws rds describe-db-instances \
  --db-instance-identifier <db-id> \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address}'
```

### Access Application Logs

```bash
# EC2 instance logs (via SSM Session Manager)
aws ssm start-session --target <instance-id>

# View Docker logs
sudo docker logs $(sudo docker ps -q -f name=linkbox)

# CodeDeploy logs
sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log

# User data execution logs
sudo cat /var/log/cloud-init-output.log
```

### Common Issues

#### Pipeline Fails at Build Stage

**Check:**
```bash
# CodeBuild logs
aws logs tail /aws/codebuild/linkbox-backend-build --follow
```

**Common causes:**
- Docker build errors → Check `backend/Dockerfile`
- ECR login failed → Verify IAM permissions
- Wrong buildspec path → Should be `cicd/buildspec-backend.yml`

#### Deployment Fails

**Check:**
```bash
# Get deployment ID
DEPLOYMENT_ID=$(aws deploy list-deployments \
  --application-name linkbox-backend-app \
  --max-items 1 --query 'deployments[0]' --output text)

# View deployment details
aws deploy get-deployment --deployment-id $DEPLOYMENT_ID

# Check lifecycle events
aws deploy get-deployment-instance \
  --deployment-id $DEPLOYMENT_ID \
  --instance-id <instance-id>
```

**Common causes:**
- Unhealthy targets → Check application logs
- Script failures → Check `scripts/*.sh` permissions and syntax
- Missing files → Verify `appspec.yml` and file structure

#### Target Group Unhealthy

**Check:**
```bash
# Health check configuration
aws elbv2 describe-target-health --target-group-arn <arn>

# Test from EC2 instance
aws ssm start-session --target <instance-id>
curl localhost/health
```

**Common causes:**
- Application not running → Check Docker container
- Wrong health check path → Should be `/health`
- Database connection failed → Check security groups and credentials

---

## Cost Estimation

### Monthly AWS Costs

| Service | Configuration | Estimated Cost |
|---------|---------------|----------------|
| **NAT Gateway** | 1x NAT Gateway | ~$32 |
| **EC2 Instances** | 1-2x t3.micro | ~$15-30 |
| **RDS PostgreSQL** | 1x db.t4g.micro | ~$15 |
| **Application Load Balancer** | 1x ALB | ~$16 |
| **S3 + CloudFront** | Varies by traffic | ~$1-5 |
| **ECR + CodeBuild** | CI/CD services | ~$1-3 |
| **Data Transfer** | Outbound data | ~$5-10 |
| **Total** | | **~$85-110/month** |

### Cost Optimization Tips

1. **NAT Gateway** (~$32/mo) - Largest cost
   - Consider removing for non-production
   - Use VPC endpoints for AWS services

2. **Stop Non-Production Environments**
   ```bash
   # Stop instances when not in use
   aws autoscaling set-desired-capacity \
     --auto-scaling-group-name linkbox-backend-asg \
     --desired-capacity 0
   ```

3. **Use Smaller Instances**
   - t3.micro/t4g.micro for learning
   - Scale up for production

4. **Enable S3 Lifecycle Policies**
   - Already configured (30-day cleanup)
   - Adjust retention as needed

5. **Monitor Costs**
   ```bash
   # Current month spend
   aws ce get-cost-and-usage \
     --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
     --granularity MONTHLY \
     --metrics UnblendedCost
   ```

---

## Security

### Implemented Security Features

#### Network Security
- ✅ Private subnets for RDS and EC2
- ✅ Security groups with least privilege
- ✅ No public database access
- ✅ NAT Gateway for outbound traffic only

#### Data Security
- ✅ RDS encryption at rest (AES-256)
- ✅ S3 bucket encryption (AES-256)
- ✅ CloudFront HTTPS enforcement
- ✅ Automated backups (7-day retention)

#### IAM Security
- ✅ Least privilege IAM policies
- ✅ Resource-specific permissions (no wildcards where possible)
- ✅ SSM Parameter Store for sensitive configs
- ✅ EC2 instance profiles (no hardcoded credentials)

#### Application Security
- ✅ CORS configuration
- ✅ Presigned URLs for secure uploads
- ✅ Input validation
- ✅ SQL injection protection (SQLAlchemy ORM)

#### Operational Security
- ✅ CloudTrail logging enabled
- ✅ CloudWatch monitoring
- ✅ Resource tagging for audit trails
- ✅ Versioned S3 buckets

### Optional: IAM Database Authentication

For password-less database access:

```bash
# Enable IAM auth (already configured in templates)
# Use scripts/start_application_iam.sh instead

# Setup IAM DB user (one-time)
./scripts/setup_iam_db_user.sh

# Update appspec.yml to use IAM auth script
```

See: `IAM-DATABASE-AUTHENTICATION.md` for details

---

## Cleanup

**⚠️ WARNING:** This permanently deletes all resources and data!

### Delete Everything

```bash
# 1. Empty S3 buckets first (required)
aws s3 rm s3://linkbox-uploads --recursive
aws s3 rm s3://<frontend-bucket-name> --recursive  
aws s3 rm s3://linkbox-pipeline-artifacts-<account-id> --recursive

# Delete all images
aws ecr batch-delete-image \
  --repository-name linkbox-backend \
  --image-ids "$(aws ecr list-images \
    --repository-name linkbox-backend \
    --query 'imageIds[*]' \
    --output json)"

# 2. Delete main stack (cascades to nested stacks)
aws cloudformation delete-stack --stack-name linkbox-master

# 3. Wait for deletion (~10-15 minutes)
aws cloudformation wait stack-delete-complete --stack-name linkbox-master

# 4. Delete S3 buckets
aws s3 rb s3://linkbox-uploads --force
aws s3 rb s3://<frontend-bucket-name> --force
aws s3 rb s3://linkbox-pipeline-artifacts-<account-id> --force

# 5. Delete templates bucket
aws s3 rb s3://linkbox-cfn-templates --force

echo "✅ All resources deleted"
```

### Partial Cleanup

To keep infrastructure but stop costs:

```bash
# Stop EC2 instances
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name linkbox-backend-asg \
  --desired-capacity 0

# Stop RDS database
aws rds stop-db-instance --db-instance-identifier <db-id>
```

---

## Project Structure

```
linkbox/
├── backend/                    # FastAPI backend
│   ├── app/
│   │   ├── main.py            # Application entry point
│   │   ├── models.py          # Database models
│   │   ├── api/               # API routes
│   │   ├── core/              # Configuration
│   │   └── utils/             # Utilities
│   ├── Dockerfile             # Container definition
│   ├── requirements.txt       # Python dependencies
│   └── docker-compose.yml     # Local development
│
├── frontend/                  # React frontend
│   ├── src/
│   ├── public/
│   ├── package.json
│   └── vite.config.js
│
├── infrastructure/            # CloudFormation templates
│   ├── main.yml              # Master stack
│   ├── 01-network.yml        # VPC, subnets, routing
│   ├── 02-database.yml       # RDS PostgreSQL
│   ├── 03-backend.yml        # EC2, ALB, ASG, ECR
│   ├── 04-frontend.yml       # S3, CloudFront
│   ├── 05-cicd.yml           # Pipeline, CodeBuild, CodeDeploy
│   ├── deploy.sh             # Deployment script
│   ├── deploy-frontend.sh    # Frontend deployment
│   ├── quick-update.sh       # Fast stack updates
│   ├── update-stack.sh       # Full stack updates
│   └── get-ami-id.sh         # Fetch latest AMI
│
├── cicd/
│   └── buildspec-backend.yml # CodeBuild configuration
│
├── scripts/                   # CodeDeploy lifecycle hooks
│   ├── install_dependencies.sh
│   ├── start_application.sh
│   ├── stop_application.sh
│   ├── start_application_iam.sh  # IAM auth version
│   └── setup_iam_db_user.sh
│
├── appspec.yml               # CodeDeploy configuration
└── README.md                 # This file
```

---

## Additional Documentation

Detailed documentation for specific topics:

| Document | Description |
|----------|-------------|
| `infrastructure/README.md` | Infrastructure details and reference |
| `infrastructure/UPDATE-GUIDE.md` | Stack update procedures |
| `infrastructure/INFRASTRUCTURE-FIXES.md` | Applied security fixes |
| `backend/LOCAL-DEVELOPMENT.md` | Backend development guide |
| `IAM-DATABASE-AUTHENTICATION.md` | IAM auth setup |
| `infrastructure-diagram.md` | Visual architecture diagram |

---

## Useful Commands Reference

### Infrastructure

```bash
# Get stack outputs
aws cloudformation describe-stacks --stack-name linkbox-master \
  --query 'Stacks[0].Outputs' --output table

# Update stack (quick)
cd infrastructure && ./quick-update.sh

# Get latest AMI
./infrastructure/get-ami-id.sh
```

### Application

```bash
# Trigger backend deployment
aws codepipeline start-pipeline-execution --name linkbox-backend-pipeline

# Deploy frontend
cd infrastructure && ./deploy-frontend.sh

# Check backend health
curl http://<alb-dns>/health

# View application logs
aws logs tail /aws/codebuild/linkbox-backend-build --follow
```

### Monitoring

```bash
# Pipeline status
aws codepipeline get-pipeline-state --name linkbox-backend-pipeline

# Target health
aws elbv2 describe-target-health --target-group-arn <arn>

# EC2 instances
aws ec2 describe-instances --filters "Name=tag:Project,Values=LinkBox"

# SSM Session Manager (access EC2)
aws ssm start-session --target <instance-id>
```

### Local Development

```bash
# Backend
cd backend
docker-compose up -d db
uv run uvicorn app.main:app --reload

# Frontend  
cd frontend
npm run dev

# Run tests
cd backend && uv run pytest
```

---

## Support & Resources

### AWS Documentation
- [CloudFormation](https://docs.aws.amazon.com/cloudformation/)
- [CodePipeline](https://docs.aws.amazon.com/codepipeline/)
- [EC2 Auto Scaling](https://docs.aws.amazon.com/autoscaling/)
- [RDS](https://docs.aws.amazon.com/rds/)

### Project Resources
- **Architecture Diagram**: `infrastructure-diagram.md`
- **Cost Calculator**: [AWS Pricing Calculator](https://calculator.aws/)
- **GitHub Issues**: For bug reports and features

### Getting Help

1. Check the troubleshooting section above
2. Review CloudFormation events for errors
3. Check CloudWatch Logs for application logs
4. Verify security group rules and IAM permissions
5. Review additional documentation in project

---

## License

[Your License Here]

---

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

**Built with ❤️ for learning AWS and cloud-native architectures**

**Ready to deploy! 🚀**
