#!/usr/bin/env bash
set -euo pipefail

SEQUENCE_FILE="/root/yapdp-kiosk-service-sequence.txt"
if [[ ! -r "$SEQUENCE_FILE" ]]; then
  echo "Service sequence file is missing: $SEQUENCE_FILE" >&2
  exit 1
fi

# Read the private sequence directly from the root-only hand-off file. Never
# print it to stdout: the installer redirects stdout into its persistent log.
SEQUENCE="$(awk -F': ' '/^yaPDP kiosk local service sequence/ { next } /^[F][0-9]+( -> [F][0-9]+)*$/ { print; exit }' "$SEQUENCE_FILE")"
if [[ -z "$SEQUENCE" ]]; then
  echo "Could not parse the local service sequence file." >&2
  exit 1
fi

MESSAGE="STAFF ONLY — RECORD THIS SERVICE SEQUENCE

$SEQUENCE

To enter local maintenance:
1. Hold Right Ctrl + Right Alt + Right Shift for 3 seconds.
2. Release all three keys.
3. Press the three function keys above in order within 5 seconds.

The sequence is stored in $SEQUENCE_FILE.
Keep it away from visitors. An administrator password is still required.

Press Enter/OK only after recording the sequence."

if [[ -r /dev/tty && -w /dev/tty ]]; then
  if [[ "${NONINTERACTIVE:-0}" != "1" ]] && command -v dialog >/dev/null 2>&1; then
    dialog --clear --title "yaPDP Kiosk — STAFF ONLY" --msgbox "$MESSAGE" 18 76 < /dev/tty > /dev/tty || true
  else
    printf '\n%s\n\n' "$MESSAGE" > /dev/tty
    if [[ "${NONINTERACTIVE:-0}" != "1" ]]; then
      printf 'Press Enter after recording the service sequence... ' > /dev/tty
      read -r _ < /dev/tty || true
    fi
  fi
else
  echo "Retrieve the service sequence locally with: sudo cat $SEQUENCE_FILE"
fi
