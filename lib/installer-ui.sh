#!/usr/bin/env bash
# Shared quiet installer UI and persistent diagnostics for yaPDP kiosk scripts.

yapdp_log_init() {
  if [[ -n "${YAPDP_INSTALL_LOG:-}" ]]; then
    LOG_FILE="$YAPDP_INSTALL_LOG"
    return 0
  fi

  local log_dir="/var/log/yapdp-kiosk"
  install -d -m 0750 "$log_dir"
  LOG_FILE="$log_dir/install-$(date +%Y%m%d-%H%M%S)-$$.log"
  export YAPDP_INSTALL_LOG="$LOG_FILE"
  exec > >(tee -a "$LOG_FILE" >/dev/null) 2>&1
  echo "===== yaPDP kiosk installation started: $(date --iso-8601=seconds) ====="
  echo "Log file: $LOG_FILE"
  trap 'yapdp_log_error $? $LINENO "$BASH_COMMAND"' ERR
}

yapdp_log_error() {
  local status="$1" line="$2" command="$3"
  trap - ERR
  {
    echo
    echo "ERROR: command failed with status $status at line $line"
    echo "Command: $command"
    echo "===== installation failed: $(date --iso-8601=seconds) ====="
  } >> "${LOG_FILE:-/dev/null}"
  if [[ -t 0 && -t 1 && -r /dev/tty ]] && command -v dialog >/dev/null 2>&1; then
    dialog --title "yaPDP Kiosk Setup — Error" --msgbox \
      "Installation failed (exit code $status).\n\nDetailed diagnostics were saved to:\n${LOG_FILE:-unknown}" 10 78 < /dev/tty || true
  else
    echo "Installation failed (exit code $status). Log: ${LOG_FILE:-not available}" >&2
  fi
}

# Run a quiet command in the background while keeping the visitor-facing
# terminal alive with a lightweight activity spinner. Command output is still
# captured by the global installer log redirection.
yapdp_run_with_spinner() {
  local message="$1"
  shift
  local pid status frame=0
  local spinner='|/-\'

  ("$@") &
  pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    printf '\r  Working %s  %s' "${spinner:frame%4:1}" "$message" > /dev/tty 2>/dev/null || true
    frame=$((frame + 1))
    sleep 0.12
  done

  if wait "$pid"; then
    status=0
  else
    status=$?
  fi
  printf '\r\033[K' > /dev/tty 2>/dev/null || true
  return "$status"
}

yapdp_phase() {
  local percent="$1" title="$2"
  local width=32 filled empty bar
  local base="${YAPDP_PROGRESS_BASE:-0}" span="${YAPDP_PROGRESS_SPAN:-100}"
  percent=$((base + percent * span / 100))
  (( percent > 100 )) && percent=100
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
    printf '  Detailed output is being saved to:\n  %s\n' "${LOG_FILE:-${YAPDP_INSTALL_LOG:-/var/log/yapdp-kiosk}}"
  } > /dev/tty 2>/dev/null || echo "[$percent%] $title"
}
