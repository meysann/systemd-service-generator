#!/usr/bin/env bash
set -Eeuo pipefail
cat << EOF
Systemd Service Generator — Features
-----------------------------------
• Scope — system (/etc/systemd/system) or user (~/.config/systemd/user)
• Unit name & description — base name (no .service) and short text
• Service type — simple / oneshot / notify / forking (forking needs PIDFile)
• ExecStart & WorkingDirectory — command to run (absolute path recommended) and optional work dir
• PIDFile — required for forking daemons
• Lifecycle hooks — ExecStartPre / ExecStartPost / ExecReload / ExecStop
• Restart policy — on-failure / always / no; plus RestartSec; RemainAfterExit for oneshot
• Crash-loop guard — StartLimitIntervalSec + StartLimitBurst
• Dependencies — network-online.target; After=, Wants=, Requires=
• Logging — journal (default) or file (append/truncate); SyslogIdentifier; StandardError routing
• Resource limits — CPUQuota, MemoryMax, TasksMax, LimitNOFILE
• Permissions — UMask for files/dirs created by the service
• Hardening — NoNewPrivileges, PrivateTmp, PrivateDevices, ProtectSystem, ProtectHome,
              ProtectKernelTunables, ProtectKernelModules, ProtectControlGroups,
              RestrictSUIDSGID, RestrictNamespaces, LockPersonality, MemoryDenyWriteExecute
• Run user/group (optional) — run as specific User/Group
• Generate & save — write unit, daemon-reload, enable/start, tail logs
• Export to repo (optional) — copy unit(s) to repo and optionally git commit
• Timer (planned) — .timer with OnCalendar / RandomizedDelaySec / AccuracySec
EOF
