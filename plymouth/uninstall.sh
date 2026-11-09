#!/usr/bin/env bash
set -euo pipefail

THEME_NAME="yapdp-plymouth"
THEME_DIR="/usr/share/plymouth/themes/$THEME_NAME"
THEME_FILE="$THEME_DIR/$THEME_NAME.plymouth"
PLYMOUTH_LINK="/usr/share/plymouth/themes/default.plymouth"
STATE_FILE="/etc/default/yapdp-plymouth.previous"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

previous=""
if [[ -r "$STATE_FILE" ]]; then
  previous="$(cat "$STATE_FILE")"
fi

update-alternatives --remove default.plymouth "$THEME_FILE" || true
if [[ -n "$previous" && -f "$previous" ]]; then
  update-alternatives --set default.plymouth "$previous"
else
  echo "The previous theme was not recorded; choose a theme with:" >&2
  echo "  sudo update-alternatives --config default.plymouth" >&2
fi

update-initramfs -u
rm -rf -- "$THEME_DIR"
rm -f -- "$STATE_FILE"
echo "yaPDP Plymouth theme removed."
