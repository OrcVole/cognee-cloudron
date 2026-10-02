#!/bin/bash
set -eu

mkdir -p /app/data/system /app/data/data /app/data/cache /app/data/logs \
         /app/data/repos /app/data/home /app/data/.secrets /run/nginx /run/ui-cache

# The downloaded models live in /app/models, a persistent directory the platform keeps across updates and
# leaves OUT of backups (they are re-downloadable and large). Earlier builds kept them in /app/data/models,
# which put about 800 MB into every backup: remove that copy so an existing install sheds it.
mkdir -p /app/models/huggingface /app/models/fastembed
if [ -d /app/data/models ]; then rm -rf /app/data/models; fi

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

chown -R cloudron:cloudron /app/data /app/models /run/ui-cache

exec /usr/bin/supervisord --configuration /app/code/supervisord.conf
