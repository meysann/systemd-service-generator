#!/usr/bin/env bash

ensure_bash() { [[ -n "${BASH_VERSION:-}" ]] || { echo "Run with Bash: bash bin/ssg" >&2; exit 1; }; }
ensure_tty()  { [[ -t 0 && -t 1 ]] || { echo "Interactive TTY required." >&2; exit 1; }; }
ensure_systemctl() { command -v systemctl >/dev/null 2>&1 || { echo "systemctl not found (systemd required)." >&2; exit 1; }; }

# set -e safe: use an if-statement so grep's non-match (exit 1) doesn't kill the shell
maybe_warn_crlf() {
  local f="${1:-}"
  [[ -n "$f" && -r "$f" ]] || return 0
  if grep -q $'\r' "$f" 2>/dev/null; then
    echo "Warning: CRLF detected in $f. Fix: sed -i 's/\r$//' $f" >&2
  fi
}

sudo_warm() { (( EUID != 0 )) && sudo -v >/dev/null 2>&1 || true; }
