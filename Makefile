# Herobot Docker Management Makefile

.PHONY: help build up down restart logs shell test clean cache-clear check-deps

# Docker Compose command detection
DOCKER_COMPOSE := $(shell which docker-compose 2>/dev/null)
ifeq ($(DOCKER_COMPOSE),)
    DOCKER_COMPOSE := docker compose
endif

# Default target
help: ## Show this help message
	@echo "Herobot Docker Management Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Dependency check
check-deps: ## Check if required dependencies are installed
	@echo "Checking dependencies..."
	@command -v docker >/dev/null 2>&1 || (echo "❌ Docker is not installed. Please run: ./scripts/setup.sh" && exit 1)
	@(command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1) || (echo "❌ Docker Compose is not installed. Please run: ./scripts/setup.sh" && exit 1)
	@echo "✅ All dependencies are installed"

# Docker operations
build: check-deps ## Build all containers
	$(DOCKER_COMPOSE) build --no-cache

up: check-deps ## Start all services
	$(DOCKER_COMPOSE) up -d

down: check-deps ## Stop all services
	$(DOCKER_COMPOSE) down

restart: check-deps ## Restart all services
	$(DOCKER_COMPOSE) restart

logs: check-deps ## View logs from all services
	$(DOCKER_COMPOSE) logs -f

logs-app: check-deps ## View logs from Laravel app only
	$(DOCKER_COMPOSE) logs -f laravel.test

logs-db: check-deps ## View logs from database only
	$(DOCKER_COMPOSE) logs -f mariadb

logs-redis: check-deps ## View logs from Redis only
	$(DOCKER_COMPOSE) logs -f redis

# Container access
shell: check-deps ## Access Laravel container shell
	$(DOCKER_COMPOSE) exec laravel.test bash

shell-db: check-deps ## Access database container shell
	$(DOCKER_COMPOSE) exec mariadb bash

shell-redis: check-deps ## Access Redis container shell
	$(DOCKER_COMPOSE) exec redis redis-cli

# Application operations
artisan: check-deps ## Run artisan command (usage: make artisan cmd="migrate")
	$(DOCKER_COMPOSE) exec laravel.test php artisan $(cmd)

composer: check-deps ## Run composer command (usage: make composer cmd="install")
	$(DOCKER_COMPOSE) exec laravel.test composer $(cmd)

npm: check-deps ## Run npm command (usage: make npm cmd="install")
	$(DOCKER_COMPOSE) exec laravel.test npm $(cmd)

test: check-deps ## Run tests
	$(DOCKER_COMPOSE) exec laravel.test php artisan test

test-coverage: check-deps ## Run tests with coverage
	$(DOCKER_COMPOSE) exec laravel.test php artisan test --coverage

# Cache operations
cache-clear: check-deps ## Clear all caches
	$(DOCKER_COMPOSE) exec laravel.test php artisan cache:clear
	$(DOCKER_COMPOSE) exec laravel.test php artisan config:clear
	$(DOCKER_COMPOSE) exec laravel.test php artisan route:clear
	$(DOCKER_COMPOSE) exec laravel.test php artisan view:clear

cache-optimize: check-deps ## Optimize caches for production
	$(DOCKER_COMPOSE) exec laravel.test php artisan config:cache
	$(DOCKER_COMPOSE) exec laravel.test php artisan route:cache
	$(DOCKER_COMPOSE) exec laravel.test php artisan view:cache
	$(DOCKER_COMPOSE) exec laravel.test composer dump-autoload --optimize

# Database operations
db-fresh: check-deps ## Fresh database migration with seeding
	$(DOCKER_COMPOSE) exec laravel.test php artisan migrate:fresh --seed

db-migrate: check-deps ## Run database migrations
	$(DOCKER_COMPOSE) exec laravel.test php artisan migrate

db-seed: check-deps ## Run database seeders
	$(DOCKER_COMPOSE) exec laravel.test php artisan db:seed

db-rollback: check-deps ## Rollback last migration
	$(DOCKER_COMPOSE) exec laravel.test php artisan migrate:rollback

# Development tools
dev-setup: ## Setup development environment
	@echo "Setting up development environment..."
	@if [ ! -f .env ]; then \
		echo "Creating .env file from .env.example..."; \
		cp .env.example .env; \
	else \
		echo ".env file already exists"; \
	fi
	@echo "Running dependency check..."
	@./scripts/setup.sh || (echo "❌ Setup failed. Please check the error messages above." && exit 1)
	@echo "✅ Development environment setup completed!"

prod-build: check-deps ## Build for production
	$(DOCKER_COMPOSE) -f docker-compose.yml build
	$(DOCKER_COMPOSE) -f docker-compose.yml up -d
	make cache-optimize

# Maintenance
clean: check-deps ## Clean up Docker resources
	$(DOCKER_COMPOSE) down -v
	docker system prune -f
	docker volume prune -f

clean-all: check-deps ## Clean up everything including images
	$(DOCKER_COMPOSE) down -v --rmi all
	docker system prune -a -f
	docker volume prune -f

# Monitoring
stats: check-deps ## Show container stats
	docker stats

health: check-deps ## Check container health
	$(DOCKER_COMPOSE) ps
	$(DOCKER_COMPOSE) exec laravel.test php artisan about

# Security
security-check: check-deps ## Run security checks
	$(DOCKER_COMPOSE) exec laravel.test composer audit
	$(DOCKER_COMPOSE) exec laravel.test npm audit

# Backup
backup-db: check-deps ## Backup database
	$(DOCKER_COMPOSE) exec mariadb mysqldump -u root -p$(shell grep DB_PASSWORD .env | cut -d '=' -f2) $(shell grep DB_DATABASE .env | cut -d '=' -f2) > backup_$(shell date +%Y%m%d_%H%M%S).sql

restore-db: check-deps ## Restore database (usage: make restore-db file="backup.sql")
	$(DOCKER_COMPOSE) exec -T mariadb mysql -u root -p$(shell grep DB_PASSWORD .env | cut -d '=' -f2) $(shell grep DB_DATABASE .env | cut -d '=' -f2) < $(file)

# Installation helpers
install-deps: ## Install Docker and Docker Compose (Ubuntu/Debian)
	@echo "Installing dependencies using setup script..."
	@chmod +x ./scripts/setup.sh
	@./scripts/setup.sh

# Quick commands without dependency check (for troubleshooting)
force-up: ## Force start services (skip dependency check)
	$(DOCKER_COMPOSE) up -d

force-down: ## Force stop services (skip dependency check)  
	$(DOCKER_COMPOSE) down

force-logs: ## Force view logs (skip dependency check)
	$(DOCKER_COMPOSE) logs -f

# Container maintenance
rebuild: check-deps ## Rebuild Laravel container and restart
	$(DOCKER_COMPOSE) down
	docker rmi sail-8.4/app 2>/dev/null || true
	$(DOCKER_COMPOSE) build --no-cache laravel.test
	$(DOCKER_COMPOSE) up -d

quick-fix: ## Quick fix for container restart issues
	@chmod +x ./scripts/quick-fix.sh
	@./scripts/quick-fix.sh