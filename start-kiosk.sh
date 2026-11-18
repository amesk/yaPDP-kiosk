#!/usr/bin/env bash
set -euo pipefail

KIOSK_URL="${KIOSK_URL:-http://127.0.0.1:8080/}"
PROFILE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/yapdp-kiosk/chrome-profile"

if command -v google-chrome-stable >/dev/null 2>&1; then
  BROWSER="$(command -v google-chrome-stable)"
elif command -v google-chrome >/dev/null 2>&1; then
  BROWSER="$(command -v google-chrome)"
elif command -v chromium >/dev/null 2>&1; then
  BROWSER="$(command -v chromium)"
elif command -v chromium-browser >/dev/null 2>&1; then
  BROWSER="$(command -v chromium-browser)"
else
  echo "Chrome/Chromium was not found. Install Google Chrome before starting the kiosk." >&2
  exit 1
fi

mkdir -p "$PROFILE_DIR"

# Disable the common GNOME shortcuts that can reveal the desktop or switch
# away from the kiosk window. These are per-user settings: the administrator's
# desktop remains unaffected. Run from the graphical session, where gsettings
# has access to the kiosk user's dconf database.
#
# switch-to-session-1..12 are the compositor's own Ctrl+Alt+F1..F12 handlers.
# gnome-kiosk runs Mutter, which owns those shortcuts, so clearing them is what
# keeps a visitor on the exhibit VT. The installer seeds the same values before
# the session starts and additionally suppresses Magic SysRq, Ctrl+Alt+Del and
# the logind power/reboot keys, which no user-space shortcut can block.
disable_gnome_shortcuts() {
  local schema key
  local -a wm_keys=(
    close minimize maximize unmaximize
    switch-applications switch-applications-backward
    switch-windows switch-windows-backward
    switch-group switch-group-backward
    switch-to-workspace-left switch-to-workspace-right
    switch-to-workspace-up switch-to-workspace-down
    move-to-workspace-left move-to-workspace-right
    move-to-workspace-up move-to-workspace-down
    panel-run-dialog show-desktop
  )
  local -a mutter_keys=(
    switch-to-session-1 switch-to-session-2 switch-to-session-3
    switch-to-session-4 switch-to-session-5 switch-to-session-6
    switch-to-session-7 switch-to-session-8 switch-to-session-9
    switch-to-session-10 switch-to-session-11 switch-to-session-12
  )
  local -a shell_keys=(
    toggle-overview toggle-application-view toggle-message-tray
    show-screenshot-ui show-screen-recording-ui open-application-menu
    lock-screen logout power-off
    switch-to-application-1 switch-to-application-2 switch-to-application-3
    switch-to-application-4 switch-to-application-5 switch-to-application-6
    switch-to-application-7 switch-to-application-8 switch-to-application-9
  )

  for key in "${wm_keys[@]}"; do
    gsettings set org.gnome.desktop.wm.keybindings "$key" "[]" 2>/dev/null || true
  done
  # switch-to-session-N does not exist in every mutter/gnome-kiosk build, so
  # only write the keys this schema actually ships.
  local mutter_available
  mutter_available="$(gsettings list-keys org.gnome.mutter.keybindings 2>/dev/null || true)"
  for key in "${mutter_keys[@]}"; do
    if printf '%s\n' "$mutter_available" | grep -Fxq "$key"; then
      gsettings set org.gnome.mutter.keybindings "$key" "@as []" 2>/dev/null || true
    fi
  done
  for key in "${shell_keys[@]}"; do
    gsettings set org.gnome.shell.keybindings "$key" "[]" 2>/dev/null || true
  done
}

# A public exhibit must not blank or lock the kiosk session while idle.
# Apply these per-user GNOME settings from the live graphical session so they
# are written to this account's dconf database, not the administrator's.
disable_idle_lock() {
  gsettings set org.gnome.desktop.screensaver lock-enabled false
  gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
  gsettings set org.gnome.desktop.session idle-delay 0
}

disable_gnome_shortcuts
disable_idle_lock

# Chrome's kiosk flag is presentation, not process supervision. If a visitor
# closes it (Alt+F4, Ctrl+Q, etc.), relaunch it instead of leaving the desktop
# exposed. A short delay avoids a tight loop if Chrome cannot start.
while true; do
  "$BROWSER" \
    --kiosk \
    --no-first-run \
    --no-default-browser-check \
    --password-store=basic \
    --disable-session-crashed-bubble \
    --disable-infobars \
    --user-data-dir="$PROFILE_DIR" \
    "$KIOSK_URL" || true
  sleep 2
done
