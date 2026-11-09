#!/usr/bin/env bash
set -euo pipefail

# First-time deployment bootstrap for a dedicated Ubuntu 24.04 museum kiosk.
# Download, inspect, then run with sudo:
#   sudo bash instant-setup.sh
#
# Refs are deliberately pinned. Update them only after validating a new release.

# Repository URLs and refs are editable in the dialog or overridable through the environment.
YAPDP_REPO_URL="${YAPDP_REPO_URL:-https://github.com/amesk/yaPDP.git}"
KIOSK_REPO_URL="${KIOSK_REPO_URL:-https://github.com/amesk/yaPDP-kiosk.git}"
# Keep known-good revisions pinned by default. Forks can override the refs too.
YAPDP_REF="${YAPDP_REF:-6d949d18d5b335bc69effc0dda8b80bb39afb015}"
KIOSK_REF="${KIOSK_REF:-abc911a2b77b87915f255b0e19600c1c0b97b7c5}"
readonly INSTALL_ROOT="/opt/yapdp-exhibit"

KIOSK_USER="${KIOSK_USER:-yapdp-kiosk}"
IDLE_TIMEOUT="${IDLE_TIMEOUT:-180}"
IDLE_REDIRECT="${IDLE_REDIRECT:-/}"
INSTALL_PLYMOUTH="${INSTALL_PLYMOUTH:-0}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

# Keep the console clean; all command output is retained in a per-run log.
LOG_DIR="/var/log/yapdp-kiosk"
install -d -m 0750 "$LOG_DIR"
LOG_FILE="$LOG_DIR/bootstrap-$(date +%Y%m%d-%H%M%S-%N).log"
export YAPDP_INSTALL_LOG="$LOG_FILE"
exec > >(tee -a "$LOG_FILE" >/dev/null) 2>&1
echo "===== yaPDP kiosk bootstrap started: $(date --iso-8601=seconds) ====="
echo "Log file: $LOG_FILE"

show_phase() {
  local percent="$1" title="$2"
  local width=32 filled empty bar
  filled=$((percent * width / 100))
  empty=$((width - filled))
  printf -v bar '%*s' "$filled" ''
  bar="${bar// /#}"
  printf -v bar '%-*s' "$width" "$bar"
  printf '\033[H\033[2J\033[3J' > /dev/tty 2>/dev/null || true
  {
    printf '\n  yaPDP MUSEUM KIOSK SETUP\n\n'
    printf '  %s\n\n' "$title"
    printf '  [%s] %3d%%\n\n' "$bar" "$percent"
    printf '  Detailed output is being saved to:\n  %s\n' "$LOG_FILE"
  } > /dev/tty 2>/dev/null || echo "[$percent%] $title"
}

trap 'status=$?; line=$LINENO; command=$BASH_COMMAND; echo "ERROR: exit $status at line $line: $command"; echo "Installation log: $LOG_FILE"; if [[ -r /dev/tty && -w /dev/tty ]] && command -v dialog >/dev/null 2>&1; then dialog --title "yaPDP Kiosk Setup — Error" --msgbox "Installation failed (exit code $status).\n\nDetailed log:\n$LOG_FILE" 10 78 </dev/tty >/dev/tty 2>&1 || true; else echo "Installation failed. Log: $LOG_FILE" >&2; fi' ERR

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

# The welcome screen and settings wizard both use dialog. Install it
# before showing either screen; package-manager output remains in the log.
if [[ "${NONINTERACTIVE:-0}" != "1" && -r /dev/tty && -w /dev/tty ]] &&
   ! command -v dialog >/dev/null 2>&1; then
  {
    printf '\n  yaPDP MUSEUM KIOSK SETUP\n\n'
    printf '  Preparing the installation wizard...\n\n'
    printf '  Ubuntu may be completing background updates. The installer\n'
    printf '  will wait until the package manager is available, then\n'
    printf '  prepare the setup screens.\n\n'
    printf '  Please wait; no action is required.\n\n'
    printf '  Detailed installation log:\n  %s\n' "$LOG_FILE"
  } > /dev/tty

  if ! { apt-get -o DPkg::Lock::Timeout=300 update && DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y dialog; }; then
    {
      printf '\n  ERROR: Could not install the dialog interface.\n'
      printf '  The installer cannot continue interactively.\n\n'
      printf '  Please inspect the log:\n  %s\n' "$LOG_FILE"
      printf '\n  Press Enter to exit. '
    } > /dev/tty
    IFS= read -r _ < /dev/tty || true
    exit 1
  fi
fi

show_welcome() {
  [[ "${NONINTERACTIVE:-0}" == "1" || ! -r /dev/tty || ! -w /dev/tty ]] && return 0
  dialog --title "yaPDP Museum Kiosk Setup" --no-collapse --msgbox \
    "This installer will prepare this Ubuntu 24.04 computer as a dedicated, full-screen museum exhibit.\n\nIt will configure:\n  • Google Chrome and the GNOME Kiosk session\n  • yaPDP and the kiosk presentation files\n  • A local web server and automatic kiosk login\n\nExisting files under /opt/yapdp-exhibit will not be overwritten.\n\nDetailed installation output is saved to:\n$LOG_FILE\n\nSelect OK to configure the installation, or Cancel to abort." \
    20 78 </dev/tty >/dev/tty 2>&1
}

show_welcome

# Collect kiosk-specific settings before downloading or changing the system.
# NONINTERACTIVE=1 skips the UI and uses environment variables/defaults.
if [[ "${NONINTERACTIVE:-0}" != "1" && -r /dev/tty && -w /dev/tty ]]; then
  ask_setting() {
    local variable="$1"
    local prompt="$2"
    local current="$3"
    local answer
    if ! answer="$(dialog --stdout --title "yaPDP Museum Kiosk Setup" \
      --inputbox "$prompt" 10 78 "$current" </dev/tty 2>/dev/tty)"; then
      clear >/dev/tty 2>&1 || true
      echo "Installation cancelled." >&2
      exit 1
    fi
    printf -v "$variable" '%s' "$answer"
  }

  ask_setting YAPDP_REPO_URL "Git repository URL for yaPDP:" "$YAPDP_REPO_URL"
  ask_setting KIOSK_REPO_URL "Git repository URL for yaPDP-kiosk:" "$KIOSK_REPO_URL"
  ask_setting YAPDP_REF "Git ref for yaPDP (branch, tag, or commit SHA):" "$YAPDP_REF"
  ask_setting KIOSK_REF "Git ref for yaPDP-kiosk (branch, tag, or commit SHA):" "$KIOSK_REF"
  ask_setting IDLE_TIMEOUT "Visitor inactivity timeout in seconds (0 disables automatic return):" "$IDLE_TIMEOUT"
  ask_setting IDLE_REDIRECT "URL to open after inactivity (HTTP(S) or relative URL):" "$IDLE_REDIRECT"

  PLYMOUTH_DEFAULT=(--defaultno)
  if [[ "$INSTALL_PLYMOUTH" == "1" ]]; then
    PLYMOUTH_DEFAULT=()
  fi
  if dialog "${PLYMOUTH_DEFAULT[@]}" --title "Optional boot splash" --yesno \
    "Install the yaPDP PDP-11/70 Plymouth boot splash?\n\nThis changes the system boot theme and rebuilds initramfs.\nYou can also install it later from plymouth/install.sh." 11 78 </dev/tty >/dev/tty 2>&1; then
    INSTALL_PLYMOUTH=1
  else
    dialog_status=$?
    if [[ "$dialog_status" -ne 1 ]]; then
      clear >/dev/tty 2>&1 || true
      echo "Installation cancelled." >&2
      exit 1
    fi
    INSTALL_PLYMOUTH=0
  fi

  if ! dialog --title "Confirm kiosk installation" --yesno \
    "yaPDP repository:\n$YAPDP_REPO_URL\nRef: $YAPDP_REF\n\nyaPDP-kiosk repository:\n$KIOSK_REPO_URL\nRef: $KIOSK_REF\n\nInactivity timeout: $IDLE_TIMEOUT seconds\nReturn URL: $IDLE_REDIRECT\nPlymouth boot splash: $([[ "$INSTALL_PLYMOUTH" == "1" ]] && echo "Yes" || echo "No")\n\nContinue with these settings?" 22 82 </dev/tty >/dev/tty 2>&1; then
    clear >/dev/tty 2>&1 || true
    echo "Installation cancelled." >&2
    exit 1
  fi
  clear >/dev/tty 2>&1 || true
fi

show_phase 0 "Settings confirmed. Preparing the installation..."

if [[ "$INSTALL_PLYMOUTH" != "0" && "$INSTALL_PLYMOUTH" != "1" ]]; then
  echo "INSTALL_PLYMOUTH must be 0 (disabled) or 1 (enabled)." >&2
  exit 1
fi
if [[ -z "$YAPDP_REPO_URL" || "$YAPDP_REPO_URL" =~ [[:space:]] ||
      -z "$KIOSK_REPO_URL" || "$KIOSK_REPO_URL" =~ [[:space:]] ]]; then
  echo "Repository URLs must be non-empty and contain no whitespace." >&2
  exit 1
fi
if [[ -z "$YAPDP_REF" || "$YAPDP_REF" =~ [[:space:]] ||
      -z "$KIOSK_REF" || "$KIOSK_REF" =~ [[:space:]] ]]; then
  echo "Repository refs must be non-empty and contain no whitespace." >&2
  exit 1
fi
if [[ ! "$IDLE_TIMEOUT" =~ ^[0-9]+$ ]] || (( IDLE_TIMEOUT > 2147483 )); then
  echo "IDLE_TIMEOUT must be an integer from 0 to 2147483 seconds." >&2
  exit 1
fi
python3 - "$IDLE_TIMEOUT" "$IDLE_REDIRECT" <<'PY'
from urllib.parse import urlsplit
import sys

timeout = int(sys.argv[1])
redirect = sys.argv[2].strip()
if timeout == 0:
    raise SystemExit(0)
if not redirect or any(ord(char) < 32 for char in redirect):
    raise SystemExit("IDLE_REDIRECT must be a non-empty URL without control characters.")
parsed = urlsplit(redirect)
if parsed.scheme and parsed.scheme.lower() not in ("http", "https"):
    raise SystemExit("IDLE_REDIRECT must use HTTP(S), or be a relative URL.")
if parsed.scheme.lower() in ("http", "https") and not parsed.netloc:
    raise SystemExit("IDLE_REDIRECT is missing a host.")
PY

STAGE_DIR="$(mktemp -d /opt/.yapdp-exhibit.XXXXXX)"
cleanup() { rm -rf "$STAGE_DIR"; }
trap cleanup EXIT

show_phase 10 "Checking and installing Google Chrome..."

# Prefer the official Google Chrome Stable build for a predictable exhibit
# runtime. If it is absent, install Google's signed Debian package. Chromium
# may already be present, but is not silently substituted for Chrome.
if ! command -v google-chrome-stable >/dev/null 2>&1 \
   && ! command -v google-chrome >/dev/null 2>&1; then
  ARCH="$(dpkg --print-architecture)"
  if [[ "$ARCH" != "amd64" ]]; then
    echo "Google Chrome Stable is supported here on amd64 only (detected: $ARCH)." >&2
    echo "Install a supported Chrome build manually before continuing." >&2
    exit 1
  fi

  echo "Google Chrome Stable is not installed; installing the official Google .deb package."
  apt-get -o DPkg::Lock::Timeout=300 update
  DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y ca-certificates curl

  CHROME_DEB="$STAGE_DIR/google-chrome-stable_current_amd64.deb"
  curl --fail --location --silent --show-error \
    --retry 3 --retry-delay 2 \
    --output "$CHROME_DEB" \
    "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

  if [[ "$(dpkg-deb -f "$CHROME_DEB" Package 2>/dev/null || true)" != "google-chrome-stable" ]]; then
    echo "Downloaded file is not the expected google-chrome-stable Debian package." >&2
    exit 1
  fi

  DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y "$CHROME_DEB"
fi

CHROME_BIN="$(command -v google-chrome-stable || command -v google-chrome || true)"
if [[ -z "$CHROME_BIN" ]]; then
  echo "Google Chrome installation did not provide the expected executable." >&2
  exit 1
fi
if ! "$CHROME_BIN" --version; then
  echo "Google Chrome is installed but failed its version check." >&2
  exit 1
fi

show_phase 20 "Google Chrome is ready. Preparing repository download..."

if ! command -v git >/dev/null 2>&1; then
  apt-get -o DPkg::Lock::Timeout=300 update
  DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y git ca-certificates
fi

fetch_pinned_repo() {
  local url="$1"
  local ref="$2"
  local destination="$3"
  git init -q "$destination"
  git -C "$destination" remote add origin "$url"
  git -C "$destination" fetch --quiet --depth 1 origin "$ref"
  git -C "$destination" checkout --quiet --detach FETCH_HEAD
}

show_phase 30 "Downloading pinned yaPDP and kiosk repositories..."
fetch_pinned_repo "$KIOSK_REPO_URL" "$KIOSK_REF" "$STAGE_DIR/yaPDP-kiosk"
fetch_pinned_repo "$YAPDP_REPO_URL" "$YAPDP_REF" "$STAGE_DIR/yaPDP"

# Keep the installed tree root-owned; the kiosk user only needs read access.
chown -R root:root "$STAGE_DIR"
find "$STAGE_DIR" -type d -exec chmod 0755 {} +
find "$STAGE_DIR" -type f -exec chmod a+r {} +

# Publish the complete tree only after both pinned checkouts succeeded.
if [[ -e "$INSTALL_ROOT" ]]; then
  echo "$INSTALL_ROOT appeared during setup; refusing to overwrite it." >&2
  exit 1
fi
mv "$STAGE_DIR" "$INSTALL_ROOT"
trap - EXIT

show_phase 50 "Repositories downloaded. Preparing kiosk installation..."
echo "Repositories installed at $INSTALL_ROOT."
show_phase 55 "Installing GNOME Kiosk, nginx and automatic login..."
echo "Starting the Ubuntu 24.04 kiosk installer..."
YAPDP_PROGRESS_BASE=55 YAPDP_PROGRESS_SPAN=40 \
  KIOSK_USER="$KIOSK_USER" IDLE_TIMEOUT="$IDLE_TIMEOUT" IDLE_REDIRECT="$IDLE_REDIRECT" \
  bash "$INSTALL_ROOT/yaPDP-kiosk/install/ubuntu-24.04.sh"

if [[ "$INSTALL_PLYMOUTH" == "1" ]]; then
  show_phase 97 "Installing the optional Plymouth boot splash..."
  echo
  echo "Installing the optional yaPDP Plymouth boot splash..."
  if ! bash "$INSTALL_ROOT/yaPDP-kiosk/plymouth/install.sh"; then
    echo "WARNING: Plymouth setup did not complete. The kiosk itself is installed; check the selected theme and initramfs before rebooting." >&2
    echo "You can inspect the error and retry later with:" >&2
    echo "  sudo bash $INSTALL_ROOT/yaPDP-kiosk/plymouth/install.sh" >&2
  fi
fi

show_phase 100 "Installation completed."
echo
echo "Initial setup is complete. Reboot to enter the kiosk account automatically."
echo "Detailed installation log: $LOG_FILE"
echo "Keep a separate administrator account for maintenance."
