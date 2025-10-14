# Stack Update Guide

This guide explains how to update your deployed LinkBox infrastructure stack.

---

## 📚 **Table of Contents**

1. [When to Update](#when-to-update)
2. [Update Scripts](#update-scripts)
3. [Quick Update (Recommended)](#quick-update-recommended)
4. [Full Update (Advanced)](#full-update-advanced)
5. [Common Update Scenarios](#common-update-scenarios)
6. [Troubleshooting](#troubleshooting)

---

## 🤔 **When to Update**

Update your CloudFormation stack when you've made changes to:

- ✅ Infrastructure templates (`.yml` files)
- ✅ IAM policies or roles
- ✅ Security group rules
- ✅ EC2 instance types or configurations
- ✅ Database settings (non-password changes)
- ✅ ALB or Target Group settings
- ✅ S3 bucket configurations

**Don't need to update stack for:**
- ❌ Application code changes (use CodePipeline instead)
- ❌ Frontend changes (use `deploy-frontend.sh`)
- ❌ Environment variables in `.env` files

---

## 📜 **Update Scripts**

We provide two update scripts:

| Script | Use Case | Parameters | Interactive |
|--------|----------|------------|-------------|
| `quick-update.sh` | Infrastructure changes, keep all settings | No | ❌ |
| `update-stack.sh` | Change parameters, update everything | Yes | ✅ |

---

## ⚡ **Quick Update (Recommended)**

Use this when you've **only changed infrastructure templates** and want to keep all existing parameters (passwords, AMI IDs, GitHub settings, etc.).

### **Usage:**

```bash
cd infrastructure

# Make the script executable (first time only)
chmod +x quick-update.sh

# Run the update
./quick-update.sh [stack-name] [templates-bucket]

# Example with default values
./quick-update.sh

# Example with custom values
./quick-update.sh linkbox-master linkbox-cfn-templates
```

### **What It Does:**

1. ✅ Uploads all 6 CloudFormation templates to S3
2. ✅ Retrieves current stack parameters
3. ✅ Updates stack using existing parameter values
4. ✅ Waits for update to complete
5. ✅ Shows stack outputs

### **Time:** 10-20 minutes

### **Example Output:**

```
🔄 Quick Stack Update
====================
Stack: linkbox-master
Bucket: linkbox-cfn-templates

📤 Uploading templates to S3...
upload: ./main.yml to s3://linkbox-cfn-templates/main.yml
upload: ./01-network.yml to s3://linkbox-cfn-templates/01-network.yml
...
✅ Templates uploaded

📋 Using existing parameters...
🚀 Updating CloudFormation stack...
✅ Update initiated

⏳ Waiting for stack update to complete (this may take 10-20 minutes)...
✅ Stack updated successfully!

📊 Stack outputs:
[table of outputs]
```

---

## 🔧 **Full Update (Advanced)**

Use this when you want to **change parameters** like AMI ID, database password, GitHub settings, etc.

### **Usage:**

```bash
cd infrastructure

# Make the script executable (first time only)
chmod +x update-stack.sh

# Run the interactive update
./update-stack.sh [stack-name] [templates-bucket]

# Example with default values
./update-stack.sh

# Example with custom values
./update-stack.sh linkbox-master linkbox-cfn-templates
```

### **What It Does:**

1. ✅ Validates prerequisites (AWS CLI, credentials, stack exists)
2. ✅ Retrieves current parameters
3. ✅ Uploads all templates to S3
4. ✅ Asks if you want to update parameters (interactive)
5. ✅ Updates stack with your choices
6. ✅ Monitors update progress
7. ✅ Shows stack outputs and post-update actions

### **Interactive Options:**

```
What would you like to update?

1) Infrastructure only (use existing parameters)
2) Infrastructure + change parameters
3) Cancel

Enter your choice (1-3): 
```

If you choose option 2, you'll be prompted to update:
- Environment name
- AMI ID (can fetch latest automatically)
- Database password
- GitHub repository, branch, and token

### **Time:** 10-20 minutes + your input time

---

## 📝 **Common Update Scenarios**

### **Scenario 1: Fixed IAM Permissions (Like Today)**

**Problem:** EC2 instances need new permissions (e.g., CodeDeploy S3 access)

**Solution:**
```bash
cd infrastructure

# 1. Edit the template (e.g., 03-backend.yml)
# 2. Run quick update
./quick-update.sh

# 3. Wait for completion
# 4. Redeploy application
aws codepipeline start-pipeline-execution --name linkbox-backend-pipeline
```

**Why:** IAM policy changes don't require parameter updates, just template changes.

---

### **Scenario 2: Update to Latest AMI**

**Problem:** You want to use the latest Amazon Linux 2 AMI for security patches

**Solution:**
```bash
cd infrastructure

# 1. Get latest AMI ID
./get-ami-id.sh

# 2. Run full update script
./update-stack.sh

# 3. Choose option 2 (Infrastructure + change parameters)
# 4. When prompted for AMI update, say "yes"
# 5. Script will show latest AMI and ask to use it
```

**Note:** This will trigger instance replacement (brief downtime).

---

### **Scenario 3: Change Database Password**

**Problem:** You need to rotate the database password

**Solution:**
```bash
cd infrastructure

# 1. Run full update script
./update-stack.sh

# 2. Choose option 2 (Infrastructure + change parameters)
# 3. Answer "No" to most prompts (use existing values)
# 4. When asked "Update database password?", answer "Yes"
# 5. Enter new password (hidden input)
```

**Important:** After update, you'll need to update SSM parameter manually or wait for next deployment.

---

### **Scenario 4: Change Instance Type**

**Problem:** You want to scale up/down EC2 instance size

**Solution:**
```bash
cd infrastructure

# 1. Edit 03-backend.yml
# Find: InstanceType: t3.micro
# Change to: InstanceType: t3.small (or desired size)

# 2. Run quick update
./quick-update.sh

# 3. CloudFormation will replace instances with new type
```

**Note:** This causes instance replacement (brief downtime during rollout).

---

### **Scenario 5: Update Security Group Rules**

**Problem:** Need to allow/block specific traffic

**Solution:**
```bash
cd infrastructure

# 1. Edit relevant template (e.g., 03-backend.yml for backend SG)
# 2. Modify SecurityGroupIngress or SecurityGroupEgress rules
# 3. Run quick update
./quick-update.sh

# 4. Rules update immediately (no instance restart needed)
```

**Note:** Security group rule updates are instant, no downtime.

---

### **Scenario 6: Update GitHub Repository or Token**

**Problem:** Moved repository or token expired

**Solution:**
```bash
cd infrastructure

# 1. Run full update script
./update-stack.sh

# 2. Choose option 2
# 3. When asked "Update GitHub settings?", answer "Yes"
# 4. Enter new repo, branch, or token
```

**Note:** Pipeline will be updated with new GitHub connection.

---

## 🔍 **Monitoring Stack Updates**

### **View Update Progress in Console:**

```
https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks
```

### **Monitor via CLI:**

```bash
# Check stack status
aws cloudformation describe-stacks \
  --stack-name linkbox-master \
  --query 'Stacks[0].StackStatus' \
  --output text

# List stack events (see what's being updated)
aws cloudformation describe-stack-events \
  --stack-name linkbox-master \
  --max-items 20 \
  --query 'StackEvents[*].{Time:Timestamp,Status:ResourceStatus,Type:ResourceType,Reason:ResourceStatusReason}' \
  --output table

# Watch for completion
watch -n 10 'aws cloudformation describe-stacks --stack-name linkbox-master --query "Stacks[0].StackStatus" --output text'
```

---

## 🛠️ **Troubleshooting**

### **Issue: "No updates are to be performed"**

**Meaning:** The templates you uploaded are identical to what's currently deployed.

**Solution:** 
- This is not an error! Stack is already up-to-date.
- Verify you actually changed something in the templates.
- If you made changes, ensure they were uploaded to S3.

---

### **Issue: "Stack is in UPDATE_ROLLBACK_COMPLETE state"**

**Meaning:** A previous update failed and was rolled back.

**Solution:**
```bash
# View failure reason
aws cloudformation describe-stack-events \
  --stack-name linkbox-master \
  --max-items 50 | grep -i fail

# Fix the issue in templates
# Then run update again
./quick-update.sh
```

---

### **Issue: "Insufficient permissions"**

**Meaning:** Your AWS credentials don't have permission to update CloudFormation or resources.

**Solution:**
- Ensure you're using credentials with `CloudFormationFullAccess` or similar
- Check if IAM user/role has `iam:PassRole` permission
- Verify S3 bucket permissions

---

### **Issue: "Resource failed to stabilize"**

**Meaning:** A resource (EC2, RDS, etc.) failed to reach healthy state during update.

**Common Causes:**
- Health checks failing (check target group)
- Security group blocking traffic
- IAM permissions missing
- Resource dependencies not met

**Solution:**
```bash
# Find which resource failed
aws cloudformation describe-stack-events \
  --stack-name linkbox-master \
  --query 'StackEvents[?ResourceStatus==`UPDATE_FAILED`]' \
  --output table

# Fix the resource issue
# Retry update
./quick-update.sh
```

---

### **Issue: Update Takes Too Long**

**Normal Times:**
- Network changes: 5-10 minutes
- IAM policy changes: 1-2 minutes
- EC2 instance updates: 10-15 minutes
- RDS updates: 15-30 minutes
- Complete stack: 15-25 minutes

**If Stuck:**
```bash
# Check current operation
aws cloudformation describe-stack-events \
  --stack-name linkbox-master \
  --max-items 5

# If truly stuck (>1 hour), you may need to cancel
aws cloudformation cancel-update-stack --stack-name linkbox-master
```

---

## 🚨 **Rollback Procedures**

### **If Update Fails:**

**Automatic Rollback:**
CloudFormation automatically rolls back failed updates to the previous stable state.

**Manual Rollback (if needed):**
```bash
# Continue rollback if stuck
aws cloudformation continue-update-rollback --stack-name linkbox-master
```

### **If You Need to Revert Changes:**

**Option 1: Update with Previous Template**
```bash
# Re-upload old template
aws s3 cp old-template.yml s3://linkbox-cfn-templates/03-backend.yml

# Run update
./quick-update.sh
```

**Option 2: Use Git History**
```bash
# Restore previous version
git checkout HEAD~1 infrastructure/03-backend.yml

# Upload and update
cd infrastructure
aws s3 cp 03-backend.yml s3://linkbox-cfn-templates/
./quick-update.sh

# Restore current version after rollback
git checkout HEAD infrastructure/03-backend.yml
```

---

## ✅ **Best Practices**

1. **Always Test in Dev First**
   - Create a separate dev stack
   - Test updates there first
   - Then apply to production

2. **Commit Changes to Git**
   ```bash
   git add infrastructure/
   git commit -m "fix: Add CodeDeploy S3 access to instance role"
   git push
   ```

3. **Backup Important Data**
   - Take RDS snapshot before database changes
   - Export important configuration

4. **Use Quick Update for Most Cases**
   - Faster
   - Less error-prone
   - Maintains all settings

5. **Schedule Updates During Low Traffic**
   - Some updates require instance replacement
   - This causes brief downtime

6. **Monitor After Updates**
   ```bash
   # Check target health
   aws elbv2 describe-target-health --target-group-arn <arn>
   
   # Test application
   curl http://<alb-dns>/health
   
   # Check logs
   aws logs tail /aws/linkbox/backend --follow
   ```

---

## 📊 **Update Impact Matrix**

| Change Type | Downtime | Instances Replaced | Time |
|-------------|----------|-------------------|------|
| IAM Policies | ❌ None | ❌ No | 1-2 min |
| Security Groups | ❌ None | ❌ No | 1-2 min |
| Instance Type | ⚠️ Brief | ✅ Yes | 10-15 min |
| AMI ID | ⚠️ Brief | ✅ Yes | 10-15 min |
| ALB Settings | ❌ None | ❌ No | 2-5 min |
| Database Password | ❌ None | ❌ No | 1-2 min |
| RDS Instance Class | ⚠️ Yes | ✅ Yes | 15-30 min |
| Network Changes | ⚠️ Possible | ⚠️ Maybe | 5-15 min |

---

## 🎯 **Quick Reference**

### **Just Updated Infrastructure Templates:**
```bash
cd infrastructure
./quick-update.sh
```

### **Need to Change Parameters:**
```bash
cd infrastructure
./update-stack.sh
# Choose option 2
```

### **After Update, Redeploy Application:**
```bash
aws codepipeline start-pipeline-execution --name linkbox-backend-pipeline
```

### **Check If Update Needed:**
```bash
# Compare local changes
git status infrastructure/

# View stack status
aws cloudformation describe-stacks --stack-name linkbox-master --query 'Stacks[0].StackStatus'
```

---

## 📚 **Related Documentation**

- `deploy.sh` - Initial stack deployment
- `DEPLOYMENT-FIX.md` - Fixing deployment issues
- `infrastructure/README.md` - Infrastructure overview
- AWS CloudFormation [Update Behaviors](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-updating-stacks.html)

---

**Last Updated:** 2025-10-14  
**Scripts Version:** 1.0  
**Status:** ✅ Production Ready

