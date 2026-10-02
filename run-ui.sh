#!/bin/bash
set -eu
export PORT=3000 HOSTNAME=127.0.0.1 NODE_ENV=production NEXT_TELEMETRY_DISABLED=1
export COGNEE_BACKEND_URL=https://$CLOUDRON_APP_DOMAIN
export DEFAULT_USER_EMAIL=ui-fallback-disabled@invalid
unset DEFAULT_USER_PASSWORD
cd /app/code/ui
exec gosu cloudron:cloudron env HOME=/run/ui-cache /app/code/node/bin/node server.js
