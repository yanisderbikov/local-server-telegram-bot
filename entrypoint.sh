#!/bin/bash
set -euo pipefail
: "${TELEGRAM_API_ID:?Set TELEGRAM_API_ID}"
: "${TELEGRAM_API_HASH:?Set TELEGRAM_API_HASH}"
: "${TELEGRAM_HTTP_PORT:=8081}"
: "${TELEGRAM_HTTP_IP_ADDRESS:=0.0.0.0}"
: "${TELEGRAM_DATA_DIR:=/var/lib/telegram-bot-api}"
: "${TELEGRAM_TEMP_DIR:=${TELEGRAM_DATA_DIR}/temp}"
: "${TELEGRAM_VERBOSITY:=1}"
: "${FILE_SERVER_PORT:=8082}"
mkdir -p "$TELEGRAM_DATA_DIR" "$TELEGRAM_TEMP_DIR"

# The native server reads TELEGRAM_API_ID/HASH directly from env.
api=(telegram-bot-api --local --http-ip-address="$TELEGRAM_HTTP_IP_ADDRESS"
  --http-port="$TELEGRAM_HTTP_PORT" --dir="$TELEGRAM_DATA_DIR"
  --temp-dir="$TELEGRAM_TEMP_DIR" --verbosity="$TELEGRAM_VERBOSITY")

# Without a token there is no file server: consumers must share the data volume.
if [ -z "${FILE_SERVER_TOKEN:-}" ]; then exec "${api[@]}"; fi

if [[ "$TELEGRAM_HTTP_IP_ADDRESS" == *:* ]]; then listen="[::]:$FILE_SERVER_PORT ipv6only=off"
else listen="$TELEGRAM_HTTP_IP_ADDRESS:$FILE_SERVER_PORT"; fi
# As root (e.g. RAILWAY_RUN_UID=0) workers would drop to nobody and could not read
# the API's private files, so keep them under the same user as telegram-bot-api.
user_directive=""
if [ "$(id -u)" = 0 ]; then user_directive="user root;"; fi
conf=/tmp/nginx/nginx.conf
mkdir -p /tmp/nginx
cat > "$conf" <<NGINX
$user_directive
worker_processes 1;
pid /tmp/nginx/nginx.pid;
error_log stderr warn;
events { worker_connections 64; }
http {
  access_log off;
  client_body_temp_path /tmp/nginx/body;
  proxy_temp_path /tmp/nginx/proxy;
  fastcgi_temp_path /tmp/nginx/fastcgi;
  uwsgi_temp_path /tmp/nginx/uwsgi;
  scgi_temp_path /tmp/nginx/scgi;
  sendfile on;
  server {
    listen $listen;
    root $TELEGRAM_DATA_DIR;
    autoindex off;
    if (\$http_authorization != "Bearer $FILE_SERVER_TOKEN") { return 401; }
    # TDLib state is never served or deleted.
    location ~ (td\.binlog|\.sqlite|/temp/) { return 403; }
    location / {
      dav_methods DELETE;
      limit_except GET DELETE { deny all; }
    }
  }
}
NGINX

"${api[@]}" &
nginx -e stderr -c "$conf" -g 'daemon off;' &
trap 'kill -TERM $(jobs -p) 2>/dev/null' TERM INT
# Exit when either process stops so the platform restarts the container.
wait -n
status=$?
kill -TERM $(jobs -p) 2>/dev/null || true
wait
exit "$status"
