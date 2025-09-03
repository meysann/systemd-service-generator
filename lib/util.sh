#!/usr/bin/env bash
sanitize_unit_name() {
  local n="${1-}"
  [[ -z "${n}" ]] && { printf "%s" ""; return 0; }
  n="${n%.service}"
  n="${n// /-}"
  n="${n//[^A-Za-z0-9@._-]/-}"
  printf "%s" "$n"
}
# absolute path => must be a regular file AND executable; otherwise, look up on PATH
is_executable_path() {
  local cmd="${1-}"; [[ -z "${cmd}" ]] && return 1
  local bin="${cmd%% *}"
  if [[ "$bin" == /* ]]; then [[ -f "$bin" && -x "$bin" ]]
  else command -v "$bin" >/dev/null 2>&1
  fi
}
