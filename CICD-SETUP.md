# LinkBox CI/CD Setup Guide

This guide will help you set up a simple CI/CD pipeline using AWS services for your LinkBox application.

## Overview

The CI/CD pipeline includes:
- **AWS CodePipeline**: Orchestrates the entire deployment process
- **AWS CodeBuild**: Builds Docker images and pushes to ECR
- **AWS CodeDeploy**: Deploys applications to EC2 instances
- **Amazon ECR**: Stores Docker images
- **GitHub Integration**: Automatically triggers on code changes

## Architecture

```
GitHub → CodePipeline → CodeBuild → ECR → CodeDeploy → EC2 Instances
```

## Prerequisites

1. **GitHub Repository**: Your code should be in a GitHub repository
2. **GitHub Personal Access Token**: Required for webhook integration
3. **AWS Account**: With appropriate permissions
4. **Domain**: (Optional) For custom domain setup

## Step-by-Step Setup

### 1. Create GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Click "Generate new token (classic)"
3. Select these scopes:
   - `repo` (Full control of private repositories)
   - `admin:repo_hook` (Full control of repository hooks)
4. Save the token securely - you'll need it for CloudFormation

### 2. Prepare Your Repository

Ensure your repository has these files (already created):
- `appspec.yml` - CodeDeploy application specification
- `cicd/buildspec-backend.yml` - CodeBuild build specification
- `scripts/install_dependencies.sh` - Installation script
- `scripts/start_application.sh` - Application start script
- `scripts/stop_application.sh` - Application stop script

### 3. Deploy Infrastructure

Deploy the CloudFormation stacks in order:

```bash
# 1. Network Stack
aws cloudformation create-stack \
  --stack-name linkbox-network \
  --template-body file://infrastructure/01-network.yml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=linkbox

# 2. Database Stack
aws cloudformation create-stack \
  --stack-name linkbox-database \
  --template-body file://infrastructure/02-database.yml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=linkbox \
               ParameterKey=DBUsername,ParameterValue=linkbox \
               ParameterKey=DBPassword,ParameterValue=your-secure-password

# 3. Backend Stack (includes ECR)
aws cloudformation create-stack \
  --stack-name linkbox-backend \
  --template-body file://infrastructure/03-backend.yml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=linkbox \
               ParameterKey=AmiId,ParameterValue=ami-0abcdef1234567890 \
               ParameterKey=ECRImageUrl,ParameterValue=your-account.dkr.ecr.region.amazonaws.com/linkbox-backend:latest \
               ParameterKey=DBUsername,ParameterValue=linkbox \
               ParameterKey=DBPassword,ParameterValue=your-secure-password \
  --capabilities CAPABILITY_IAM

# 4. CI/CD Stack
aws cloudformation create-stack \
  --stack-name linkbox-cicd \
  --template-body file://infrastructure/05-cicd.yml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=linkbox \
               ParameterKey=GitHubRepo,ParameterValue=yourusername/yourrepo \
               ParameterKey=GitHubBranch,ParameterValue=main \
               ParameterKey=GitHubToken,ParameterValue=your-github-token \
  --capabilities CAPABILITY_IAM
```

### 4. Initial Image Push

Since CodeDeploy needs an initial image, push one manually:

```bash
# Get ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin your-account.dkr.ecr.us-east-1.amazonaws.com

# Build and push initial image
cd backend
docker build -t linkbox-backend .
docker tag linkbox-backend:latest your-account.dkr.ecr.us-east-1.amazonaws.com/linkbox-backend:latest
docker push your-account.dkr.ecr.us-east-1.amazonaws.com/linkbox-backend:latest
```

## How It Works

### When you push code to GitHub:

1. **GitHub Webhook** triggers CodePipeline
2. **CodePipeline** starts the deployment process
3. **CodeBuild** runs and:
   - Logs into ECR
   - Builds Docker image from `backend/` directory
   - Tags image with git commit hash
   - Pushes image to ECR
   - Creates `imagedefinitions.json` with image URI
4. **CodeDeploy** deploys to EC2 instances by:
   - Running `scripts/stop_application.sh` (stops old container)
   - Running `scripts/install_dependencies.sh` (installs dependencies)
   - Running `scripts/start_application.sh` (starts new container)

### Deployment Scripts Explained

**install_dependencies.sh**:
- Installs Docker and AWS CLI
- Creates application directory

**stop_application.sh**:
- Stops and removes existing Docker container

**start_application.sh**:
- Reads image URI from build artifacts
- Logs into ECR
- Pulls new Docker image
- Starts new container with environment variables

## Configuration

### Environment Variables

The deployment scripts use these environment variables:
- `S3_BUCKET_NAME`: S3 bucket for file uploads
- `AWS_REGION`: AWS region
- `DATABASE_URL`: PostgreSQL connection string

### Customization

You can customize the pipeline by:
1. Modifying `buildspec-backend.yml` for different build steps
2. Updating deployment scripts for different deployment logic
3. Changing CodeDeploy configuration for different deployment strategies

## Monitoring

### View Pipeline Status
```bash
aws codepipeline get-pipeline-state --name linkbox-backend-pipeline
```

### View Build Logs
```bash
aws logs tail /aws/codebuild/linkbox-backend-build --follow
```

### View Deployment Status
```bash
aws deploy get-deployment --deployment-id <deployment-id>
```

## Troubleshooting

### Common Issues

1. **Build Fails**:
   - Check CodeBuild logs in CloudWatch
   - Verify ECR permissions
   - Check Docker syntax in buildspec

2. **Deployment Fails**:
   - Check CodeDeploy agent logs: `/var/log/aws/codedeploy-agent/`
   - Verify EC2 instance has proper IAM role
   - Check deployment scripts permissions

3. **Container Won't Start**:
   - Check Docker logs: `docker logs linkbox-backend`
   - Verify environment variables
   - Check database connectivity

### Debug Commands

```bash
# Check CodeDeploy agent status
sudo service codedeploy-agent status

# View deployment logs
sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log

# Check Docker container
docker ps -a
docker logs linkbox-backend
```

## Security Best Practices

1. **GitHub Token**: Store securely, use minimal required permissions
2. **Database Password**: Use AWS Secrets Manager instead of plain text
3. **IAM Roles**: Follow principle of least privilege
4. **ECR Images**: Enable vulnerability scanning
5. **Environment Variables**: Use Parameter Store for sensitive data

## Cost Optimization

1. **ECR Lifecycle Policy**: Automatically delete old images (already configured)
2. **CodeBuild**: Use appropriate instance size
3. **EC2 Instances**: Use appropriate instance types
4. **S3 Artifacts**: Set lifecycle policies for old artifacts

## Next Steps

1. Set up monitoring with CloudWatch
2. Add automated testing to the pipeline
3. Implement blue-green deployments
4. Add notifications (SNS, Slack)
5. Set up multiple environments (dev, staging, prod)

This setup provides a solid foundation for CI/CD with AWS services, automatically building and deploying your application whenever you push code to GitHub.