# LinkBox - Database Connectivity Guide

Complete guide explaining how the backend connects to the database in different environments.

---

## 🔍 Overview

The LinkBox backend needs database credentials (username and password) to connect to PostgreSQL. The way these credentials are provided differs between local development and AWS production.

---

## 📊 Connectivity Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    LOCAL DEVELOPMENT                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Backend App (FastAPI)                                         │
│      ↓                                                          │
│  Reads DATABASE_URL from:                                      │
│    1. .env file (if exists)                                    │
│    2. Default in config.py                                     │
│      ↓                                                          │
│  postgresql://linkbox_user:linkbox_password@localhost:5432/... │
│      ↓                                                          │
│  Docker Compose PostgreSQL                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    AWS PRODUCTION                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. CloudFormation creates:                                    │
│     - RDS PostgreSQL                                           │
│     - SSM Parameters (encrypted):                              │
│         /linkbox/db-endpoint                                   │
│         /linkbox/db-username                                   │
│         /linkbox/db-password (SecureString)                    │
│         /linkbox/db-name                                       │
│                                                                 │
│  2. CodeDeploy triggers deployment script                      │
│      ↓                                                          │
│  3. start_application.sh:                                      │
│     - Reads SSM parameters (with decryption)                   │
│     - Constructs DATABASE_URL                                  │
│     - Passes to Docker container as env var                    │
│      ↓                                                          │
│  4. Backend App receives DATABASE_URL                          │
│      ↓                                                          │
│  5. Connects to RDS PostgreSQL                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔑 How Credentials Are Managed

### Local Development

**Method:** Hardcoded defaults (for ease of development)

**Location:** `backend/app/core/config.py`
```python
database_url: AnyUrl = "postgresql://linkbox_user:linkbox_password@localhost:5432/linkbox_dev"
```

**Database Setup:** `backend/docker-compose.yml`
```yaml
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: linkbox_user
      POSTGRES_PASSWORD: linkbox_password
      POSTGRES_DB: linkbox_dev
```

**Why this is safe:**
- Only works locally (localhost)
- Not exposed to internet
- Easy for developers to get started
- Can be overridden with .env file

---

### AWS Production

**Method:** AWS Systems Manager Parameter Store (SSM) - Encrypted & Secure

**Step 1: CloudFormation Creates Parameters**

**File:** `infrastructure/02-database.yml`

```yaml
DBEndpointParameter:
  Type: AWS::SSM::Parameter
  Properties:
    Name: /linkbox/db-endpoint
    Type: String
    Value: <RDS-endpoint>.rds.amazonaws.com

DBUsernameParameter:
  Type: AWS::SSM::Parameter
  Properties:
    Name: /linkbox/db-username
    Type: String
    Value: linkbox  # From CloudFormation parameter

DBPasswordParameter:
  Type: AWS::SSM::Parameter
  Properties:
    Name: /linkbox/db-password
    Type: SecureString  # ← ENCRYPTED!
    Value: <password>   # From CloudFormation parameter

DBNameParameter:
  Type: AWS::SSM::Parameter
  Properties:
    Name: /linkbox/db-name
    Type: String
    Value: linkbox
```

**Step 2: EC2 Instance Reads Parameters**

**File:** `scripts/start_application.sh`

```bash
# Read from Parameter Store
DB_ENDPOINT=$(aws ssm get-parameter \
    --name "/linkbox/db-endpoint" \
    --query Parameter.Value \
    --output text)

DB_USERNAME=$(aws ssm get-parameter \
    --name "/linkbox/db-username" \
    --query Parameter.Value \
    --output text)

DB_PASSWORD=$(aws ssm get-parameter \
    --name "/linkbox/db-password" \
    --with-decryption \    # ← Decrypts SecureString
    --query Parameter.Value \
    --output text)

# Construct DATABASE_URL
DATABASE_URL="postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_ENDPOINT}:5432/linkbox"
```

**Step 3: Pass to Docker Container**

```bash
docker run -d \
    --name linkbox-backend \
    -p 80:80 \
    -e DATABASE_URL=$DATABASE_URL \  # ← Injected here
    $IMAGE_URI
```

**Step 4: Backend Receives and Uses**

The backend app reads `DATABASE_URL` from environment variables (Pydantic Settings automatically loads this).

---

## 🔒 Security Features

### Production Security Measures

1. **Encrypted Storage** ✅
   - Password stored as SSM SecureString (AES-256)
   - Encrypted at rest in AWS

2. **IAM Permissions** ✅
   - Only EC2 instances with proper IAM role can read
   - Role policy scoped to `/linkbox/*` parameters only

3. **Network Security** ✅
   - RDS in private subnet (no internet access)
   - Security group only allows connections from backend instances
   - No public endpoint

4. **Audit Trail** ✅
   - All SSM parameter access logged to CloudTrail
   - Can track who/what accessed credentials

5. **Rotation Ready** 🔄
   - Can update SSM parameter to rotate password
   - Restart containers to pick up new value

---

## 📝 Deployment Flow

### Initial Infrastructure Deployment

```bash
# 1. Deploy infrastructure
cd infrastructure
./deploy.sh linkbox-cfn-templates linkbox-master ami-xxx github-repo token

# During deployment, you provide:
# - DBUsername: linkbox (default)
# - DBPassword: <your-secure-password>

# CloudFormation creates:
# ✅ RDS database
# ✅ SSM parameters with credentials
# ✅ EC2 instances with IAM role to read SSM
```

### Backend Deployment

```bash
# 2. Build and push Docker image
ECR_URI=<from-cloudformation>
docker build -t $ECR_URI:latest backend/
docker push $ECR_URI:latest

# 3. Git push triggers CodePipeline (or manual trigger)
git push origin main

# CodeDeploy executes on EC2:
# ✅ Pulls Docker image
# ✅ Reads SSM parameters (credentials)
# ✅ Starts container with DATABASE_URL
# ✅ Backend connects to RDS
```

---

## 🧪 Testing Connectivity

### Local Development

```bash
# 1. Start database
cd backend
docker-compose up -d db

# 2. Test connection
docker-compose exec db psql -U linkbox_user -d linkbox_dev

# 3. Start backend
uv run uvicorn app.main:app --reload

# 4. Check health
curl http://localhost:8000/health
```

### AWS Production

```bash
# 1. Check SSM parameters exist
aws ssm get-parameter --name /linkbox/db-endpoint
aws ssm get-parameter --name /linkbox/db-username
aws ssm get-parameter --name /linkbox/db-password --with-decryption

# 2. SSH into EC2 instance (via SSM Session Manager)
aws ssm start-session --target <instance-id>

# 3. Check Docker container environment
sudo docker exec linkbox-backend env | grep DATABASE_URL

# 4. Test database connection from container
sudo docker exec linkbox-backend bash -c "
apt-get update && apt-get install -y postgresql-client
psql \$DATABASE_URL -c 'SELECT version();'
"

# 5. Check application health
curl http://localhost:80/health
```

---

## 🔄 Updating Database Credentials

### In Production (Rotate Password)

```bash
# 1. Update SSM parameter
aws ssm put-parameter \
    --name /linkbox/db-password \
    --type SecureString \
    --value "new-secure-password" \
    --overwrite

# 2. Update RDS master password
aws rds modify-db-instance \
    --db-instance-identifier linkbox-db \
    --master-user-password "new-secure-password" \
    --apply-immediately

# 3. Restart backend containers (CodeDeploy or manual)
# They will read the new password from SSM
```

---

## 🐛 Troubleshooting

### Local: "Connection Refused"

```bash
# Check if database is running
docker-compose ps

# View logs
docker-compose logs db

# Verify connection string
echo "postgresql://linkbox_user:linkbox_password@localhost:5432/linkbox_dev"
```

### Production: "Could not connect to server"

```bash
# 1. Check security group rules
aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=*linkbox-db-sg*"

# Should show ingress from backend security group on port 5432

# 2. Verify SSM parameters
aws ssm get-parameter --name /linkbox/db-endpoint
aws ssm get-parameter --name /linkbox/db-password --with-decryption

# 3. Test from EC2 instance
aws ssm start-session --target <instance-id>
nc -zv <db-endpoint> 5432

# 4. Check IAM permissions
# EC2 instance role should have:
# - ssm:GetParameter for /linkbox/*
# - Decrypt permission for SSM SecureStrings
```

### "Authentication Failed"

```bash
# Verify credentials in SSM match RDS
aws ssm get-parameter --name /linkbox/db-username
aws ssm get-parameter --name /linkbox/db-password --with-decryption

# Check RDS master username
aws rds describe-db-instances \
    --db-instance-identifier linkbox-db \
    --query 'DBInstances[0].MasterUsername'
```

---

## 📖 Configuration Files Reference

### Backend Configuration
- **`app/core/config.py`** - Pydantic settings with DATABASE_URL
- **`ENV.EXAMPLE`** - Example environment variables
- **`docker-compose.yml`** - Local PostgreSQL setup

### Infrastructure
- **`infrastructure/02-database.yml`** - RDS + SSM parameters
- **`infrastructure/03-backend.yml`** - EC2 IAM role with SSM access

### Deployment Scripts
- **`scripts/start_application.sh`** - Reads SSM, starts Docker with DATABASE_URL
- **`scripts/stop_application.sh`** - Stops running containers
- **`scripts/install_dependencies.sh`** - Installs required packages

---

## ✅ Best Practices

1. **Never Hardcode Production Credentials** ✅
   - Use SSM Parameter Store
   - Use environment variables
   - Never commit .env files to git

2. **Use Strong Passwords** ✅
   - Minimum 12 characters
   - Mix of uppercase, lowercase, numbers, symbols
   - Use password generator

3. **Rotate Credentials Regularly** 🔄
   - Update SSM parameters
   - Update RDS password
   - Restart applications

4. **Monitor Access** 📊
   - Enable CloudTrail logging
   - Set up CloudWatch alarms
   - Review access logs

5. **Principle of Least Privilege** 🔒
   - IAM roles scoped to specific resources
   - Security groups limited to required ports
   - Network isolation with private subnets

---

## 📚 Related Documentation

- **`backend/LOCAL-DEVELOPMENT.md`** - Local development setup
- **`DEPLOYMENT-GUIDE.md`** - Full deployment walkthrough
- **`infrastructure/INFRASTRUCTURE-FIXES.md`** - Security improvements
- **AWS SSM Parameter Store**: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html

---

## 🎯 Summary

**Question:** Does the backend need username and password to connect to the database?

**Answer:** **YES**, but handled differently in each environment:

**Local Development:**
- Username: `linkbox_user`
- Password: `linkbox_password`
- Stored in: `docker-compose.yml` and `config.py`
- Security: Low (local only)

**AWS Production:**
- Username: From CloudFormation parameter (default: `linkbox`)
- Password: From CloudFormation parameter (your secure password)
- Stored in: SSM Parameter Store (encrypted SecureString)
- Retrieved by: Deployment scripts with IAM permissions
- Passed to: Docker container as environment variable
- Security: High (encrypted, audited, network-isolated)

**The backend ALWAYS needs credentials, but production credentials are never hardcoded - they're securely managed by AWS!** 🔐

---

**Need Help?**
- Check the troubleshooting section above
- Review CloudWatch logs: `/aws/linkbox/backend`
- Test connectivity from EC2 instance
- Verify SSM parameters and IAM permissions

