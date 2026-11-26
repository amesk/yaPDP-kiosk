#!/usr/bin/env bash
set -euo pipefail
PASSWORD_FILE="/root/yapdp-kiosk-grub-password.txt"
[[ -r "$PASSWORD_FILE" ]] || { echo "GRUB password file is missing: $PASSWORD_FILE" >&2; exit 1; }
PASSWORD="$(cat "$PASSWORD_FILE")"
MESSAGE="STAFF ONLY — GRUB SERVICE PASSWORD

$PASSWORD

Use this password only for the GRUB entry:
Enter service mode

The normal kiosk boot does not require a password.
The password is also stored locally in:
$PASSWORD_FILE

Keep it in the museum's protected staff documentation.
After recording it, press Enter/OK to finish."
if [[ "${NONINTERACTIVE:-0}" != "1" && -r /dev/tty && -w /dev/tty ]] && command -v dialog >/dev/null 2>&1; then
  dialog --clear --title "yaPDP Kiosk — STAFF ONLY" --msgbox "$MESSAGE" 15 76 </dev/tty >/dev/tty || true
elif [[ "${NONINTERACTIVE:-0}" != "1" && -r /dev/tty && -w /dev/tty ]]; then
  printf '\n%s\n\nPress Enter after recording the GRUB password... ' "$MESSAGE" >/dev/tty
  read -r _ </dev/tty || true
else
  echo "GRUB password saved in $PASSWORD_FILE (root-only)."
  echo "Retrieve it locally with: sudo cat $PASSWORD_FILE"
fi
