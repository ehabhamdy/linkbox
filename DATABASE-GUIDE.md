# LinkBox Database Guide

Complete guide to database setup, connectivity, and security for the LinkBox application.

---

## 📑 Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture Overview](#architecture-overview)
3. [Local Development](#local-development)
4. [Production Deployment](#production-deployment)
5. [Authentication Methods](#authentication-methods)
6. [IAM Authentication Setup](#iam-authentication-setup)
7. [Security & Best Practices](#security--best-practices)
8. [Troubleshooting](#troubleshooting)
9. [Configuration Reference](#configuration-reference)

---

## 🚀 Quick Start

### Local Development
```bash
cd backend
docker-compose up -d db
uv run uvicorn app.main:app --reload
```

### Production (Password Auth)
```bash
./infrastructure/deploy.sh <params>
git push origin main  # Auto-deploys via CodePipeline
```

### Production (IAM Auth - Recommended)
```bash
# 1. Deploy infrastructure
./infrastructure/deploy.sh <params>

# 2. Setup IAM user (once)
./scripts/setup_iam_db_user.sh linkbox us-east-1

# 3. Deploy with IAM
# Update appspec.yml to use start_application_iam.sh
git push origin main
```

---

## 🏗 Architecture Overview

### Local Development Flow
```
Backend App (FastAPI)
    ↓
Reads DATABASE_URL from:
  1. .env file (if exists)
  2. Default in config.py
    ↓
postgresql://linkbox_user:linkbox_password@localhost:5432/linkbox_dev
    ↓
Docker Compose PostgreSQL
```

### Production Flow (Password Auth)
```
CloudFormation
  ↓ Creates
AWS Systems Manager Parameter Store
  - /linkbox/db-endpoint
  - /linkbox/db-username
  - /linkbox/db-password (encrypted)
  - /linkbox/db-name
    ↓
EC2 reads via IAM role
    ↓
start_application.sh
  - Reads SSM parameters
  - Constructs DATABASE_URL
  - Passes to Docker container
    ↓
Backend connects to RDS
```

### Production Flow (IAM Auth - Recommended)
```
CloudFormation
  ↓ Creates
RDS with IAM auth enabled
    +
EC2 IAM role with rds-db:connect
    ↓
start_application_iam.sh
  - No password needed!
  - Backend generates auth token
    ↓
Backend connects with token (15 min validity)
  - Token auto-refreshes
  - All access logged to CloudTrail
```

---

## 💻 Local Development

### Prerequisites
- Docker & Docker Compose
- Python 3.13+
- uv package manager

### Database Setup

**1. Start PostgreSQL**
```bash
cd backend
docker-compose up -d db
```

**Configuration in `docker-compose.yml`:**
```yaml
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: linkbox_user
      POSTGRES_PASSWORD: linkbox_password
      POSTGRES_DB: linkbox_dev
    ports:
      - "5432:5432"
```

**2. Backend Configuration**

**Default in `config.py`:**
```python
database_url: AnyUrl = "postgresql://linkbox_user:linkbox_password@localhost:5432/linkbox_dev"
```

**Override with `.env` file:**
```bash
DATABASE_URL=postgresql://linkbox_user:linkbox_password@localhost:5432/linkbox_dev
```

**3. Test Connection**
```bash
# Via psql
docker-compose exec db psql -U linkbox_user -d linkbox_dev

# Via backend
uv run uvicorn app.main:app --reload
curl http://localhost:8000/health
```

### Using pgAdmin (Optional)
```yaml
# Add to docker-compose.yml
pgadmin:
  image: dpage/pgadmin4
  environment:
    PGADMIN_DEFAULT_EMAIL: admin@linkbox.com
    PGADMIN_DEFAULT_PASSWORD: admin
  ports:
    - "5050:80"
```

Access: http://localhost:5050

---

## 🚀 Production Deployment

### Infrastructure Setup

**1. Deploy CloudFormation Stacks**
```bash
cd infrastructure
./deploy.sh \
  linkbox-cfn-templates \    # S3 bucket for templates
  linkbox-master \            # Stack name
  ami-xxxxx \                 # Amazon Linux 2 AMI
  github-repo \               # Your GitHub repo
  github-token                # GitHub PAT
```

**During deployment, provide:**
- `DBUsername`: Database master username (default: linkbox)
- `DBPassword`: Strong password (12+ chars)

**What gets created:**
- RDS PostgreSQL instance
- SSM Parameters (encrypted credentials)
- EC2 instances with IAM roles
- Security groups (network isolation)

**2. SSM Parameters Created**

| Parameter | Type | Description |
|-----------|------|-------------|
| `/linkbox/db-endpoint` | String | RDS endpoint address |
| `/linkbox/db-name` | String | Database name (linkbox) |
| `/linkbox/db-username` | String | Master username |
| `/linkbox/db-password` | SecureString | Master password (encrypted) |

**3. EC2 IAM Permissions**

Instances automatically get permissions to:
- Read SSM parameters (`/linkbox/*`)
- Decrypt SecureString parameters
- Connect to RDS via IAM (`rds-db:connect`)

---

## 🔐 Authentication Methods

You have **two authentication methods** available:

### Method 1: Password Authentication (Default)

**How it works:**
1. CloudFormation stores encrypted password in SSM
2. Deployment script reads password (decrypted)
3. Constructs `DATABASE_URL` with password
4. Backend connects to RDS

**Pros:**
- ✅ Simple and straightforward
- ✅ Works everywhere (local, AWS)
- ✅ No additional setup
- ✅ Easy to understand

**Cons:**
- ⚠️ Password must be stored (even if encrypted)
- ⚠️ Manual rotation required
- ⚠️ Static credential

**Best for:**
- Local development
- Testing/staging environments
- Quick prototyping

**Security Rating:** ⭐⭐⭐⭐☆ (Good)

---

### Method 2: IAM Authentication (Recommended for Production)

**How it works:**
1. Backend requests auth token from AWS
2. AWS generates token (valid 15 minutes)
3. Token used as password
4. Token automatically refreshes

**Pros:**
- ✅ **No password stored anywhere**
- ✅ Tokens auto-expire (15 minutes)
- ✅ CloudTrail audit logging
- ✅ AWS security best practice
- ✅ Zero secrets management

**Cons:**
- ⚠️ Only works on AWS (requires IAM role)
- ⚠️ Requires initial setup
- ⚠️ Requires SSL connection

**Best for:**
- **Production AWS deployments** ← Recommended
- Security/compliance requirements
- Following AWS best practices

**Security Rating:** ⭐⭐⭐⭐⭐ (Excellent)

---

### Comparison Table

| Feature | Password Auth | IAM Auth |
|---------|--------------|----------|
| **Setup Complexity** | Simple | Moderate |
| **Credential Storage** | SSM (encrypted) | None |
| **Credential Rotation** | Manual | Automatic (15 min) |
| **Works Locally** | ✅ Yes | ❌ No (AWS only) |
| **Works on AWS** | ✅ Yes | ✅ Yes |
| **Security Level** | Good | Excellent |
| **Audit Logging** | SSM access | All DB access |
| **AWS Best Practice** | ✅ Acceptable | ✅✅ Recommended |
| **Compliance** | Meets most | Meets strict requirements |

---

## 🔐 IAM Authentication Setup

### Prerequisites
- RDS with IAM auth enabled (already configured)
- EC2 IAM role with `rds-db:connect` (already configured)
- PostgreSQL client (`psql`)

### Step 1: Create IAM Database User (One-Time)

**From your local machine or bastion host:**
```bash
./scripts/setup_iam_db_user.sh linkbox us-east-1
```

**What it does:**
```sql
CREATE USER linkbox_iam_user WITH LOGIN;
GRANT rds_iam TO linkbox_iam_user;
GRANT ALL PRIVILEGES ON DATABASE linkbox TO linkbox_iam_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO linkbox_iam_user;
```

**Note:** This user has **NO PASSWORD** and can only authenticate via IAM tokens.

### Step 2: Update Deployment Configuration

**Option A: Update appspec.yml**
```yaml
hooks:
  ApplicationStart:
    - location: scripts/start_application_iam.sh  # ← Use IAM script
      timeout: 300
      runas: ec2-user
```

**Option B: Modify existing script**

Edit `scripts/start_application.sh` and add IAM environment variables:
```bash
docker run -d \
    --name linkbox-backend \
    -p 80:80 \
    -e ENVIRONMENT=production \
    -e AWS_REGION=$AWS_REGION \
    -e S3_BUCKET_NAME=$S3_BUCKET_NAME \
    -e USE_IAM_DB_AUTH=true \
    -e DB_ENDPOINT=$DB_ENDPOINT \
    -e DB_NAME=$DB_NAME \
    -e DB_IAM_USER=linkbox_iam_user \
    -e DB_PORT=5432 \
    --restart unless-stopped \
    $IMAGE_URI
```

### Step 3: Deploy
```bash
git add .
git commit -m "Enable IAM database authentication"
git push origin main  # Triggers CodePipeline
```

### Step 4: Verify

**Check container environment:**
```bash
# SSH to EC2 instance
aws ssm start-session --target <instance-id>

# Check IAM auth is enabled
sudo docker exec linkbox-backend env | grep USE_IAM_DB_AUTH
# Expected: USE_IAM_DB_AUTH=true
```

**Test connection:**
```bash
# Check health endpoint
curl http://localhost/health

# View logs
sudo docker logs linkbox-backend

# Look for:
# INFO: Generating IAM auth token for linkbox_iam_user@xxx.rds.amazonaws.com
# INFO: IAM auth token generated successfully
```

### How IAM Auth Works (Technical Details)

**Token Generation:**
```python
# Backend code (app/utils/db_iam_auth.py)
client = boto3.client('rds', region_name='us-east-1')
token = client.generate_db_auth_token(
    DBHostname='xxx.rds.amazonaws.com',
    Port=5432,
    DBUsername='linkbox_iam_user',
    Region='us-east-1'
)
# Token valid for 15 minutes
```

**Connection String:**
```python
# Token used as password
conn_str = f"postgresql://linkbox_iam_user:{token}@endpoint:5432/linkbox?sslmode=require"
```

**Automatic Refresh:**
- SQLAlchemy connection pool handles token refresh
- `pool_pre_ping=True` ensures connections are alive
- `pool_recycle=600` recycles connections every 10 minutes (before token expiry)

---

## 🔒 Security & Best Practices

### Network Security

**1. RDS Isolation**
- ✅ Private subnets only (no internet access)
- ✅ Security group allows only backend instances
- ✅ No public endpoint

**2. Encryption**
- ✅ Data at rest (RDS storage encryption)
- ✅ Data in transit (SSL/TLS required)
- ✅ Password storage (SSM SecureString with AES-256)

**3. Access Control**
- ✅ IAM policies (least privilege)
- ✅ Security groups (network segmentation)
- ✅ CloudTrail logging (audit trail)

### Credential Management

**For Password Auth:**
```bash
# ✅ DO: Use strong passwords
DBPassword: "Xy9$mK2@pL4#qR8!"

# ✅ DO: Store in SSM SecureString
aws ssm put-parameter \
    --name /linkbox/db-password \
    --type SecureString \
    --value "secure-password"

# ❌ DON'T: Hardcode in code
DATABASE_URL = "postgresql://user:password@..."

# ❌ DON'T: Commit to git
.env  # Should be in .gitignore
```

**For IAM Auth:**
```bash
# ✅ DO: Use IAM authentication
USE_IAM_DB_AUTH=true

# ✅ DO: Least privilege IAM policies
Action: rds-db:connect
Resource: arn:aws:rds-db:*:*:dbuser:*/linkbox_iam_user

# ✅ DO: Monitor CloudTrail logs
aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::RDS::DBUser
```

### Password Rotation

**Manual Rotation (Password Auth):**
```bash
# 1. Update SSM parameter
aws ssm put-parameter \
    --name /linkbox/db-password \
    --type SecureString \
    --value "new-secure-password" \
    --overwrite

# 2. Update RDS master password
aws rds modify-db-instance \
    --db-instance-identifier linkbox-postgres \
    --master-user-password "new-secure-password" \
    --apply-immediately

# 3. Restart backend containers
# (They will read the new password from SSM)
```

**Automatic Rotation (IAM Auth):**
- ✅ Tokens automatically expire every 15 minutes
- ✅ New tokens generated automatically
- ✅ No manual intervention needed

### Monitoring & Auditing

**CloudWatch Logs:**
```bash
# View backend logs
aws logs tail /aws/linkbox/backend --follow

# Search for connection errors
aws logs filter-pattern /aws/linkbox/backend --filter-pattern "database error"
```

**CloudTrail (IAM Auth):**
```bash
# View database access events
aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=EventName,AttributeValue=connect \
    --max-results 50
```

**RDS Performance Insights:**
- Monitor connection counts
- Track slow queries
- Identify performance bottlenecks

---

## 🐛 Troubleshooting

### Local Development Issues

**Problem: "Connection refused"**
```bash
# Check if database is running
docker-compose ps

# View database logs
docker-compose logs db

# Restart database
docker-compose restart db

# Verify port is listening
nc -zv localhost 5432
```

**Problem: "Authentication failed"**
```bash
# Verify credentials in docker-compose.yml
docker-compose exec db psql -U linkbox_user -d linkbox_dev

# Check config.py default DATABASE_URL
# Should match docker-compose environment variables
```

### Production Issues (Password Auth)

**Problem: "Could not connect to server"**
```bash
# 1. Check SSM parameters exist
aws ssm get-parameter --name /linkbox/db-endpoint
aws ssm get-parameter --name /linkbox/db-password --with-decryption

# 2. Verify security group rules
aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=*linkbox-db-sg*"
# Should show ingress from backend SG on port 5432

# 3. Test from EC2 instance
aws ssm start-session --target <instance-id>
nc -zv <db-endpoint> 5432

# 4. Check IAM permissions for SSM
aws iam get-role-policy \
    --role-name linkbox-instance-role \
    --policy-name SSMParameterAccess
```

**Problem: "Authentication failed"**
```bash
# Verify credentials match between SSM and RDS
aws ssm get-parameter --name /linkbox/db-username
aws ssm get-parameter --name /linkbox/db-password --with-decryption

aws rds describe-db-instances \
    --db-instance-identifier linkbox-postgres \
    --query 'DBInstances[0].MasterUsername'
```

### Production Issues (IAM Auth)

**Problem: "User does not exist"**
```bash
# IAM database user not created
# Solution: Run setup script
./scripts/setup_iam_db_user.sh linkbox us-east-1
```

**Problem: "Permission denied for database"**
```bash
# IAM user lacks permissions
# Solution: Re-run setup script or manually grant
psql -h <endpoint> -U linkbox -d linkbox << EOF
GRANT ALL PRIVILEGES ON DATABASE linkbox TO linkbox_iam_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO linkbox_iam_user;
EOF
```

**Problem: "Token has expired"**
```bash
# Tokens valid for 15 minutes - should auto-refresh
# Check connection pool settings in db.py:

# Should have:
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,  # ← Verifies connections
    pool_recycle=600     # ← Recycles every 10 min
)
```

**Problem: "No credentials available"**
```bash
# EC2 instance doesn't have IAM permissions
# Verify rds-db:connect permission:
aws iam get-role-policy \
    --role-name linkbox-instance-role \
    --policy-name RDSIAMAuthentication

# Should show:
# Action: rds-db:connect
# Resource: arn:aws:rds-db:*:*:dbuser:*/linkbox_iam_user
```

**Problem: "SSL connection required"**
```bash
# IAM auth requires SSL
# Verify connection string includes ?sslmode=require
# Already configured in db_iam_auth.py ✅
```

### General Debugging

**Check Docker container logs:**
```bash
sudo docker logs linkbox-backend --tail 100 --follow
```

**Exec into container:**
```bash
sudo docker exec -it linkbox-backend bash

# Test database connection
apt-get update && apt-get install -y postgresql-client
psql $DATABASE_URL -c "SELECT version();"
```

**Check environment variables:**
```bash
sudo docker exec linkbox-backend env | grep -E '(DATABASE|DB_|USE_IAM)'
```

---

## 📋 Configuration Reference

### Environment Variables

**Local Development:**
```bash
ENVIRONMENT=dev
DATABASE_URL=postgresql://linkbox_user:linkbox_password@localhost:5432/linkbox_dev
AWS_REGION=us-east-1
S3_BUCKET_NAME=linkbox-dev-bucket
```

**Production (Password Auth):**
```bash
ENVIRONMENT=production
DATABASE_URL=postgresql://linkbox:<password>@<endpoint>:5432/linkbox
AWS_REGION=us-east-1
S3_BUCKET_NAME=linkbox-uploads
```

**Production (IAM Auth):**
```bash
ENVIRONMENT=production
USE_IAM_DB_AUTH=true
DB_ENDPOINT=xxx.rds.amazonaws.com
DB_NAME=linkbox
DB_IAM_USER=linkbox_iam_user
DB_PORT=5432
AWS_REGION=us-east-1
S3_BUCKET_NAME=linkbox-uploads
```

### Configuration Files

**Backend:**
- `backend/app/core/config.py` - Pydantic settings
- `backend/app/db.py` - SQLAlchemy engine setup
- `backend/app/utils/db_iam_auth.py` - IAM auth helpers
- `backend/docker-compose.yml` - Local PostgreSQL
- `backend/ENV.EXAMPLE` - Environment variables template

**Infrastructure:**
- `infrastructure/02-database.yml` - RDS + SSM parameters
- `infrastructure/03-backend.yml` - EC2 IAM roles + policies

**Scripts:**
- `scripts/start_application.sh` - Password auth deployment
- `scripts/start_application_iam.sh` - IAM auth deployment
- `scripts/setup_iam_db_user.sh` - Create IAM database user
- `scripts/stop_application.sh` - Stop containers
- `scripts/install_dependencies.sh` - Install prerequisites

---

## 📚 Additional Resources

### AWS Documentation
- [RDS PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- [IAM Database Authentication](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html)
- [SSM Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [Security Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.Security.html)

### Related Documentation
- `backend/LOCAL-DEVELOPMENT.md` - Local development setup
- `infrastructure/README.md` - Infrastructure overview
- `infrastructure/UPDATE-GUIDE.md` - How to update stacks
- `appspec.yml` - CodeDeploy configuration

---

## ✅ Checklist

### Initial Setup
- [ ] Infrastructure deployed (CloudFormation stacks)
- [ ] RDS database created
- [ ] SSM parameters created
- [ ] EC2 instances running
- [ ] Security groups configured

### Local Development
- [ ] Docker Compose installed
- [ ] PostgreSQL container running
- [ ] Backend can connect to local DB
- [ ] Health endpoint returns 200

### Production (Password Auth)
- [ ] SSM parameters accessible
- [ ] IAM role has SSM read permissions
- [ ] DATABASE_URL constructed correctly
- [ ] Backend can connect to RDS
- [ ] Health endpoint returns 200

### Production (IAM Auth)
- [ ] RDS has IAM auth enabled
- [ ] IAM database user created
- [ ] EC2 role has rds-db:connect permission
- [ ] Backend generates tokens successfully
- [ ] Backend can connect with IAM tokens
- [ ] CloudTrail logging enabled

---

## 🎯 Summary

**Database Setup:**
- **Local:** Docker Compose PostgreSQL with hardcoded credentials
- **Production:** AWS RDS with secure credential management

**Authentication Methods:**
- **Password:** Simple, works everywhere, good security
- **IAM:** AWS-native, no passwords, excellent security ← **Recommended for production**

**Security:**
- Network isolation (private subnets)
- Encryption (at rest and in transit)
- IAM access control
- CloudTrail auditing

**Next Steps:**
1. Choose authentication method for production
2. Deploy infrastructure
3. Configure deployment scripts
4. Test connectivity
5. Monitor and maintain

**Need help?** Check the troubleshooting section or review related documentation.

---

**Last Updated:** October 2025  
**Maintained By:** LinkBox Team

