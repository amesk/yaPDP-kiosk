#!/usr/bin/env bash
set -euo pipefail

# Install the local nginx site, dedicated kiosk account, GDM auto-login,
# and per-user desktop autostart entry.
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

if ! command -v nginx >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
fi

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

# Keep the launcher scoped to the kiosk account, not every desktop user.
rm -f "$OLD_AUTOSTART"
# The parent may already exist (for example, if it was created by a root
# provisioning command). Ensure both XDG config directories are user-owned.
install -d -o "$KIOSK_USER" -g "$KIOSK_USER" -m 0750 "$USER_HOME/.config"
install -d -o "$KIOSK_USER" -g "$KIOSK_USER" -m 0750 "$USER_HOME/.config/autostart"
# Ubuntu 24.04 runs GNOME Initial Setup on a new account's first login.
# Mark it complete for the dedicated kiosk user so no welcome wizard covers the exhibit.
printf 'yes\n' > "$USER_HOME/.config/gnome-initial-setup-done"
chown "$KIOSK_USER:$KIOSK_USER" "$USER_HOME/.config/gnome-initial-setup-done"
chmod 0644 "$USER_HOME/.config/gnome-initial-setup-done"
cat > "$USER_AUTOSTART" <<DESKTOP
[Desktop Entry]
Type=Application
Name=yaPDP Museum Kiosk
Comment=Start yaPDP in full-screen kiosk mode
Exec=/bin/bash $KIOSK_DIR/start-kiosk.sh
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
chown "$KIOSK_USER:$KIOSK_USER" "$USER_AUTOSTART"
chmod 0644 "$USER_AUTOSTART"

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

systemctl enable --now nginx
systemctl reload nginx

echo
echo "yaPDP kiosk nginx site installed."
echo "Kiosk account: $KIOSK_USER"
echo "GDM automatic login enabled for that account (effective after reboot)."
echo "Kiosk URL: http://127.0.0.1:8080/"
echo "yaPDP URL: http://127.0.0.1:8080/yapdp/pdp11.html"
if ! command -v google-chrome-stable >/dev/null 2>&1 &&
   ! command -v google-chrome >/dev/null 2>&1; then
  echo "Google Chrome is not installed. Run instant-setup.sh to install it."
fi
echo "The kiosk account is not an administrator; use a separate admin account for maintenance."
