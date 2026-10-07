#!/usr/bin/env bash
# shellcheck disable=SC2034  # globals are shared across the sourced modules
# harden.sh — version-aware sandboxing profiles.
#
# Each entry is  Directive=Value|min-systemd-version|scope
#   scope: b = system and user manager, s = system manager only
# Directives newer than the target systemd are skipped automatically.

HARDEN_BASIC=(
  'NoNewPrivileges=yes|187|b'
  'LockPersonality=yes|235|b'
  'RestrictSUIDSGID=yes|242|b'
  'RestrictRealtime=yes|231|b'
  'PrivateTmp=yes|187|s'
  'ProtectKernelModules=yes|232|s'
  'ProtectKernelTunables=yes|232|s'
  'ProtectControlGroups=yes|232|s'
)
HARDEN_STANDARD=(
  'ProtectSystem=full|187|s'
  'ProtectHome=read-only|187|s'
  'PrivateDevices=yes|187|s'
  'ProtectKernelLogs=yes|244|s'
  'ProtectClock=yes|245|s'
  'ProtectHostname=yes|242|s'
  'RestrictNamespaces=yes|233|b'
  'SystemCallArchitectures=native|209|b'
)
HARDEN_STRICT=(
  'ProtectSystem=strict|187|s'
  'ProtectHome=yes|187|s'
  'ProtectProc=invisible|247|s'
  'ProcSubset=pid|247|s'
  'RemoveIPC=yes|212|s'
  'MemoryDenyWriteExecute=yes|231|b'
  'RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6|211|b'
  'SystemCallFilter=@system-service|187|b'
  'SystemCallFilter=~@privileged @resources|187|b'
  'CapabilityBoundingSet=|187|s'
  'UMask=0077|0|b'
)

# Directives counted by `ssg lint` / `ssg score` when judging a unit's sandbox.
SANDBOX_KEYS=(NoNewPrivileges PrivateTmp PrivateDevices ProtectSystem ProtectHome
  ProtectKernelTunables ProtectKernelModules ProtectKernelLogs ProtectControlGroups
  ProtectClock ProtectHostname RestrictNamespaces RestrictRealtime RestrictSUIDSGID
  LockPersonality MemoryDenyWriteExecute RestrictAddressFamilies SystemCallFilter
  SystemCallArchitectures CapabilityBoundingSet)

sd_version() {
  if [[ -z ${SD_VER:-} ]]; then
    if [[ -n ${SSG_SYSTEMD_VERSION:-} ]]; then
      SD_VER=$SSG_SYSTEMD_VERSION
    elif command -v systemctl > /dev/null 2>&1; then
      SD_VER=$(systemctl --version 2> /dev/null | awk 'NR==1{print $2}')
    fi
    [[ ${SD_VER:-} =~ ^[0-9]+$ ]] || SD_VER=255
  fi
  printf '%s' "$SD_VER"
}

# harden_lines LEVEL SCOPE  → fills HARDEN_LINES with final "Key=Value" lines for
# the [Service] section and HARDEN_SKIPPED with options this systemd is too old for.
# Reads the model U[] for allow_jit / no_network / umask / home-path conflicts.
HARDEN_SKIPPED=()
HARDEN_LINES=()
harden_lines() {
  local level=$1 scope=$2 ver entry body min sc key val
  local -a tiers=() out=()
  ver=$(sd_version)
  HARDEN_SKIPPED=()
  HARDEN_LINES=()
  case $level in
    none) ;;
    basic) tiers=("${HARDEN_BASIC[@]}") ;;
    standard) tiers=("${HARDEN_BASIC[@]}" "${HARDEN_STANDARD[@]}") ;;
    strict)
      for entry in "${HARDEN_BASIC[@]}" "${HARDEN_STANDARD[@]}"; do
        case $entry in ProtectSystem=* | ProtectHome=*) continue ;; esac
        tiers+=("$entry")
      done
      tiers+=("${HARDEN_STRICT[@]}")
      ;;
  esac
  for entry in ${tiers[@]+"${tiers[@]}"}; do
    sc=${entry##*|}
    body=${entry%|*}
    min=${body##*|}
    body=${body%|*}
    key=${body%%=*}
    val=${body#*=}
    if [[ $scope == user && $sc == s ]]; then continue; fi
    if ((ver < min)); then
      HARDEN_SKIPPED+=("$key (needs systemd >= $min)")
      continue
    fi
    # user-driven adjustments
    case $key in
      MemoryDenyWriteExecute) [[ ${U[allow_jit]:-no} == yes ]] && continue ;;
      UMask) [[ -n ${U[umask]:-} ]] && continue ;;
      RestrictAddressFamilies)
        if [[ ${U[no_network]:-no} == yes ]]; then val="AF_UNIX"; fi
        ;;
      ProtectHome)
        if [[ $val == yes ]] && _uses_home; then val="read-only"; fi
        ;;
      CapabilityBoundingSet)
        if [[ -n ${U[caps]:-} ]]; then val=$(_caps_joined); fi
        ;;
    esac
    out+=("$key=$val")
  done
  if [[ ${U[no_network]:-no} == yes && $level != none && $scope == system ]]; then
    out+=("PrivateNetwork=yes")
  fi
  # capabilities requested explicitly apply to every level
  if [[ -n ${U[caps]:-} ]]; then
    local caps
    caps=$(_caps_joined)
    local have=0 l
    for l in ${out[@]+"${out[@]}"}; do [[ $l == CapabilityBoundingSet=* ]] && have=1; done
    ((have)) || out+=("CapabilityBoundingSet=$caps")
    out+=("AmbientCapabilities=$caps")
  fi
  HARDEN_LINES=("${out[@]+"${out[@]}"}")
}

_caps_joined() { d_list caps | paste -sd' ' -; }

# True when the command or working dir lives under /home, /root or /run/user.
_uses_home() {
  local p
  for p in "$(exec_binary "${U[exec]:-}")" "${U[workdir]:-}"; do
    [[ $p == /home/* || $p == /root/* || $p == /run/user/* || $p == /home || $p == /root ]] && return 0
  done
  return 1
}
