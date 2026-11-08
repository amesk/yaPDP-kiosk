#!/usr/bin/env bash
set -euo pipefail

# First-time deployment bootstrap for a dedicated Ubuntu 24.04 museum kiosk.
# Download, inspect, then run with sudo:
#   sudo bash instant-setup.sh
#
# Refs are deliberately pinned. Update them only after validating a new release.

readonly YAPDP_REPO="https://github.com/amesk/yaPDP.git"
readonly KIOSK_REPO="https://github.com/amesk/yaPDP-kiosk.git"
readonly YAPDP_REF="6d949d18d5b335bc69effc0dda8b80bb39afb015" # idle redirect support
readonly KIOSK_REF="5b5edc580479a97818ab8aed9427abe1985c11fd" # installer + GDM auto-login
readonly INSTALL_ROOT="/opt/yapdp-exhibit"

KIOSK_USER="${KIOSK_USER:-yapdp-kiosk}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "Cannot identify the operating system." >&2
  exit 1
fi
. /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
  echo "This bootstrap supports Ubuntu 24.04 only." >&2
  exit 1
fi

if [[ -e "$INSTALL_ROOT" ]]; then
  echo "$INSTALL_ROOT already exists; refusing to overwrite an existing installation." >&2
  echo "Move it aside or remove it deliberately before a fresh installation." >&2
  exit 1
fi

if ! dpkg-query -W -f='${Status}' ubuntu-desktop 2>/dev/null | grep -q "install ok installed" \
   && ! dpkg-query -W -f='${Status}' ubuntu-desktop-minimal 2>/dev/null | grep -q "install ok installed"; then
  echo "Install Ubuntu 24.04 Desktop first; this script does not install or repartition an operating system." >&2
  exit 1
fi

if ! dpkg-query -W -f='${Status}' gdm3 2>/dev/null | grep -q "install ok installed"; then
  echo "GNOME Display Manager (gdm3) is required. Install Ubuntu Desktop with its default display manager first." >&2
  exit 1
fi

if ! command -v google-chrome-stable >/dev/null 2>&1 \
   && ! command -v google-chrome >/dev/null 2>&1 \
   && ! command -v chromium >/dev/null 2>&1 \
   && ! command -v chromium-browser >/dev/null 2>&1; then
  echo "Install Google Chrome or Chromium before running this bootstrap." >&2
  echo "The browser is intentionally not downloaded or installed by this script." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y git ca-certificates
fi

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

fetch_pinned_repo() {
  local url="$1"
  local ref="$2"
  local destination="$3"
  git init -q "$destination"
  git -C "$destination" remote add origin "$url"
  git -C "$destination" fetch --quiet --depth 1 origin "$ref"
  git -C "$destination" checkout --quiet --detach FETCH_HEAD
}

mkdir -p "$INSTALL_ROOT"
fetch_pinned_repo "$KIOSK_REPO" "$KIOSK_REF" "$INSTALL_ROOT/yaPDP-kiosk"
fetch_pinned_repo "$YAPDP_REPO" "$YAPDP_REF" "$INSTALL_ROOT/yaPDP"

# Keep the installed tree root-owned; the kiosk user only needs read access.
chown -R root:root "$INSTALL_ROOT"
find "$INSTALL_ROOT" -type d -exec chmod 0755 {} +
find "$INSTALL_ROOT" -type f -exec chmod a+r {} +

echo "Repositories installed at $INSTALL_ROOT."
echo "Starting the Ubuntu 24.04 kiosk installer..."
KIOSK_USER="$KIOSK_USER" bash "$INSTALL_ROOT/yaPDP-kiosk/install/ubuntu-24.04.sh"

echo
echo "Initial setup is complete. Reboot to enter the kiosk account automatically."
echo "Keep a separate administrator account for maintenance."
