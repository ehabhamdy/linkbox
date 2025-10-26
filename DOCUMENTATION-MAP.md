# 📚 LinkBox Documentation Map

Quick reference guide to all documentation in this project.

---

## 🚀 Getting Started

Start here if you're new to the project:

1. **[README.md](../README.md)** - Project overview and quick start
2. **[backend/LOCAL-DEVELOPMENT.md](../backend/LOCAL-DEVELOPMENT.md)** - Set up local dev environment
3. **[infrastructure/README.md](../infrastructure/README.md)** - Infrastructure overview

---

## 📂 Documentation by Topic

### 🗄️ Database

**Main Guide:**
- **[DATABASE-GUIDE.md](DATABASE-GUIDE.md)** ⭐ Complete database guide
  - Local development setup
  - Production deployment
  - Password vs IAM authentication
  - Security best practices
  - Troubleshooting

**Quick References:**
- **[IAM-AUTH-DEPLOYMENT-GUIDE.md](../IAM-AUTH-DEPLOYMENT-GUIDE.md)** - Step-by-step IAM auth deployment

---

### 🏗️ Infrastructure

**Setup:**
- **[infrastructure/README.md](../infrastructure/README.md)** - Infrastructure overview
- **[infrastructure/deploy.sh](../infrastructure/deploy.sh)** - Main deployment script

**Updates:**
- **[infrastructure/UPDATE-GUIDE.md](../infrastructure/UPDATE-GUIDE.md)** - How to update stacks
- **[infrastructure/quick-update.sh](../infrastructure/quick-update.sh)** - Quick update script

**Architecture:**
- **[architecture.png](../architecture.png)** - System architecture diagram
- **[infrastructure-diagram.md](../infrastructure-diagram.md)** - Text-based diagrams
- **[infrastructure/diagram-mermaid.md](../infrastructure/diagram-mermaid.md)** - Mermaid diagrams

---

### 🔧 Backend Development

**Local Development:**
- **[backend/LOCAL-DEVELOPMENT.md](../backend/LOCAL-DEVELOPMENT.md)** - Complete local setup guide
- **[backend/README.md](../backend/README.md)** - Backend overview
- **[backend/ENV.EXAMPLE](../backend/ENV.EXAMPLE)** - Environment variables

**Code:**
- `backend/app/` - Application code
- `backend/tests/` - Test suite
- `backend/pyproject.toml` - Dependencies

---

### 🎨 Frontend Development

**Setup:**
- **[frontend/README.md](../frontend/README.md)** - Frontend overview
- `frontend/package.json` - Dependencies
- `frontend/vite.config.ts` - Vite configuration

**Code:**
- `frontend/src/` - React application
- `frontend/src/components/` - React components

---

### 🔄 CI/CD

**Pipeline:**
- **[infrastructure/05-cicd.yml](../infrastructure/05-cicd.yml)** - CodePipeline CloudFormation
- **[cicd/buildspec-backend.yml](../cicd/buildspec-backend.yml)** - Backend build spec
- **[cicd/buildspec-frontend.yml](../cicd/buildspec-frontend.yml)** - Frontend build spec

**Deployment:**
- **[appspec.yml](../appspec.yml)** - CodeDeploy configuration
- **[scripts/](../scripts/)** - Deployment scripts
- **[infrastructure/CICD-VERIFICATION.md](../infrastructure/CICD-VERIFICATION.md)** - CI/CD verification

---

### 🔐 Security

**IAM Authentication:**
- **[DATABASE-GUIDE.md](DATABASE-GUIDE.md)** - See "IAM Authentication Setup" section
- **[IAM-AUTH-DEPLOYMENT-GUIDE.md](../IAM-AUTH-DEPLOYMENT-GUIDE.md)** - Deployment guide
- **[backend/app/utils/db_iam_auth.py](../backend/app/utils/db_iam_auth.py)** - Implementation

**Best Practices:**
- See database guide security section
- See infrastructure security groups configuration

---

## 📑 Documentation by Role

### 👨‍💻 For Developers

**First Time Setup:**
1. [README.md](../README.md) - Overview
2. [backend/LOCAL-DEVELOPMENT.md](../backend/LOCAL-DEVELOPMENT.md) - Local setup
3. [DATABASE-GUIDE.md](DATABASE-GUIDE.md) - Database setup

**Daily Development:**
- [backend/README.md](../backend/README.md) - Backend API
- [frontend/README.md](../frontend/README.md) - Frontend app
- [backend/ENV.EXAMPLE](../backend/ENV.EXAMPLE) - Configuration

---

### 🏗️ For DevOps/Infrastructure

**Deployment:**
1. [infrastructure/README.md](../infrastructure/README.md) - Overview
2. [infrastructure/deploy.sh](../infrastructure/deploy.sh) - Deploy script
3. [DATABASE-GUIDE.md](DATABASE-GUIDE.md) - Database setup

**Updates:**
- [infrastructure/UPDATE-GUIDE.md](../infrastructure/UPDATE-GUIDE.md) - Update guide
- [infrastructure/quick-update.sh](../infrastructure/quick-update.sh) - Quick updates

**CI/CD:**
- [infrastructure/05-cicd.yml](../infrastructure/05-cicd.yml) - Pipeline config
- [infrastructure/CICD-VERIFICATION.md](../infrastructure/CICD-VERIFICATION.md) - Verification

---

### 🔒 For Security/Compliance

**Security Setup:**
- [DATABASE-GUIDE.md](DATABASE-GUIDE.md) - Database security
- [docs/IAM-AUTH-DEPLOYMENT-GUIDE.md](../IAM-AUTH-DEPLOYMENT-GUIDE.md) - IAM authentication

**Infrastructure Security:**
- [infrastructure/01-network.yml](../infrastructure/01-network.yml) - VPC & network isolation
- [infrastructure/02-database.yml](../infrastructure/02-database.yml) - RDS security
- [infrastructure/03-backend.yml](../infrastructure/03-backend.yml) - IAM roles & policies

---

## 📊 Quick Reference Tables

### Environment-Specific Guides

| Environment | Guide | Purpose |
|------------|-------|---------|
| **Local** | [backend/LOCAL-DEVELOPMENT.md](../backend/LOCAL-DEVELOPMENT.md) | Dev environment setup |
| **AWS Production** | [DATABASE-GUIDE.md](DATABASE-GUIDE.md) | Production deployment |
| **CI/CD** | [infrastructure/CICD-VERIFICATION.md](../infrastructure/CICD-VERIFICATION.md) | Pipeline setup |

### By Infrastructure Component

| Component | CloudFormation | Documentation |
|-----------|----------------|---------------|
| **Network** | [infrastructure/01-network.yml](../infrastructure/01-network.yml) | VPC, subnets, NAT |
| **Database** | [infrastructure/02-database.yml](../infrastructure/02-database.yml) | [DATABASE-GUIDE.md](DATABASE-GUIDE.md) |
| **Backend** | [infrastructure/03-backend.yml](../infrastructure/03-backend.yml) | ALB, ASG, EC2 |
| **Frontend** | [infrastructure/04-frontend.yml](../infrastructure/04-frontend.yml) | S3, CloudFront |
| **CI/CD** | [infrastructure/05-cicd.yml](../infrastructure/05-cicd.yml) | CodePipeline, CodeDeploy |

### By Task

| Task | Documentation |
|------|---------------|
| **First time setup** | [README.md](../README.md) |
| **Local development** | [backend/LOCAL-DEVELOPMENT.md](../backend/LOCAL-DEVELOPMENT.md) |
| **Deploy infrastructure** | [infrastructure/README.md](../infrastructure/README.md) |
| **Deploy with password auth** | [DATABASE-GUIDE.md](DATABASE-GUIDE.md) → "Password Authentication" |
| **Deploy with IAM auth** | [IAM-AUTH-DEPLOYMENT-GUIDE.md](../IAM-AUTH-DEPLOYMENT-GUIDE.md) |
| **Update infrastructure** | [infrastructure/UPDATE-GUIDE.md](../infrastructure/UPDATE-GUIDE.md) |
| **Troubleshoot database** | [DATABASE-GUIDE.md](DATABASE-GUIDE.md) → "Troubleshooting" |
| **Configure CI/CD** | [infrastructure/CICD-VERIFICATION.md](../infrastructure/CICD-VERIFICATION.md) |

---

## 🔍 Finding What You Need

### "I want to..."

**...set up local development**
→ [backend/LOCAL-DEVELOPMENT.md](../backend/LOCAL-DEVELOPMENT.md)

**...deploy to AWS for the first time**
→ [infrastructure/README.md](../infrastructure/README.md) then [DATABASE-GUIDE.md](DATABASE-GUIDE.md)

**...use IAM database authentication**
→ [IAM-AUTH-DEPLOYMENT-GUIDE.md](../IAM-AUTH-DEPLOYMENT-GUIDE.md)

**...update infrastructure**
→ [infrastructure/UPDATE-GUIDE.md](../infrastructure/UPDATE-GUIDE.md)

**...troubleshoot database connection**
→ [DATABASE-GUIDE.md](DATABASE-GUIDE.md) → Troubleshooting section

**...understand the architecture**
→ [architecture.png](../architecture.png) and [infrastructure-diagram.md](../infrastructure-diagram.md)

**...configure CI/CD pipeline**
→ [infrastructure/05-cicd.yml](../infrastructure/05-cicd.yml) and [infrastructure/CICD-VERIFICATION.md](../infrastructure/CICD-VERIFICATION.md)

---

## 📝 Deprecated/Legacy Files

These files are kept for reference but are superseded by newer documentation:

- `DATABASE-CONNECTIVITY.md` → See [DATABASE-GUIDE.md](DATABASE-GUIDE.md)
- `DATABASE-UPDATES-SUMMARY.md` → See [DATABASE-GUIDE.md](DATABASE-GUIDE.md)
- `IAM-DATABASE-AUTHENTICATION.md` → See [DATABASE-GUIDE.md](DATABASE-GUIDE.md) and [IAM-AUTH-DEPLOYMENT-GUIDE.md](../IAM-AUTH-DEPLOYMENT-GUIDE.md)
- `IAM-IMPLEMENTATION-SUMMARY.md` → See [IAM-AUTH-DEPLOYMENT-GUIDE.md](../IAM-AUTH-DEPLOYMENT-GUIDE.md)
- `legacy/` directory → Old infrastructure templates (pre-modular)

---

## 📚 External Resources

### AWS Documentation
- [RDS PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- [IAM Database Authentication](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html)
- [CloudFormation](https://docs.aws.amazon.com/cloudformation/)
- [CodePipeline](https://docs.aws.amazon.com/codepipeline/)

### Technology Stack
- [FastAPI](https://fastapi.tiangolo.com/)
- [React](https://react.dev/)
- [PostgreSQL](https://www.postgresql.org/docs/)
- [SQLAlchemy](https://docs.sqlalchemy.org/)

---

## 🔄 Keeping Documentation Updated

When you make changes:

1. **Update relevant guide** - Update the main guide for that topic
2. **Update this map** - Add new docs here if needed
3. **Update README** - Keep main README in sync
4. **Check cross-references** - Ensure links still work

---

## ❓ Can't Find What You Need?

1. **Search by keyword** - Use your IDE's search across all .md files
2. **Check this map** - Review sections above
3. **Check README** - Often has quick links
4. **Check code comments** - Implementation details in source files

---

**Last Updated:** October 2025  
**Maintained By:** LinkBox Team

