#!/bin/bash
set -eu

export DB_PROVIDER=postgres
export DB_HOST=$CLOUDRON_POSTGRESQL_HOST
export DB_PORT=$CLOUDRON_POSTGRESQL_PORT
export DB_USERNAME=$CLOUDRON_POSTGRESQL_USERNAME
export DB_PASSWORD=$CLOUDRON_POSTGRESQL_PASSWORD
export DB_NAME=$CLOUDRON_POSTGRESQL_DATABASE
export GRAPH_DATABASE_PROVIDER=kuzu
export VECTOR_DB_PROVIDER=lancedb
export ENABLE_BACKEND_ACCESS_CONTROL=true
export REQUIRE_AUTHENTICATION=true
export SYSTEM_ROOT_DIRECTORY=/app/data/system
export DATA_ROOT_DIRECTORY=/app/data/data
export CACHE_ROOT_DIRECTORY=/app/data/cache
export COGNEE_LOGS_DIR=/app/data/logs
export COGNEE_LOG_FILE=false
export COGNEE_REPOS_DIR=/app/data/repos
export HF_HOME=/app/data/models/huggingface
export FASTEMBED_CACHE_PATH=/app/data/models/fastembed
export HOME=/app/data/home
export TELEMETRY_DISABLED=1
export ENV=production
export CORS_ALLOWED_ORIGINS=https://$CLOUDRON_APP_DOMAIN
export ACCEPT_LOCAL_FILE_PATH=true
export COGNEE_ALLOWED_LOCAL_FILE_ROOTS=/app/data/data
export ALLOW_CYPHER_QUERY=false
export HASH_API_KEY=true
export TOKENIZERS_PARALLELISM=false
export HTTP_PORT=8000
export BIND_ADDRESS=127.0.0.1
export PYTHONPATH=/app/code
export PATH=/app/code/.venv/bin:$PATH
export UV_PYTHON_DOWNLOADS=never
export PYTHONUNBUFFERED=1

set -a
. /app/data/.secrets/env
set +a

export DEFAULT_USER_EMAIL="$(cat /app/data/admin-email)"

gosu cloudron:cloudron env HOME=/app/data/home python - <<'PYTHON'
import asyncio

from cognee.modules.migrations.startup import run_migrations

failed = asyncio.run(run_migrations())
if failed:
    print(
        "Data migrations failed for: " + ", ".join(failed)
        + ". Writes to those datasets are blocked until they migrate; "
        "retried on the next start."
    )
PYTHON

exec gosu cloudron:cloudron env HOME=/app/data/home gunicorn -w 1 -k uvicorn.workers.UvicornWorker -t 30000 --bind=127.0.0.1:8000 --log-level error --access-logfile - --error-logfile - cognee.api.client:app
