#!/usr/bin/env bash
# shellcheck disable=SC2034  # globals are shared across the sourced modules
# cli.sh — argument parsing and the `new` command.

# long option → model key (takes a value)
declare -gA OPT_VAL=(
  ["--name"]=name ["--desc"]=desc ["--description"]=desc ["--exec"]=exec ["--user"]=user ["--group"]=group
  ["--workdir"]=workdir ["--type"]=type ["--restart"]=restart ["--restart-sec"]=restart_sec
  ["--stop-timeout"]=stop_timeout ["--start-limit-interval"]=start_limit_interval
  ["--start-limit-burst"]=start_limit_burst ["--env"]=env ["--env-file"]=env_file
  ["--after"]=after ["--wants"]=wants ["--requires"]=requires ["--on-failure"]=on_failure ["--doc"]=doc
  ["--pre"]=pre ["--post"]=post ["--reload"]=reload ["--stop"]=stop ["--syslog-id"]=syslog_id ["--log-file"]=logfile
  ["--harden"]=harden ["--state-dir"]=state_dir ["--cache-dir"]=cache_dir ["--logs-dir"]=logs_dir
  ["--runtime-dir"]=runtime_dir ["--config-dir"]=config_dir ["--rw-path"]=rw_path ["--ro-path"]=ro_path ["--cap"]=caps
  ["--memory-max"]=mem_max ["--cpu-quota"]=cpu_quota ["--tasks-max"]=tasks_max ["--nofile"]=nofile
  ["--umask"]=umask ["--nice"]=nice ["--scope"]=scope ["--wantedby"]=wantedby ["--preset"]=preset
  ["--on-calendar"]=on_calendar ["--every"]=every ["--random-delay"]=random_delay ["--accuracy"]=accuracy
  ["--listen"]=listen ["--watch"]=watch ["--watch-modified"]=watch_modified ["--watch-exists"]=watch_exists
  ["--watch-dir"]=watch_dir ["--set"]=set
)
# long flag → model key (sets "yes")
declare -gA OPT_FLAG=(
  ["--dynamic-user"]=dynamic_user ["--allow-jit"]=allow_jit ["--no-network"]=no_network ["--network"]=network
  ["--persistent"]=persistent ["--remain-after-exit"]=remain ["--bind-low-ports"]=bind_low_ports
)

CLI_OPS=() # "key<TAB>value", applied after --from so flags win over the spec
SPEC_FILE="" SAVE_SPEC="" FORCE_WIZARD=0 NO_WIZARD=0

new_usage() {
  cat << 'USAGE'
Usage: ssg new [OPTIONS] [-- COMMAND [ARGS…]]
       ssg                      (no arguments on a terminal: guided wizard)

What to run
  --exec CMD            command line (or put it after --)
  --name NAME           unit name (default: derived from the binary)
  --desc TEXT           description
  --preset NAME         binary node python java webserver docker-compose cron-job watcher
  --scope system|user   where it lives (default: system)
  --type TYPE           simple|exec|forking|oneshot|notify|dbus|idle
  --workdir DIR  --env KEY=VAL (repeat)  --env-file FILE
  --pre CMD  --post CMD  --reload CMD  --stop CMD   (repeatable ExecStartPre/Post/Reload/Stop)

Identity & lifecycle
  --user U  --group G  --dynamic-user
  --restart POLICY      no|on-failure|always|… (default on-failure; oneshot: no)
  --restart-sec T  --stop-timeout T  --start-limit-interval T  --start-limit-burst N
  --remain-after-exit   --on-failure UNIT
  --after U  --wants U  --requires U   (comma separated / repeatable)
  --network             wait for network-online.target

Triggers (each adds a unit file)
  --on-calendar EXPR    timer: daily, hourly, 'Mon *-*-* 03:00', …
  --every SPAN          timer: every 15min (boot + since last run)
  --persistent  --random-delay T  --accuracy T
  --listen SPEC         socket: 8080, 127.0.0.1:8080, /run/x.sock, udp:5353
  --watch PATH          path unit: run when PATH changes
  --watch-modified P  --watch-exists P  --watch-dir DIR

Security & resources
  --harden LEVEL        none|basic|standard|strict   (default: standard)
  --allow-jit           keep W+X memory allowed (Node, Java, …)
  --no-network          deny network access completely
  --cap CAP_X           grant a capability (repeatable);  --bind-low-ports = CAP_NET_BIND_SERVICE
  --state-dir N --cache-dir N --logs-dir N --runtime-dir N --config-dir N
  --rw-path P  --ro-path P
  --memory-max 512M  --cpu-quota 50%  --tasks-max N  --nofile N  --umask 0027  --nice N
  --log-file PATH  --syslog-id ID
  --set Section.Key=Value   raw directive escape hatch (repeatable)

Output
  --stdout              print the unit(s) only; touch nothing
  --dry-run             show what would be done; touch nothing
  --output DIR          write files into DIR instead of installing
  -y, --yes             no questions; install and apply the --enable/--start flags
  --enable  --start  --now        activate after install (--now = both)
  --force               overwrite existing units (a .bak-TIMESTAMP is kept)
  --no-verify           skip systemd-analyze verify
  --score               show systemd-analyze security after install
  --from FILE           read settings from a spec file (flags override it)
  --save-spec FILE      write the settings to a reusable spec file
  --wizard / --no-wizard
USAGE
}

_cli_op() { CLI_OPS+=("$1"$'\t'"$2"); }

# parse_new_args "$@" — fills CLI_OPS and the O_* output switches
parse_new_args() {
  local a val key
  local -a exec_argv=()
  while (($#)); do
    a=$1
    shift
    local had_eq=0
    if [[ $a == --*=* ]]; then
      set -- "${a#*=}" "$@"
      a=${a%%=*}
      had_eq=1
    fi
    if [[ -n ${OPT_VAL[$a]+x} ]]; then
      (($#)) || die "Option $a needs a value." 2
      val=$1
      shift
      _cli_op "${OPT_VAL[$a]}" "$val"
      continue
    fi
    if [[ -n ${OPT_FLAG[$a]+x} ]]; then
      ((had_eq)) && {
        val=$1
        shift
        _cli_op "${OPT_FLAG[$a]}" "$val"
        continue
      }
      _cli_op "${OPT_FLAG[$a]}" yes
      continue
    fi
    ((had_eq)) && die "Unknown option: $a" 2
    case $a in
      --stdout) O_STDOUT=1 ;;
      --dry-run) O_DRYRUN=1 ;;
      --output)
        O_OUTPUT=${1:?--output needs a directory}
        shift
        ;;
      -y | --yes) SSG_YES=1 ;;
      --enable) O_ENABLE=1 ;;
      --start) O_START=1 ;;
      --now)
        O_ENABLE=1
        O_START=1
        ;;
      --force) O_FORCE=1 ;;
      --no-verify) O_VERIFY=0 ;;
      --score) O_SCORE=1 ;;
      --strict) O_STRICT=1 ;;
      --from)
        SPEC_FILE=${1:?--from needs a file}
        shift
        ;;
      --save-spec)
        SAVE_SPEC=${1:?--save-spec needs a file}
        shift
        ;;
      --wizard) FORCE_WIZARD=1 ;;
      --no-wizard) NO_WIZARD=1 ;;
      -h | --help)
        new_usage
        exit 0
        ;;
      --)
        exec_argv=("$@")
        break
        ;;
      *) die "Unknown option: $a  (try: ssg new --help)" 2 ;;
    esac
  done
  if ((${#exec_argv[@]})); then
    local q joined=""
    for q in "${exec_argv[@]}"; do joined+="${joined:+ }$(quote_exec_arg "$q")"; done
    _cli_op exec "$joined"
  fi
}

apply_cli_ops() {
  local op k v
  for op in ${CLI_OPS[@]+"${CLI_OPS[@]}"}; do
    k=${op%%$'\t'*}
    v=${op#*$'\t'}
    model_set "$k" "$v" || die "--${k//_/-}: $VERR" 2
  done
}

cmd_new() {
  CLI_OPS=()
  model_reset
  parse_new_args "$@"
  [[ -z $SPEC_FILE ]] || spec_load "$SPEC_FILE"
  apply_cli_ops

  # --- wizard? ---
  local want_wizard=0
  if ((FORCE_WIZARD)); then
    want_wizard=1
  elif ((!NO_WIZARD)) && [[ -z ${U[exec]:-} ]] && is_interactive && ((!SSG_YES)); then want_wizard=1; fi
  if ((want_wizard)); then
    is_interactive || die "The wizard needs an interactive terminal." 2
    wizard_run
  fi

  [[ -z $SAVE_SPEC ]] || {
    spec_dump > "$SAVE_SPEC"
    info "Spec saved to $SAVE_SPEC"
  }

  model_finalize
  if ! model_validate; then
    local e
    for e in "${ERRS[@]}"; do err "$e"; done
    exit 2
  fi
  local w
  for w in ${WARNS[@]+"${WARNS[@]}"}; do warn "$w"; done

  render_all
  local s
  for s in ${HARDEN_SKIPPED[@]+"${HARDEN_SKIPPED[@]}"}; do dbg "skipped: $s"; done
  if ((${#HARDEN_SKIPPED[@]})); then
    note "Target systemd $(sd_version): skipped ${#HARDEN_SKIPPED[@]} newer sandbox option(s) (use SSG_SYSTEMD_VERSION to target another version)."
  fi

  # self-lint the generated text — catches mistakes in --set overrides too
  local f tmp lint_out
  tmp=$(mktemp -d)
  for f in "${UNIT_ORDER[@]}"; do
    printf '%s' "${UNITS[$f]}" > "$tmp/$f"
  done
  LINT_ERRORS=0 LINT_WARNINGS=0
  for f in "${UNIT_ORDER[@]}"; do
    lint_out=$(lint_file "$tmp/$f" "${U[scope]}" || true)
    lint_out=$(printf '%s\n' "${lint_out//"$tmp/"/}" | grep -E ': (error|warning):' | grep -v SSG121 || true)
    if [[ -n $lint_out ]]; then printf '%s\n' "$lint_out" >&2; fi
  done
  rm -rf "$tmp"

  if ((O_STDOUT)); then
    print_stdout
    return 0
  fi

  show_units
  if ((O_VERIFY)); then verify_units || { ((O_STRICT)) && die "Verification failed (--strict)." 1; }; fi
  if ((O_DRYRUN)); then
    note "Dry run: would write $(printf '%s ' "${UNIT_ORDER[@]}")to ${O_OUTPUT:-$(unit_dir "${U[scope]}")}"
    return 0
  fi
  if ((!SSG_YES)) && [[ -z $O_OUTPUT ]]; then
    is_interactive || die "Not a terminal: pass --yes to install, or --stdout / --output DIR / --dry-run." 2
  fi
  if ((!SSG_YES)); then
    ask_yes_no "Write these unit(s) to ${O_OUTPUT:-$(unit_dir "${U[scope]}")}?" y || {
      warn "Nothing written."
      return 0
    }
  fi
  install_units
}
