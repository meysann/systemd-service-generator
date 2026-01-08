#!/usr/bin/env bash
# Step 90: Timer configuration (optional)
# shellcheck disable=SC2034  # variables consumed by later steps

step "Timer setup (optional)"

# Ask if user wants to create a timer
if ask_yes_no "Create a .timer unit for this service?" "y/N"; then
  TIMER_ENABLED="yes"

  note "Configure when the timer should run (OnCalendar):"
  note "Examples:"
  note "  daily:            daily"
  note "  every 5 minutes:  *:0/5"
  note "  hourly:           hourly"
  note "  specific time:    Mon,Wed,Fri 14:30:00"
  note "  business hours:   Mon..Fri 09:00:00"
  note "Tip: see systemd.time(7) for syntax if you're unsure."

  # OnCalendar
  while :; do
    ON_CALENDAR="$(ask_text "OnCalendar value" "daily" true)"
    if [[ -n "${ON_CALENDAR}" ]]; then
      break
    fi
    warn "OnCalendar cannot be empty when creating a timer."
  done

  # RandomizedDelaySec (optional)
  note "Optional: add a randomized delay to spread load across machines."
  note "Examples: 30s, 5m, 1h"
  RANDOMIZED_DELAY="$(ask_text "RandomizedDelaySec (blank for none)" "" false)"

  # AccuracySec (optional)
  note "Optional: timer accuracy (lower = more precise, higher = more power-friendly)."
  note "Examples: 1s, 1min, 5min"
  ACCURACY="$(ask_text "AccuracySec (blank for default)" "" false)"

  # Persistent
  if ask_yes_no "Make timer persistent (run missed executions on boot)?" "Y/n"; then
    PERSISTENT="yes"
  else
    PERSISTENT="no"
  fi

  # WakeSystem
  if ask_yes_no "Wake system from sleep/hibernation?" "y/N"; then
    WAKE_SYSTEM="yes"
  else
    WAKE_SYSTEM="no"
  fi

  # Timer description
  TIMER_DESC="$(ask_text "Timer description" "Timer for ${UNIT_DESC}" true)"

  echo
  info "Timer configuration:"
  info "  Service:            ${UNIT_NAME}.service"
  info "  Timer:              ${UNIT_NAME}.timer"
  info "  OnCalendar:         ${ON_CALENDAR}"
  info "  RandomizedDelaySec: ${RANDOMIZED_DELAY:-<none>}"
  info "  AccuracySec:        ${ACCURACY:-<default>}"
  info "  Persistent:         ${PERSISTENT}"
  info "  WakeSystem:         ${WAKE_SYSTEM}"
else
  TIMER_ENABLED="no"
  TIMER_DESC=""
  ON_CALENDAR=""
  RANDOMIZED_DELAY=""
  ACCURACY=""
  PERSISTENT=""
  WAKE_SYSTEM=""
fi

return 0
