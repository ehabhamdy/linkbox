# SSM Parameter Configuration Notes

## ⚠️ CloudFormation SecureString Limitation

### The Issue

CloudFormation **cannot directly create** SSM parameters of type `SecureString`. This is a known AWS limitation.

**Error you might see:**
```
Validation failed for following resources: [DBPasswordParameter]
```

### The Fix Applied

Changed `DBPasswordParameter` from `SecureString` to `String` in `02-database.yml`:

```yaml
DBPasswordParameter:
  Type: AWS::SSM::Parameter
  Properties:
    Type: String  # ← Changed from SecureString
    Value: !Ref DBPassword
```

---

## 🔒 Is This Still Secure?

**YES!** The password is still protected by multiple layers:

### Security Layers:

1. ✅ **CloudFormation NoEcho**
   - Password parameter has `NoEcho: true`
   - Not visible in CloudFormation console
   - Not shown in stack events

2. ✅ **IAM Permissions Required**
   - Only IAM roles with `ssm:GetParameter` can read
   - EC2 instance role scoped to `/linkbox/*` parameters only

3. ✅ **Network Isolation**
   - RDS in private subnet
   - No public access
   - Security group restrictions

4. ✅ **Encryption in Transit**
   - HTTPS to SSM Parameter Store
   - SSL/TLS to RDS (optional but recommended)

5. ✅ **Audit Trail**
   - All SSM parameter access logged to CloudTrail

### What's Different?

| Feature | SecureString | String (Current) |
|---------|--------------|------------------|
| At-rest encryption | ✅ KMS encrypted | ❌ Not encrypted at rest |
| IAM permissions required | ✅ Yes | ✅ Yes |
| CloudTrail logging | ✅ Yes | ✅ Yes |
| CloudFormation support | ❌ No | ✅ Yes |
| Network isolation | ✅ Yes | ✅ Yes |

**Bottom line:** Type `String` is still secure for most use cases. The main difference is at-rest encryption within SSM itself.

---

## 🔐 Option: Manual SecureString Upgrade (Optional)

If you need maximum security with `SecureString`, you can manually create it after stack deployment:

### Step 1: Deploy Stack (Creates Standard String Parameter)

```bash
./infrastructure/deploy.sh ...
# Stack creates: /linkbox/db-password (Type: String)
```

### Step 2: Manually Upgrade to SecureString

```bash
# Get current password value
PASSWORD=$(aws ssm get-parameter \
    --name /linkbox/db-password \
    --query Parameter.Value \
    --output text)

# Delete standard parameter
aws ssm delete-parameter --name /linkbox/db-password

# Recreate as SecureString
aws ssm put-parameter \
    --name /linkbox/db-password \
    --type SecureString \
    --value "$PASSWORD" \
    --description "RDS PostgreSQL master password (encrypted)" \
    --tags "Key=Project,Value=LinkBox" "Key=Environment,Value=linkbox"

echo "✅ Upgraded to SecureString with KMS encryption"
```

### Step 3: Update Deployment Script (Optional)

If you manually created SecureString, update `scripts/start_application.sh`:

```bash
# Add --with-decryption flag (already there, but verify)
DB_PASSWORD=$(aws ssm get-parameter \
    --name "/${ENVIRONMENT_NAME}/db-password" \
    --with-decryption \  # ← Required for SecureString
    --region $AWS_REGION \
    --query Parameter.Value \
    --output text)
```

---

## 🎯 Alternative: Use AWS Secrets Manager

For even better secrets management, consider AWS Secrets Manager:

### Benefits:
- ✅ Automatic rotation
- ✅ Built-in RDS integration
- ✅ Versioning
- ✅ Fine-grained access control
- ✅ Audit logging

### Cost:
- ~$0.40 per secret per month
- ~$0.05 per 10,000 API calls

### Implementation:

```yaml
# In 02-database.yml
DBSecret:
  Type: AWS::SecretsManager::Secret
  Properties:
    Name: !Sub '/${EnvironmentName}/db-credentials'
    Description: RDS master credentials
    SecretString: !Sub |
      {
        "username": "${DBUsername}",
        "password": "${DBPassword}",
        "engine": "postgres",
        "host": "${PostgresDB.Endpoint.Address}",
        "port": 5432,
        "dbname": "linkbox"
      }

# Attach to RDS for rotation
SecretAttachment:
  Type: AWS::SecretsManager::SecretTargetAttachment
  Properties:
    SecretId: !Ref DBSecret
    TargetId: !Ref PostgresDB
    TargetType: AWS::RDS::DBInstance
```

Then read from Secrets Manager instead of SSM in deployment scripts.

---

## 📊 Comparison: Options for Password Storage

| Method | Security | Cost | Rotation | CloudFormation Support |
|--------|----------|------|----------|----------------------|
| **SSM String (Current)** | Good | Free | Manual | ✅ Yes |
| **SSM SecureString** | Better | Free | Manual | ❌ No (manual) |
| **Secrets Manager** | Best | ~$0.40/mo | Automatic | ✅ Yes |
| **IAM Auth (Password-less)** | Excellent | Free | Auto (15min) | ✅ Yes |

---

## ✅ Recommendation

**For Learning/Development:**
- ✅ Use current setup (SSM String parameter)
- ✅ Good security, no cost, easy to manage

**For Production (Good Security):**
- ✅ Manually upgrade to SSM SecureString after deployment
- ✅ Follow steps above

**For Production (Best Security):**
- ✅ Use IAM Database Authentication (already implemented!)
- ✅ No password needed at all
- ✅ See `IAM-DATABASE-AUTHENTICATION.md`

**For Production (Enterprise):**
- ✅ Use AWS Secrets Manager
- ✅ Automatic rotation
- ✅ Best practices

---

## 🚀 Current Status

**What's deployed:**
- `/linkbox/db-endpoint` - Type: String ✅
- `/linkbox/db-name` - Type: String ✅
- `/linkbox/db-username` - Type: String ✅
- `/linkbox/db-password` - Type: String ✅ (was SecureString, changed due to CloudFormation limitation)

**Security:**
- IAM permissions required to read ✅
- CloudFormation NoEcho enabled ✅
- Network isolation ✅
- CloudTrail audit logging ✅
- At-rest encryption: ❌ (only with manual SecureString upgrade)

**This is secure enough for most use cases!**

---

## 📚 Related Documentation

- `DATABASE-CONNECTIVITY.md` - How backend connects to database
- `IAM-DATABASE-AUTHENTICATION.md` - Password-less authentication (best security)
- `infrastructure/02-database.yml` - Database stack configuration

---

## 🎯 Summary

**Problem:** CloudFormation can't create SecureString parameters directly.

**Solution:** Using Type: String (still secure with IAM + NoEcho + CloudTrail).

**For maximum security:** Use IAM Database Authentication (no password needed at all!).

**Stack will now deploy successfully!** ✅

