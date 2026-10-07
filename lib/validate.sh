#!/usr/bin/env bash
# shellcheck disable=SC2034  # globals are shared across the sourced modules
# validate.sh — input validators and unit-file escaping.
# Validators return 0/1 and put a human message in $VERR.

_fail() {
  VERR=$1
  return 1
}

v_no_ctl() { # no control characters / newlines — prevents directive injection
  if [[ $1 =~ [[:cntrl:]] ]]; then _fail "Control characters and newlines are not allowed."; fi
}

v_name() {
  local n=$1
  [[ $n =~ ^[A-Za-z0-9:_.@-]+$ ]] || _fail "Unit names may only contain A-Z a-z 0-9 : _ . @ -" || return 1
  [[ $n != [-.]* ]] || _fail "Unit names must not start with '-' or '.'" || return 1
  ((${#n} <= 200)) || _fail "Unit name is too long (max 200)." || return 1
}

v_abs_path() {
  v_no_ctl "$1" || return 1
  [[ $1 == /* ]] || _fail "Must be an absolute path (start with /)." || return 1
  [[ $1 != *[[:space:]]* ]] || _fail "Whitespace in paths is not supported here; use a symlink." || return 1
}

v_rel_dir() { # StateDirectory= style: relative, no .. components
  [[ $1 =~ ^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$ ]] || _fail "Use a relative name like 'myapp' (no leading /)." || return 1
  [[ $1 != *..* ]] || _fail "'..' is not allowed." || return 1
}

v_user() {
  [[ $1 =~ ^[a-z_][a-z0-9_-]*\$?$ || $1 =~ ^[0-9]+$ ]] || _fail "Not a valid user/group name." || return 1
  ((${#1} <= 32)) || _fail "Name too long (max 32)." || return 1
}

v_uint() { [[ $1 =~ ^[0-9]+$ ]] || _fail "Must be a non-negative integer."; }
v_nice() { [[ $1 =~ ^-?[0-9]+$ && $1 -ge -20 && $1 -le 19 ]] || _fail "Nice must be between -20 and 19."; }
v_umask() { [[ $1 =~ ^0?[0-7]{3}$ ]] || _fail "Use an octal umask such as 0027."; }
v_mem() { [[ $1 =~ ^[0-9]+[KMGT]?$ || $1 =~ ^[0-9]+%$ || $1 == infinity ]] || _fail "Use e.g. 512M, 2G, 50% or infinity."; }
v_cpu() { [[ $1 =~ ^[0-9]+%$ ]] || _fail "Use a percentage such as 50% or 200%."; }
v_nofile() { [[ $1 =~ ^[0-9]+(:[0-9]+)?$ || $1 == infinity ]] || _fail "Use a number such as 65536 (or soft:hard)."; }

_SPAN_RE='^([0-9]+(\.[0-9]+)?[[:space:]]*(usec|us|msec|ms|seconds|second|sec|s|minutes|minute|min|m|hours|hour|hr|h|days|day|d|weeks|week|w|months|month|M|years|year|y)?[[:space:]]*)+$'
v_timespan() {
  v_no_ctl "$1" || return 1
  [[ $1 == infinity || $1 =~ $_SPAN_RE ]] || _fail "Not a time span (examples: 30s, 5min, 1h, 2d)." || return 1
  if command -v systemd-analyze > /dev/null 2>&1 && [[ -z "${SSG_NO_ANALYZE:-}" ]]; then
    systemd-analyze timespan "$1" > /dev/null 2>&1 || _fail "systemd rejects this time span: $1" || return 1
  fi
}

v_calendar() {
  v_no_ctl "$1" || return 1
  if command -v systemd-analyze > /dev/null 2>&1 && [[ -z "${SSG_NO_ANALYZE:-}" ]]; then
    systemd-analyze calendar "$1" > /dev/null 2>&1 || _fail "systemd rejects this calendar expression: $1" || return 1
  else
    [[ $1 =~ ^[A-Za-z0-9:*,/.~\ -]+$ ]] || _fail "Not a calendar expression (examples: daily, Mon *-*-* 03:00)." || return 1
  fi
}

v_restart() {
  case $1 in
    no | on-success | on-failure | on-abnormal | on-watchdog | on-abort | always) ;;
    *) _fail "Restart must be one of: no on-success on-failure on-abnormal on-watchdog on-abort always" ;;
  esac
}

v_type() {
  case $1 in
    simple | exec | forking | oneshot | notify | notify-reload | dbus | idle) ;;
    *) _fail "Type must be one of: simple exec forking oneshot notify notify-reload dbus idle" ;;
  esac
}

v_harden() {
  case $1 in
    none | basic | standard | strict) ;;
    *) _fail "Hardening level must be: none, basic, standard or strict." ;;
  esac
}

v_scope() { [[ $1 == system || $1 == user ]] || _fail "Scope must be 'system' or 'user'."; }

v_env() {
  v_no_ctl "$1" || return 1
  [[ $1 =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]] || _fail "Use KEY=value (KEY: letters, digits, underscore)." || return 1
}

v_unit_ref() {
  v_no_ctl "$1" || return 1
  [[ $1 =~ ^[A-Za-z0-9:_.@-]+(\.(service|target|socket|timer|path|mount|automount|device|slice|swap|scope))?$ ]] ||
    _fail "Not a unit name: $1" || return 1
}

v_listen() {
  v_no_ctl "$1" || return 1
  local a=${1#udp:}
  if [[ $a == /* || $a == @* ]]; then return 0; fi
  [[ $a =~ ^([0-9]{1,3}(\.[0-9]{1,3}){3}:|\[[0-9a-fA-F:]+\]:)?[0-9]{1,5}$ ]] ||
    _fail "Use PORT, ADDR:PORT, [v6]:PORT, /path/to.sock (prefix 'udp:' for datagram)." || return 1
}

v_cap() { [[ $1 =~ ^CAP_[A-Z_]+$ ]] || _fail "Use a capability name such as CAP_NET_BIND_SERVICE."; }

v_set() { # Section.Key=Value
  v_no_ctl "$1" || return 1
  [[ $1 =~ ^(Unit|Service|Install|Timer|Socket|Path)\.[A-Za-z][A-Za-z0-9]*=.*$ ]] ||
    _fail "Use Section.Key=Value, e.g. Service.SuccessExitStatus=143" || return 1
}

v_cmd() { # an Exec* command line
  v_no_ctl "$1" || return 1
  [[ -n ${1//[[:space:]]/} ]] || _fail "Command is empty." || return 1
}

# ------------------------------------------------------------- escaping ---
# `%` introduces specifiers (%i, %n, %h …). They are meaningful only in
# template units (name@.service); everywhere else a literal % must be %%.
esc_pct() {
  if [[ ${U[name]:-} == *@ ]]; then printf '%s' "$1"; else printf '%s' "${1//%/%%}"; fi
}

# Environment="KEY=value" — escape \ and " inside the double quotes.
esc_env() {
  local v=$1
  v=${v//\\/\\\\}
  v=${v//\"/\\\"}
  esc_pct "$v"
}

_QUOTE_RE='[[:space:]"'"'"'\\;]'
# Quote one argv element for an Exec line (used for the `-- cmd args…` form).
quote_exec_arg() {
  local a=$1
  if [[ -z $a || $a =~ $_QUOTE_RE ]]; then
    a=${a//\\/\\\\}
    a=${a//\"/\\\"}
    printf '"%s"' "$a"
  else
    printf '%s' "$a"
  fi
}

# "My Cool App!" → My-Cool-App-
sanitize_name() {
  local n=${1-}
  n=${n%.service}
  n=${n//[[:space:]]/-}
  n=${n//[^A-Za-z0-9:_.@-]/-}
  while [[ $n == [-.]* ]]; do n=${n#?}; done
  printf '%s' "$n"
}

# Split an Exec line into (modifier-prefix, binary, rest) and resolve a bare
# binary name to an absolute path when possible.
resolve_exec() {
  local line=$1 pre="" bin rest
  while [[ $line == [-@+!:]* ]]; do
    pre+=${line:0:1}
    line=${line:1}
  done
  bin=${line%%[[:space:]]*}
  rest=${line#"$bin"}
  if [[ $bin != /* && $bin != %* ]]; then
    local found
    if found=$(type -P -- "$bin" 2> /dev/null) && [[ $found == /* ]]; then bin=$found; fi
  fi
  printf '%s%s%s' "$pre" "$bin" "$rest"
}

exec_binary() { # absolute binary of an Exec line (modifiers stripped), or empty
  local line=$1
  while [[ $line == [-@+!:]* ]]; do line=${line:1}; done
  printf '%s' "${line%%[[:space:]]*}"
}
