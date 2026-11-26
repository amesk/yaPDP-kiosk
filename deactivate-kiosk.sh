#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo: sudo $0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RESTORE="$SCRIPT_DIR/scripts/restore-system-state.py"
if [[ ! -f "$RESTORE" ]]; then
  RESTORE="/usr/local/lib/yapdp-kiosk/restore-system-state.py"
fi
if [[ ! -f "$RESTORE" ]]; then
  echo "Restore helper not found; refusing to change the machine." >&2
  exit 1
fi

STATE="/var/lib/yapdp-kiosk/original-state"
if [[ ! -s "$STATE/manifest.json" ]]; then
  echo "No valid installation backup at $STATE; refusing to guess the original system state." >&2
  exit 1
fi

echo "Stopping yaPDP kiosk components..."
systemctl disable --now yapdp-kiosk-guard.service 2>/dev/null || true
/usr/local/sbin/yapdp-vt-switch-lock unlock >/dev/null 2>&1 || true

# Restore the captured nginx site symlink/configuration, but do not stop the
# whole nginx service: the host may serve unrelated local sites as well.
python3 "$RESTORE"
systemctl daemon-reload
sysctl --system >/dev/null 2>&1 || true

GRUB_UPDATE_OK=1
if command -v update-grub >/dev/null 2>&1; then
  if ! update-grub; then
    GRUB_UPDATE_OK=0
  fi
fi

# Restore service enablement and runtime state. Do not restart GDM here:
# doing so would terminate the administrator's current service-mode session.
# Its original configuration takes effect on the next reboot.
python3 - "$STATE/manifest.json" <<'PY'
import json
import subprocess
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    data = json.load(stream)

for name, state in data["services"].items():
    enabled = state["enabled"]
    if enabled == "enabled":
        subprocess.run(["systemctl", "enable", name], check=False)
    elif enabled == "masked":
        subprocess.run(["systemctl", "mask", name], check=False)
    elif enabled in ("disabled", "not-found"):
        subprocess.run(["systemctl", "disable", name], check=False)

    # Keep the current GDM session alive. The restored GDM settings will be
    # read on the next boot, which is the intended point of mode transition.
    if name == "gdm3.service":
        continue

    active = state["active"]
    if active == "active":
        subprocess.run(["systemctl", "start", name], check=False)
        if name == "nginx.service":
            subprocess.run(["systemctl", "reload", name], check=False)
    elif active in ("inactive", "failed"):
        subprocess.run(["systemctl", "stop", name], check=False)
PY

echo
echo "yaPDP kiosk deactivated. Original configuration has been restored."
echo "The yaPDP-kiosk nginx site has been restored to its pre-install state."
echo "Unrelated nginx sites and the nginx service itself were not deliberately disabled."
echo "No repositories, disk images, saved states, packages, or user data were deleted."
echo "The kiosk account and its home directory were retained."
echo "Review the GRUB menu and nginx status, then reboot manually when convenient."

if [[ "$GRUB_UPDATE_OK" -ne 1 ]]; then
  echo "WARNING: update-grub failed. The configuration files were restored, but inspect GRUB before rebooting." >&2
  exit 1
fi
