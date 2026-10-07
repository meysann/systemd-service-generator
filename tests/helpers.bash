# shared bats helpers
ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SSG="$ROOT/bin/ssg"
export NO_COLOR=1
export SSG_SYSTEMD_VERSION=255

# source the libraries for unit-testing individual functions
load_libs() {
  export SSG_ROOT="$ROOT"
  local m
  for m in core validate model harden presets render install lint explain wizard cli; do
    # shellcheck source=/dev/null
    source "$ROOT/lib/$m.sh"
  done
}

# gen ARGS… → generated units on stdout (stderr discarded)
gen() { "$SSG" new --stdout --no-verify "$@" 2> /dev/null; }
