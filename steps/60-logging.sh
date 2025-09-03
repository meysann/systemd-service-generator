#!/usr/bin/env bash
# shellcheck disable=SC2015
# Step 60: Logging (journal vs file) + SyslogIdentifier
# Sets: SYSLOG_ID, LOGFILE, STDOUT, STDERR

step "Logging & SyslogIdentifier"

# defaults
SYSLOG_ID="${SYSLOG_ID:-$UNIT_NAME}"
STDOUT="${STDOUT:-journal}"
STDERR="${STDERR:-journal}"
LOGFILE="${LOGFILE:-}"

note "By default, logs go to the journal (view: journalctl -u ${UNIT_NAME} -f)."

if ask_yes_no "Log to a FILE instead of the journal?" "y/N"; then
  # Get log path
  while :; do
    LOGFILE="$(ask_text "  Log file path (e.g., /var/log/${UNIT_NAME}/${UNIT_NAME}.log)")"
    [[ -n "$LOGFILE" ]] && break
    warn "Please provide a file path."
  done

  # Warn about user scope writing to root-owned dirs
  if [[ "${SCOPE}" == "user" && "${LOGFILE}" != "$HOME"* ]]; then
    warn "User services usually cannot write to ${LOGFILE}. Prefer a path under your HOME."
  fi

  # Check systemd version for append:/truncate: support (>= 240)
  SYSTEMD_VER="$(systemctl --version 2> /dev/null | head -n1 | awk '{print $2}' || echo 0)"
  supports=false
  [[ "$SYSTEMD_VER" =~ ^[0-9]+$ ]] && ((SYSTEMD_VER >= 240)) && supports=true

  mode="$(ask_choice "  File mode" "append (keep existing content)" "truncate (overwrite on start)")"
  if [[ "$mode" == append* ]]; then
    if $supports; then
      STDOUT="append:${LOGFILE}"
      STDERR="append:${LOGFILE}"
    else
      warn "systemd $SYSTEMD_VER lacks append:/truncate: → using file: (truncate on start)."
      STDOUT="file:${LOGFILE}"
      STDERR="file:${LOGFILE}"
    fi
  else
    if $supports; then
      STDOUT="truncate:${LOGFILE}"
      STDERR="truncate:${LOGFILE}"
    else
      STDOUT="file:${LOGFILE}"
      STDERR="file:${LOGFILE}"
    fi
  fi

  # Offer to create the log directory now (quality-of-life)
  logdir="$(dirname "$LOGFILE")"
  if [[ ! -d "$logdir" ]]; then
    if ask_yes_no "  Create directory ${logdir} now?" "Y/n"; then
      if [[ "${SCOPE}" == "system" ]]; then
        ((EUID == 0)) && mkdir -p "$logdir" || sudo mkdir -p "$logdir"
        # optional ownership to service user (if later set)
        if [[ -n "${RUN_USER:-}" && -n "${RUN_GROUP:-}" ]]; then
          ask_yes_no "  chown -R ${RUN_USER}:${RUN_GROUP} ${logdir} ?" "y/N" && { ((EUID == 0)) && chown -R "${RUN_USER}:${RUN_GROUP}" "$logdir" || sudo chown -R "${RUN_USER}:${RUN_GROUP}" "$logdir"; }
        fi
      else
        mkdir -p "$logdir"
      fi
      info "Created ${logdir}"
    fi
  fi
else
  STDOUT="journal"
  STDERR="journal"
fi

SYSLOG_ID="$(ask_text "SyslogIdentifier (tag in journal)" "${SYSLOG_ID}" true)"

echo
info "Logging summary:"
info "  SyslogIdentifier: ${SYSLOG_ID}"
if [[ "${STDOUT}" == "journal" ]]; then
  info "  Output: journal (journalctl -u ${UNIT_NAME} -f)"
else
  info "  Output: ${STDOUT}"
  [[ -n "${LOGFILE}" ]] && info "  File:   ${LOGFILE}"
fi

return 0
