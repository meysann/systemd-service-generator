#!/usr/bin/env bash
# Step 30: Service type & ExecStart (+ optional PIDFile/WorkingDirectory)

step "Service type & command"

note "Type controls how systemd tracks your app:"
note "• simple  – default; systemd considers the service started once ExecStart begins."
note "• oneshot – run a command and exit (jobs/hooks)."
note "• notify  – app calls sd_notify to signal readiness (advanced)."
note "• forking – legacy daemons that double-fork (needs PIDFile)."

TYPE="$(ask_choice "Service type" "simple" "oneshot" "notify" "forking")"

# ExecStart
while :; do
  [[ "$TYPE" == "oneshot" ]] && note "Enter the command to run once and exit" || note "Enter the long-running command"
  EXEC="$(ask_text "ExecStart command (full command line)")"
  if is_executable_path "$EXEC"; then
    break
  else
    warn "Command not found/executable (the first token)."
    ask_yes_no "Keep this command anyway?" "y/N" && break
  fi
done

# If the command is relative, offer to fix it
if [[ -n "$EXEC" && "$EXEC" != /* ]]; then
  cwd="$(pwd)"
  if ask_yes_no "ExecStart is relative. Convert to absolute using ${cwd}? (recommended)" "Y/n"; then
    EXEC="${cwd}/${EXEC}"
  else
    if [[ -z "${WORKDIR:-}" ]]; then
      ask_yes_no "Set WorkingDirectory to ${cwd}?" "Y/n" && WORKDIR="${cwd}"
    fi
  fi
fi

# PIDFile for forking type
PIDFILE=""
if [[ "$TYPE" == "forking" ]]; then
  PIDFILE="$(ask_text "PIDFile (required for forking daemons)" "/run/${UNIT_NAME}.pid")"
fi

# Optional working directory
WORKDIR="${WORKDIR:-}"
if ask_yes_no "Set WorkingDirectory?" "y/N"; then
  while :; do
    WORKDIR="$(ask_text "  WorkingDirectory path" "${WORKDIR:-}")"
    if [[ -z "$WORKDIR" ]]; then
      break
    elif [[ -d "$WORKDIR" ]]; then
      break
    else
      warn "Directory does not exist."
      ask_yes_no "Use it anyway?" "y/N" && break
    fi
  done
fi

echo
info "Type:         $TYPE"
info "ExecStart:    $EXEC"
[[ -n "$PIDFILE" ]] && info "PIDFile:      $PIDFILE"
[[ -n "$WORKDIR" ]] && info "WorkDir:      $WORKDIR"

return 0
