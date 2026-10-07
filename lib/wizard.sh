#!/usr/bin/env bash
# shellcheck disable=SC2034  # globals are shared across the sourced modules
# wizard.sh — guided interactive flow. Only asks about what was not already
# supplied by flags, a spec file or a preset.

_unset() { [[ -z ${U[$1]:-} ]]; }

# ask for a scalar setting if it is still unset
_ask() { # key prompt default validator [optional]
  local key=$1 prompt=$2 def=${3-} validator=${4-} optional=${5-} v
  _unset "$key" || return 0
  if [[ $optional == opt ]]; then v=$(ask_opt "$prompt" "$def" "$validator"); else v=$(ask_text "$prompt" "$def" "$validator"); fi
  if [[ -n $v ]]; then model_set "$key" "$v"; fi
}

wizard_run() {
  heading "ssg — systemd unit wizard"
  hr
  note "Press Enter to accept the [default]. Ctrl-C aborts without writing anything."

  # --- preset ---------------------------------------------------------------
  if _unset preset; then
    local -a opts=("none|Start from scratch")
    local p
    for p in "${PRESET_NAMES[@]}"; do opts+=("$p|$p — ${PRESET_DESC[$p]}"); done
    p=$(ask_choice "What are you running?" none "${opts[@]}")
    if [[ $p != none ]]; then model_set preset "$p"; fi
  fi
  # apply preset defaults now so later questions see them (idempotent)
  if [[ -n ${U[preset]:-} ]]; then "preset_${U[preset]//-/_}"; fi

  # --- scope ----------------------------------------------------------------
  if _unset scope; then
    local def=system
    [[ $EUID -ne 0 ]] && def=user
    model_set scope "$(ask_choice "Where should it live?" "$def" \
      "system|system — /etc/systemd/system, starts at boot (needs root/sudo)" \
      "user|user — ~/.config/systemd/user, runs as you, starts at login")"
  fi

  # --- when does it run ----------------------------------------------------
  if [[ ${U[preset]:-} == watcher ]] && ! d_has watch; then
    model_set watch "$(ask_text "Path to watch for changes" "" v_abs_path)"
  fi
  if _unset on_calendar && _unset every && ! d_has listen && ! d_has watch && _unset type; then
    case $(ask_choice "When should it run?" always \
      "always|continuously — a long-running service, restarted if it fails" \
      "once|once at start — a job that runs to completion (oneshot)" \
      "schedule|on a schedule — creates a .timer" \
      "socket|on demand when a client connects — creates a .socket" \
      "path|when a file or directory changes — creates a .path") in
      once) model_set type oneshot ;;
      schedule) _wizard_schedule ;;
      socket) model_set listen "$(ask_text "Listen on (PORT, ADDR:PORT or /path/to.sock)" "8080" v_listen)" ;;
      path) model_set watch "$(ask_text "Path to watch for changes" "" v_abs_path)" ;;
    esac
  fi

  # --- command --------------------------------------------------------------
  local hint=""
  [[ -n ${U[preset]:-} ]] && hint=${PRESET_EXEC[${U[preset]}]:-}
  _ask exec "Command to run (absolute path + args)" "$hint" v_cmd
  _ask name "Unit name" "$(sanitize_name "$(basename "$(exec_binary "${U[exec]}")")")" v_name
  _ask desc "Description" "${U[name]} service" v_no_ctl
  _ask workdir "Working directory" "" v_abs_path opt

  # --- identity -------------------------------------------------------------
  if [[ ${U[scope]} == system ]] && _unset user && _unset dynamic_user; then
    case $(ask_choice "Run as which user?" dynamic \
      "dynamic|a throw-away dynamic user (recommended, DynamicUser=yes)" \
      "named|an existing/system user I will name" \
      "root|root (not recommended)") in
      dynamic)
        model_set dynamic_user yes
        _ask state_dir "State directory under /var/lib (writable; blank to skip)" "${U[name]}" v_rel_dir opt
        ;;
      named)
        _ask user "User" "" v_user
        _ask group "Group" "${U[user]}" v_user opt
        ;;
    esac
  fi

  # --- restart / env / network ---------------------------------------------
  if _unset restart && [[ ${U[type]:-simple} != oneshot ]]; then
    model_set restart "$(ask_choice "If it stops unexpectedly…" on-failure \
      "on-failure|restart on crash / non-zero exit (recommended)" \
      "always|always restart" \
      "no|never restart")"
  fi
  if ! d_has env && is_interactive; then
    local e
    while :; do
      e=$(ask_opt "Environment variable KEY=value (Enter when done)" "" v_env)
      [[ -z $e ]] && break
      model_set env "$e"
    done
  fi
  if _unset network; then
    if ask_yes_no "Does it need the network at start-up (wait for network-online)?" n; then model_set network yes; else model_set network no; fi
  fi

  # --- hardening ------------------------------------------------------------
  if _unset harden; then
    model_set harden "$(ask_choice "Security sandbox" standard \
      "none|none — no restrictions" \
      "basic|basic — no new privileges, private /tmp, kernel protections" \
      "standard|standard — + read-only OS, no devices, namespaces/clock locked (recommended)" \
      "strict|strict — + read-only filesystem, syscall filter, no capabilities, W^X")"
  fi
  if [[ ${U[harden]} == strict && ${U[allow_jit]:-no} != yes ]]; then
    if ask_yes_no "Is it a JIT runtime (Node.js, Java, PyPy, .NET)? (disables W^X protection)" n; then model_set allow_jit yes; fi
  fi

  # --- limits ---------------------------------------------------------------
  if _unset mem_max && _unset cpu_quota && ask_yes_no "Set resource limits (memory / CPU)?" n; then
    _ask mem_max "Memory limit (e.g. 512M, 2G)" "" v_mem opt
    _ask cpu_quota "CPU quota (e.g. 50%, 200%)" "" v_cpu opt
  fi
}

_wizard_schedule() {
  local k
  k=$(ask_choice "How often?" daily \
    "hourly|every hour" \
    "daily|every day" \
    "weekly|every week" \
    "interval|every N minutes/hours (since the last run)" \
    "custom|custom OnCalendar expression (see: systemd-analyze calendar)")
  case $k in
    hourly | daily | weekly) model_set on_calendar "$k" ;;
    interval) model_set every "$(ask_text "Interval (e.g. 15min, 2h)" "15min" v_timespan)" ;;
    custom) model_set on_calendar "$(ask_text "OnCalendar expression" "*-*-* 03:00:00" v_calendar)" ;;
  esac
  if [[ -n ${U[on_calendar]:-} ]] && ask_yes_no "Catch up on runs missed while the machine was off (Persistent)?" y; then
    model_set persistent yes
  fi
}
