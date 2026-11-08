#!/usr/bin/env bash
set -euo pipefail

KIOSK_URL="${KIOSK_URL:-http://127.0.0.1:8080/}"
PROFILE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/yapdp-kiosk/chrome-profile"

if command -v google-chrome-stable >/dev/null 2>&1; then
  BROWSER="$(command -v google-chrome-stable)"
elif command -v google-chrome >/dev/null 2>&1; then
  BROWSER="$(command -v google-chrome)"
elif command -v chromium >/dev/null 2>&1; then
  BROWSER="$(command -v chromium)"
elif command -v chromium-browser >/dev/null 2>&1; then
  BROWSER="$(command -v chromium-browser)"
else
  echo "Chrome/Chromium was not found. Install Google Chrome before starting the kiosk." >&2
  exit 1
fi

mkdir -p "$PROFILE_DIR"

exec "$BROWSER" \
  --kiosk \
  --no-first-run \
  --no-default-browser-check \
  --disable-session-crashed-bubble \
  --disable-infobars \
  --user-data-dir="$PROFILE_DIR" \
  "$KIOSK_URL"
