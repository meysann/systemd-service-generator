#!/usr/bin/env bash
# Step 70: Resource limits & hardening
# Sets vars: CPU_QUOTA, MEM_MAX, TASKS_MAX, LIMIT_NOFILE, UMASK
#            NO_NEW_PRIVS, PRIVATE_TMP, PRIVATE_DEVICES,
#            PROTECT_SYSTEM, PROTECT_HOME,
#            PROTECT_KERNEL_TUNABLES, PROTECT_KERNEL_MODULES, PROTECT_CONTROL_GROUPS,
#            RESTRICT_SUID_SGID, RESTRICT_NAMESPACES, LOCK_PERSONALITY, MEMORY_DENY_WX

step "Resource limits & hardening"

# --- Resource limits (optional) ---
if ask_yes_no "Set resource limits (CPU/Memory/Tasks/NOFILE)?" "y/N"; then
  CPU_QUOTA="$(ask_text "  CPUQuota (e.g., 50%%; empty = unlimited)" "" true)"
  MEM_MAX="$(ask_text "  MemoryMax (e.g., 512M; empty = unlimited)" "" true)"
  TASKS_MAX="$(ask_text "  TasksMax (e.g., 500; empty = default)" "" true)"
  LIMIT_NOFILE="$(ask_text "  LimitNOFILE (e.g., 65535; empty = default)" "" true)"
fi

# --- UMask (optional) ---
if ask_yes_no "Set service UMask? (controls default file perms)" "y/N"; then
  UMASK="$(ask_text "  UMask (e.g., 0027)" "0027")"
fi

# --- Hardening toggles (opt-in; defaults conservative to avoid breakage) ---
NO_NEW_PRIVS="no"
ask_yes_no "Enable NoNewPrivileges? (blocks gaining new privileges)" "y/N" && NO_NEW_PRIVS="yes"

PRIVATE_TMP="no"
ask_yes_no "Enable PrivateTmp? (isolated /tmp)" "y/N" && PRIVATE_TMP="yes"

PRIVATE_DEVICES="no"
ask_yes_no "Enable PrivateDevices? (hide most of /dev)" "y/N" && PRIVATE_DEVICES="yes"

# ProtectSystem
psel="$(ask_choice "ProtectSystem level" "no (default)" "full (protect /usr /boot /etc readonly)" "strict (protect whole FS readonly)")"
case "$psel" in
  no*)     PROTECT_SYSTEM="";;
  full*)   PROTECT_SYSTEM="full";;
  strict*) PROTECT_SYSTEM="strict";;
esac

# ProtectHome
hsel="$(ask_choice "ProtectHome" "no (default)" "read-only" "tmpfs")"
case "$hsel" in
  no*)        PROTECT_HOME="";;
  read-only)  PROTECT_HOME="read-only";;
  tmpfs)      PROTECT_HOME="tmpfs";;
esac

PROTECT_KERNEL_TUNABLES="no"
ask_yes_no "ProtectKernelTunables? (deny /proc/sys etc.)" "y/N" && PROTECT_KERNEL_TUNABLES="yes"

PROTECT_KERNEL_MODULES="no"
ask_yes_no "ProtectKernelModules? (deny module ops)" "y/N" && PROTECT_KERNEL_MODULES="yes"

PROTECT_CONTROL_GROUPS="no"
ask_yes_no "ProtectControlGroups? (deny cgroup tree)" "y/N" && PROTECT_CONTROL_GROUPS="yes"

RESTRICT_SUID_SGID="no"
ask_yes_no "RestrictSUIDSGID? (block setuid/setgid binaries)" "y/N" && RESTRICT_SUID_SGID="yes"

RESTRICT_NAMESPACES="no"
ask_yes_no "RestrictNamespaces? (block creating namespaces)" "y/N" && RESTRICT_NAMESPACES="yes"

LOCK_PERSONALITY="no"
ask_yes_no "LockPersonality? (block arch changes)" "y/N" && LOCK_PERSONALITY="yes"

MEMORY_DENY_WX="no"
ask_yes_no "MemoryDenyWriteExecute? (W^X enforcement)" "y/N" && MEMORY_DENY_WX="yes"

echo
info "Limits & hardening summary:"
[[ -n "${CPU_QUOTA:-}"   ]] && info "  CPUQuota:             ${CPU_QUOTA}"
[[ -n "${MEM_MAX:-}"     ]] && info "  MemoryMax:            ${MEM_MAX}"
[[ -n "${TASKS_MAX:-}"   ]] && info "  TasksMax:             ${TASKS_MAX}"
[[ -n "${LIMIT_NOFILE:-}" ]] && info "  LimitNOFILE:          ${LIMIT_NOFILE}"
[[ -n "${UMASK:-}"       ]] && info "  UMask:                ${UMASK}"
[[ "${NO_NEW_PRIVS}" == "yes"         ]] && info "  NoNewPrivileges:      yes"
[[ "${PRIVATE_TMP}" == "yes"          ]] && info "  PrivateTmp:           yes"
[[ "${PRIVATE_DEVICES}" == "yes"      ]] && info "  PrivateDevices:       yes"
[[ -n "${PROTECT_SYSTEM:-}"           ]] && info "  ProtectSystem:        ${PROTECT_SYSTEM}"
[[ -n "${PROTECT_HOME:-}"             ]] && info "  ProtectHome:          ${PROTECT_HOME}"
[[ "${PROTECT_KERNEL_TUNABLES}" == "yes"  ]] && info "  ProtectKernelTunables: yes"
[[ "${PROTECT_KERNEL_MODULES}" == "yes"   ]] && info "  ProtectKernelModules:  yes"
[[ "${PROTECT_CONTROL_GROUPS}" == "yes"   ]] && info "  ProtectControlGroups:  yes"
[[ "${RESTRICT_SUID_SGID}" == "yes"      ]] && info "  RestrictSUIDSGID:      yes"
[[ "${RESTRICT_NAMESPACES}" == "yes"     ]] && info "  RestrictNamespaces:    yes"
[[ "${LOCK_PERSONALITY}" == "yes"        ]] && info "  LockPersonality:       yes"
[[ "${MEMORY_DENY_WX}" == "yes"         ]] && info "  MemoryDenyWriteExecute: yes"

return 0
