# IAM Database Authentication Guide

Complete guide to using IAM authentication for RDS PostgreSQL instead of passwords.

---

## 🔐 What is IAM Database Authentication?

IAM database authentication allows your EC2 instances to connect to RDS PostgreSQL using temporary authentication tokens generated from their IAM role, **instead of using a password**.

### Traditional Authentication (Password-Based)
```
EC2 Instance → Connect with username:password → RDS PostgreSQL
              ↓
         Password stored in:
         - SSM Parameter Store (encrypted)
         - Environment variables
         - Must manage and rotate
```

### IAM Authentication (Token-Based)
```
EC2 Instance → Request auth token from AWS (using IAM role)
              ↓
         Token generated (valid for 15 minutes)
              ↓
         Connect with token → RDS PostgreSQL
              ↓
         No password needed!
         Token automatically expires
```

---

## ✅ Benefits

| Aspect | Password-Based | IAM Authentication |
|--------|----------------|-------------------|
| **Security** | Password stored (even if encrypted) | No password, tokens only |
| **Rotation** | Manual rotation needed | Automatic (tokens expire in 15 min) |
| **Audit** | Password access logged | All access logged to CloudTrail |
| **Management** | Must manage secrets | No secrets to manage |
| **Best Practice** | Good | AWS recommended |

**AWS Quote:**
> "For applications running on Amazon EC2, you can use profile credentials specific to your EC2 instance to access your database instead of a password, for greater security"

---

## 📋 Prerequisites

- ✅ RDS PostgreSQL (version 9.5+)
- ✅ EC2 instance with IAM role
- ✅ IAM authentication enabled on RDS
- ✅ Special database user with `rds_iam` role

---

## 🚀 Implementation

### Step 1: Enable IAM Authentication on RDS

**Already configured in:** `infrastructure/02-database.yml`

```yaml
PostgresDB:
  Type: AWS::RDS::DBInstance
  Properties:
    EnableIAMDatabaseAuthentication: true  # ← Enables IAM auth
    # ... other properties
```

**What this does:**
- Allows RDS to accept IAM authentication tokens
- Must be enabled before creating IAM database users

---

### Step 2: Grant IAM Permission to EC2 Instances

**Already configured in:** `infrastructure/03-backend.yml`

```yaml
InstanceRole:
  Type: AWS::IAM::Role
  Policies:
    - PolicyName: RDSIAMAuthentication
      PolicyDocument:
        Statement:
          - Effect: Allow
            Action: rds-db:connect
            Resource: arn:aws:rds-db:REGION:ACCOUNT:dbuser:*/linkbox_iam_user
```

**What this does:**
- Grants EC2 instances permission to generate auth tokens
- Scoped to specific database user (`linkbox_iam_user`)

---

### Step 3: Create IAM-Authenticated Database User

After deploying infrastructure, run this **once**:

```bash
# Install PostgreSQL client if not already installed
# On Amazon Linux 2:
sudo amazon-linux-extras install postgresql14

# Run setup script
cd scripts
./setup_iam_db_user.sh linkbox us-east-1
```

**What the script does:**
```sql
-- Creates database user
CREATE USER linkbox_iam_user WITH LOGIN;

-- Grants IAM authentication capability
GRANT rds_iam TO linkbox_iam_user;

-- Grants necessary permissions
GRANT ALL PRIVILEGES ON DATABASE linkbox TO linkbox_iam_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO linkbox_iam_user;
```

**Important:** This user has NO PASSWORD. It can only authenticate using IAM tokens.

---

### Step 4: Update Backend to Use IAM Authentication

**Backend code already supports IAM auth** via:
- `backend/app/utils/db_iam_auth.py` - Helper functions
- `backend/app/core/config.py` - Automatic IAM auth when enabled

**How it works:**

```python
# When USE_IAM_DB_AUTH=true:
# 1. Backend generates auth token using boto3
token = rds_client.generate_db_auth_token(
    DBHostname=db_endpoint,
    Port=5432,
    DBUsername='linkbox_iam_user',
    Region='us-east-1'
)

# 2. Token is used as the password (valid for 15 minutes)
connection_string = f"postgresql://linkbox_iam_user:{token}@{endpoint}:5432/linkbox"

# 3. Backend connects to RDS
engine = create_engine(connection_string)

# 4. Token automatically refreshed as needed
```

---

### Step 5: Deploy with IAM Authentication

**Option A: Use IAM deployment script**

Update `appspec.yml` to use the IAM script:

```yaml
hooks:
  ApplicationStart:
    - location: scripts/start_application_iam.sh  # ← Use IAM version
      timeout: 300
      runas: root
```

**Option B: Use existing script with IAM enabled**

Modify `scripts/start_application.sh` to set `USE_IAM_DB_AUTH=true` in docker run command.

**Deploy:**
```bash
git add .
git commit -m "Enable IAM database authentication"
git push origin main
```

CodePipeline will deploy automatically with IAM auth enabled.

---

## 🔄 How It Works (Complete Flow)

### Initial Setup (Once)

```
1. Deploy Infrastructure
   └→ RDS created with EnableIAMDatabaseAuthentication: true
   └→ EC2 IAM role granted rds-db:connect permission
   
2. Run setup_iam_db_user.sh
   └→ Creates linkbox_iam_user in database
   └→ Grants rds_iam role
   └→ Grants necessary permissions
   
3. Backend code ready
   └→ db_iam_auth.py helper functions
   └→ Config supports IAM auth
```

### Every Connection (Automatic)

```
1. Backend App Starts
   └→ Reads USE_IAM_DB_AUTH=true
   └→ Reads DB_IAM_USER=linkbox_iam_user
   
2. Generate Auth Token
   └→ Backend calls boto3.client('rds').generate_db_auth_token()
   └→ Uses EC2 instance's IAM role (automatic)
   └→ Token generated (valid for 15 minutes)
   
3. Connect to Database
   └→ Uses token as password
   └→ PostgreSQL verifies token with AWS
   └→ Connection established
   
4. Token Refresh (Automatic)
   └→ SQLAlchemy connection pool handles this
   └→ New token generated when needed
   └→ Seamless to application
```

---

## 🧪 Testing IAM Authentication

### Test Token Generation (from EC2)

```bash
# SSH into EC2 instance
aws ssm start-session --target <instance-id>

# Generate token manually
DB_ENDPOINT="xxx.rds.amazonaws.com"
DB_USER="linkbox_iam_user"
REGION="us-east-1"

TOKEN=$(aws rds generate-db-auth-token \
    --hostname $DB_ENDPOINT \
    --port 5432 \
    --username $DB_USER \
    --region $REGION)

echo "Auth token (first 50 chars): ${TOKEN:0:50}..."
```

### Test Database Connection with IAM

```bash
# Connect using token as password
export PGPASSWORD=$TOKEN

psql -h $DB_ENDPOINT \
     -U linkbox_iam_user \
     -d linkbox \
     -c "SELECT current_user, inet_server_addr();"

# Should show:
#    current_user    | inet_server_addr
# -------------------+------------------
#  linkbox_iam_user  | 10.20.x.x
```

### Test Backend Application

```bash
# Check container environment
sudo docker exec linkbox-backend env | grep IAM

# Should show:
# USE_IAM_DB_AUTH=true
# DB_IAM_USER=linkbox_iam_user

# Test API
curl http://localhost:80/health

# Check logs for IAM auth messages
sudo docker logs linkbox-backend | grep IAM
```

---

## 🔄 Migration Path

### From Password to IAM Authentication

**Phase 1: Enable IAM (Keep Password as Fallback)**
```bash
1. Deploy infrastructure updates (enable IAM on RDS)
2. Run setup_iam_db_user.sh
3. Test IAM authentication manually
4. Keep password auth working (for rollback)
```

**Phase 2: Switch to IAM**
```bash
5. Update deployment script to use IAM
6. Set USE_IAM_DB_AUTH=true
7. Deploy via CodePipeline
8. Verify connections working
```

**Phase 3: Remove Password (Optional)**
```bash
9. Remove DB password from SSM (after confirming IAM works)
10. Update documentation
```

---

## 🐛 Troubleshooting

### "Authentication failed for user linkbox_iam_user"

**Cause:** User doesn't have `rds_iam` role

**Fix:**
```sql
-- Connect as master user
GRANT rds_iam TO linkbox_iam_user;
```

### "Token has expired"

**Cause:** Tokens are valid for only 15 minutes

**Fix:** This should auto-refresh. If not:
```python
# Check token generation in code
# Ensure new token is generated for each connection
```

### "Access denied: User does not have CONNECT privilege"

**Cause:** IAM role doesn't have `rds-db:connect` permission

**Fix:**
```bash
# Verify IAM policy
aws iam get-role-policy \
    --role-name linkbox-instance-role \
    --policy-name RDSIAMAuthentication

# Should show rds-db:connect action
```

### "SSL connection required"

**Cause:** IAM auth requires SSL

**Fix:** Connection string must include `?sslmode=require`:
```
postgresql://user:token@endpoint:5432/db?sslmode=require
```

Already configured in `db_iam_auth.py` ✅

---

## 📊 Comparison: Password vs IAM

### Password Authentication (Current Default)

**Advantages:**
- ✅ Simple to understand
- ✅ Works everywhere (local, AWS, etc.)
- ✅ No additional setup needed

**Disadvantages:**
- ❌ Password must be stored (even if encrypted)
- ❌ Manual rotation required
- ❌ Risk of password exposure
- ❌ More to manage

**Use Case:** Local development, non-production environments

---

### IAM Authentication (Enhanced Security)

**Advantages:**
- ✅ No password to store or manage
- ✅ Automatic token rotation (15 min expiry)
- ✅ CloudTrail audit logging
- ✅ AWS security best practice
- ✅ Leverages existing IAM infrastructure

**Disadvantages:**
- ❌ Only works on AWS (with IAM role)
- ❌ Requires additional setup (IAM user in database)
- ❌ Slightly more complex to understand
- ❌ Requires SSL connection

**Use Case:** Production AWS deployments

---

## 🔐 Security Comparison

| Security Aspect | Password | IAM Auth |
|----------------|----------|----------|
| **Credential Storage** | Stored in SSM | No storage needed |
| **Credential Exposure** | Could be leaked | Token only, expires quickly |
| **Rotation** | Manual | Automatic (15 min) |
| **Audit Trail** | SSM access logged | All access logged |
| **Network Security** | SSL optional | SSL required |
| **Compliance** | Good | Better (meets stricter requirements) |

---

## 📚 Files Reference

### Infrastructure
- `infrastructure/02-database.yml` - Enables IAM auth on RDS
- `infrastructure/03-backend.yml` - Grants rds-db:connect permission

### Backend Code
- `backend/app/utils/db_iam_auth.py` - IAM auth helper functions
- `backend/app/core/config.py` - Configuration with IAM support

### Scripts
- `scripts/setup_iam_db_user.sh` - Creates IAM database user
- `scripts/start_application_iam.sh` - Deployment with IAM auth
- `scripts/start_application.sh` - Standard deployment (password)

### Documentation
- `IAM-DATABASE-AUTHENTICATION.md` - This file
- `DATABASE-CONNECTIVITY.md` - General DB connectivity
- `backend/LOCAL-DEVELOPMENT.md` - Local development

---

## ✅ Decision Guide

**Use Password Authentication when:**
- Local development
- Testing/staging environments
- Need to work outside AWS
- Team not familiar with IAM
- Quick prototyping

**Use IAM Authentication when:**
- Production on AWS ✅ Recommended
- Security/compliance requirements
- Want to eliminate password management
- Following AWS best practices
- Have IAM infrastructure in place

---

## 🚀 Quick Start (IAM Authentication)

### Prerequisites Complete:
```bash
# 1. Infrastructure deployed with IAM enabled
./infrastructure/deploy.sh ...

# 2. IAM database user created
./scripts/setup_iam_db_user.sh linkbox us-east-1
```

### Deploy with IAM Auth:
```bash
# Update appspec.yml to use IAM script
sed -i 's/start_application.sh/start_application_iam.sh/' appspec.yml

# Commit and push
git add .
git commit -m "Enable IAM database authentication"
git push origin main

# CodePipeline deploys automatically
```

### Verify:
```bash
# Check container is using IAM
aws ssm start-session --target <instance-id>
sudo docker exec linkbox-backend env | grep USE_IAM_DB_AUTH

# Test API
curl http://<alb-dns>/health

# Check logs
sudo docker logs linkbox-backend
```

---

## 📖 Additional Resources

- **AWS IAM Database Authentication**: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html
- **PostgreSQL IAM Auth**: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.Connecting.Python.html
- **Security Best Practices**: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.Security.html

---

## 🎯 Summary

**Question:** "I want to use IAM database authentication"

**Answer:** ✅ **Implemented!**

**What was added:**
1. ✅ RDS configured with IAM auth enabled
2. ✅ EC2 IAM role granted `rds-db:connect` permission
3. ✅ Setup script to create IAM database user
4. ✅ Backend code supports IAM authentication
5. ✅ Alternative deployment script for IAM
6. ✅ Complete documentation

**To use IAM auth:**
1. Deploy infrastructure (already has IAM enabled)
2. Run `setup_iam_db_user.sh` once
3. Use `start_application_iam.sh` for deployments
4. No passwords needed!

**Security improvement:**
- No passwords stored anywhere
- Tokens automatically expire (15 min)
- All access logged to CloudTrail
- AWS security best practice ✅

---

**You now have BOTH options available - choose based on your needs!** 🎉

