#!/usr/bin/env bash
# shellcheck disable=SC2034  # globals are shared across the sourced modules
# model.sh — the unit model: one associative array U plus list helpers.
#
# Scalars live in U[key]. Lists (env, after, …) are newline-joined strings in
# U[key]; use d_add / d_list. Values can never contain newlines (validated),
# so this encoding is unambiguous.

declare -gA U=()
declare -ga ERRS=() WARNS=()

LIST_KEYS=" env after wants requires pre post rw_path ro_path caps listen watch watch_modified watch_exists watch_dir set doc "
BOOL_KEYS=" dynamic_user allow_jit no_network network persistent remain "

model_reset() {
  U=()
  ERRS=()
  WARNS=()
}

d_add() { U[$1]+="${U[$1]:+$'\n'}$2"; }
d_list() { if [[ -n ${U[$1]:-} ]]; then printf '%s\n' "${U[$1]}"; fi; }
d_has() { [[ -n ${U[$1]:-} ]]; }

to_bool() {
  case "${1,,}" in
    1 | y | yes | true | on) printf yes ;;
    0 | n | no | false | off) printf no ;;
    *) return 1 ;;
  esac
}

# model_set KEY VALUE — the single entry point used by CLI flags, spec files and
# the wizard. Returns 1 (with VERR) on invalid input.
model_set() {
  local k=${1//-/_} v=$2 b
  case $k in
    name) v_name "$v" || return 1 ;;
    bind_low_ports)
      b=$(to_bool "$v") || {
        VERR="'bind_low_ports' expects yes/no."
        return 1
      }
      if [[ $b == yes ]]; then d_add caps CAP_NET_BIND_SERVICE; fi
      return 0
      ;;
    desc | syslog_id | preset) v_no_ctl "$v" || return 1 ;;
    scope) v_scope "$v" || return 1 ;;
    type) v_type "$v" || return 1 ;;
    restart) v_restart "$v" || return 1 ;;
    harden) v_harden "$v" || return 1 ;;
    exec) v_cmd "$v" || return 1 ;;
    workdir | env_file | logfile | wantedby) v_no_ctl "$v" || return 1 ;;
    user | group) v_user "$v" || return 1 ;;
    restart_sec | stop_timeout | start_limit_interval) v_timespan "$v" || return 1 ;;
    start_limit_burst | tasks_max) v_uint "$v" || return 1 ;;
    nofile) v_nofile "$v" || return 1 ;;
    nice) v_nice "$v" || return 1 ;;
    umask) v_umask "$v" || return 1 ;;
    mem_max) v_mem "$v" || return 1 ;;
    cpu_quota) v_cpu "$v" || return 1 ;;
    state_dir | logs_dir | cache_dir | config_dir | runtime_dir) v_rel_dir "$v" || return 1 ;;
    on_failure) v_unit_ref "$v" || return 1 ;;
    on_calendar) v_calendar "$v" || return 1 ;;
    every | random_delay | accuracy) v_timespan "$v" || return 1 ;;
    env) v_env "$v" || return 1 ;;
    after | wants | requires)
      local item
      for item in ${v//,/ }; do v_unit_ref "$item" || return 1; done
      ;;
    pre | post | reload | stop) v_cmd "$v" || return 1 ;;
    rw_path | ro_path | watch | watch_modified | watch_exists | watch_dir) v_abs_path "$v" || return 1 ;;
    caps) v_cap "$v" || return 1 ;;
    listen) v_listen "$v" || return 1 ;;
    set) v_set "$v" || return 1 ;;
    doc) v_no_ctl "$v" || return 1 ;;
    *)
      if [[ $BOOL_KEYS == *" $k "* ]]; then
        b=$(to_bool "$v") || {
          VERR="'$k' expects yes/no."
          return 1
        }
        v=$b
      else
        VERR="Unknown setting '$1'."
        return 1
      fi
      ;;
  esac
  if [[ $BOOL_KEYS == *" $k "* ]]; then
    b=$(to_bool "$v") || {
      VERR="'$k' expects yes/no."
      return 1
    }
    v=$b
  fi
  case $k in
    after | wants | requires)
      local u
      for u in ${v//,/ }; do
        [[ $u == *.* ]] || u+=".service"
        d_add "$k" "$u"
      done
      ;;
    *)
      if [[ $LIST_KEYS == *" $k "* ]]; then d_add "$k" "$v"; else U[$k]=$v; fi
      ;;
  esac
}

# ---- spec files: KEY=VALUE lines, '#' comments, repeated keys for lists ----
spec_load() {
  local file=$1 line k v n=0
  [[ -r $file ]] || die "Cannot read spec file: $file" 2
  while IFS= read -r line || [[ -n $line ]]; do
    n=$((n + 1))
    line=${line%$'\r'}
    line=${line#"${line%%[![:space:]]*}"}
    [[ -z $line || $line == \#* ]] && continue
    [[ $line == *=* ]] || die "$file:$n: expected key=value" 2
    k=${line%%=*}
    v=${line#*=}
    k=${k%"${k##*[![:space:]]}"}
    v=${v#"${v%%[![:space:]]*}"}
    if [[ $v == \"*\" && ${#v} -ge 2 ]]; then v=${v:1:${#v}-2}; fi
    model_set "$k" "$v" || die "$file:$n: $VERR" 2
  done < "$file"
}

spec_dump() {
  local k item
  printf '# ssg spec — regenerate with: ssg new --from <this file> --yes\n'
  for k in $(printf '%s\n' "${!U[@]}" | sort); do
    [[ $k == preset ]] && {
      printf 'preset=%s\n' "${U[$k]}"
      continue
    }
    if [[ $LIST_KEYS == *" $k "* ]]; then
      while IFS= read -r item; do printf '%s=%s\n' "$k" "$item"; done <<< "${U[$k]}"
    else
      printf '%s=%s\n' "$k" "${U[$k]}"
    fi
  done
}

# ------------------------------------------------------------- finalize ---
p_default() { # preset helper: set only if the user has not
  local k=$1 v=$2
  if [[ $LIST_KEYS == *" $k "* ]]; then
    d_has "$k" || model_set "$k" "$v"
  else
    [[ -n ${U[$k]:-} ]] || model_set "$k" "$v"
  fi
}

model_finalize() {
  local p=${U[preset]:-}
  if [[ -n $p ]]; then
    declare -F "preset_${p//-/_}" > /dev/null || die "Unknown preset '$p' (see: ssg presets)" 2
    "preset_${p//-/_}"
  fi
  [[ -n ${U[scope]:-} ]] || U[scope]=system

  U[has_timer]=no U[has_socket]=no U[has_path]=no
  if [[ -n ${U[on_calendar]:-} || -n ${U[every]:-} ]]; then U[has_timer]=yes; fi
  if d_has listen; then U[has_socket]=yes; fi
  if d_has watch || d_has watch_modified || d_has watch_exists || d_has watch_dir; then U[has_path]=yes; fi

  if [[ -z ${U[name]:-} && -n ${U[exec]:-} ]]; then
    local b
    b=$(exec_binary "${U[exec]}")
    b=$(sanitize_name "${b##*/}")
    [[ -n $b ]] && U[name]=$b
  fi
  if [[ -z ${U[type]:-} ]]; then
    if [[ ${U[has_timer]} == yes || ${U[has_path]} == yes ]]; then U[type]=oneshot; else U[type]=simple; fi
  fi
  if [[ -z ${U[restart]:-} ]]; then
    if [[ ${U[type]} == oneshot ]]; then U[restart]=no; else U[restart]=on-failure; fi
  fi
  if [[ ${U[restart]} != no && -z ${U[restart_sec]:-} ]]; then U[restart_sec]=5s; fi
  [[ -n ${U[harden]:-} ]] || U[harden]=standard
  if [[ -z ${U[desc]:-} && -n ${U[name]:-} ]]; then U[desc]="${U[name]} service"; fi
  if [[ -z ${U[wantedby]:-} ]]; then
    if [[ ${U[scope]} == system ]]; then U[wantedby]=multi-user.target; else U[wantedby]=default.target; fi
  fi
  if [[ ${U[network]:-no} == yes ]]; then
    d_has after || model_set after network-online.target
    d_has wants || model_set wants network-online.target
  fi
  return 0
}

# Which unit files this model produces, primary activation unit first.
model_units() {
  local n=${U[name]}
  if [[ ${U[has_timer]} == yes ]]; then printf '%s.timer\n' "$n"; fi
  if [[ ${U[has_socket]} == yes ]]; then printf '%s.socket\n' "$n"; fi
  if [[ ${U[has_path]} == yes ]]; then printf '%s.path\n' "$n"; fi
  printf '%s.service\n' "$n"
}

# The unit that gets `enable`d / `start`ed.
model_primary() { model_units | head -n1; }

# --------------------------------------------------------------- checks ---
model_validate() {
  ERRS=()
  WARNS=()
  local bin
  [[ -n ${U[name]:-} ]] || ERRS+=("No unit name (use --name).")
  [[ -n ${U[exec]:-} ]] || ERRS+=("No command to run (use --exec, or put the command after --).")
  if ((${#ERRS[@]})); then return 1; fi

  bin=$(exec_binary "${U[exec]}")
  if [[ $bin == /* ]]; then
    if [[ ! -e $bin ]]; then
      WARNS+=("ExecStart binary does not exist (yet): $bin")
    elif [[ ! -x $bin ]]; then
      WARNS+=("ExecStart binary is not executable: $bin")
    fi
  elif [[ $bin != %* ]]; then
    WARNS+=("'$bin' was not found in PATH; systemd needs an absolute path.")
  fi
  if [[ ${U[exec]} =~ (^|[[:space:]])(\||\|\||\&\&|\;|\>|\>\>|\<|2\>\&1)([[:space:]]|$) ]]; then
    WARNS+=("ExecStart contains shell operators; systemd does not run a shell. Wrap with: /bin/sh -c '...'")
  fi
  if [[ ${U[dynamic_user]:-no} == yes && -n ${U[user]:-} ]]; then
    ERRS+=("--dynamic-user and --user are mutually exclusive.")
  fi
  if [[ ${U[scope]} == user ]]; then
    [[ -z ${U[user]:-} && -z ${U[group]:-} ]] || WARNS+=("User=/Group= are ignored by the user manager.")
    [[ ${U[dynamic_user]:-no} == yes ]] && ERRS+=("DynamicUser= is not available in user scope.")
  fi
  if [[ -n ${U[user]:-} && ${U[scope]} == system && ! ${U[user]} =~ ^[0-9]+$ ]] && ! getent passwd "${U[user]}" > /dev/null 2>&1; then
    WARNS+=("User '${U[user]}' does not exist on this machine (create it: useradd --system --no-create-home ${U[user]}).")
  fi
  if [[ -n ${U[group]:-} && ${U[scope]} == system && ! ${U[group]} =~ ^[0-9]+$ ]] && ! getent group "${U[group]}" > /dev/null 2>&1; then
    WARNS+=("Group '${U[group]}' does not exist on this machine.")
  fi
  if [[ -n ${U[workdir]:-} ]]; then
    v_abs_path "${U[workdir]}" || ERRS+=("WorkingDirectory: $VERR")
  fi
  if [[ ${U[type]} == forking ]]; then
    WARNS+=("Type=forking: make sure the daemon writes a PID file and add --set Service.PIDFile=/run/NAME.pid")
  fi
  if [[ ${U[type]} == notify ]]; then
    WARNS+=("Type=notify requires the program to call sd_notify(READY=1), otherwise start will time out.")
  fi
  if [[ ${U[type]} == oneshot && ${U[has_timer]} == no && ${U[has_path]} == no && ${U[restart]} != no ]]; then
    WARNS+=("Restart=${U[restart]} on a oneshot service is usually not what you want.")
  fi
  if [[ ${U[harden]} == strict && -z ${U[state_dir]:-} ]] && ! d_has rw_path && [[ -z ${U[logfile]:-} ]]; then
    WARNS+=("harden=strict makes the file system read-only for the service; add --state-dir NAME or --rw-path DIR if it must write.")
  fi
  if [[ ${U[harden]} != none && ${U[scope]} == user ]]; then
    WARNS+=("User-scope units only get the sandbox options the user manager can apply (no mount namespacing).")
  fi
  if [[ ${U[has_timer]} == yes && -n ${U[on_calendar]:-} && -n ${U[every]:-} ]]; then
    WARNS+=("Both --on-calendar and --every set; the timer will fire for either.")
  fi
  [[ ${U[has_timer]} == yes && ${U[has_socket]} == yes ]] && WARNS+=("Combining timer and socket activation is unusual.")
  ((${#ERRS[@]} == 0))
}
