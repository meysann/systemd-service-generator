#!/usr/bin/env bash
# Step 50: Dependencies & ordering
# Fills arrays: AFTER[], WANTS[], REQUIRES[]

step "Dependencies & ordering"

# Network readiness helper (common need for networked apps)
if ask_yes_no "Does the service need the network to be fully up? (adds network-online.target)" "Y/n"; then
  AFTER+=("network-online.target")
  WANTS+=("network-online.target")
fi

# Add After= (ordering)
if ask_yes_no "Add unit(s) to After= ? (start *after* these units)" "y/N"; then
  while :; do
    u="$(ask_text "  Unit name for After= (empty to stop)" "" true)"
    [[ -z "$u" ]] && break
    AFTER+=("$u")
  done
fi

# Add Wants= (soft dependency)
if ask_yes_no "Add unit(s) to Wants= ? (soft dependency; try to start them)" "y/N"; then
  while :; do
    u="$(ask_text "  Unit name for Wants= (empty to stop)" "" true)"
    [[ -z "$u" ]] && break
    WANTS+=("$u")
  done
fi

# Add Requires= (hard dependency)
if ask_yes_no "Add unit(s) to Requires= ? (hard dependency; fail if they fail)" "y/N"; then
  while :; do
    u="$(ask_text "  Unit name for Requires= (empty to stop)" "" true)"
    [[ -z "$u" ]] && break
    REQUIRES+=("$u")
  done
fi

echo
info "Dependencies summary:"
((${#AFTER[@]} > 0)) && info "  After=    ${AFTER[*]}"
((${#WANTS[@]} > 0)) && info "  Wants=    ${WANTS[*]}"
((${#REQUIRES[@]} > 0)) && info "  Requires= ${REQUIRES[*]}"

return 0
