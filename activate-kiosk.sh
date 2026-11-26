#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo: sudo $0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/install/ubuntu-24.04.sh"
if [[ ! -f "$INSTALLER" ]]; then
  INSTALLER="/opt/yapdp-exhibit/yaPDP-kiosk/install/ubuntu-24.04.sh"
fi
if [[ ! -f "$INSTALLER" ]]; then
  echo "yaPDP-kiosk installer was not found. Keep the repository at /opt/yapdp-exhibit/yaPDP-kiosk or run this script from its checkout." >&2
  exit 1
fi

STATE="/var/lib/yapdp-kiosk/original-state"
if [[ ! -s "$STATE/manifest.json" ]]; then
  echo "No original-state snapshot found at $STATE." >&2
  echo "Activation is intended for a previously installed and deactivated kiosk; run the installer for first-time setup." >&2
  exit 1
fi

# Reapply the managed kiosk configuration. The installer preserves the first
# snapshot and reuses the existing GRUB password, so this does not redefine the
# machine's pre-install state or rotate staff credentials.
exec bash "$INSTALLER"
