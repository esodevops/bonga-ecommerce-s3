SHELL := /bin/bash
COMPOSE := $(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; elif command -v docker-compose >/dev/null 2>&1; then echo "docker-compose"; fi)
ENV ?= .env.dev

.PHONY: setup setup-dev setup-prod up load validate pipeline down logs pipeline-dev pipeline-prod

setup:
	cp -n .env.example .env || true
	@echo "Edit .env and set a strong POSTGRES_PASSWORD before continuing."

setup-dev:
	cp -n .env.dev.example .env.dev || true
	@echo "Edit .env.dev and set a strong POSTGRES_PASSWORD before continuing."

setup-prod:
	cp -n .env.production.example .env.production || true
	@echo "Edit .env.production and set a strong POSTGRES_PASSWORD before continuing."

up:
	@set -a; source $(ENV); set +a; \
	ENV_FILE_PATH=$(ENV) $(COMPOSE) --env-file $(ENV) up -d db

load:
	ENV_FILE_PATH=$(ENV) bash scripts/run_pipeline.sh

validate:
	@set -a; source $(ENV); set +a; \
	ENV_FILE_PATH=$(ENV) $(COMPOSE) --env-file $(ENV) exec -T db psql -v ON_ERROR_STOP=1 -U $$POSTGRES_USER -d $$POSTGRES_DB -f /workspace/sql/03_validate.sql

pipeline: load

pipeline-dev:
	$(MAKE) pipeline ENV=.env.dev

pipeline-prod:
	$(MAKE) pipeline ENV=.env.production

down:
	@set -a; source $(ENV); set +a; \
	ENV_FILE_PATH=$(ENV) $(COMPOSE) --env-file $(ENV) down

logs:
	@set -a; source $(ENV); set +a; \
	ENV_FILE_PATH=$(ENV) $(COMPOSE) --env-file $(ENV) logs -f db
