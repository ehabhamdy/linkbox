# GitHub Webhook Setup Guide

## 🐛 **Issue: Pipeline Not Auto-Triggering on Push**

When using GitHub V1 (OAuth) source provider, CloudFormation creates the webhook in AWS but **does not automatically register it in GitHub**. You need to manually add the webhook to your GitHub repository.

---

## ✅ **Option 1: Manual Trigger (Quick Fix)**

If you just need to run the pipeline now:

```bash
aws codepipeline start-pipeline-execution --name linkbox-backend-pipeline
```

**This is good for:**
- ✅ Testing changes immediately
- ✅ One-time deployments
- ❌ Not automatic on every push

---

## 🔧 **Option 2: Register Webhook in GitHub (Permanent Fix)**

### **Step 1: Get the Webhook URL**

```bash
# Get webhook URL from AWS
WEBHOOK_URL=$(aws codepipeline list-webhooks \
  --query 'webhooks[?definition.name==`linkbox-github-webhook`].url' \
  --output text)

echo "Webhook URL: $WEBHOOK_URL"
```

**Example output:**
```
https://us-east-1.webhooks.aws/trigger?t=eyJlbmNyeXB0ZWREYXRhIjoi...
```

### **Step 2: Add Webhook to GitHub**

1. **Go to your GitHub repository:**
   - https://github.com/ehabhamdy/linkbox

2. **Navigate to Settings:**
   - Click **Settings** tab
   - Click **Webhooks** in left sidebar
   - Click **Add webhook**

3. **Configure the webhook:**

   | Field | Value |
   |-------|-------|
   | **Payload URL** | Paste the webhook URL from Step 1 |
   | **Content type** | `application/json` |
   | **Secret** | Your GitHub token (same one used in CloudFormation) |
   | **Which events?** | Select "Just the push event" |
   | **Active** | ✅ Checked |

4. **Click "Add webhook"**

5. **Verify:** You should see a green checkmark next to the webhook after GitHub sends a test ping.

---

## 🎯 **Option 3: Switch to Polling (Simple but Less Efficient)**

If you don't want to deal with webhooks, enable polling:

### **Update CloudFormation Template**

**File:** `infrastructure/05-cicd.yml`

```yaml
# In the Source stage action configuration:
Configuration:
  Owner: !Select [0, !Split ['/', !Ref GitHubRepo]]
  Repo: !Select [1, !Split ['/', !Ref GitHubRepo]]
  Branch: !Ref GitHubBranch
  OAuthToken: !Ref GitHubToken
  PollForSourceChanges: true  # ← Change from false to true
```

**Then update the stack:**
```bash
cd infrastructure
./deploy.sh linkbox-cfn-templates linkbox-master ami-xxx ehabhamdy/linkbox token
```

**Pros:**
- ✅ No webhook configuration needed
- ✅ Works automatically

**Cons:**
- ⚠️ Polls GitHub every minute (slower response)
- ⚠️ Uses API calls (but likely within free tier)
- ⚠️ Not instant like webhooks

---

## 🚀 **Option 4: Upgrade to GitHub V2 (Recommended for Production)**

For better webhook management, use CodeStar Connections (GitHub V2):

### **Why GitHub V2 is Better:**
- ✅ Webhooks automatically registered
- ✅ More secure (no OAuth token in template)
- ✅ Better GitHub integration
- ✅ Supports GitHub Enterprise

### **How to Migrate:**

1. **Create CodeStar Connection:**
   ```bash
   aws codestar-connections create-connection \
     --provider-type GitHub \
     --connection-name linkbox-github-connection
   ```

2. **Complete GitHub OAuth flow in AWS Console**

3. **Update CloudFormation template:**
   ```yaml
   # Replace GitHub V1 source with V2:
   - Name: SourceAction
     ActionTypeId:
       Category: Source
       Owner: AWS
       Provider: CodeStarSourceConnection  # ← Changed
       Version: '1'
     Configuration:
       ConnectionArn: !Ref GitHubConnectionArn  # ← New
       FullRepositoryId: !Ref GitHubRepo
       BranchName: !Ref GitHubBranch
     OutputArtifacts:
       - Name: SourceOutput
   ```

**Note:** This requires more setup but is the modern approach.

---

## 🧪 **Testing Webhook**

### **After Setting Up Webhook:**

1. **Make a small change:**
   ```bash
   cd /path/to/your/repo
   echo "# test" >> README.md
   git add README.md
   git commit -m "test: Verify webhook triggers pipeline"
   git push origin main
   ```

2. **Check if pipeline triggered:**
   ```bash
   # Should show new execution
   aws codepipeline list-pipeline-executions \
     --pipeline-name linkbox-backend-pipeline \
     --max-items 1
   ```

3. **Check GitHub webhook deliveries:**
   - GitHub → Settings → Webhooks → linkbox-webhook
   - Click on the webhook
   - See "Recent Deliveries" (should show 200 OK)

---

## 🔍 **Troubleshooting**

### **Webhook Shows Red X in GitHub**

**Possible causes:**
1. Wrong webhook URL
2. Wrong secret (should match GitHub token)
3. AWS webhook deleted

**Fix:**
```bash
# Re-check webhook URL
aws codepipeline list-webhooks \
  --query 'webhooks[?definition.name==`linkbox-github-webhook`].url' \
  --output text

# Update webhook URL in GitHub
```

### **Pipeline Still Not Triggering**

**Check webhook delivery in GitHub:**
1. Go to webhook settings in GitHub
2. Click "Recent Deliveries"
3. Check response code:
   - **200 OK** ✅ - Working
   - **400/401** ❌ - Wrong secret
   - **404** ❌ - Wrong URL
   - **500** ❌ - AWS error

**Check CloudWatch logs:**
```bash
# Check for webhook errors
aws logs tail /aws/codepipeline/linkbox-backend-pipeline --since 1h --follow
```

### **Wrong Branch**

If pushing to a different branch:

```bash
# Check which branch webhook monitors
aws codepipeline list-webhooks \
  --query 'webhooks[?definition.name==`linkbox-github-webhook`].definition.filters' \
  --output json

# Should show: "matchEquals": "refs/heads/main"
```

Make sure you're pushing to `main`, not `master` or another branch.

---

## 📊 **Comparison: Webhook Methods**

| Method | Setup Complexity | Response Time | Maintenance | Recommended |
|--------|-----------------|---------------|-------------|-------------|
| **Manual Trigger** | ⭐ Easy | Instant | High (manual) | ❌ No |
| **GitHub V1 + Manual Webhook** | ⭐⭐ Moderate | Instant | Low | ✅ Learning |
| **GitHub V1 + Polling** | ⭐ Easy | ~1 minute | Low | ✅ Simple |
| **GitHub V2 (CodeStar)** | ⭐⭐⭐ Complex | Instant | Very Low | ✅ Production |

---

## 🎯 **Recommended Quick Fix**

**For now, use manual trigger when you push changes:**

```bash
# 1. Push your code
git push origin main

# 2. Trigger pipeline
aws codepipeline start-pipeline-execution --name linkbox-backend-pipeline

# 3. Watch progress
aws logs tail /aws/codebuild/linkbox-backend-build --follow
```

**Later, add the webhook to GitHub following Step 2 above.**

---

## ✅ **Verify Pipeline Configuration**

```bash
# Check current configuration
aws codepipeline get-pipeline \
  --name linkbox-backend-pipeline \
  --query 'pipeline.stages[0].actions[0].configuration'

# Should show:
{
  "Owner": "ehabhamdy",
  "Repo": "linkbox",
  "Branch": "main",
  "PollForSourceChanges": "false",  # ← Relies on webhook
  "OAuthToken": "****"
}
```

If `PollForSourceChanges` is `false`, you **must** register the webhook in GitHub or the pipeline won't auto-trigger.

---

## 📝 **Summary**

**Why it's not triggering:**
- CloudFormation created webhook in AWS ✅
- Webhook NOT registered in GitHub ❌
- `PollForSourceChanges: false` (no polling) ❌

**Quick fix (now):**
```bash
aws codepipeline start-pipeline-execution --name linkbox-backend-pipeline
```

**Permanent fix (5 minutes):**
1. Get webhook URL from AWS
2. Add webhook to GitHub repository
3. Future pushes will auto-trigger ✅

**Alternative (easier, less instant):**
- Change `PollForSourceChanges: true` in template
- Redeploy stack
- Pipeline polls GitHub every minute ✅

---

## 📚 **Related Documentation**

- `infrastructure/05-cicd.yml` - Pipeline configuration
- `infrastructure/CICD-VERIFICATION.md` - Complete CI/CD documentation
- AWS Docs: [CodePipeline GitHub Webhooks](https://docs.aws.amazon.com/codepipeline/latest/userguide/update-change-detection.html)
- AWS Docs: [CodeStar Connections](https://docs.aws.amazon.com/dtconsole/latest/userguide/welcome-connections.html)

---

**Status:** ⚠️ Webhook not registered in GitHub  
**Quick Fix:** Manual trigger with AWS CLI  
**Permanent Fix:** Register webhook in GitHub settings  
**Time to Fix:** 5 minutes

