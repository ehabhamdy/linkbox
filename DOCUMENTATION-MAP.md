# LinkBox Documentation Map

This guide helps you find the right documentation for your needs.

---

## 📘 Start Here

**[README.md](README.md)** - **Main Documentation (START HERE!)**
- Complete project overview
- Quick start guide (30-minute deployment)
- Full deployment walkthrough
- Local development setup
- CI/CD pipeline explanation
- Configuration guide
- Stack updates procedures
- Monitoring & troubleshooting
- Cost estimation
- Security overview
- All essential commands

**This is your single source of truth for the LinkBox project.**

---

## 📁 Specialized Documentation

### Infrastructure

**[infrastructure/README.md](infrastructure/README.md)** - Infrastructure Technical Reference
- CloudFormation templates details
- Resource specifications
- Parameters reference
- Stack-by-stack breakdown
- Post-deployment steps

**[infrastructure/UPDATE-GUIDE.md](infrastructure/UPDATE-GUIDE.md)** - Stack Update Guide
- How to update deployed stacks
- Update scenarios and examples
- Troubleshooting updates
- Rollback procedures

**[infrastructure/CICD-VERIFICATION.md](infrastructure/CICD-VERIFICATION.md)** - CI/CD Deep Dive
- Complete pipeline verification
- Buildspec and appspec details
- Security best practices
- Common issues and solutions

### Backend & Database

**[backend/LOCAL-DEVELOPMENT.md](backend/LOCAL-DEVELOPMENT.md)** - Backend Development Guide
- Docker Compose setup
- Database configuration
- Testing guide
- Troubleshooting local issues

**[DATABASE-CONNECTIVITY.md](DATABASE-CONNECTIVITY.md)** - Database Connection Details
- Password-based authentication
- IAM authentication
- Connection flow diagrams

**[IAM-DATABASE-AUTHENTICATION.md](IAM-DATABASE-AUTHENTICATION.md)** - IAM Auth Setup
- Benefits of IAM authentication
- Implementation guide
- Setup scripts usage

### Architecture

**[infrastructure-diagram.md](infrastructure-diagram.md)** - Visual Architecture
- Mermaid diagrams
- Component relationships
- Data flow

---

## 🎯 Documentation by Task

### "I want to deploy LinkBox"
→ **[README.md](README.md)** - Quick Start & Deployment Guide sections

### "I want to develop locally"
→ **[README.md](README.md)** - Local Development section
→ **[backend/LOCAL-DEVELOPMENT.md](backend/LOCAL-DEVELOPMENT.md)** (for details)

### "I need to understand the infrastructure"
→ **[README.md](README.md)** - Architecture Overview
→ **[infrastructure/README.md](infrastructure/README.md)** - Technical reference
→ **[infrastructure-diagram.md](infrastructure-diagram.md)** - Visual diagrams

### "I need to update my deployed stack"
→ **[README.md](README.md)** - Stack Updates section
→ **[infrastructure/UPDATE-GUIDE.md](infrastructure/UPDATE-GUIDE.md)** - Detailed procedures

### "My deployment failed"
→ **[README.md](README.md)** - Monitoring & Troubleshooting section
→ **[infrastructure/CICD-VERIFICATION.md](infrastructure/CICD-VERIFICATION.md)** - CI/CD issues

### "I need to understand CI/CD"
→ **[README.md](README.md)** - CI/CD Pipeline section
→ **[infrastructure/CICD-VERIFICATION.md](infrastructure/CICD-VERIFICATION.md)** - Deep dive

### "I want to use IAM database authentication"
→ **[IAM-DATABASE-AUTHENTICATION.md](IAM-DATABASE-AUTHENTICATION.md)** - Complete guide
→ **[DATABASE-CONNECTIVITY.md](DATABASE-CONNECTIVITY.md)** - Connection details

---

## 📂 File Organization

```
linkbox/
├── README.md                              # 🌟 MAIN DOCUMENTATION (START HERE)
├── DOCUMENTATION-MAP.md                   # This file - documentation guide
│
├── Specialized Guides:
│   ├── infrastructure-diagram.md          # Visual architecture
│   ├── DATABASE-CONNECTIVITY.md           # Database connection guide
│   └── IAM-DATABASE-AUTHENTICATION.md     # IAM auth setup
│
├── infrastructure/
│   ├── README.md                          # Infrastructure technical reference
│   ├── UPDATE-GUIDE.md                    # Stack update procedures
│   └── CICD-VERIFICATION.md               # CI/CD verification & troubleshooting
│
└── backend/
    └── LOCAL-DEVELOPMENT.md               # Backend development guide
```

---

## 🔍 Quick Search

### Commands & Scripts
- All commands: **[README.md](README.md)** → "Useful Commands Reference"
- Deployment: **[README.md](README.md)** → "Deployment Guide"
- Updates: **[infrastructure/UPDATE-GUIDE.md](infrastructure/UPDATE-GUIDE.md)**

### Troubleshooting
- General: **[README.md](README.md)** → "Monitoring & Troubleshooting"
- CI/CD issues: **[infrastructure/CICD-VERIFICATION.md](infrastructure/CICD-VERIFICATION.md)** → "Common Issues"
- Local dev issues: **[backend/LOCAL-DEVELOPMENT.md](backend/LOCAL-DEVELOPMENT.md)** → "Troubleshooting"

### Configuration
- All configs: **[README.md](README.md)** → "Configuration"
- Infrastructure params: **[infrastructure/README.md](infrastructure/README.md)** → "Parameters Reference"
- Backend env vars: **[backend/LOCAL-DEVELOPMENT.md](backend/LOCAL-DEVELOPMENT.md)** → "Configuration"

### Cost & Security
- Cost breakdown: **[README.md](README.md)** → "Cost Estimation"
- Security features: **[README.md](README.md)** → "Security"
- IAM policies: **[infrastructure/INFRASTRUCTURE-FIXES.md](infrastructure/INFRASTRUCTURE-FIXES.md)**

---

## 📝 Notes

### Documentation Cleanup

**Removed (Consolidated into README.md):**
- ✅ DEPLOYMENT-GUIDE.md → Now in README.md
- ✅ DEPLOYMENT-FIX.md → Troubleshooting in README.md
- ✅ CICD-SETUP.md → CI/CD section in README.md
- ✅ UPDATE-SCRIPTS-SUMMARY.md → Stack Updates in README.md
- ✅ WEBHOOK-SETUP.md → CICD-VERIFICATION.md
- ✅ cicd/BUILDSPEC-FIX.md → No longer needed
- ✅ infrastructure/INFRASTRUCTURE-FIXES.md → Best practices incorporated
- ✅ infrastructure/SSM-PARAMETER-NOTES.md → No longer needed

**Kept (Deep-dive technical details):**
- ✅ infrastructure/README.md - Technical reference
- ✅ infrastructure/UPDATE-GUIDE.md - Detailed update procedures
- ✅ infrastructure/CICD-VERIFICATION.md - CI/CD deep dive
- ✅ backend/LOCAL-DEVELOPMENT.md - Detailed dev setup
- ✅ DATABASE-CONNECTIVITY.md - DB connection details
- ✅ IAM-DATABASE-AUTHENTICATION.md - IAM auth guide
- ✅ infrastructure-diagram.md - Visual architecture

---

## 🎯 Recommendation

**For 90% of use cases:**
- Start and stay in **[README.md](README.md)**
- It has everything you need from deployment to troubleshooting

**For advanced/specific needs:**
- Refer to specialized documentation linked above
- Each document is focused on its specific domain

---

**Happy building! 🚀**

