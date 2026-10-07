#!/usr/bin/env bash
# Run the same checks as CI: shfmt, shellcheck, bats.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
files=(bin/ssg lib/*.sh scripts/*.sh completions/ssg.bash tests/helpers.bash)
echo "== shfmt =="
shfmt -d -i 2 -ci -sr "${files[@]}"
echo "== shellcheck =="
shellcheck -x -e SC1090 -e SC1091 "${files[@]}"
echo "== bats =="
bats -r tests
echo "All checks passed."
