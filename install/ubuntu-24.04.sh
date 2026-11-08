#!/usr/bin/env bash
set -euo pipefail

# Install the local nginx site and desktop autostart entry.
# Expected layout:
#   /opt/yapdp-exhibit/yaPDP-kiosk/
#   /opt/yapdp-exhibit/yaPDP/

if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo: sudo $0" >&2
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

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This installer supports Ubuntu 24.04 (apt-get) only." >&2
  exit 1
fi

if ! command -v nginx >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
fi

NGINX_AVAILABLE="/etc/nginx/sites-available/yapdp-kiosk"
NGINX_ENABLED="/etc/nginx/sites-enabled/yapdp-kiosk"
AUTOSTART="/etc/xdg/autostart/yapdp-kiosk.desktop"
BACKUP=""

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

install -d -m 0755 /etc/xdg/autostart
cat > "$AUTOSTART" <<DESKTOP
[Desktop Entry]
Type=Application
Name=yaPDP Museum Kiosk
Comment=Start yaPDP in full-screen kiosk mode
Exec=$KIOSK_DIR/start-kiosk.sh
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
chmod 0644 "$AUTOSTART"

systemctl enable --now nginx
systemctl reload nginx

echo
echo "yaPDP kiosk nginx site installed."
echo "Kiosk URL: http://127.0.0.1:8080/"
echo "yaPDP URL: http://127.0.0.1:8080/yapdp/pdp11.html"
echo "Desktop autostart installed for graphical user sessions."
echo "Configure desktop auto-login for the dedicated kiosk account separately."
echo "Install Google Chrome if it is not already available."
