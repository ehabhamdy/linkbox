# LinkBox Backend - Local Development Guide

Complete guide for running the LinkBox backend locally with PostgreSQL.

---

## 🚀 Quick Start (Docker Compose)

The fastest way to get started is using Docker Compose which sets up everything automatically.

### Prerequisites
- Docker and Docker Compose installed
- Git (to clone the repository)

### Setup Steps

```bash
# 1. Navigate to backend directory
cd backend

# 2. Start PostgreSQL database
docker-compose up -d db

# 3. Verify database is running
docker-compose ps

# 4. Install Python dependencies
# Option A: Using uv (recommended)
pip install uv
uv sync

# Option B: Using pip
pip install -r requirements.txt

# 5. Run the backend
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Or with python -m
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Access
- **API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health

---

## 📦 Database Configuration

### Default Database Settings (docker-compose)

The `docker-compose.yml` automatically creates a PostgreSQL database with:

```yaml
Database:     linkbox_dev
Username:     linkbox_user
Password:     linkbox_password
Port:         5432
Host:         localhost
```

**Connection String:**
```
postgresql://linkbox_user:linkbox_password@localhost:5432/linkbox_dev
```

This matches the default `DATABASE_URL` in `app/core/config.py`.

---

## 🔧 Configuration

### Option 1: Use Defaults (No Setup Required)

The backend is pre-configured with defaults that work with `docker-compose`.

**File:** `app/core/config.py`
```python
database_url: AnyUrl = "postgresql://linkbox_user:linkbox_password@localhost:5432/linkbox_dev"
```

Just start the database and run the backend - it will work!

### Option 2: Custom Configuration (.env file)

For custom settings, create a `.env` file:

```bash
# Copy example
cp ENV.EXAMPLE .env

# Edit values
nano .env
```

**Example `.env` for local development:**
```bash
ENVIRONMENT=dev
AWS_REGION=us-east-1
S3_BUCKET_NAME=linkbox-dev-bucket
DATABASE_URL=postgresql://linkbox_user:linkbox_password@localhost:5432/linkbox_dev
PRESIGNED_EXPIRY_SECONDS=3600
MAX_UPLOAD_BYTES=10485760
```

---

## 🗄️ Database Management

### Access Database with psql

```bash
# Using Docker Compose
docker-compose exec db psql -U linkbox_user -d linkbox_dev

# Or connect directly (if psql installed)
psql postgresql://linkbox_user:linkbox_password@localhost:5432/linkbox_dev
```

### Database Commands

```sql
-- List all tables
\dt

-- Describe files table
\d files

-- Query data
SELECT * FROM files;

-- Drop all tables (reset)
DROP TABLE files CASCADE;
```

### Using pgAdmin (Optional)

Start pgAdmin for GUI database management:

```bash
# Start pgAdmin
docker-compose --profile tools up -d pgadmin

# Access at: http://localhost:8080
# Email: admin@linkbox.local
# Password: admin123
```

**Add Server in pgAdmin:**
- Host: db (container name)
- Port: 5432
- Database: linkbox_dev
- Username: linkbox_user
- Password: linkbox_password

---

## 🧪 Running Tests

```bash
# Run all tests
uv run pytest

# Run with coverage
uv run pytest --cov=app --cov-report=html

# Run specific test file
uv run pytest tests/test_id.py

# Verbose output
uv run pytest -v
```

---

## 🐛 Troubleshooting

### Database Connection Refused

```bash
# Check if database container is running
docker-compose ps

# View database logs
docker-compose logs db

# Restart database
docker-compose restart db
```

### Port 5432 Already in Use

If you have PostgreSQL installed locally:

```bash
# Stop local PostgreSQL (macOS)
brew services stop postgresql

# Or use different port in docker-compose.yml
ports:
  - "5433:5432"

# Then update DATABASE_URL
DATABASE_URL=postgresql://linkbox_user:linkbox_password@localhost:5433/linkbox_dev
```

### Tables Not Created

The backend automatically creates tables on startup (see `app/main.py` startup event).

If tables aren't created:

```bash
# Check application logs for errors
# Tables should be created when you first start the backend

# Manually create tables (if needed)
docker-compose exec db psql -U linkbox_user -d linkbox_dev -c "
CREATE TABLE IF NOT EXISTS files (
    id VARCHAR PRIMARY KEY,
    original_filename VARCHAR NOT NULL,
    s3_key VARCHAR NOT NULL,
    content_type VARCHAR,
    size_bytes INTEGER,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"
```

### S3 Connection Issues (Local Dev)

For local development without AWS:

**Option A: Use LocalStack**
```bash
# Install LocalStack
pip install localstack

# Start LocalStack
localstack start -d

# Update .env
S3_BUCKET_NAME=linkbox-local
AWS_ENDPOINT_URL=http://localhost:4566
```

**Option B: Disable S3 Operations**
Comment out S3-related code in `app/main.py` for local testing without S3.

---

## 🔄 Reset Everything

```bash
# Stop and remove all containers + volumes
docker-compose down -v

# Restart fresh
docker-compose up -d db

# Backend will recreate tables on startup
```

---

## 📊 Database Schema

The backend uses SQLAlchemy ORM with automatic table creation.

**Current Schema (see `app/models.py`):**

```python
class FileObject(Base):
    __tablename__ = "files"
    
    id: str              # Short unique ID (6 chars)
    original_filename: str
    s3_key: str          # S3 object key
    content_type: str    # MIME type
    size_bytes: int      # File size
    uploaded_at: datetime
```

---

## 🌐 API Endpoints

Once running, test the API:

```bash
# Health check
curl http://localhost:8000/health

# Generate presigned URL
curl -X POST http://localhost:8000/generate-presigned-url \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "test.txt",
    "content_type": "text/plain",
    "size_bytes": 1024
  }'

# Get file metadata
curl http://localhost:8000/files/{file_id}

# API Documentation
open http://localhost:8000/docs
```

---

## 🔐 AWS Credentials (Optional for Local)

If you want to test S3 uploads locally:

```bash
# Configure AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export AWS_DEFAULT_REGION=us-east-1
```

---

## 📝 Development Workflow

### Making Changes

```bash
# 1. Make code changes
# 2. Backend auto-reloads (if using --reload flag)
# 3. Test changes

# Run linter
uv run ruff check app/

# Format code
uv run ruff format app/
```

### Testing Database Changes

```bash
# Drop and recreate database
docker-compose down -v
docker-compose up -d db

# Backend will recreate schema on startup
```

---

## 🚢 Production vs Local

### Local Development
- **Database**: Docker Compose PostgreSQL
- **S3**: LocalStack or mock
- **Config**: .env file or defaults
- **Port**: 8000 (or any)

### AWS Production
- **Database**: RDS PostgreSQL
  - Endpoint from SSM: `/linkbox/db-endpoint`
  - Username from SSM: `/linkbox/db-username`
  - Password from SSM: `/linkbox/db-password` (encrypted)
  - Port: 5432
  - Database: linkbox
  
- **S3**: CloudFormation-managed bucket (`linkbox-uploads`)

- **Config**: Injected by deployment scripts
  - `DATABASE_URL`: Constructed from SSM parameters
  - `S3_BUCKET_NAME`: From CloudFormation
  - `AWS_REGION`: From instance metadata
  
- **Port**: 80 (inside Docker container)

**Connection Flow (Production):**
```
CodeDeploy Script (start_application.sh)
    ↓
Read SSM Parameter Store:
  - /linkbox/db-endpoint
  - /linkbox/db-username  
  - /linkbox/db-password (encrypted SecureString)
  - /linkbox/db-name
    ↓
Construct DATABASE_URL
    ↓
Pass to Docker Container as Environment Variable
    ↓
Backend App Connects to RDS
```

---

## 📚 Additional Resources

- **FastAPI Docs**: https://fastapi.tiangolo.com
- **SQLAlchemy Docs**: https://www.sqlalchemy.org
- **Pydantic Settings**: https://docs.pydantic.dev/latest/concepts/pydantic_settings/
- **PostgreSQL Docs**: https://www.postgresql.org/docs/

---

## ✅ Quick Reference

**Start Development:**
```bash
docker-compose up -d db
uv run uvicorn app.main:app --reload
```

**Stop Development:**
```bash
docker-compose down
```

**Reset Database:**
```bash
docker-compose down -v
docker-compose up -d db
```

**Run Tests:**
```bash
uv run pytest
```

**View Logs:**
```bash
docker-compose logs -f db
```

---

**Happy Coding! 🚀**

