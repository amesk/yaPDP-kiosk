#!/usr/bin/env bash
# TEMPORARY migration helper for legacy yaPDP-kiosk installations that predate
# /var/lib/yapdp-kiosk/original-state. Remove this file after legacy machines
# have been migrated and the new snapshot-based rollback has been validated.
#
# This restores known legacy yaPDP overrides to ordinary Ubuntu behaviour.
# Without a pre-install snapshot it cannot reconstruct arbitrary prior custom
# settings. It therefore changes only settings identifiable as yaPDP-managed,
# keeps packages/accounts/data, and makes a root-only backup before modifying.

set -Eeuo pipefail

KIOSK_USER="${KIOSK_USER:-yapdp-kiosk}"
ASSUME_YES=0

usage() {
  cat <<'USAGE'
Usage:
  sudo bash legacy-deactivate-kiosk.sh [--user USER] [--yes]

Options:
  --user USER  Kiosk account name (default: yapdp-kiosk)
  --yes        Do not ask for interactive confirmation

This helper is only for installations created before the original-state
snapshot mechanism. It must not be used on an installation that has a
/var/lib/yapdp-kiosk/original-state/manifest.json snapshot.
USAGE
}

while (($#)); do
  case "$1" in
    --user)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      KIOSK_USER="$2"
      shift 2
      ;;
    --yes|-y)
      ASSUME_YES=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

if [[ ! "$KIOSK_USER" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
  echo "Invalid kiosk username: $KIOSK_USER" >&2
  exit 2
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  echo "Cannot identify the operating system." >&2
  exit 1
fi
if [[ "${ID:-}" != ubuntu || "${VERSION_ID:-}" != 24.04 ]]; then
  echo "This legacy rollback is intended for Ubuntu 24.04 only." >&2
  exit 1
fi

STATE_DIR="/var/lib/yapdp-kiosk/original-state"
if [[ -s "$STATE_DIR/manifest.json" ]]; then
  echo "A snapshot-based installation is present at $STATE_DIR." >&2
  echo "Use: sudo deactivate-yapdp-kiosk" >&2
  echo "Refusing to run the legacy rollback." >&2
  exit 1
fi

# This helper does not know how to remove the newer GRUB-managed service-mode
# configuration. Refuse rather than leave a partly deactivated boot setup.
for grub_file in /etc/grub.d/01_yapdp_disable_stock \
                 /etc/grub.d/08_yapdp_kiosk_auth \
                 /etc/grub.d/09_yapdp_kiosk; do
  if [[ -e "$grub_file" ]]; then
    echo "Newer yaPDP GRUB configuration found: $grub_file" >&2
    echo "Use the snapshot-based deactivate-yapdp-kiosk command instead." >&2
    exit 1
  fi
done

USER_HOME=""
if getent passwd "$KIOSK_USER" >/dev/null 2>&1; then
  USER_HOME="$(getent passwd "$KIOSK_USER" | cut -d: -f6)"
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
NGINX_AVAILABLE="/etc/nginx/sites-available/yapdp-kiosk"
NGINX_ENABLED="/etc/nginx/sites-enabled/yapdp-kiosk"
RELEASE_CONFIG="/etc/update-manager/release-upgrades"
RELEASE_BACKUP="/etc/update-manager/release-upgrades.yapdp-kiosk.bak"
GDM_CONFIG="/etc/gdm3/custom.conf"
LOGIND_DROPIN="/etc/systemd/logind.conf.d/90-yapdp-kiosk.conf"
SYSCTL_DROPIN="/etc/sysctl.d/90-yapdp-kiosk.conf"
PLYMOUTH_STATE="/etc/default/yapdp-plymouth.previous"
PLYMOUTH_THEME="/usr/share/plymouth/themes/yapdp-plymouth/yapdp-plymouth.plymouth"

echo "Legacy yaPDP-kiosk deactivation"
echo "  Kiosk account: $KIOSK_USER"
echo "  Snapshot-based rollback: not present"
echo
echo "Known yaPDP settings will be disabled. Packages, repositories, the kiosk"
echo "account and its home directory will be retained. Original arbitrary GDM,"
echo "nginx and GNOME settings cannot be reconstructed without an old backup."
echo "A root-only backup of the current state will be created before changes."

if (( ! ASSUME_YES )); then
  if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
    echo "No interactive terminal. Re-run with --yes after reviewing the script." >&2
    exit 2
  fi
  printf 'Type DEACTIVATE to continue: ' >/dev/tty
  IFS= read -r answer </dev/tty
  [[ "$answer" == DEACTIVATE ]] || { echo "Cancelled."; exit 1; }
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="/root/yapdp-kiosk-legacy-deactivation-$STAMP"
install -d -o root -g root -m 0700 "$BACKUP_DIR"

backup_paths=(
  "$GDM_CONFIG"
  "$NGINX_AVAILABLE"
  "$NGINX_ENABLED"
  "$RELEASE_CONFIG"
  "$RELEASE_BACKUP"
  "$LOGIND_DROPIN"
  "$SYSCTL_DROPIN"
  "/etc/systemd/system/ctrl-alt-del.target"
  "/etc/xdg/autostart/yapdp-kiosk.desktop"
  "/etc/default/yapdp-plymouth.previous"
  "/usr/share/plymouth/themes/default.plymouth"
  "/var/lib/dpkg/alternatives/default.plymouth"
)
if [[ -n "$USER_HOME" ]]; then
  backup_paths+=(
    "/var/lib/AccountsService/users/$KIOSK_USER"
    "$USER_HOME/.local/bin/gnome-kiosk-script"
    "$USER_HOME/.config/autostart/yapdp-kiosk.desktop"
    "$USER_HOME/.config/dconf/user"
  )
fi

{
  echo "Temporary backup of the system immediately before legacy deactivation."
  echo "This is NOT the original pre-kiosk Ubuntu state."
  echo "Created: $(date -Is)"
  echo "Kiosk user: $KIOSK_USER"
  echo "Backup directory: $BACKUP_DIR"
} > "$BACKUP_DIR/README.txt"
chmod 0600 "$BACKUP_DIR/README.txt"

for path in "${backup_paths[@]}"; do
  if [[ -e "$path" || -L "$path" ]]; then
    destination="$BACKUP_DIR$path"
    mkdir -p "$(dirname -- "$destination")"
    cp -a -- "$path" "$destination"
  fi
done
chmod -R go-rwx "$BACKUP_DIR"

echo "Current state backed up to: $BACKUP_DIR"
echo

# Restore the release-upgrade policy from the exact backup created by the
# legacy installer. If it does not exist, leave the file alone: that means the
# installer either made no change or the original value is unknowable.
if [[ -f "$RELEASE_BACKUP" && -f "$RELEASE_CONFIG" ]]; then
  cp -a -- "$RELEASE_BACKUP" "$RELEASE_CONFIG"
  echo "[restored] Ubuntu release-upgrades configuration from its installer backup."
else
  echo "[kept] Release-upgrades configuration (no yaPDP backup was found)."
fi

# Disable GDM auto-login only when the configured account is the kiosk user.
# Other users' auto-login configuration is deliberately left untouched.
if [[ -f "$GDM_CONFIG" ]]; then
  python3 - "$GDM_CONFIG" "$KIOSK_USER" <<'PY'
from pathlib import Path
import re
import sys
path = Path(sys.argv[1])
user = sys.argv[2]
text = path.read_text(encoding="utf-8")
lines = text.splitlines()
section = None
target = False
for line in lines:
    if re.match(r"^\s*\[[^]]+\]", line):
        section = line.strip().lower()
    if section == "[daemon]":
        match = re.match(r'^\s*AutomaticLogin\s*=\s*"?([^"#\s]+)"?', line)
        if match and match.group(1) == user:
            target = True
            break
if target:
    section_start = next(i for i, line in enumerate(lines)
                         if re.match(r"^\s*\[daemon\]", line, re.I))
    section_end = next((i for i in range(section_start + 1, len(lines))
                        if re.match(r"^\s*\[[^]]+\]", lines[i])), len(lines))
    seen = False
    for i in range(section_start + 1, section_end):
        if re.match(r"^\s*#?\s*AutomaticLoginEnable\s*=", lines[i], re.I):
            if not seen:
                lines[i] = "AutomaticLoginEnable=False"
                seen = True
            else:
                lines[i] = "# Disabled duplicate AutomaticLoginEnable by legacy yaPDP rollback"
    if not seen:
        lines.insert(section_end, "AutomaticLoginEnable=False")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[disabled] GDM automatic login for {user}.")
else:
    print(f"[kept] GDM auto-login does not target {user}; no GDM change made.")
PY
else
  echo "[skipped] GDM configuration not found."
fi

# Remove only the kiosk session selectors written by the old installer.
if [[ -n "$USER_HOME" && -f "/var/lib/AccountsService/users/$KIOSK_USER" ]]; then
  python3 - "/var/lib/AccountsService/users/$KIOSK_USER" <<'PY'
from pathlib import Path
import re, sys
path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
keys = {"Session": "gnome-kiosk-script-wayland",
        "SessionType": "wayland",
        "XSession": "gnome-kiosk-script-xorg"}
out, removed = [], []
for line in lines:
    match = re.match(r"^\s*(Session|SessionType|XSession)\s*=\s*(.*?)\s*$", line)
    if match and match.group(1) in keys and match.group(2) == keys[match.group(1)]:
        removed.append(match.group(1))
    else:
        out.append(line)
if removed:
    path.write_text("\n".join(out) + "\n", encoding="utf-8")
    print("[cleaned] AccountsService kiosk session selection: " + ", ".join(sorted(set(removed))))
else:
    print("[kept] No matching kiosk session selection in AccountsService.")
PY
fi

# The old installer wrote one GNOME Kiosk launcher. Remove it only when its
# content still clearly points to start-kiosk.sh; do not delete user scripts.
if [[ -n "$USER_HOME" && -f "$USER_HOME/.local/bin/gnome-kiosk-script" ]]; then
  if grep -q 'start-kiosk\.sh' "$USER_HOME/.local/bin/gnome-kiosk-script"; then
    rm -f -- "$USER_HOME/.local/bin/gnome-kiosk-script"
    echo "[removed] Generated GNOME Kiosk session launcher."
  else
    echo "[kept] Kiosk launcher path exists but does not match the legacy yaPDP launcher."
  fi
fi

# Reset only the dconf keys changed by the old install/start script. This is
# limited to the kiosk account; no administrator's GNOME profile is touched.
if [[ -n "$USER_HOME" ]]; then
  if command -v dbus-run-session >/dev/null 2>&1 && command -v gsettings >/dev/null 2>&1; then
    if runuser -u "$KIOSK_USER" -- env HOME="$USER_HOME" dbus-run-session -- bash -s <<'RESET_GNOME'
set -u
reset_keys() {
  local schema="$1"; shift
  local available
  available="$(gsettings list-keys "$schema" 2>/dev/null || true)"
  for key in "$@"; do
    if printf '%s\n' "$available" | grep -Fxq "$key"; then
      gsettings reset "$schema" "$key" 2>/dev/null || true
    fi
  done
}
reset_keys org.gnome.desktop.background \
  color-shading-type primary-color secondary-color picture-uri picture-uri-dark
reset_keys org.gnome.desktop.screensaver lock-enabled idle-activation-enabled
reset_keys org.gnome.desktop.session idle-delay
reset_keys org.gnome.desktop.wm.keybindings \
  close minimize maximize unmaximize switch-applications \
  switch-applications-backward switch-windows switch-windows-backward \
  switch-group switch-group-backward switch-to-workspace-left \
  switch-to-workspace-right switch-to-workspace-up switch-to-workspace-down \
  move-to-workspace-left move-to-workspace-right move-to-workspace-up \
  move-to-workspace-down panel-run-dialog show-desktop
reset_keys org.gnome.mutter.keybindings \
  switch-to-session-1 switch-to-session-2 switch-to-session-3 \
  switch-to-session-4 switch-to-session-5 switch-to-session-6 \
  switch-to-session-7 switch-to-session-8 switch-to-session-9 \
  switch-to-session-10 switch-to-session-11 switch-to-session-12
reset_keys org.gnome.shell.keybindings \
  toggle-overview toggle-application-view toggle-message-tray \
  show-screenshot-ui show-screen-recording-ui open-application-menu \
  lock-screen logout power-off switch-to-application-1 \
  switch-to-application-2 switch-to-application-3 switch-to-application-4 \
  switch-to-application-5 switch-to-application-6 switch-to-application-7 \
  switch-to-application-8 switch-to-application-9
RESET_GNOME
    then
      echo "[reset] Known kiosk-specific GNOME settings for $KIOSK_USER."
    else
      echo "[warning] Could not reset the kiosk user's GNOME settings; reset them manually or leave this account unused."
    fi
  else
    echo "[warning] dbus-run-session/gsettings unavailable; kiosk user's GNOME settings were not reset."
  fi
fi

# Remove legacy autostart entries only if their contents identify yaPDP.
for autostart in /etc/xdg/autostart/yapdp-kiosk.desktop \
                 "${USER_HOME:+$USER_HOME/.config/autostart/yapdp-kiosk.desktop}"; do
  [[ -n "$autostart" && -f "$autostart" ]] || continue
  if grep -Eqi 'yapdp|start-kiosk\.sh' "$autostart"; then
    rm -f -- "$autostart"
    echo "[removed] Legacy yaPDP autostart entry: $autostart"
  fi
done

# Remove the legacy logind/sysctl overrides only when they carry the installer
# marker. Reload sysctl settings after removing its drop-in. logind changes are
# intentionally left for the next reboot to avoid disrupting the admin session.
if [[ -f "$LOGIND_DROPIN" ]] && grep -q 'Managed by the yaPDP kiosk installer' "$LOGIND_DROPIN"; then
  rm -f -- "$LOGIND_DROPIN"
  echo "[removed] yaPDP logind hardening drop-in (effective after reboot)."
else
  echo "[kept] logind drop-in absent or not identifiable as yaPDP-managed."
fi

if [[ -f "$SYSCTL_DROPIN" ]] && grep -q 'Managed by the yaPDP kiosk installer' "$SYSCTL_DROPIN"; then
  rm -f -- "$SYSCTL_DROPIN"
  if command -v sysctl >/dev/null 2>&1; then
    sysctl --system >/dev/null
  fi
  echo "[removed] yaPDP SysRq sysctl override; remaining sysctl configuration reloaded."
else
  echo "[kept] sysctl drop-in absent or not identifiable as yaPDP-managed."
fi

# The old installer explicitly masked ctrl-alt-del.target. Remove only the
# standard system-wide /dev/null mask created by systemctl mask.
CAD_MASK="/etc/systemd/system/ctrl-alt-del.target"
if [[ -L "$CAD_MASK" && "$(readlink "$CAD_MASK")" == /dev/null ]]; then
  rm -f -- "$CAD_MASK"
  echo "[unmasked] ctrl-alt-del.target system-wide mask removed."
else
  echo "[kept] No standard ctrl-alt-del.target mask found."
fi

# Disable the yaPDP nginx vhost, but never stop/disable nginx itself: it may
# host other services and its pre-install enabled/running state is unknowable.
NGINX_SITE_REMOVED=0
if [[ -f "$NGINX_AVAILABLE" ]] &&
   grep -q 'listen 127\.0\.0\.1:8080;' "$NGINX_AVAILABLE" &&
   grep -q 'location /yapdp/' "$NGINX_AVAILABLE" &&
   grep -q 'alias ' "$NGINX_AVAILABLE"; then
  if [[ -L "$NGINX_ENABLED" ]]; then
    enabled_target="$(readlink -f "$NGINX_ENABLED" 2>/dev/null || true)"
    available_target="$(readlink -f "$NGINX_AVAILABLE" 2>/dev/null || true)"
    if [[ -n "$enabled_target" && "$enabled_target" == "$available_target" ]]; then
      rm -f -- "$NGINX_ENABLED"
      NGINX_SITE_REMOVED=1
      echo "[disabled] yaPDP nginx site symlink removed; site definition retained in sites-available."
    else
      echo "[kept] nginx enabled symlink points somewhere other than the legacy yaPDP site."
    fi
  elif [[ -e "$NGINX_ENABLED" ]]; then
    echo "[warning] sites-enabled/yapdp-kiosk is not a symlink; left untouched."
  else
    echo "[kept] yaPDP nginx site was already disabled."
  fi
else
  if [[ -e "$NGINX_ENABLED" || -e "$NGINX_AVAILABLE" ]]; then
    echo "[warning] nginx site files do not match the known legacy yaPDP layout; left untouched."
  else
    echo "[kept] No legacy yaPDP nginx site found."
  fi
fi

if (( NGINX_SITE_REMOVED )); then
  if nginx -t; then
    if systemctl is-active --quiet nginx.service; then
      systemctl reload nginx.service
      echo "[reloaded] nginx with the yaPDP site disabled; other sites were retained."
    else
      echo "[updated] nginx configuration test passed; nginx was not running and was not started."
    fi
  else
    echo "[warning] nginx -t failed after removing the yaPDP site. The symlink remains removed, but running nginx was not reloaded." >&2
    echo "          Inspect nginx configuration before restarting the service." >&2
  fi
fi

# The optional Plymouth installer has its own recorded previous-theme path
# and an official rollback script. Use it only when that record exists.
if [[ -s "$PLYMOUTH_STATE" && -f "$SCRIPT_DIR/plymouth/uninstall.sh" ]]; then
  echo "[rollback] Restoring the previous Plymouth theme..."
  bash "$SCRIPT_DIR/plymouth/uninstall.sh"
elif [[ "$(readlink -f /usr/share/plymouth/themes/default.plymouth 2>/dev/null || true)" == "$PLYMOUTH_THEME" ]]; then
  echo "[warning] yaPDP Plymouth theme is selected, but no previous-theme record/helper was found."
  echo "          Select the intended theme with: sudo update-alternatives --config default.plymouth"
  echo "          Then run: sudo update-initramfs -u"
else
  echo "[kept] No recorded yaPDP Plymouth installation to roll back."
fi

systemctl daemon-reload

echo
echo "Legacy yaPDP kiosk deactivation finished."
echo "Automatic kiosk login was disabled only if GDM targeted '$KIOSK_USER'."
echo "nginx was not stopped or disabled; unrelated sites were not changed deliberately."
echo "GNOME Kiosk/Chrome/nginx packages and the kiosk account/home were retained."
echo "The kiosk files and yaPDP repositories were not deleted."
echo "A reboot is recommended: it applies the restored logind policy and returns"
echo "the machine to the normal GDM login screen."
echo
echo "Pre-deactivation backup: $BACKUP_DIR"
echo "Important: without an original snapshot, prior custom GDM/nginx/dconf values"
echo "cannot be reconstructed exactly. Review the warnings above before rebooting."
