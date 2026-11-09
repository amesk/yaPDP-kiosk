#!/usr/bin/env bash
set -euo pipefail

THEME_NAME="yapdp-plymouth"
THEME_DIR="/usr/share/plymouth/themes/$THEME_NAME"
SOURCE_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
PLYMOUTH_LINK="/usr/share/plymouth/themes/default.plymouth"
THEME_FILE="$THEME_DIR/$THEME_NAME.plymouth"
STATE_FILE="/etc/default/yapdp-plymouth.previous"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

if ! command -v update-alternatives >/dev/null 2>&1 ||
   ! command -v update-initramfs >/dev/null 2>&1; then
  echo "Plymouth/update-initramfs tools are not installed. Install Ubuntu Desktop's Plymouth packages first." >&2
  exit 1
fi

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "Installing SVG renderer (librsvg2-bin)..."
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y librsvg2-bin
fi

mkdir -p "$THEME_DIR"
for asset in panel led-green led-amber bar-fill; do
  rsvg-convert --format=png --output="$THEME_DIR/$asset.png" "$SOURCE_DIR/$asset.svg"
done
install -m 0644 "$SOURCE_DIR/$THEME_NAME.plymouth" "$THEME_FILE"
install -m 0644 "$SOURCE_DIR/$THEME_NAME.script" "$THEME_DIR/$THEME_NAME.script"

# Preserve the currently selected theme only on the first install.
if [[ ! -e "$STATE_FILE" ]]; then
  current="$(readlink -f "$PLYMOUTH_LINK" 2>/dev/null || true)"
  if [[ -n "$current" && "$current" != "$THEME_FILE" ]]; then
    printf '%s\n' "$current" > "$STATE_FILE"
    chmod 0600 "$STATE_FILE"
  fi
fi

update-alternatives --install "$PLYMOUTH_LINK" default.plymouth "$THEME_FILE" 200
update-alternatives --set default.plymouth "$THEME_FILE"
update-initramfs -u

echo "yaPDP Plymouth theme installed and selected."
echo "Previous theme (for rollback): $(cat "$STATE_FILE" 2>/dev/null || echo 'not recorded')"
echo "Preview with: sudo plymouthd --no-daemon --debug --tty=$(tty)"
echo "Then, from another terminal: sudo plymouth show-splash"
echo "Stop the preview with: sudo plymouth quit"
