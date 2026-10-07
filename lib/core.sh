#!/usr/bin/env bash
# core.sh — constants, logging and interactive prompts. Sourced, never executed.
# shellcheck disable=SC2034  # colour/state variables are consumed by other modules

SSG_REPO_URL="https://github.com/meysann/systemd-service-generator"
SSG_DEBUG="${SSG_DEBUG:-0}"
SSG_QUIET=0
SSG_YES=0
VERR=""

ssg_version() {
  local f="$SSG_ROOT/VERSION"
  if [[ -r $f ]]; then tr -d '[:space:]' < "$f"; else printf 'dev'; fi
}

init_colors() {
  if [[ -t 2 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
    C_B=$'\e[1m' C_D=$'\e[2m' C_R=$'\e[31m' C_G=$'\e[32m' C_Y=$'\e[33m' C_C=$'\e[36m' C_0=$'\e[0m'
  else
    C_B="" C_D="" C_R="" C_G="" C_Y="" C_C="" C_0=""
  fi
}
init_colors

err() { printf '%s✖%s %s\n' "$C_R" "$C_0" "$*" >&2; }
warn() { printf '%s▲%s %s\n' "$C_Y" "$C_0" "$*" >&2; }
info() { if ((SSG_QUIET == 0)); then printf '%s✔%s %s\n' "$C_G" "$C_0" "$*" >&2; fi; }
note() { if ((SSG_QUIET == 0)); then printf '%s➤%s %s\n' "$C_C" "$C_0" "$*" >&2; fi; }
dbg() { if ((SSG_DEBUG)); then printf '%s[dbg]%s %s\n' "$C_D" "$C_0" "$*" >&2; fi; }
die() {
  err "$1"
  exit "${2:-1}"
}
hr() { printf '%s────────────────────────────────────────────────────────%s\n' "$C_D" "$C_0" >&2; }
heading() { printf '\n%s%s%s\n' "$C_B" "$*" "$C_0" >&2; }

# ---------------------------------------------------------------- prompts ---
# All prompts write to stderr and read from stdin, so stdout stays clean for
# generated units (`ssg new --stdout > file`).

is_interactive() { [[ -n "${SSG_FORCE_INTERACTIVE:-}" ]] || [[ -t 0 && -t 2 ]]; }

_read() { IFS= read -r REPLY || die "Input closed before all questions were answered." 1; }

# ask_text PROMPT [DEFAULT] [VALIDATOR]   — required answer
ask_text() {
  local p=$1 def=${2-} validator=${3-} ans
  while :; do
    if [[ -n $def ]]; then
      printf '%s%s%s %s[%s]%s: ' "$C_B" "$p" "$C_0" "$C_D" "$def" "$C_0" >&2
    else
      printf '%s%s%s: ' "$C_B" "$p" "$C_0" >&2
    fi
    _read
    ans=${REPLY:-$def}
    if [[ -z $ans ]]; then
      warn "A value is required."
      continue
    fi
    if [[ -n $validator ]] && ! "$validator" "$ans"; then
      warn "$VERR"
      continue
    fi
    printf '%s\n' "$ans"
    return 0
  done
}

# ask_opt PROMPT [DEFAULT] [VALIDATOR]    — Enter skips; a lone "-" clears the default
ask_opt() {
  local p=$1 def=${2-} validator=${3-} ans
  while :; do
    if [[ -n $def ]]; then
      printf '%s%s%s %s[%s, "-" to clear]%s: ' "$C_B" "$p" "$C_0" "$C_D" "$def" "$C_0" >&2
    else
      printf '%s%s%s %s(optional)%s: ' "$C_B" "$p" "$C_0" "$C_D" "$C_0" >&2
    fi
    _read
    ans=${REPLY:-$def}
    [[ $REPLY == "-" ]] && ans=""
    if [[ -n $ans && -n $validator ]] && ! "$validator" "$ans"; then
      warn "$VERR"
      continue
    fi
    printf '%s\n' "$ans"
    return 0
  done
}

# ask_yes_no QUESTION [y|n]
ask_yes_no() {
  local q=$1 def=${2:-n} hint ans
  [[ $def == y ]] && hint="Y/n" || hint="y/N"
  if ((SSG_YES)); then
    [[ $def == y ]]
    return
  fi
  while :; do
    printf '%s%s%s %s[%s]%s ' "$C_B" "$q" "$C_0" "$C_D" "$hint" "$C_0" >&2
    _read
    ans=${REPLY:-$def}
    case "${ans,,}" in
      y | yes) return 0 ;;
      n | no) return 1 ;;
    esac
    warn "Please answer y or n."
  done
}

# ask_choice TITLE DEFAULT_KEY "key|Label — description" ...   → prints key
ask_choice() {
  local title=$1 def=$2 i=0 idx=0 opt ans
  shift 2
  local -a keys=() labels=()
  for opt in "$@"; do
    keys+=("${opt%%|*}")
    labels+=("${opt#*|}")
    [[ ${opt%%|*} == "$def" ]] && idx=$((i + 1))
    i=$((i + 1))
  done
  printf '%s%s%s\n' "$C_B" "$title" "$C_0" >&2
  for ((i = 0; i < ${#keys[@]}; i++)); do
    printf '  %d) %s\n' "$((i + 1))" "${labels[i]}" >&2
  done
  while :; do
    printf '%sChoose%s [1-%d%s]: ' "$C_B" "$C_0" "${#keys[@]}" "${idx:+, Enter=$idx}" >&2
    _read
    ans=${REPLY:-$idx}
    if [[ $ans =~ ^[0-9]+$ ]] && ((ans >= 1 && ans <= ${#keys[@]})); then
      printf '%s\n' "${keys[ans - 1]}"
      return 0
    fi
    warn "Enter a number between 1 and ${#keys[@]}."
  done
}
