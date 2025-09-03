#!/usr/bin/env bash
step "Choose scope (where the unit will live)"
note "• system → managed by root, starts at boot, units go to /etc/systemd/system"
note "• user   → per-user service, managed with systemctl --user, units go to ~/.config/systemd/user"

choice="$(ask_choice "Scope" \
  "system – root-managed, boots on startup (/etc/systemd/system)" \
  "user – per-user, no sudo (~/.config/systemd/user)")"

if [[ "$choice" == system* ]]; then
  SCOPE="system"
  sudo_warm
else
  SCOPE="user"
fi

return 0
