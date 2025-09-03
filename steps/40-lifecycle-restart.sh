#!/usr/bin/env bash
# Step 40: Lifecycle hooks & restart policy
# Uses/sets: TYPE, EXEC_PRE[], EXEC_POST, EXEC_RELOAD, EXEC_STOP,
#            RESTART, RESTART_SEC, REMAIN, START_LIMIT_INTERVAL, START_LIMIT_BURST

step "Lifecycle hooks & restart policy"

# --- ExecStartPre (zero or more) ---
if ask_yes_no "Add ExecStartPre commands (run before start)?" "y/N"; then
  while :; do
    pre="$(ask_text "  ExecStartPre command (empty to stop)" "" true)"
    [[ -z "$pre" ]] && break
    EXEC_PRE+=("$pre")
  done
fi

# --- Optional ones ---
if ask_yes_no "Add ExecStartPost (after service starts)?" "y/N"; then
  EXEC_POST="$(ask_text "  ExecStartPost command")"
fi
if ask_yes_no "Add ExecReload (reload configuration)?" "y/N"; then
  EXEC_RELOAD="$(ask_text "  ExecReload command")"
fi
if ask_yes_no "Add ExecStop (graceful stop)?" "y/N"; then
  EXEC_STOP="$(ask_text "  ExecStop command")"
fi

# --- Restart policy ---
RESTART="${RESTART:-no}"
RESTART_SEC="${RESTART_SEC:-}"
REMAIN="${REMAIN:-no}"
START_LIMIT_INTERVAL="${START_LIMIT_INTERVAL:-}"
START_LIMIT_BURST="${START_LIMIT_BURST:-}"

if [[ "$TYPE" == "oneshot" ]]; then
  if ask_yes_no "Keep active state after exit (RemainAfterExit)?" "Y/n"; then
    REMAIN="yes"
  else
    REMAIN="no"
  fi
  local_choice="$(ask_choice "Restart policy (oneshot)" "no (default)" "on-failure" "always")"
  case "$local_choice" in
    no*) RESTART="no" ;;
    on-failure) RESTART="on-failure" ;;
    always) RESTART="always" ;;
  esac
else
  local_choice="$(ask_choice "Restart policy" "on-failure (default)" "always" "no")"
  case "$local_choice" in
    on-failure*) RESTART="on-failure" ;;
    always) RESTART="always" ;;
    no) RESTART="no" ;;
  esac
  RESTART_SEC="$(ask_text "Seconds to wait before restart" "3s")"
  if ask_yes_no "Guard against crash loops (StartLimitInterval/Burst)?" "Y/n"; then
    START_LIMIT_INTERVAL="$(ask_text "  StartLimitIntervalSec" "30s")"
    START_LIMIT_BURST="$(ask_text "  StartLimitBurst" "5")"
  fi
fi

echo
info "Lifecycle summary:"
if ((${#EXEC_PRE[@]} > 0)); then
  info "  ExecStartPre: ${#EXEC_PRE[@]} entr$( ((${#EXEC_PRE[@]} == 1)) && echo 'y' || echo 'ies')"
fi
[[ -n "${EXEC_POST:-}" ]] && info "  ExecStartPost: $EXEC_POST"
[[ -n "${EXEC_RELOAD:-}" ]] && info "  ExecReload:    $EXEC_RELOAD"
[[ -n "${EXEC_STOP:-}" ]] && info "  ExecStop:      $EXEC_STOP"
info "  Restart:       $RESTART"
[[ -n "${RESTART_SEC:-}" ]] && info "  RestartSec:     $RESTART_SEC"
[[ -n "${START_LIMIT_INTERVAL:-}" ]] && info "  StartLimitIntervalSec: $START_LIMIT_INTERVAL"
[[ -n "${START_LIMIT_BURST:-}" ]] && info "  StartLimitBurst:       $START_LIMIT_BURST"
[[ "$TYPE" == "oneshot" ]] && info "  RemainAfterExit: $REMAIN"

return 0
