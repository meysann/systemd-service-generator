#!/usr/bin/env bash
# shellcheck disable=SC2034  # globals are shared across the sourced modules
# install.sh — write units safely, verify them, and drive systemctl.

O_OUTPUT="" O_DRYRUN=0 O_FORCE=0 O_VERIFY=1 O_ENABLE=0 O_START=0 O_SCORE=0 O_STDOUT=0 O_STRICT=0

unit_dir() { # scope
  if [[ $1 == system ]]; then
    printf '/etc/systemd/system'
  else
    printf '%s/systemd/user' "${XDG_CONFIG_HOME:-$HOME/.config}"
  fi
}

# run a command with privileges when writing to the system manager
_priv() {
  if [[ ${U[scope]} == system && $EUID -ne 0 && -z $O_OUTPUT ]]; then
    command -v sudo > /dev/null 2>&1 || die "Root is required to write to /etc/systemd/system (sudo not found)."
    sudo "$@"
  else
    "$@"
  fi
}

_sctl() { # systemctl for the right manager, with privileges when needed
  if [[ ${U[scope]} == user ]]; then systemctl --user "$@"; else _priv systemctl "$@"; fi
}

# Verify a unit set in a scratch dir. systemd-analyze checks syntax, unknown
# directives and dependency references without touching the real system.
verify_units() {
  command -v systemd-analyze > /dev/null 2>&1 || {
    warn "systemd-analyze not found — skipping verification."
    return 0
  }
  local tmp f rc=0 out
  tmp=$(mktemp -d)
  for f in "${UNIT_ORDER[@]}"; do printf '%s' "${UNITS[$f]}" > "$tmp/$f"; done
  local -a args=(verify --man=no)
  [[ ${U[scope]} == user ]] && args=(--user "${args[@]}")
  local -a files=()
  for f in "${UNIT_ORDER[@]}"; do files+=("$tmp/$f"); done
  out=$(systemd-analyze "${args[@]}" "${files[@]}" 2>&1) || rc=$?
  out=${out//"$tmp/"/}
  rm -rf "$tmp"
  if [[ -n $out ]]; then
    printf '%s\n' "$out" | sed 's/^/    /' >&2
  fi
  if ((rc != 0)); then
    warn "systemd-analyze verify reported problems (exit $rc). A missing binary is expected if it is not installed yet."
    return 1
  fi
  info "systemd-analyze verify: OK"
}

show_units() {
  local f
  for f in "${UNIT_ORDER[@]}"; do
    printf '\n%s# %s%s\n' "$C_B" "$f" "$C_0" >&2
    printf '%s' "${UNITS[$f]}" | sed 's/^/    /' >&2
  done
  printf '\n' >&2
}

print_stdout() {
  local f multi=0
  ((${#UNIT_ORDER[@]} > 1)) && multi=1
  for f in "${UNIT_ORDER[@]}"; do
    if ((multi)); then printf '# ===== %s =====\n' "$f"; fi
    printf '%s' "${UNITS[$f]}"
    if ((multi)); then printf '\n'; fi
  done
}

write_unit() { # dir filename
  local dir=$1 f=$2 dest tmp
  dest=$dir/$f
  tmp=$(mktemp)
  printf '%s' "${UNITS[$f]}" > "$tmp"
  if [[ -e $dest ]]; then
    if cmp -s "$tmp" "$dest"; then
      info "$dest is already up to date."
      rm -f "$tmp"
      return 0
    fi
    note "$dest exists and differs:"
    diff -u "$dest" "$tmp" 2> /dev/null | sed 's/^/    /' >&2 || true
    if ((!O_FORCE)) && ((!SSG_YES)); then
      if is_interactive; then
        ask_yes_no "Overwrite $dest (a backup is kept)?" n || {
          warn "Skipped $f"
          rm -f "$tmp"
          return 0
        }
      else
        rm -f "$tmp"
        die "$dest exists. Re-run with --force (or --yes) to overwrite; a backup is kept." 1
      fi
    fi
    local bak
    bak="$dest.bak-$(date +%Y%m%d-%H%M%S)"
    _priv cp -p "$dest" "$bak"
    info "Backup: $bak"
  fi
  _priv install -d -m 0755 "$dir"
  _priv install -m 0644 "$tmp" "$dest"
  rm -f "$tmp"
  info "Wrote $dest"
}

install_units() {
  local dir f primary
  if [[ -n $O_OUTPUT ]]; then dir=$O_OUTPUT; else dir=$(unit_dir "${U[scope]}"); fi
  for f in "${UNIT_ORDER[@]}"; do write_unit "$dir" "$f"; done
  [[ -n $O_OUTPUT ]] && {
    note "Files written to $O_OUTPUT (no systemctl actions performed)."
    return 0
  }

  command -v systemctl > /dev/null 2>&1 || die "systemctl not found; units were written but not activated."
  _sctl daemon-reload
  info "daemon-reload done."
  primary=$(model_primary)

  local do_enable=$O_ENABLE do_start=$O_START
  if ((!do_enable)) && is_interactive && ((!SSG_YES)); then ask_yes_no "Enable $primary (start at boot/login)?" y && do_enable=1; fi
  if ((do_enable)); then
    _sctl enable "$primary" 2>&1 | sed 's/^/    /' >&2
    info "Enabled $primary"
  fi
  if ((!do_start)) && is_interactive && ((!SSG_YES)); then ask_yes_no "Start $primary now?" y && do_start=1; fi
  if ((do_start)); then
    if _sctl start "$primary"; then
      info "Started $primary"
    else
      warn "Start failed — see: journalctl ${U[scope]/system/} -xeu $primary"
    fi
    _sctl --no-pager --full status "$primary" 2>&1 | sed 's/^/    /' >&2 || true
  fi
  if ((O_SCORE)); then score_unit "${U[name]}.service" "${U[scope]}"; fi
  next_steps "$primary"
}

next_steps() {
  local primary=$1 flag=""
  [[ ${U[scope]} == user ]] && flag=" --user"
  heading "Next steps"
  printf '  logs     journalctl%s -u %s -f\n' "$flag" "${U[name]}.service" >&2
  printf '  status   systemctl%s status %s\n' "$flag" "$primary" >&2
  printf '  security systemd-analyze%s security %s.service   (or: ssg score %s)\n' "$flag" "${U[name]}" "${U[name]}" >&2
  printf '  remove   ssg uninstall %s%s\n' "${U[name]}" "$([[ ${U[scope]} == user ]] && printf ' --scope user')" >&2
}

score_unit() { # unit scope
  command -v systemd-analyze > /dev/null 2>&1 || die "systemd-analyze not found."
  local -a a=(security --no-pager)
  [[ $2 == user ]] && a=(--user "${a[@]}")
  systemd-analyze "${a[@]}" "$1" 2>&1 | sed 's/^/  /' >&2
}

cmd_uninstall() {
  local scope=system name="" a
  while (($#)); do
    a=$1
    shift
    case $a in
      --scope)
        scope=${1:?--scope needs a value}
        shift
        ;;
      --scope=*) scope=${a#*=} ;;
      -y | --yes) SSG_YES=1 ;;
      -h | --help)
        printf 'Usage: ssg uninstall NAME [--scope system|user] [--yes]\n'
        return 0
        ;;
      -*) die "Unknown option: $a" 2 ;;
      *) name=$a ;;
    esac
  done
  v_scope "$scope" || die "$VERR" 2
  [[ -n $name ]] || die "Usage: ssg uninstall NAME" 2
  v_name "$name" || die "$VERR" 2
  name=${name%.service}
  U[scope]=$scope
  local dir ext found=() f
  dir=$(unit_dir "$scope")
  for ext in timer socket path service; do
    f="$dir/$name.$ext"
    [[ -e $f ]] && found+=("$name.$ext")
  done
  ((${#found[@]})) || die "No $name.{timer,socket,path,service} found in $dir" 1
  note "Will stop, disable and delete from $dir: ${found[*]}"
  if ((!SSG_YES)); then ask_yes_no "Continue?" n || die "Aborted." 1; fi
  for f in "${found[@]}"; do
    _sctl disable --now "$f" > /dev/null 2>&1 || true
    _priv rm -f -- "$dir/$f"
    info "Removed $f"
  done
  _sctl daemon-reload
}
