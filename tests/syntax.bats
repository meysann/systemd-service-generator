#!/usr/bin/env bats

@test "all bash files parse cleanly" {
  files=$(git ls-files '*.sh' 'bin/*' 'lib/*' 'steps/*' 2>/dev/null || true)
  for f in $files; do
    [[ -f "$f" ]] || continue
    bash -n "$f"
  done
}
