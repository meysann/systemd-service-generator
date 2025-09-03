# shellcheck disable=SC2034  # color vars used by helpers in this and other sourced files
#!/usr/bin/env bash
# colors (safe fallback)
if command -v tput > /dev/null 2>&1 && tput colors > /dev/null 2>&1; then
  BOLD="$(tput bold)"
  DIM="$(tput dim)"
  NC="$(tput sgr0)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  RED="$(tput setaf 1)"
  CYAN="$(tput setaf 6)"
else
  BOLD=""
  DIM=""
  NC=""
  GREEN=""
  YELLOW=""
  RED=""
  CYAN=""
fi

hr() { printf "%s\n" "${DIM}────────────────────────────────────────────────────────${NC}"; }
step() {
  ((++STEP))
  printf "\n%sStep %d:%s %s\n" "$BOLD" "$STEP" "$NC" "$1"
  hr
}
info() { printf "%b✔%b %s\n" "$GREEN" "$NC" "$*"; }
note() { printf "%b➤%b %s\n" "$CYAN" "$NC" "$*"; }
warn() { printf "%b▲%b %s\n" "$YELLOW" "$NC" "$*"; }

# prompts to stderr, answers to stdout
ask_choice() {
  local title="$1"
  shift
  local options=("$@") ans
  printf "%s%s%s\n" "$BOLD" "$title" "$NC" >&2
  local i=1
  for o in "${options[@]}"; do
    printf "  %d) %s\n" "$i" "$o" >&2
    ((i++))
  done
  while :; do
    printf "Select for \"%s\" [1-%d]: " "$title" "${#options[@]}" >&2
    IFS= read -r ans || true
    [[ "$ans" =~ ^[0-9]+$ ]] && ((ans >= 1 && ans <= ${#options[@]})) && {
      printf "%s\n" "${options[ans - 1]}"
      return
    }
    warn "Enter a number between 1 and ${#options[@]}." >&2
  done
}

# --- extra prompt helpers (append) ---
ask_text() {
  # $1=prompt, $2=default(optional), $3=allow_empty(true/false default false)
  local p="$1" def="${2-}" allow="${3-false}" ans
  while :; do
    if [[ -n "$def" ]]; then
      printf "%s%s%s %s[default: %s]%s: " "$BOLD" "$p" "$NC" "$DIM" "$def" "$NC" >&2
      IFS= read -r ans || true
      ans="${ans:-$def}"
    else
      printf "%s%s%s: " "$BOLD" "$p" "$NC" >&2
      IFS= read -r ans || true
    fi
    [[ -n "$ans" || "$allow" == "true" ]] && {
      printf "%s\n" "$ans"
      return
    }
    warn "Please enter a value." >&2
  done
}

ask_yes_no() {
  # $1=question, $2=default(Y/n or y/N)
  local q="$1" d="${2:-y/N}" ans hint
  case "$d" in Y/n) hint="[Y/n]" ;; y/N) hint="[y/N]" ;; *) hint="[$d]" ;; esac
  while :; do
    printf "%s%s%s %s%s%s " "$BOLD" "$q" "$NC" "$DIM" "$hint" "$NC" >&2
    IFS= read -r ans || true
    ans="${ans:-$d}"
    case "$ans" in Y | y | yes) return 0 ;; N | n | no) return 1 ;; esac
    warn "Please answer y or n." >&2
  done
}
