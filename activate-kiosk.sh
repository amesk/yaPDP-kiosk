#!/usr/bin/env bash
set -euo pipefail
if [[ "$EUID" -ne 0 ]]; then echo "Run with sudo: sudo $0" >&2; exit 1; fi
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/install/ubuntu-24.04.sh"
if [[ ! -f "$INSTALLER" ]]; then
  INSTALLER="/opt/yapdp-exhibit/yaPDP-kiosk/install/ubuntu-24.04.sh"
fi
if [[ ! -f "$INSTALLER" ]]; then
  echo "yaPDP-kiosk installer was not found. Keep the repository at /opt/yapdp-exhibit/yaPDP-kiosk or run this script from its checkout." >&2
  exit 1
fi
# Re-running the installer reapplies kiosk settings. Its original-state snapshot
# is retained and capture-system-state.py never overwrites an existing backup.
exec bash "$INSTALLER"
