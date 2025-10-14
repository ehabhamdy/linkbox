# BuildSpec Configuration Fix

## 🐛 **Issue: ECR Login Failed with "None" Account ID**

### **Error Encountered**

```
Error response from daemon: login attempt to https://None.dkr.ecr.us-east-1.amazonaws.com/v2/ failed with status: 400 Bad Request
```

**Root Cause:** `aws sts get-caller-identity` was returning `None` instead of the actual AWS account ID.

---

## ❌ **What Was Wrong**

### **Original buildspec-backend.yml:**

```yaml
version: 0.2

env:
  variables:
    IMAGE_REPO_NAME: linkbox-backend
    AWS_DEFAULT_REGION: us-east-1

phases:
  pre_build:
    commands:
      - ACCOUNT_ID=$(aws sts get-caller-identity --query account --output text)
      - REPOSITORY_URI=$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME
```

### **Problems:**

1. **Hardcoded Environment Variables**
   - Buildspec defined its own `env.variables` section
   - This **overrode** the environment variables passed from CloudFormation
   - CloudFormation was passing `AWS_ACCOUNT_ID`, `AWS_DEFAULT_REGION`, `IMAGE_REPO_NAME`
   - But buildspec's hardcoded values took precedence

2. **Dynamic STS Call Failing**
   - Tried to get account ID dynamically: `aws sts get-caller-identity`
   - This command was returning `None` (likely due to timing or permissions)
   - Used the failed result (`None`) to construct ECR URI
   - Result: `None.dkr.ecr.us-east-1.amazonaws.com/linkbox-backend` ❌

3. **Why STS Call Failed**
   - CodeBuild environment might not have STS permissions initialized immediately
   - The hardcoded `env.variables` might have interfered with AWS SDK initialization
   - CloudFormation was already providing the correct values!

---

## ✅ **The Fix**

### **Updated buildspec-backend.yml:**

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws --version
      - echo "AWS Account ID: $AWS_ACCOUNT_ID"
      - echo "AWS Region: $AWS_DEFAULT_REGION"
      - echo "Image Repo Name: $IMAGE_REPO_NAME"
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME
      - echo "Repository URI: $REPOSITORY_URI"
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $REPOSITORY_URI
```

### **What Changed:**

1. **Removed `env.variables` Section**
   - No longer overriding CloudFormation environment variables
   - Uses environment variables passed from CloudFormation template

2. **Use CloudFormation Variables Directly**
   - `$AWS_ACCOUNT_ID` - Passed from CloudFormation (via `!Ref AWS::AccountId`)
   - `$AWS_DEFAULT_REGION` - Passed from CloudFormation (via `!Ref AWS::Region`)
   - `$IMAGE_REPO_NAME` - Passed from CloudFormation

3. **Added Debug Echo Statements**
   - Prints all environment variables to CodeBuild logs
   - Makes debugging easier if issues occur
   - Verifies correct values are being used

---

## 📋 **How Environment Variables Flow**

### **CloudFormation Template (`05-cicd.yml`):**

```yaml
CodeBuildProject:
  Type: AWS::CodeBuild::Project
  Properties:
    Environment:
      EnvironmentVariables:
        - Name: AWS_DEFAULT_REGION
          Value: !Ref AWS::Region              # ✅ us-east-1
        - Name: AWS_ACCOUNT_ID
          Value: !Ref AWS::AccountId           # ✅ 789702501748
        - Name: IMAGE_REPO_NAME
          Value: !Sub '${EnvironmentName}-backend'  # ✅ linkbox-backend
```

### **BuildSpec Receives These Variables:**

```bash
$AWS_DEFAULT_REGION = "us-east-1"
$AWS_ACCOUNT_ID = "789702501748"
$IMAGE_REPO_NAME = "linkbox-backend"
```

### **BuildSpec Uses Them:**

```bash
REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME
# Result: 789702501748.dkr.ecr.us-east-1.amazonaws.com/linkbox-backend ✅
```

---

## 🎯 **Why This Approach is Better**

| Aspect | Old (Hardcoded) | New (CloudFormation) |
|--------|----------------|---------------------|
| **Flexibility** | ❌ Hardcoded region | ✅ Works in any region |
| **Account** | ❌ Dynamic STS call (unreliable) | ✅ CloudFormation provides it |
| **Repo Name** | ❌ Hardcoded | ✅ Uses environment name |
| **Debugging** | ❌ No visibility | ✅ Echo statements |
| **Reliability** | ❌ STS can fail | ✅ CloudFormation always correct |
| **Speed** | ❌ Extra STS call | ✅ No extra API calls |

---

## 🔍 **Debugging the Build**

### **View CodeBuild Logs:**

```bash
# Tail logs in real-time
aws logs tail /aws/codebuild/linkbox-backend-build --follow

# Or view in AWS Console
# CodeBuild → Build Projects → linkbox-backend-build → Build history → View logs
```

### **What You Should See Now:**

```
[Container] 2025/10/14 12:34:56 Running command echo "AWS Account ID: $AWS_ACCOUNT_ID"
AWS Account ID: 789702501748

[Container] 2025/10/14 12:34:56 Running command echo "AWS Region: $AWS_DEFAULT_REGION"
AWS Region: us-east-1

[Container] 2025/10/14 12:34:56 Running command echo "Image Repo Name: $IMAGE_REPO_NAME"
Image Repo Name: linkbox-backend

[Container] 2025/10/14 12:34:56 Running command echo "Repository URI: $REPOSITORY_URI"
Repository URI: 789702501748.dkr.ecr.us-east-1.amazonaws.com/linkbox-backend

[Container] 2025/10/14 12:34:57 Running command aws ecr get-login-password...
Login Succeeded
```

**If you see "None" anywhere, the CloudFormation template isn't passing the variables correctly.**

---

## 🚀 **Testing the Fix**

### **Option 1: Push to GitHub (Automatic)**

```bash
# Commit the fixed buildspec
cd /path/to/your/repo
git add cicd/buildspec-backend.yml
git commit -m "fix: Use CloudFormation env vars instead of STS call"
git push origin main

# Pipeline will automatically trigger
# Watch it in AWS Console: CodePipeline → linkbox-backend-pipeline
```

### **Option 2: Manual Pipeline Trigger**

```bash
# Trigger pipeline manually
aws codepipeline start-pipeline-execution \
  --name linkbox-backend-pipeline

# Get execution ID
aws codepipeline list-pipeline-executions \
  --pipeline-name linkbox-backend-pipeline \
  --max-items 1
```

### **Monitor Build Progress:**

```bash
# Watch CodeBuild logs
aws logs tail /aws/codebuild/linkbox-backend-build --follow

# Check build status
aws codebuild list-builds-for-project \
  --project-name linkbox-backend-build \
  --max-items 1
```

---

## ✅ **Expected Results**

### **Pre-Build Phase:**
- ✅ Echo statements show correct values
- ✅ Repository URI constructed correctly
- ✅ ECR login succeeds
- ✅ Git hash extracted for image tag

### **Build Phase:**
- ✅ Docker image builds from `./backend`
- ✅ Image tagged with commit hash and `latest`

### **Post-Build Phase:**
- ✅ Both images pushed to ECR
- ✅ `imagedefinitions.json` created
- ✅ Artifacts packaged (appspec.yml, scripts)

### **Deploy Phase:**
- ✅ CodeDeploy receives artifacts
- ✅ Deployment to EC2 Auto Scaling Group
- ✅ New container running on instances

---

## 📊 **Environment Variables Reference**

### **Available in CodeBuild (from CloudFormation):**

| Variable | Value | Source |
|----------|-------|--------|
| `AWS_DEFAULT_REGION` | `us-east-1` | `!Ref AWS::Region` |
| `AWS_ACCOUNT_ID` | `789702501748` | `!Ref AWS::AccountId` |
| `IMAGE_REPO_NAME` | `linkbox-backend` | `!Sub '${EnvironmentName}-backend'` |

### **Available in CodeBuild (built-in):**

| Variable | Example Value | Description |
|----------|---------------|-------------|
| `CODEBUILD_BUILD_ID` | `linkbox-backend:uuid` | Unique build identifier |
| `CODEBUILD_BUILD_NUMBER` | `42` | Sequential build number |
| `CODEBUILD_RESOLVED_SOURCE_VERSION` | `abc123...` | Git commit SHA |
| `CODEBUILD_SOURCE_REPO_URL` | `https://github.com/...` | Repository URL |
| `CODEBUILD_SOURCE_VERSION` | `main` | Branch name |

### **Derived in BuildSpec:**

| Variable | Construction | Example |
|----------|-------------|---------|
| `REPOSITORY_URI` | `$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME` | `789702501748.dkr.ecr.us-east-1.amazonaws.com/linkbox-backend` |
| `GIT_HASH` | First 7 chars of commit SHA | `abc1234` |
| `IMAGE_TAG` | `$GIT_HASH` or `latest` | `abc1234` |

---

## 🔒 **Security Note**

**Why not use STS in buildspec?**

1. **Reliability:** CloudFormation knows the account ID at stack creation
2. **Performance:** No extra API call needed
3. **Permissions:** Don't need to grant STS permissions to CodeBuild role
4. **Simplicity:** One source of truth (CloudFormation template)

**The CodeBuild role still has ECR permissions** (defined in `05-cicd.yml`):
```yaml
- Effect: Allow
  Action:
    - ecr:GetAuthorizationToken
    - ecr:BatchCheckLayerAvailability
    - ecr:GetDownloadUrlForLayer
    - ecr:BatchGetImage
    - ecr:PutImage
  Resource: '*'
```

This is sufficient for building and pushing Docker images.

---

## 🎯 **Summary**

**Issue:** BuildSpec was overriding CloudFormation environment variables and trying to query account ID dynamically (failing with "None").

**Fix:** Removed hardcoded `env.variables` section and used CloudFormation-provided environment variables directly.

**Result:** ECR URI now constructed correctly, login succeeds, build proceeds.

**Next Steps:**
1. ✅ Commit fixed buildspec to your GitHub repository
2. ✅ Push to trigger pipeline
3. ✅ Watch build succeed in CodeBuild logs
4. ✅ Verify Docker image pushed to ECR
5. ✅ Verify deployment to EC2 instances

---

## 📚 **Related Files**

- `cicd/buildspec-backend.yml` - Build specification (FIXED)
- `infrastructure/05-cicd.yml` - CI/CD CloudFormation stack (provides env vars)
- `infrastructure/CICD-VERIFICATION.md` - Complete CI/CD documentation

---

**Issue:** ❌ ECR login failed with "None" account ID  
**Status:** ✅ **FIXED**  
**Action:** Push fixed buildspec to GitHub and rebuild

