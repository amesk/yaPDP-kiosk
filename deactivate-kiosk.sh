#!/usr/bin/env bash
set -euo pipefail
if [[ "$EUID" -ne 0 ]]; then echo "Run with sudo: sudo $0" >&2; exit 1; fi
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RESTORE="$SCRIPT_DIR/scripts/restore-system-state.py"
if [[ ! -f "$RESTORE" ]]; then RESTORE="/usr/local/lib/yapdp-kiosk/restore-system-state.py"; fi
if [[ ! -f "$RESTORE" ]]; then
  echo "Restore helper not found; refusing to change the machine." >&2
  exit 1
fi
STATE="/var/lib/yapdp-kiosk/original-state"
[[ -s "$STATE/manifest.json" ]] || { echo "No valid installation backup at $STATE; refusing to guess the original system state." >&2; exit 1; }

echo "Stopping yaPDP kiosk components..."
systemctl disable --now yapdp-kiosk-guard.service 2>/dev/null || true
/usr/local/sbin/yapdp-vt-switch-lock unlock >/dev/null 2>&1 || true
systemctl stop nginx.service 2>/dev/null || true
# Restore all captured files, including the original nginx site symlink and GRUB generators.
python3 "$RESTORE"
systemctl daemon-reload
sysctl --system >/dev/null 2>&1 || true
GRUB_UPDATE_OK=1
if command -v update-grub >/dev/null 2>&1; then
  if ! update-grub; then GRUB_UPDATE_OK=0; fi
fi
# Restore the services' pre-install enable/active state.
python3 - "$STATE/manifest.json" <<'PY'
import json, subprocess, sys
data=json.load(open(sys.argv[1]))
for name,state in data["services"].items():
    enabled=state["enabled"]
    if enabled == "enabled":
        subprocess.run(["systemctl","enable",name],check=False)
    elif enabled in ("disabled","masked","static","indirect","generated","transient","not-found"):
        if enabled == "masked": subprocess.run(["systemctl","mask",name],check=False)
        elif enabled in ("disabled","not-found"): subprocess.run(["systemctl","disable",name],check=False)
    if state["active"] == "active":
        subprocess.run(["systemctl","restart" if name == "gdm3.service" else "start",name],check=False)
    elif state["active"] in ("inactive","failed"): subprocess.run(["systemctl","stop",name],check=False)
PY
echo
echo "yaPDP kiosk deactivated. Original configuration has been restored."
echo "No repositories, disk images, saved states, or user data were deleted."
echo "The kiosk account and its home directory were retained; no user data was removed."
echo "Review the GRUB menu and nginx status, then reboot manually when convenient."
if [[ "$GRUB_UPDATE_OK" -ne 1 ]]; then
  echo "WARNING: update-grub failed. The configuration files were restored, but inspect GRUB before rebooting." >&2
  exit 1
fi
