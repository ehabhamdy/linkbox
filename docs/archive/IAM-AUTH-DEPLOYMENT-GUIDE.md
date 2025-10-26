# IAM Database Authentication Deployment Guide

This guide explains how to deploy LinkBox with IAM database authentication instead of traditional password-based authentication.

## 🔐 What is IAM Database Authentication?

IAM authentication allows your EC2 instances to connect to RDS using temporary tokens instead of passwords:

- ✅ **No passwords stored** - Tokens generated on-demand by AWS
- ✅ **Auto-expiring tokens** - Each token valid for only 15 minutes
- ✅ **CloudTrail logging** - All database access logged
- ✅ **IAM policies** - Control who can access the database
- ✅ **Automatic rotation** - No credential management needed

## 📋 Prerequisites

1. **RDS with IAM Auth Enabled** - Your database already has `EnableIAMDatabaseAuthentication: true`
2. **EC2 IAM Role** - Your instances have `rds-db:connect` permission
3. **PostgreSQL client** - Needed to create the IAM user (one-time setup)

## 🚀 Deployment Steps

### Step 1: Create the IAM Database User (One-Time Setup)

This creates a special PostgreSQL user that authenticates via IAM instead of a password.

**Prerequisites:**
- `psql` client installed on your local machine
- Network access to RDS (bastion host, VPN, or temporary security group rule)

**Run the setup script:**

```bash
# From your local machine or a bastion host with RDS access
./scripts/setup_iam_db_user.sh linkbox us-east-1
```

**What it does:**
```sql
CREATE USER linkbox_iam_user WITH LOGIN;
GRANT rds_iam TO linkbox_iam_user;  -- Enables IAM auth
GRANT ALL PRIVILEGES ON DATABASE linkbox TO linkbox_iam_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO linkbox_iam_user;
```

**Expected output:**
```
✅ IAM database user created successfully!

User: linkbox_iam_user
Authentication: IAM (no password)
```

### Step 2: Update Your Application Config

Your Python application already supports IAM auth. Verify these settings in `config.py`:

```python
# IAM Database Authentication
use_iam_db_auth: bool = False  # Will be set via env var
db_iam_user: Optional[str] = None
db_endpoint: Optional[str] = None
db_name: Optional[str] = None
db_port: int = 5432
```

### Step 3: Update Deployment Script

Use the IAM-enabled deployment script in your CodeDeploy `appspec.yml`:

**Option A: Update appspec.yml to use IAM script**
```yaml
ApplicationStart:
  - location: scripts/start_application_iam.sh
    timeout: 300
    runas: ec2-user
```

**Option B: Modify existing script**
Add IAM environment variables to `start_application.sh`:
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
    -e DB_IAM_USER=$DB_IAM_USER \
    -e DB_PORT=5432 \
    --restart unless-stopped \
    $IMAGE_URI
```

### Step 4: Deploy!

Deploy your application through CodePipeline or manually:

```bash
# If deploying manually
cd infrastructure
./deploy.sh
```

## 🔍 Verification

### Check Container Logs
```bash
# On your EC2 instance
docker logs linkbox-backend
```

Look for:
```
INFO: Generating IAM auth token for linkbox_iam_user@xxx.rds.amazonaws.com
INFO: IAM auth token generated successfully
```

### Test Database Connection
```bash
# From EC2 instance
docker exec linkbox-backend python -c "
from app.db import get_db
from app.core.config import get_settings

settings = get_settings()
print(f'IAM Auth: {settings.use_iam_db_auth}')
print(f'DB User: {settings.db_iam_user}')
print(f'DB Endpoint: {settings.db_endpoint}')
"
```

### Check Health Endpoint
```bash
curl http://localhost/health
# Should return: {"status":"healthy"}
```

## 🛠 Troubleshooting

### Error: "User does not exist"
**Cause:** IAM database user not created
**Solution:** Run `setup_iam_db_user.sh` script

### Error: "Permission denied for database"
**Cause:** IAM user lacks permissions
**Solution:** Re-run setup script or manually grant permissions:
```sql
GRANT ALL PRIVILEGES ON DATABASE linkbox TO linkbox_iam_user;
```

### Error: "No credentials available"
**Cause:** EC2 instance doesn't have IAM role with `rds-db:connect` permission
**Solution:** Verify IAM role in CloudFormation template (03-backend.yml)

### Error: "Token expired"
**Cause:** IAM tokens are valid for 15 minutes
**Solution:** This is normal! The app generates new tokens automatically. If it persists, check that token generation is working:
```bash
docker logs linkbox-backend | grep "Generating IAM auth token"
```

### Connection works then fails after 15 minutes
**Cause:** Connection pooling with expired tokens
**Solution:** SQLAlchemy should handle this. Check pool settings in `db.py`:
```python
engine = create_engine(
    str(settings.database_url),
    pool_pre_ping=True,  # ← Ensures connections are alive
    pool_recycle=600     # ← Recycle connections every 10 mins
)
```

## 🔄 Switching Back to Password Auth

If you need to switch back:

1. Update `appspec.yml` to use `start_application.sh` (without IAM)
2. Redeploy

The app will automatically use password-based auth when `USE_IAM_DB_AUTH` is not set.

## 📊 Security Benefits

| Feature | Password Auth | IAM Auth |
|---------|--------------|----------|
| Credential Storage | Password in SSM | No storage needed |
| Credential Rotation | Manual | Automatic (15 min) |
| CloudTrail Logging | ❌ No | ✅ Yes |
| IAM Policy Control | ❌ No | ✅ Yes |
| Zero Trust | ❌ No | ✅ Yes |

## 📚 References

- [AWS RDS IAM Database Authentication](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html)
- [PostgreSQL IAM Authentication](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.Connecting.Python.html)
- [boto3 generate_db_auth_token](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/rds.html#RDS.Client.generate_db_auth_token)

## ❓ FAQ

**Q: Does IAM auth affect performance?**
A: Minimal impact. Token generation is fast (~50-100ms) and only happens on new connections.

**Q: What happens if token generation fails?**
A: The application will fail to start and CodeDeploy will roll back.

**Q: Can I use both IAM and password auth?**
A: Yes! You can have both users in the database. Switch via environment variables.

**Q: Does this work with connection pooling?**
A: Yes! SQLAlchemy handles reconnections automatically with `pool_pre_ping=True`.

**Q: How much does IAM auth cost?**
A: Free! No additional charges for IAM database authentication.

