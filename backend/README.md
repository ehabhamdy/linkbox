# LinkBox Backend

A FastAPI-based backend service for the LinkBox application, built with modern Python tooling using uv for dependency management.

## 🚀 Quick Start

### Prerequisites

- Python 3.13+
- [uv](https://docs.astral.sh/uv/) (recommended) or pip
- PostgreSQL (for database)

### Installation

1. **Clone the repository and navigate to the backend directory:**
   ```bash
   cd backend
   ```

2. **Install dependencies using uv (recommended):**
   ```bash
   uv sync
   ```

   Or using pip:
   ```bash
   pip install -r requirements.txt
   ```

3. **Set up the local database (PostgreSQL in Docker):**
   ```bash
   # Start PostgreSQL database
   make db-up
   # Or manually:
   docker-compose up -d db
   ```

4. **Run the development server:**
   ```bash
   # Option 1: Start database and server together
   make dev-full

   # Option 2: Start server manually (database must be running)
   uv run python dev.py

   # Option 3: Use uvicorn directly
   uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

The API will be available at `http://localhost:8000`

## 📁 Project Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py          # FastAPI application entry point
│   ├── models.py        # Database models
│   ├── schemas.py       # Pydantic schemas
│   ├── db.py           # Database connection
│   ├── core/
│   │   └── config.py   # Configuration settings
│   └── utils/
│       └── id.py       # Utility functions
├── tests/
│   └── test_id.py      # Test files
├── pyproject.toml      # Project configuration and dependencies
├── uv.lock            # Dependency lock file
├── requirements.txt    # Pip fallback requirements
├── Dockerfile         # Container configuration
└── README.md          # This file
```

## 🛠️ Development

### Using uv (Recommended)

uv is a fast Python package manager that provides better dependency resolution and faster installations.

**Add new dependencies:**
```bash
uv add package-name
```

**Add development dependencies:**
```bash
uv add --dev package-name
```

**Remove dependencies:**
```bash
uv remove package-name
```

**Update dependencies:**
```bash
uv sync --upgrade
```

**Run scripts:**
```bash
uv run uvicorn app.main:app --reload  # Start development server with hot reload
uv run python dev.py                  # Alternative development server script
```

**Install development dependencies:**
```bash
uv sync --dev
```

**Code formatting and linting:**
```bash
uv run black .         # Format code
uv run isort .         # Sort imports
uv run flake8 .        # Lint code
uv run mypy .          # Type checking
```

### Environment Management

The project uses uv's built-in virtual environment management. When you run `uv sync`, it automatically creates and manages a virtual environment.

**Activate the virtual environment manually (if needed):**
```bash
source .venv/bin/activate  # On macOS/Linux
# or
.venv\Scripts\activate     # On Windows
```

### Running Tests

```bash
# Using uv
uv run pytest

# Or if environment is activated
pytest
```

### Using Make Commands (Optional)

For convenience, you can use the provided Makefile:

**Development Commands:**
```bash
make help          # Show available commands
make install       # Install dependencies
make install-dev   # Install with dev dependencies
make dev           # Start development server
make dev-full      # Start database + development server
make test          # Run tests
```

**Database Commands:**
```bash
make db-up         # Start PostgreSQL database
make db-down       # Stop database
make db-reset      # Reset database (removes all data)
make db-logs       # Show database logs
make db-shell      # Connect to database shell
make pgadmin       # Start pgAdmin web interface
```

**Code Quality Commands:**
```bash
make lint          # Run linting
make format        # Format code
make docker-build  # Build Docker image
make requirements  # Generate requirements.txt from pyproject.toml
```

### Code Quality

Make sure to follow Python best practices:

- Use type hints
- Follow PEP 8 style guidelines
- Write comprehensive tests
- Document your code

The project includes development dependencies for code quality:
- **black**: Code formatting
- **isort**: Import sorting
- **flake8**: Linting
- **mypy**: Type checking

## �️ Database Setup

### Local Development with Docker

The easiest way to set up a PostgreSQL database for local development is using Docker Compose.

**Quick Start:**
```bash
# Start the database
make db-up

# Start database and development server together
make dev-full
```

**Manual Database Management:**
```bash
# Start PostgreSQL database
docker-compose up -d db

# Check if database is ready
docker-compose logs db

# Stop database
make db-down

# Reset database (removes all data)
make db-reset

# Connect to database shell
make db-shell

# Start pgAdmin (web interface at http://localhost:8080)
make pgadmin
```

**Database Connection Details:**
- **Host**: localhost
- **Port**: 5432
- **Database**: linkbox_dev
- **Username**: linkbox_user
- **Password**: linkbox_password

**pgAdmin Access** (if started):
- **URL**: http://localhost:8080
- **Email**: admin@linkbox.local
- **Password**: admin123

### Environment Variables

For local development, you don't need to create a `.env` file as the default values in `config.py` will work with the Docker database.

For production or custom configuration:
```bash
cp ENV.EXAMPLE .env
# Edit .env with your production database settings
```

### Database Schema

The application will automatically create the necessary database tables on startup. Check `app/models.py` for the database schema definition.

## �🐳 Docker

### Build the Docker image:
```bash
docker build -t linkbox-backend .
```

### Run the container:
```bash
docker run -p 8000:80 linkbox-backend
```

The Dockerfile is optimized for uv and includes:
- Python 3.13 slim base image
- uv for fast dependency installation
- Proper caching layers
- Security best practices

## 📊 Database

The application uses PostgreSQL as the primary database. Make sure to:

1. Set up your PostgreSQL instance
2. Configure the database connection in your `.env` file
3. Run migrations if applicable

## 🔧 Configuration

Environment variables can be configured in the `.env` file. See `ENV.EXAMPLE` for available options.

Key configuration areas:
- Database connection settings
- AWS credentials and configuration
- Application-specific settings

## 📚 API Documentation

Once the server is running, you can access:

- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`
- **OpenAPI JSON**: `http://localhost:8000/openapi.json`

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Add tests for new functionality
4. Ensure all tests pass: `uv run pytest`
5. Submit a pull request

## 📝 License

[Add your license information here]

## 🆘 Troubleshooting

### Common Issues

**uv not found:**
```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
# or
pip install uv
```

**Database connection issues:**
- Verify PostgreSQL is running
- Check your database credentials in `.env`
- Ensure the database exists

**Import errors:**
- Make sure you're using the project's virtual environment
- Run `uv sync` to ensure all dependencies are installed

### Performance Tips

- Use `uv run` for better startup times
- Consider using `uvicorn` with multiple workers in production
- Enable database connection pooling for better performance

For more help, please check the project's main README or create an issue.
