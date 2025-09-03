#!/usr/bin/env bash
set -Eeuo pipefail
files=$(git ls-files "*.sh" "bin/*" "lib/*" "steps/*")
[ -z "$files" ] && { echo "no shell files"; exit 0; }
echo "== shfmt diff =="
shfmt -d -i 2 -ci -sr $files || true
echo "== shellcheck (errors cause nonzero) =="
shellcheck -S error -e SC1090 -e SC1091 $files
echo "== shellcheck (warnings/info, non-fatal) =="
shellcheck -S warning -e SC1090 -e SC1091 $files || true
echo "== bats tests =="
[ -d tests ] && bats -r tests || echo "no tests/"
