.PHONY: help install dev start test clean lint format docker-build docker-run db-up db-down db-reset db-logs db-shell

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install dependencies using uv
	uv sync

install-dev: ## Install dependencies including dev dependencies
	uv sync --dev

dev: ## Start development server with hot reload
	uv run linkbox-dev

start: ## Start production server
	uv run linkbox-start

test: ## Run tests
	uv run pytest

test-coverage: ## Run tests with coverage
	uv run pytest --cov=app --cov-report=html

clean: ## Clean up cache and temporary files
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	rm -rf .pytest_cache/
	rm -rf htmlcov/
	rm -rf dist/
	rm -rf *.egg-info/

lint: ## Run linting tools
	uv run flake8 .
	uv run mypy .

format: ## Format code
	uv run black .
	uv run isort .

format-check: ## Check if code is properly formatted
	uv run black --check .
	uv run isort --check-only .

requirements: ## Generate requirements.txt from pyproject.toml
	uv pip compile pyproject.toml -o requirements.txt

docker-build: ## Build Docker image
	docker build -t linkbox-backend .

docker-run: ## Run Docker container
	docker run -p 8000:80 linkbox-backend

docker-dev: ## Build and run Docker container for development
	docker build -t linkbox-backend .
	docker run -p 8000:80 -v $(PWD)/app:/app/app linkbox-backend

# Database commands
db-up: ## Start PostgreSQL database in Docker
	docker compose up -d db

db-down: ## Stop PostgreSQL database
	docker compose down

db-reset: ## Reset database (stop, remove volume, start fresh)
	docker compose down -v
	docker compose up -d db

db-logs: ## Show database logs
	docker compose logs -f db

db-shell: ## Connect to database shell
	docker compose exec db psql -U linkbox_user -d linkbox_dev

pgadmin: ## Start pgAdmin (web-based database admin tool)
	docker compose --profile tools up -d pgadmin

dev-full: ## Start database and development server
	docker compose up -d db
	@echo "Waiting for database to be ready..."
	@sleep 5
	uv run python dev.py