#!/bin/sh
set -eu
: "${TELEGRAM_API_ID:?Set TELEGRAM_API_ID}"
: "${TELEGRAM_API_HASH:?Set TELEGRAM_API_HASH}"
: "${TELEGRAM_HTTP_PORT:=8081}"
: "${TELEGRAM_DATA_DIR:=/var/lib/telegram-bot-api}"
: "${TELEGRAM_TEMP_DIR:=${TELEGRAM_DATA_DIR}/temp}"
: "${TELEGRAM_VERBOSITY:=1}"
mkdir -p "$TELEGRAM_DATA_DIR" "$TELEGRAM_TEMP_DIR"
# The native server reads TELEGRAM_API_ID/HASH directly from env.
exec telegram-bot-api --local --http-ip-address=0.0.0.0 \
  --http-port="$TELEGRAM_HTTP_PORT" --dir="$TELEGRAM_DATA_DIR" \
  --temp-dir="$TELEGRAM_TEMP_DIR" --verbosity="$TELEGRAM_VERBOSITY"
