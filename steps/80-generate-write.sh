#!/usr/bin/env bash
# Step 80: Generate & save the .service file; reload/enable/start (interactive)

step "Generate & save service unit"

# --- helper to append lines safely ---
UNIT_CONTENT=""
emit(){ UNIT_CONTENT+="$1"$'\n'; }

# --- [Unit] ---
emit "[Unit]"
emit "Description=${UNIT_DESC}"
if (( ${#AFTER[@]} > 0 ));    then emit "After=$(IFS=' '; echo "${AFTER[*]}")"; fi
if (( ${#WANTS[@]} > 0 ));    then emit "Wants=$(IFS=' '; echo "${WANTS[*]}")"; fi
if (( ${#REQUIRES[@]} > 0 )); then emit "Requires=$(IFS=' '; echo "${REQUIRES[*]}")"; fi
emit ""

# --- [Service] ---
emit "[Service]"
[[ -n "${TYPE:-}"      ]] && emit "Type=${TYPE}"
[[ -n "${PIDFILE:-}"   ]] && emit "PIDFile=${PIDFILE}"
if (( ${#EXEC_PRE[@]} > 0 )); then
  for pre in "${EXEC_PRE[@]}"; do emit "ExecStartPre=${pre}"; done
fi
[[ -n "${EXEC:-}"      ]] && emit "ExecStart=${EXEC}"
[[ -n "${EXEC_POST:-}" ]] && emit "ExecStartPost=${EXEC_POST}"
[[ -n "${EXEC_RELOAD:-}" ]] && emit "ExecReload=${EXEC_RELOAD}"
[[ -n "${EXEC_STOP:-}" ]] && emit "ExecStop=${EXEC_STOP}"
[[ -n "${WORKDIR:-}"   ]] && emit "WorkingDirectory=${WORKDIR}"

# Logging
[[ -n "${SYSLOG_ID:-}" ]] && emit "SyslogIdentifier=${SYSLOG_ID}"
if [[ "${STDOUT:-journal}" == "journal" ]]; then
  emit "StandardOutput=journal"
  emit "StandardError=inherit"
else
  emit "StandardOutput=${STDOUT}"
  emit "StandardError=${STDERR:-${STDOUT}}"
fi

# Restart policy
[[ -n "${RESTART:-}" && "${RESTART}" != "no" ]] && emit "Restart=${RESTART}"
[[ -n "${RESTART_SEC:-}" ]] && emit "RestartSec=${RESTART_SEC}"
[[ -n "${START_LIMIT_INTERVAL:-}" ]] && emit "StartLimitIntervalSec=${START_LIMIT_INTERVAL}"
[[ -n "${START_LIMIT_BURST:-}"    ]] && emit "StartLimitBurst=${START_LIMIT_BURST}"
[[ "${TYPE:-}" == "oneshot" ]] && [[ -n "${REMAIN:-}" ]] && emit "RemainAfterExit=${REMAIN}"

# Resource limits
[[ -n "${CPU_QUOTA:-}"     ]] && emit "CPUQuota=${CPU_QUOTA}"
[[ -n "${MEM_MAX:-}"       ]] && emit "MemoryMax=${MEM_MAX}"
[[ -n "${TASKS_MAX:-}"     ]] && emit "TasksMax=${TASKS_MAX}"
[[ -n "${LIMIT_NOFILE:-}"  ]] && emit "LimitNOFILE=${LIMIT_NOFILE}"
[[ -n "${UMASK:-}"         ]] && emit "UMask=${UMASK}"

# Hardening
[[ "${NO_NEW_PRIVS:-no}" == "yes" ]]            && emit "NoNewPrivileges=yes"
[[ "${PRIVATE_TMP:-no}" == "yes" ]]             && emit "PrivateTmp=yes"
[[ "${PRIVATE_DEVICES:-no}" == "yes" ]]         && emit "PrivateDevices=yes"
[[ -n "${PROTECT_SYSTEM:-}" ]]                  && emit "ProtectSystem=${PROTECT_SYSTEM}"
[[ -n "${PROTECT_HOME:-}"   ]]                  && emit "ProtectHome=${PROTECT_HOME}"
[[ "${PROTECT_KERNEL_TUNABLES:-no}" == "yes" ]] && emit "ProtectKernelTunables=yes"
[[ "${PROTECT_KERNEL_MODULES:-no}" == "yes"  ]] && emit "ProtectKernelModules=yes"
[[ "${PROTECT_CONTROL_GROUPS:-no}" == "yes" ]]  && emit "ProtectControlGroups=yes"
[[ "${RESTRICT_SUID_SGID:-no}" == "yes" ]]      && emit "RestrictSUIDSGID=yes"
[[ "${RESTRICT_NAMESPACES:-no}" == "yes" ]]     && emit "RestrictNamespaces=yes"
[[ "${LOCK_PERSONALITY:-no}" == "yes" ]]        && emit "LockPersonality=yes"
[[ "${MEMORY_DENY_WX:-no}" == "yes" ]]          && emit "MemoryDenyWriteExecute=yes"

# Optional run user/group (future step; included if set)
[[ -n "${RUN_USER:-}"  ]] && emit "User=${RUN_USER}"
[[ -n "${RUN_GROUP:-}" ]] && emit "Group=${RUN_GROUP}"

emit ""
emit "[Install]"
if [[ "${SCOPE}" == "system" ]]; then
  emit "WantedBy=multi-user.target"
else
  emit "WantedBy=default.target"
fi

# --- Preview ---
note "Preview of ${SERVICE_PATH}"
printf '%s\n' "$UNIT_CONTENT" | sed 's/^/    /'

# --- Save to disk? ---
if ask_yes_no "Write this unit to ${SERVICE_PATH} ?" "Y/n"; then
  target_dir="$(dirname "$SERVICE_PATH")"
  if [[ "${SCOPE}" == "system" ]]; then
    if (( EUID == 0 )); then
      install -d -m 755 "$target_dir"
      printf '%s' "$UNIT_CONTENT" > "$SERVICE_PATH"
    else
      sudo install -d -m 755 "$target_dir"
      printf '%s' "$UNIT_CONTENT" | sudo tee "$SERVICE_PATH" >/dev/null
    fi
  else
    mkdir -p "$target_dir"
    printf '%s' "$UNIT_CONTENT" > "$SERVICE_PATH"
  fi
  info "Wrote ${SERVICE_PATH}"

  # daemon-reload
  if [[ "${SCOPE}" == "system" ]]; then
    if (( EUID == 0 )); then systemctl daemon-reload; else sudo systemctl daemon-reload; fi
  else
    systemctl --user daemon-reload
  fi
  info "daemon-reload done."

  # Enable?
  if ask_yes_no "Enable ${UNIT_NAME}.service?" "Y/n"; then
    if [[ "${SCOPE}" == "system" ]]; then
      if (( EUID == 0 )); then systemctl enable "${UNIT_NAME}.service"; else sudo systemctl enable "${UNIT_NAME}.service"; fi
    else
      systemctl --user enable "${UNIT_NAME}.service"
    fi
    info "Enabled ${UNIT_NAME}.service"
  fi

  # Start?
  if ask_yes_no "Start ${UNIT_NAME}.service now?" "Y/n"; then
    if [[ "${SCOPE}" == "system" ]]; then
      if (( EUID == 0 )); then systemctl start "${UNIT_NAME}.service" || true
      else sudo systemctl start "${UNIT_NAME}.service" || true; fi
    else
      systemctl --user start "${UNIT_NAME}.service" || true
    fi
    echo
    note "Service status (short):"
    if [[ "${SCOPE}" == "system" ]]; then
      systemctl --no-pager --full status "${UNIT_NAME}.service" || true
    else
      systemctl --user --no-pager --full status "${UNIT_NAME}.service" || true
    fi
    if ask_yes_no "Tail logs now (10 lines)?" "y/N"; then
      if [[ "${SCOPE}" == "system" ]]; then
        journalctl -u "${UNIT_NAME}.service" -n 10 --no-pager || true
      else
        journalctl --user -u "${UNIT_NAME}.service" -n 10 --no-pager || true
      fi
    fi
  fi
else
  warn "Skipped writing ${SERVICE_PATH}"
fi

return 0
