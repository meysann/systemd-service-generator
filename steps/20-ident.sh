#!/usr/bin/env bash
# Step 20: name & description; computes paths

step "Name & description"

# Choose destination dir from scope
if [[ "$SCOPE" == "system" ]]; then
  UNIT_DIR="/etc/systemd/system"
else
  UNIT_DIR="$HOME/.config/systemd/user"
fi
note "Unit files will be placed under: $UNIT_DIR"

# Ask for base name and check collisions
while :; do
  raw_name="$(ask_text "Unit base name (no .service), e.g., my-app")"
  UNIT_NAME="$(sanitize_unit_name "$raw_name")"
  if [[ -z "$UNIT_NAME" ]]; then
    warn "Name cannot be empty."
    continue
  fi

  SERVICE_PATH="$UNIT_DIR/$UNIT_NAME.service"
  TIMER_PATH="$UNIT_DIR/$UNIT_NAME.timer"

  if [[ -e "$SERVICE_PATH" ]]; then
    warn "A unit named '$UNIT_NAME' already exists at: $SERVICE_PATH"
    ask_yes_no "Overwrite it?" "y/N" || continue
  fi
  break
done

UNIT_DESC="$(ask_text "Short description" "$UNIT_NAME service" true)"

echo
info "Name:         $UNIT_NAME"
info "Description:  $UNIT_DESC"
info "Service path: $SERVICE_PATH"
info "Timer path:   $TIMER_PATH"

return 0
