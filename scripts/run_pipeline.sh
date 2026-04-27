#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE_PATH="${ENV_FILE_PATH:-$ROOT_DIR/.env}"
ENV_FILE="${ENV_FILE_PATH/#\~/$HOME}"

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "[ERROR] Neither 'docker compose' nor 'docker-compose' is available."
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERROR] Env file not found: $ENV_FILE"
  echo "[HINT] Use ENV_FILE_PATH to select a file, for example:"
  echo "       ENV_FILE_PATH=$ROOT_DIR/.env.dev bash scripts/run_pipeline.sh"
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

export ENV_FILE_PATH="$ENV_FILE"

echo "[STEP] Starting PostgreSQL container"
"${COMPOSE_CMD[@]}" --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" up -d db

echo "[STEP] Waiting for PostgreSQL to become ready"
until "${COMPOSE_CMD[@]}" --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" exec -T db pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do
  sleep 2
done

# Fetch private data from cloud storage if configured
STORAGE_ENV_FILE=""
if [[ "$ENV_FILE" == "$ROOT_DIR/.env.dev" ]] && [[ -f "$ROOT_DIR/.env.storage.dev" ]]; then
  STORAGE_ENV_FILE="$ROOT_DIR/.env.storage.dev"
elif [[ "$ENV_FILE" == "$ROOT_DIR/.env.production" ]] && [[ -f "$ROOT_DIR/.env.storage.production" ]]; then
  STORAGE_ENV_FILE="$ROOT_DIR/.env.storage.production"
elif [[ -f "$ROOT_DIR/.env.storage" ]]; then
  STORAGE_ENV_FILE="$ROOT_DIR/.env.storage"
fi

if [[ -n "$STORAGE_ENV_FILE" ]]; then
  echo "[STEP] Fetching private data from cloud storage using $(basename "$STORAGE_ENV_FILE")..."
  set -a
  source "$STORAGE_ENV_FILE"
  set +a

  if bash "$ROOT_DIR/scripts/fetch_data_from_storage.sh"; then
    echo "[DONE] Cloud storage data fetch successful"
  else
    echo "[WARN] Cloud storage data fetch failed or not configured. Using local demo data."
  fi
else
  echo "[INFO] No cloud storage env file found. Using local demo data from data/raw/"
fi

echo "[STEP] Creating schema"
"${COMPOSE_CMD[@]}" --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" exec -T db \
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /workspace/sql/01_schema.sql

echo "[STEP] Loading CSV datasets"
"${COMPOSE_CMD[@]}" --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" exec -T db \
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /workspace/sql/02_load_data.sql

echo "[STEP] Running data validation checks"
"${COMPOSE_CMD[@]}" --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" exec -T db \
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /workspace/sql/03_validate.sql

echo "[DONE] Pipeline completed successfully"
