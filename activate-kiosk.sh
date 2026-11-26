#!/usr/bin/env bash
set -euo pipefail
if [[ "$EUID" -ne 0 ]]; then echo "Run with sudo: sudo $0" >&2; exit 1; fi
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/install/ubuntu-24.04.sh"
if [[ ! -f "$INSTALLER" ]]; then
  echo "Installer not found: $INSTALLER" >&2
  echo "Run this script from the yaPDP-kiosk repository." >&2
  exit 1
fi
# Re-running the installer re-applies the kiosk configuration. The original
# pre-install snapshot is intentionally retained and is never overwritten.
exec bash "$INSTALLER"
