#!/usr/bin/env bats

@test "timer step exists (required by main entrypoint)" {
  [ -f "steps/90-timer-config.sh" ]
  bash -n "steps/90-timer-config.sh"
}

@test "generator step contains timer unit generation logic" {
  # Ensure we actually generate a timer unit when TIMER_ENABLED=yes.
  run grep -n "# --- Optional \\.timer unit ---" "steps/80-generate-write.sh"
  [ "$status" -eq 0 ]

  run grep -n "emit_timer \"\\[Timer\\]\"" "steps/80-generate-write.sh"
  [ "$status" -eq 0 ]

  # Use fixed-string grep to avoid escaping issues with ${...} braces.
  run grep -nF "emit_timer \"OnCalendar=\${ON_CALENDAR}\"" "steps/80-generate-write.sh"
  [ "$status" -eq 0 ]

  # Optional timer settings
  run grep -nF "emit_timer \"RandomizedDelaySec=\${RANDOMIZED_DELAY}\"" "steps/80-generate-write.sh"
  [ "$status" -eq 0 ]

  run grep -nF "emit_timer \"AccuracySec=\${ACCURACY}\"" "steps/80-generate-write.sh"
  [ "$status" -eq 0 ]

  run grep -nF "emit_timer \"Persistent=true\"" "steps/80-generate-write.sh"
  [ "$status" -eq 0 ]

  run grep -nF "emit_timer \"WakeSystem=true\"" "steps/80-generate-write.sh"
  [ "$status" -eq 0 ]
}

@test "main script sources the timer step (non-optional)" {
  # bin/ssg uses unbraced variable expansion: source "$ROOT_DIR/steps/90-timer-config.sh"
  run grep -n 'source "\$ROOT_DIR/steps/90-timer-config\.sh"' "bin/ssg"
  [ "$status" -eq 0 ]
}
