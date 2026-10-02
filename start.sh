#!/bin/bash
set -eu

mkdir -p /app/data/system /app/data/data /app/data/cache /app/data/logs \
         /app/data/repos /app/data/models/huggingface /app/data/models/fastembed \
         /app/data/home /app/data/.secrets /run/nginx /run/ui-cache

if [ ! -f /app/data/.secrets/env ]; then
  cat > /app/data/.secrets/env <<EOF
FASTAPI_USERS_JWT_SECRET=$(openssl rand -hex 32)
FASTAPI_USERS_RESET_PASSWORD_TOKEN_SECRET=$(openssl rand -hex 32)
FASTAPI_USERS_VERIFICATION_TOKEN_SECRET=$(openssl rand -hex 32)
DEFAULT_USER_PASSWORD=$(openssl rand -hex 32)
INTEGRATION_CREDENTIALS_SEED=$(openssl rand -hex 32)
EOF
  chmod 600 /app/data/.secrets/env
fi

if [ ! -f /app/data/admin-email ]; then
  echo "admin@${CLOUDRON_APP_DOMAIN}" > /app/data/admin-email
fi

chown -R cloudron:cloudron /app/data /run/ui-cache

exec /usr/bin/supervisord --configuration /app/code/supervisord.conf
