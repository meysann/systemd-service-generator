# Contributing to systemd-service-generator

Thanks for your interest!

## Dev setup
Install: shellcheck, bats, shfmt

## Verify locally
Format: shfmt -i 2 -ci -sr -d $(git ls-files '*.sh' 'bin/*' 'lib/*' 'steps/*')
Lint:   shellcheck $(git ls-files '*.sh' 'bin/*' 'lib/*' 'steps/*')
Tests:  bats -r tests

## Style
- Bash only; set -Eeuo pipefail; quote variables.
- Avoid unguarded array refs under set -u.
- Keep steps small and interactive.

## Commit & PR
- Prefer Conventional Commits (feat:, fix:, docs: ...).
- Add tests when practical.
- Update README if user-facing behavior changes.
