#!/usr/bin/env bash
set -euo pipefail

# Install the local nginx site, dedicated kiosk account, GNOME Kiosk session,
# and GDM auto-login.
# Expected layout:
#   /opt/yapdp-exhibit/yaPDP-kiosk/
#   /opt/yapdp-exhibit/yaPDP/

if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo: sudo $0" >&2
  exit 1
fi

KIOSK_USER="${KIOSK_USER:-yapdp-kiosk}"
if [[ ! "$KIOSK_USER" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
  echo "Invalid kiosk username: $KIOSK_USER" >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
KIOSK_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
EXHIBIT_DIR="$(dirname -- "$KIOSK_DIR")"
YAPDP_DIR="$EXHIBIT_DIR/yaPDP"

source "$KIOSK_DIR/lib/installer-ui.sh"
yapdp_log_init

if [[ "$KIOSK_DIR" == *" "* || "$YAPDP_DIR" == *" "* ]]; then
  echo "Installation paths must not contain spaces (nginx alias configuration)." >&2
  exit 1
fi

if [[ ! -f "$KIOSK_DIR/index.html" || ! -f "$KIOSK_DIR/config.js" ]]; then
  echo "Kiosk files are incomplete: $KIOSK_DIR" >&2
  exit 1
fi

if [[ ! -f "$YAPDP_DIR/pdp11.html" ]]; then
  echo "yaPDP was not found at $YAPDP_DIR." >&2
  echo "Place yaPDP and yaPDP-kiosk in sibling directories under /opt/yapdp-exhibit/." >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "Cannot identify the operating system." >&2
  exit 1
fi
. /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
  echo "This installer supports Ubuntu 24.04 only." >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "apt-get was not found." >&2
  exit 1
fi

if ! dpkg-query -W -f='${Status}' gdm3 2>/dev/null | grep -q "install ok installed"; then
  echo "GNOME Display Manager (gdm3) is required for automatic login." >&2
  echo "Use Ubuntu 24.04 Desktop, or install/configure gdm3 first." >&2
  exit 1
fi

# Capture the machine's original configuration exactly once, before changing
# packages, accounts, boot settings, display manager, nginx, or systemd.
KIOSK_HOME="$(getent passwd "$KIOSK_USER" | cut -d: -f6 || true)"
if [[ -z "$KIOSK_HOME" ]]; then KIOSK_HOME="/home/$KIOSK_USER"; fi
python3 "$KIOSK_DIR/scripts/capture-system-state.py" "$KIOSK_USER" "$KIOSK_HOME" "$KIOSK_DIR"
install -d -o root -g root -m 0755 /usr/local/lib/yapdp-kiosk
install -o root -g root -m 0755 "$KIOSK_DIR/scripts/restore-system-state.py" /usr/local/lib/yapdp-kiosk/restore-system-state.py
install -o root -g root -m 0755 "$KIOSK_DIR/deactivate-kiosk.sh" /usr/local/sbin/deactivate-yapdp-kiosk
install -o root -g root -m 0755 "$KIOSK_DIR/activate-kiosk.sh" /usr/local/sbin/activate-yapdp-kiosk

yapdp_phase 15 "Installing GNOME Kiosk session components..."

# Use GNOME's dedicated single-application session instead of a normal desktop
# with a browser autostart entry. This prevents the desktop from being exposed
# when the browser process exits.
if ! dpkg-query -W -f='${Status}' gnome-kiosk-script-session 2>/dev/null | grep -q "install ok installed"; then
  yapdp_run_with_spinner "Refreshing Ubuntu package lists" apt-get -o DPkg::Lock::Timeout=300 update
fi
yapdp_run_with_spinner "Installing GNOME Kiosk session components" env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y gnome-kiosk gnome-kiosk-script-session

KIOSK_WAYLAND_SESSION="/usr/share/wayland-sessions/gnome-kiosk-script-wayland.desktop"
if [[ ! -x /usr/bin/gnome-kiosk-script || ! -f "$KIOSK_WAYLAND_SESSION" ]]; then
  echo "GNOME Kiosk Script Session did not install correctly." >&2
  exit 1
fi

# Configure the visitor-session hand-off. Values are also accepted from the
# bootstrap environment, so this installer can be used without the dialog UI.
IDLE_TIMEOUT="${IDLE_TIMEOUT:-180}"
IDLE_REDIRECT="${IDLE_REDIRECT:-/}"
if [[ ! "$IDLE_TIMEOUT" =~ ^[0-9]+$ ]] || (( IDLE_TIMEOUT > 2147483 )); then
  echo "IDLE_TIMEOUT must be an integer from 0 to 2147483 seconds (0 disables the hand-off)." >&2
  exit 1
fi

python3 - "$KIOSK_DIR/config.js" "$IDLE_TIMEOUT" "$IDLE_REDIRECT" <<'PY'
from pathlib import Path
from urllib.parse import urlencode, urlsplit
import json
import re
import sys

path = Path(sys.argv[1])
timeout = int(sys.argv[2])
redirect = sys.argv[3].strip()

if timeout > 0:
    if not redirect or any(ord(char) < 32 for char in redirect):
        raise SystemExit("IDLE_REDIRECT must be a non-empty URL without control characters.")
    parsed = urlsplit(redirect)
    if parsed.scheme and parsed.scheme.lower() not in ("http", "https"):
        raise SystemExit("IDLE_REDIRECT must use HTTP(S), or be a relative URL.")
    if parsed.scheme.lower() in ("http", "https") and not parsed.netloc:
        raise SystemExit("IDLE_REDIRECT is missing a host.")
    query = urlencode((("idle-timeout", str(timeout)), ("idle-redirect", redirect)))
    launch_url = "/yapdp/pdp11.html?" + query
else:
    launch_url = "/yapdp/pdp11.html"

content = path.read_text(encoding="utf-8")
pattern = re.compile(r"(?m)^([ \t]*launchUrl[ \t]*:[ \t]*).*(,[ \t]*)$")
content, count = pattern.subn(
    lambda match: match.group(1) + json.dumps(launch_url, ensure_ascii=False) + match.group(2),
    content,
    count=1,
)
if count != 1:
    raise SystemExit(f"Could not find exactly one launchUrl setting in {path}.")
path.write_text(content, encoding="utf-8")
print(f"Configured yaPDP launch URL: {launch_url}")
PY

yapdp_phase 35 "Configuring yaPDP launch URL and web server..."

if ! command -v nginx >/dev/null 2>&1; then
  yapdp_run_with_spinner "Refreshing Ubuntu package lists" apt-get -o DPkg::Lock::Timeout=300 update
  yapdp_run_with_spinner "Installing nginx web server" env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y nginx
fi

yapdp_phase 55 "Preparing the dedicated kiosk account..."

# Create a dedicated, unprivileged account. A newly created account has no
# usable password; GDM's automatic-login PAM service starts its desktop session.
if ! id "$KIOSK_USER" >/dev/null 2>&1; then
  useradd --create-home --user-group --shell /bin/bash \
    --comment "yaPDP Museum Kiosk" "$KIOSK_USER"
fi

if id -nG "$KIOSK_USER" | tr ' ' '\n' | grep -qx 'sudo'; then
  echo "The account $KIOSK_USER belongs to the sudo group; refusing to use it as a kiosk account." >&2
  echo "Remove it from sudo or choose another KIOSK_USER." >&2
  exit 1
fi

USER_HOME="$(getent passwd "$KIOSK_USER" | cut -d: -f6)"
if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
  echo "Cannot find a valid home directory for $KIOSK_USER." >&2
  exit 1
fi

USER_KIOSK_SCRIPT="$USER_HOME/.local/bin/gnome-kiosk-script"
ACCOUNTS_SERVICE_USER="/var/lib/AccountsService/users/$KIOSK_USER"

NGINX_AVAILABLE="/etc/nginx/sites-available/yapdp-kiosk"
NGINX_ENABLED="/etc/nginx/sites-enabled/yapdp-kiosk"
GDM_CONFIG="/etc/gdm3/custom.conf"
OLD_AUTOSTART="/etc/xdg/autostart/yapdp-kiosk.desktop"
USER_AUTOSTART="$USER_HOME/.config/autostart/yapdp-kiosk.desktop"
BACKUP=""

if [[ ! -f "$GDM_CONFIG" ]]; then
  echo "Expected GDM configuration was not found: $GDM_CONFIG" >&2
  exit 1
fi

if [[ -e "$NGINX_AVAILABLE" ]]; then
  BACKUP="$(mktemp)"
  cp -a "$NGINX_AVAILABLE" "$BACKUP"
fi

cat > "$NGINX_AVAILABLE" <<NGINX
server {
    listen 127.0.0.1:8080;
    server_name localhost;

    root $KIOSK_DIR;
    index index.html;

    location = /yapdp {
        return 301 /yapdp/;
    }

    location /yapdp/ {
        alias $YAPDP_DIR/;
        index pdp11.html;
        autoindex off;
    }

    location = /config.js {
        add_header Cache-Control "no-store";
    }

    location / {
        try_files \$uri \$uri/ =404;
    }
}
NGINX

ln -sfn "$NGINX_AVAILABLE" "$NGINX_ENABLED"

if ! nginx -t; then
  if [[ -n "$BACKUP" ]]; then
    cp -a "$BACKUP" "$NGINX_AVAILABLE"
  else
    rm -f "$NGINX_AVAILABLE"
  fi
  rm -f "$NGINX_ENABLED"
  echo "nginx configuration test failed; previous site configuration restored." >&2
  exit 1
fi

# Do not offer an in-place upgrade to a newer Ubuntu release on the public kiosk.
# This controls release-upgrade notifications only; normal package/security updates remain available.
RELEASE_UPGRADES_CONFIG="/etc/update-manager/release-upgrades"
if [[ ! -f "$RELEASE_UPGRADES_CONFIG" ]]; then
  echo "Expected Ubuntu release-upgrades configuration was not found: $RELEASE_UPGRADES_CONFIG" >&2
  exit 1
fi
python3 - "$RELEASE_UPGRADES_CONFIG" <<'PY'
from pathlib import Path
import re
import os
import shutil
import sys
import tempfile

path = Path(sys.argv[1])
original = path.read_text()
lines = original.splitlines()
section_start = None
section_end = len(lines)

for index, line in enumerate(lines):
    if re.match(r"^\s*\[DEFAULT\]\s*(?:#.*)?$", line, re.I):
        section_start = index
        for end in range(index + 1, len(lines)):
            if re.match(r"^\s*\[[^]]+\]", lines[end]):
                section_end = end
                break
        break

if section_start is None:
    if lines and lines[-1].strip():
        lines.append("")
    lines.append("[DEFAULT]")
    section_start = len(lines) - 1
    section_end = len(lines)

updated = []
seen_prompt = False
for index, line in enumerate(lines):
    if section_start < index < section_end and re.match(r"^\s*#?\s*Prompt\s*=", line, re.I):
        if not seen_prompt:
            updated.append("Prompt=never")
            seen_prompt = True
        else:
            updated.append("# Disabled duplicate setting by yaPDP kiosk installer: " + line.lstrip("# "))
        continue
    updated.append(line)

if not seen_prompt:
    insert_at = next(
        (i for i, line in enumerate(updated) if i > section_start and re.match(r"^\s*\[[^]]+\]", line)),
        len(updated),
    )
    updated.insert(insert_at, "Prompt=never")

content = "\n".join(updated) + "\n"
if content != original:
    backup = path.with_name(path.name + ".yapdp-kiosk.bak")
    if not backup.exists():
        shutil.copy2(path, backup)
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as output:
            output.write(content)
        shutil.copystat(path, temporary)
        Path(temporary).replace(path)
    finally:
        if Path(temporary).exists():
            Path(temporary).unlink()
PY

yapdp_phase 75 "Configuring GNOME Kiosk and automatic login..."

# Remove the previous desktop-autostart mechanism. The GNOME Kiosk session
# starts its dedicated user script through the package-provided systemd unit.
rm -f "$OLD_AUTOSTART" "$USER_AUTOSTART"

# Prepare the kiosk user's configuration directories and mark GNOME Initial
# Setup complete so no first-login wizard can cover the exhibit.
install -d -o "$KIOSK_USER" -g "$KIOSK_USER" -m 0750 "$USER_HOME/.config"
install -d -o "$KIOSK_USER" -g "$KIOSK_USER" -m 0750 "$USER_HOME/.local"
install -d -o "$KIOSK_USER" -g "$KIOSK_USER" -m 0750 "$USER_HOME/.local/bin"

# Ubuntu's update-notifier starts from a system-wide XDG autostart entry and
# can open Software Updater dialogs in a graphical session. Mask that entry
# only for the public kiosk account; administrator sessions and package
# security updates remain untouched. The file is included in the rollback
# snapshot, including when upgrading an installation with an older snapshot.
UPDATE_NOTIFIER_OVERRIDE="$USER_HOME/.config/autostart/update-notifier.desktop"
install -d -o "$KIOSK_USER" -g "$KIOSK_USER" -m 0750 "$USER_HOME/.config/autostart"
cat > "$UPDATE_NOTIFIER_OVERRIDE" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Update Notifier (disabled for yaPDP kiosk)
Hidden=true
X-GNOME-Autostart-enabled=false
NoDisplay=true
DESKTOP
chown "$KIOSK_USER:$KIOSK_USER" "$UPDATE_NOTIFIER_OVERRIDE"
chmod 0644 "$UPDATE_NOTIFIER_OVERRIDE"

# GNOME Kiosk 46 reads its compositor background during session startup.
# Configure the kiosk user's dconf database now, before GDM starts that session;
# changing these settings from start-kiosk.sh would be too late.
if ! runuser -u "$KIOSK_USER" -- env HOME="$USER_HOME" \
    dbus-run-session -- sh -c '
      set -eu
      gsettings set org.gnome.desktop.background color-shading-type "solid"
      gsettings set org.gnome.desktop.background primary-color "#000000"
      gsettings set org.gnome.desktop.background secondary-color "#000000"
      gsettings set org.gnome.desktop.background picture-uri ""
      gsettings set org.gnome.desktop.background picture-uri-dark ""
    '; then
  echo "Could not configure the GNOME Kiosk background for $KIOSK_USER." >&2
  exit 1
fi

# Mutter normally owns the Ctrl+Alt+F1..F12 virtual-terminal switch, but the
# switch-to-session-N keys do not exist in every mutter build and gnome-kiosk
# can ship a reduced schema. Seed them only when the key is actually present:
# an optional hardening step must never abort the installation. start-kiosk.sh
# repeats the same clearing at every browser launch.
if ! runuser -u "$KIOSK_USER" -- env HOME="$USER_HOME" \
    dbus-run-session -- sh -c '
      set -eu
      keys="$(gsettings list-keys org.gnome.mutter.keybindings 2>/dev/null || true)"
      for n in 1 2 3 4 5 6 7 8 9 10 11 12; do
        key="switch-to-session-$n"
        if printf "%s\n" "$keys" | grep -Fxq "$key"; then
          gsettings set org.gnome.mutter.keybindings "$key" "@as []" || true
        fi
      done
    '; then
  echo "Warning: could not pre-clear the Mutter switch-to-session keybindings for $KIOSK_USER; Ctrl+Alt+F1..F12 is cleared at session start instead." >&2
fi

printf 'yes\n' > "$USER_HOME/.config/gnome-initial-setup-done"
chown "$KIOSK_USER:$KIOSK_USER" "$USER_HOME/.config/gnome-initial-setup-done"
chmod 0644 "$USER_HOME/.config/gnome-initial-setup-done"

# GNOME Kiosk Script Session invokes ~/.local/bin/gnome-kiosk-script.
# Publish it atomically so an interrupted install cannot leave an empty launcher.
KIOSK_SCRIPT_TMP="$(mktemp "$USER_HOME/.local/bin/.gnome-kiosk-script.XXXXXX")"
if ! cat > "$KIOSK_SCRIPT_TMP" <<KIOSK_SCRIPT
#!/bin/sh
exec /bin/bash "$KIOSK_DIR/start-kiosk.sh"
KIOSK_SCRIPT
then
  rm -f "$KIOSK_SCRIPT_TMP"
  echo "Failed to write the GNOME Kiosk launcher." >&2
  exit 1
fi

if [[ ! -s "$KIOSK_SCRIPT_TMP" ]] ||
   ! grep -Fxq '#!/bin/sh' "$KIOSK_SCRIPT_TMP" ||
   ! grep -Fxq "exec /bin/bash \"$KIOSK_DIR/start-kiosk.sh\"" "$KIOSK_SCRIPT_TMP"; then
  rm -f "$KIOSK_SCRIPT_TMP"
  echo "Generated GNOME Kiosk launcher failed validation." >&2
  exit 1
fi
chown "$KIOSK_USER:$KIOSK_USER" "$KIOSK_SCRIPT_TMP"
chmod 0755 "$KIOSK_SCRIPT_TMP"
mv -f -- "$KIOSK_SCRIPT_TMP" "$USER_KIOSK_SCRIPT"

# Select the tested Wayland kiosk session for GDM automatic login. Session is
# the installed Wayland session desktop-file ID; SessionType makes the choice
# explicit. Keep the Xorg fallback ID available for manual recovery.
python3 - "$ACCOUNTS_SERVICE_USER" <<'PY'
from pathlib import Path
import os
import re
import tempfile
import sys

path = Path(sys.argv[1])
path.parent.mkdir(parents=True, exist_ok=True)
lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
section_start = None
section_end = len(lines)

for index, line in enumerate(lines):
    if re.match(r"^\s*\[User\]\s*(?:#.*)?$", line, re.I):
        section_start = index
        for end in range(index + 1, len(lines)):
            if re.match(r"^\s*\[[^]]+\]", lines[end]):
                section_end = end
                break
        break

if section_start is None:
    if lines and lines[-1].strip():
        lines.append("")
    lines.append("[User]")
    section_start = len(lines) - 1
    section_end = len(lines)

settings = {
    "Session": "gnome-kiosk-script-wayland",
    "SessionType": "wayland",
    "XSession": "gnome-kiosk-script-xorg",
}
seen = set()
updated = []
for index, line in enumerate(lines):
    if section_start < index < section_end:
        match = re.match(r"^\s*(Session|SessionType|XSession)\s*=", line)
        if match:
            key = match.group(1)
            if key not in seen:
                updated.append(f"{key}={settings[key]}")
                seen.add(key)
            continue
    updated.append(line)

insert_at = next(
    (i for i, line in enumerate(updated)
     if i > section_start and re.match(r"^\s*\[[^]]+\]", line)),
    len(updated),
)
updated[insert_at:insert_at] = [
    f"{key}={value}" for key, value in settings.items() if key not in seen
]

fd, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as output:
        output.write("\n".join(updated) + "\n")
    os.chmod(temporary, 0o644)
    os.chown(temporary, 0, 0)
    os.replace(temporary, path)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
PY
# Set only the GDM daemon options we own; preserve unrelated local settings.
python3 - "$GDM_CONFIG" "$KIOSK_USER" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
username = sys.argv[2]
lines = path.read_text().splitlines()
section_start = None
section_end = len(lines)

for index, line in enumerate(lines):
    if re.match(r"^\s*\[daemon\]\s*(?:#.*)?$", line, re.I):
        section_start = index
        for end in range(index + 1, len(lines)):
            if re.match(r"^\s*\[[^]]+\]", lines[end]):
                section_end = end
                break
        break

if section_start is None:
    if lines and lines[-1].strip():
        lines.append("")
    lines.append("[daemon]")
    section_start = len(lines) - 1
    section_end = len(lines)

settings = {
    "AutomaticLoginEnable": "True",
    "AutomaticLogin": username,
    "TimedLoginEnable": "False",
}
seen = set()
updated = []
for index, line in enumerate(lines):
    if section_start < index < section_end:
        match = re.match(r"^\s*#?\s*(AutomaticLoginEnable|AutomaticLogin|TimedLoginEnable)\s*=", line)
        if match:
            key = match.group(1)
            if key not in seen:
                updated.append(f"{key} = {settings[key]}")
                seen.add(key)
            continue
    updated.append(line)

# Insert missing settings immediately before the next section (or at EOF).
insert_at = section_end
# Account for lines removed/replaced in the daemon section.
insert_at = next(
    (i for i, line in enumerate(updated) if i > section_start and re.match(r"^\s*\[[^]]+\]", line)),
    len(updated),
)
missing = [f"{key} = {value}" for key, value in settings.items() if key not in seen]
updated[insert_at:insert_at] = missing
path.write_text("\n".join(updated) + "\n")
PY

yapdp_phase 85 "Hardening the kiosk against local key combinations..."

# Disable kernel SysRq and the standard Ctrl+Alt+Del reboot path.
KIOSK_LOGIND_DROPIN="/etc/systemd/logind.conf.d/90-yapdp-kiosk.conf"
install -d -m 0755 "/etc/systemd/logind.conf.d"
cat > "$KIOSK_LOGIND_DROPIN" <<'LOGIND'
# Managed by the yaPDP kiosk installer; effective after the next reboot.
# Undo with: sudo rm -f /etc/systemd/logind.conf.d/90-yapdp-kiosk.conf
[Login]
HandlePowerKey=ignore
HandlePowerKeyLongPress=poweroff
HandleRebootKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
# Do not spawn spare gettys automatically on the public exhibit.
NAutoVTs=0
ReserveVT=0
LOGIND

# Install the F1-F12 keyboard filter and kiosk-session VT lock helper.
# The filter is disabled automatically on a GRUB service-mode boot.
yapdp_run_with_spinner "Installing keyboard event support" env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y python3-evdev
modprobe uinput
install -d -m 0755 /etc/modules-load.d
printf 'uinput\n' > /etc/modules-load.d/yapdp-kiosk.conf

GUARD_DIR="/usr/local/lib/yapdp-kiosk"
install -d -o root -g root -m 0755 "$GUARD_DIR"
install -o root -g root -m 0755 "$KIOSK_DIR/scripts/kiosk-guard.py" "$GUARD_DIR/kiosk-guard.py"
install -o root -g root -m 0755 "$KIOSK_DIR/scripts/configure-gdm-boot-mode.py" "$GUARD_DIR/configure-gdm-boot-mode.py"
install -o root -g root -m 0755 "$KIOSK_DIR/scripts/vt-switch-lock.py" /usr/local/sbin/yapdp-vt-switch-lock
install -o root -g root -m 0644 "$KIOSK_DIR/systemd/yapdp-kiosk-guard.service" /etc/systemd/system/yapdp-kiosk-guard.service
install -d -m 0755 /etc/systemd/system/gdm3.service.d
install -o root -g root -m 0644 "$KIOSK_DIR/systemd/gdm3.service.d/10-yapdp-boot-mode.conf" /etc/systemd/system/gdm3.service.d/10-yapdp-boot-mode.conf
install -d -m 0755 "/etc/systemd/system/getty@tty3.service.d"
install -o root -g root -m 0644 "$KIOSK_DIR/systemd/getty@tty3.service.d/10-yapdp-service-mode.conf" "/etc/systemd/system/getty@tty3.service.d/10-yapdp-service-mode.conf"

KIOSK_SUDOERS="/etc/sudoers.d/yapdp-kiosk-vt-lock"
printf '%s ALL=(root) NOPASSWD: /usr/local/sbin/yapdp-vt-switch-lock lock\n' "$KIOSK_USER" > "$KIOSK_SUDOERS"
chmod 0440 "$KIOSK_SUDOERS"
if ! visudo -cf "$KIOSK_SUDOERS" >/dev/null; then
  rm -f "$KIOSK_SUDOERS"
  echo "Invalid sudoers rule for the virtual-terminal lock." >&2
  exit 1
fi

# GDM decides whether to auto-login immediately before it starts. The kernel
# command line marks only this one boot as service mode; the next boot naturally
# returns to kiosk auto-login without changing persistent GRUB defaults.
install -d -o root -g root -m 0700 /etc/yapdp-kiosk
# Remove the obsolete per-keyboard service trigger from earlier draft installs.
rm -f /etc/yapdp-kiosk/guard.conf /root/yapdp-kiosk-service-sequence.txt
python3 - "$KIOSK_USER" /etc/yapdp-kiosk/boot-mode.json <<'PY'
import json, os, sys
from pathlib import Path
target = Path(sys.argv[2])
target.write_text(json.dumps({"kiosk_user": sys.argv[1]}) + "\n", encoding="utf-8")
os.chown(target, 0, 0)
os.chmod(target, 0o600)
PY

# Create a separate GRUB password once. The cleartext copy is root-only and
# shown to staff at the end of the interactive installation; GRUB stores only
# its PBKDF2 hash.
if ! command -v grub-mkpasswd-pbkdf2 >/dev/null 2>&1 ||
   ! command -v update-grub >/dev/null 2>&1 ||
   ! command -v grub-probe >/dev/null 2>&1 ||
   ! command -v grub-script-check >/dev/null 2>&1; then
  echo "Required GRUB utilities are missing (grub-common/grub2-common)." >&2
  exit 1
fi
GRUB_PASSWORD_FILE="/root/yapdp-kiosk-grub-password.txt"
GRUB_PASSWORD_PATTERN='^[BCDFGHJKLMNPRSTVWZ][AEUY][BCDFGHJKLMNPRSTVWZ][AEUY][234679][BCDFGHJKLMNPRSTVWZ][AEUY][BCDFGHJKLMNPRSTVWZ]$'
GRUB_PASSWORD_TMP=""
SAVED_GRUB_PASSWORD=""
if [[ -s "$GRUB_PASSWORD_FILE" ]]; then
  SAVED_GRUB_PASSWORD="$(cat "$GRUB_PASSWORD_FILE")"
fi

# Reuse a current-format password on reinstall. Older 24-digit passwords are
# rotated once to the shorter pronounceable format.
if [[ "$SAVED_GRUB_PASSWORD" =~ $GRUB_PASSWORD_PATTERN ]]; then
  GRUB_PASSWORD="$SAVED_GRUB_PASSWORD"
else
  GRUB_PASSWORD_TMP="$(mktemp /root/.yapdp-kiosk-grub-password.XXXXXX)"
  python3 "$KIOSK_DIR/scripts/generate-grub-password.py" > "$GRUB_PASSWORD_TMP"
  chown root:root "$GRUB_PASSWORD_TMP"
  chmod 0600 "$GRUB_PASSWORD_TMP"
  GRUB_PASSWORD="$(cat "$GRUB_PASSWORD_TMP")"
fi
if [[ ! "$GRUB_PASSWORD" =~ $GRUB_PASSWORD_PATTERN ]]; then
  echo "The generated GRUB password has an invalid format." >&2
  [[ -n "$GRUB_PASSWORD_TMP" ]] && rm -f "$GRUB_PASSWORD_TMP"
  exit 1
fi
GRUB_HASH_OUTPUT="$(printf '%s\n%s\n' "$GRUB_PASSWORD" "$GRUB_PASSWORD" | grub-mkpasswd-pbkdf2 2>/dev/null)"
GRUB_PASSWORD_HASH="$(printf '%s\n' "$GRUB_HASH_OUTPUT" | grep -oE 'grub\.pbkdf2\.sha512\.[0-9]+\.[A-Fa-f0-9]+\.[A-Fa-f0-9]+' | tail -n 1)"
if [[ -z "$GRUB_PASSWORD_HASH" ]]; then
  echo "Could not generate the GRUB PBKDF2 password hash." >&2
  exit 1
fi
GRUB_AUTH_SCRIPT="/etc/grub.d/08_yapdp_kiosk_auth"
cat > "$GRUB_AUTH_SCRIPT" <<AUTH
#!/bin/sh
cat <<'YAPDP_GRUB_AUTH'
set superusers="kiosk-admin"
password_pbkdf2 kiosk-admin $GRUB_PASSWORD_HASH
YAPDP_GRUB_AUTH
AUTH
chown root:root "$GRUB_AUTH_SCRIPT"
chmod 0755 "$GRUB_AUTH_SCRIPT"

install -o root -g root -m 0755 "$KIOSK_DIR/scripts/grub/01_yapdp_disable_stock" /etc/grub.d/01_yapdp_disable_stock
install -o root -g root -m 0755 "$KIOSK_DIR/scripts/grub/09_yapdp_kiosk" /etc/grub.d/09_yapdp_kiosk

# Suppress Ubuntu's generic entries so the visitor/staff boot menu has exactly
# the two supported choices. Keep the scripts on disk for package ownership
# and recovery; only their executable bits are disabled.
for script in 10_linux 10_linux_zfs 20_linux_xen 20_memtest86+ 30_os-prober 30_uefi-firmware 40_custom 41_custom; do
  if [[ -f "/etc/grub.d/$script" ]]; then
    chmod a-x "/etc/grub.d/$script"
  fi
done

python3 - /etc/default/grub <<'PY'
from pathlib import Path
import re, sys
path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
settings = {
    "GRUB_DEFAULT": "yapdp-kiosk",
    "GRUB_TIMEOUT_STYLE": "menu",
    "GRUB_TIMEOUT": "5",
    "GRUB_DISABLE_OS_PROBER": "true",
    "GRUB_DISABLE_RECOVERY": "true",
    "GRUB_SAVEDEFAULT": "false",
}
seen, output = set(), []
for line in lines:
    match = re.match(r"^\s*#?\s*(GRUB_DEFAULT|GRUB_TIMEOUT_STYLE|GRUB_TIMEOUT|GRUB_DISABLE_OS_PROBER|GRUB_DISABLE_RECOVERY|GRUB_SAVEDEFAULT)\s*=", line)
    if match:
        key = match.group(1)
        if key not in seen:
            output.append(f"{key}={settings[key]}")
            seen.add(key)
        continue
    output.append(line)
for key, value in settings.items():
    if key not in seen:
        output.append(f"{key}={value}")
path.write_text("\n".join(output) + "\n", encoding="utf-8")
PY

systemctl daemon-reload
systemctl enable yapdp-kiosk-guard.service getty@tty3.service
update-grub
GRUB_MENU_COUNT="$(grep -c '^menuentry ' /boot/grub/grub.cfg || true)"
if [[ "$GRUB_MENU_COUNT" != "2" ]]; then
  echo "Expected exactly two GRUB menu entries, found $GRUB_MENU_COUNT." >&2
  echo "Inspect /boot/grub/grub.cfg and /etc/grub.d before rebooting." >&2
  exit 1
fi
if ! grub-script-check /boot/grub/grub.cfg; then
  echo "Generated GRUB configuration failed grub-script-check." >&2
  exit 1
fi

# Publish a newly generated password only after the new GRUB configuration
# has been generated and validated, keeping the saved credential in sync.
if [[ -n "$GRUB_PASSWORD_TMP" ]]; then
  mv -f -- "$GRUB_PASSWORD_TMP" "$GRUB_PASSWORD_FILE"
  chown root:root "$GRUB_PASSWORD_FILE"
  chmod 0600 "$GRUB_PASSWORD_FILE"
fi

KIOSK_SYSCTL_DROPIN="/etc/sysctl.d/90-yapdp-kiosk.conf"
cat > "$KIOSK_SYSCTL_DROPIN" <<'SYSCTL'
# Managed by the yaPDP kiosk installer: no Magic SysRq on a public exhibit.
# Undo at runtime with: sudo sysctl kernel.sysrq=1
kernel.sysrq = 0
SYSCTL
sysctl -q -p "$KIOSK_SYSCTL_DROPIN"

if ! systemctl mask ctrl-alt-del.target >/dev/null 2>&1; then
  echo "Warning: could not mask ctrl-alt-del.target; Ctrl+Alt+Del may reboot the exhibit." >&2
fi

yapdp_phase 95 "Enabling the local web server and finalizing setup..."

systemctl enable --now nginx
systemctl reload nginx
systemctl restart yapdp-kiosk-guard.service

echo
echo "yaPDP kiosk nginx site installed."
echo "Kiosk account: $KIOSK_USER"
echo "GNOME Kiosk Wayland session selected for GDM automatic login."
echo "GDM auto-login configured for normal kiosk boots; service boots use the standard greeter."
echo "Keyboard filter: active in kiosk mode; F1-F12 are suppressed."
echo "GRUB menu: Load yaPDP-kiosk / Enter service mode (password protected)."
echo "GRUB username: kiosk-admin"
echo "GRUB password file: /root/yapdp-kiosk-grub-password.txt"
echo "Kiosk URL: http://127.0.0.1:8080/"
echo "yaPDP URL: http://127.0.0.1:8080/yapdp/pdp11.html"
if ! command -v google-chrome-stable >/dev/null 2>&1 &&
   ! command -v google-chrome >/dev/null 2>&1; then
  echo "Google Chrome is not installed. Run instant-setup.sh to install it."
fi
echo "The kiosk account is not an administrator; use a separate admin account for maintenance."
echo "Detailed installation log: ${LOG_FILE:-$YAPDP_INSTALL_LOG}"
yapdp_phase 100 "Kiosk installation completed."

# Show the private GRUB password only after all installation output.
bash "$KIOSK_DIR/scripts/show-grub-password.sh"

GRUB_PASSWORD_TMP=""
SAVED_GRUB_PASSWORD=""
if [[ -s "$GRUB_PASSWORD_FILE" ]]; then
  SAVED_GRUB_PASSWORD="$(cat "$GRUB_PASSWORD_FILE")"
fi

# Reuse a current-format password on reinstall. Older 24-digit passwords are
# rotated once to the shorter pronounceable format.
if [[ "$SAVED_GRUB_PASSWORD" =~ $GRUB_PASSWORD_PATTERN ]]; then
  GRUB_PASSWORD="$SAVED_GRUB_PASSWORD"
else
  GRUB_PASSWORD_TMP="$(mktemp /root/.yapdp-kiosk-grub-password.XXXXXX)"
  python3 "$KIOSK_DIR/scripts/generate-grub-password.py" > "$GRUB_PASSWORD_TMP"
  chown root:root "$GRUB_PASSWORD_TMP"
  chmod 0600 "$GRUB_PASSWORD_TMP"
  GRUB_PASSWORD="$(cat "$GRUB_PASSWORD_TMP")"
fi
if [[ ! "$GRUB_PASSWORD" =~ $GRUB_PASSWORD_PATTERN ]]; then
  echo "The generated GRUB password has an invalid format." >&2
  [[ -n "$GRUB_PASSWORD_TMP" ]] && rm -f "$GRUB_PASSWORD_TMP"
  exit 1
fi
GRUB_HASH_OUTPUT="$(printf '%s\n%s\n' "$GRUB_PASSWORD" "$GRUB_PASSWORD" | grub-mkpasswd-pbkdf2 2>/dev/null)"
GRUB_PASSWORD_HASH="$(printf '%s\n' "$GRUB_HASH_OUTPUT" | grep -oE 'grub\.pbkdf2\.sha512\.[0-9]+\.[A-Fa-f0-9]+\.[A-Fa-f0-9]+' | tail -n 1)"
if [[ -z "$GRUB_PASSWORD_HASH" ]]; then
  echo "Could not generate the GRUB PBKDF2 password hash." >&2
  exit 1
fi
GRUB_AUTH_SCRIPT="/etc/grub.d/08_yapdp_kiosk_auth"
cat > "$GRUB_AUTH_SCRIPT" <<AUTH
#!/bin/sh
cat <<'YAPDP_GRUB_AUTH'
set superusers="kiosk-admin"
password_pbkdf2 kiosk-admin $GRUB_PASSWORD_HASH
YAPDP_GRUB_AUTH
AUTH
chown root:root "$GRUB_AUTH_SCRIPT"
chmod 0755 "$GRUB_AUTH_SCRIPT"

install -o root -g root -m 0755 "$KIOSK_DIR/scripts/grub/01_yapdp_disable_stock" /etc/grub.d/01_yapdp_disable_stock
install -o root -g root -m 0755 "$KIOSK_DIR/scripts/grub/09_yapdp_kiosk" /etc/grub.d/09_yapdp_kiosk

# Suppress Ubuntu's generic entries so the visitor/staff boot menu has exactly
# the two supported choices. Keep the scripts on disk for package ownership
# and recovery; only their executable bits are disabled.
for script in 10_linux 10_linux_zfs 20_linux_xen 20_memtest86+ 30_os-prober 30_uefi-firmware 40_custom 41_custom; do
  if [[ -f "/etc/grub.d/$script" ]]; then
    chmod a-x "/etc/grub.d/$script"
  fi
done

python3 - /etc/default/grub <<'PY'
from pathlib import Path
import re, sys
path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
settings = {
    "GRUB_DEFAULT": "yapdp-kiosk",
    "GRUB_TIMEOUT_STYLE": "menu",
    "GRUB_TIMEOUT": "5",
    "GRUB_DISABLE_OS_PROBER": "true",
    "GRUB_DISABLE_RECOVERY": "true",
    "GRUB_SAVEDEFAULT": "false",
}
seen, output = set(), []
for line in lines:
    match = re.match(r"^\s*#?\s*(GRUB_DEFAULT|GRUB_TIMEOUT_STYLE|GRUB_TIMEOUT|GRUB_DISABLE_OS_PROBER|GRUB_DISABLE_RECOVERY|GRUB_SAVEDEFAULT)\s*=", line)
    if match:
        key = match.group(1)
        if key not in seen:
            output.append(f"{key}={settings[key]}")
            seen.add(key)
        continue
    output.append(line)
for key, value in settings.items():
    if key not in seen:
        output.append(f"{key}={value}")
path.write_text("\n".join(output) + "\n", encoding="utf-8")
PY

systemctl daemon-reload
systemctl enable yapdp-kiosk-guard.service getty@tty3.service
update-grub
GRUB_MENU_COUNT="$(grep -c '^menuentry ' /boot/grub/grub.cfg || true)"
if [[ "$GRUB_MENU_COUNT" != "2" ]]; then
  echo "Expected exactly two GRUB menu entries, found $GRUB_MENU_COUNT." >&2
  echo "Inspect /boot/grub/grub.cfg and /etc/grub.d before rebooting." >&2
  exit 1
fi
if ! grub-script-check /boot/grub/grub.cfg; then
  echo "Generated GRUB configuration failed grub-script-check." >&2
  exit 1
fi

KIOSK_SYSCTL_DROPIN="/etc/sysctl.d/90-yapdp-kiosk.conf"
cat > "$KIOSK_SYSCTL_DROPIN" <<'SYSCTL'
# Managed by the yaPDP kiosk installer: no Magic SysRq on a public exhibit.
# Undo at runtime with: sudo sysctl kernel.sysrq=1
kernel.sysrq = 0
SYSCTL
sysctl -q -p "$KIOSK_SYSCTL_DROPIN"

if ! systemctl mask ctrl-alt-del.target >/dev/null 2>&1; then
  echo "Warning: could not mask ctrl-alt-del.target; Ctrl+Alt+Del may reboot the exhibit." >&2
fi

yapdp_phase 95 "Enabling the local web server and finalizing setup..."

systemctl enable --now nginx
systemctl reload nginx
systemctl restart yapdp-kiosk-guard.service

echo
echo "yaPDP kiosk nginx site installed."
echo "Kiosk account: $KIOSK_USER"
echo "GNOME Kiosk Wayland session selected for GDM automatic login."
echo "GDM auto-login configured for normal kiosk boots; service boots use the standard greeter."
echo "Keyboard filter: active in kiosk mode; F1-F12 are suppressed."
echo "GRUB menu: Load yaPDP-kiosk / Enter service mode (password protected)."
echo "GRUB username: kiosk-admin"
echo "GRUB password file: /root/yapdp-kiosk-grub-password.txt"
echo "Kiosk URL: http://127.0.0.1:8080/"
echo "yaPDP URL: http://127.0.0.1:8080/yapdp/pdp11.html"
if ! command -v google-chrome-stable >/dev/null 2>&1 &&
   ! command -v google-chrome >/dev/null 2>&1; then
  echo "Google Chrome is not installed. Run instant-setup.sh to install it."
fi
echo "The kiosk account is not an administrator; use a separate admin account for maintenance."
echo "Detailed installation log: ${LOG_FILE:-$YAPDP_INSTALL_LOG}"
yapdp_phase 100 "Kiosk installation completed."

# Show the private GRUB password only after all installation output.
bash "$KIOSK_DIR/scripts/show-grub-password.sh"
