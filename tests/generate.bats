#!/usr/bin/env bats
load helpers

@test "minimal service has secure defaults and an [Install] section" {
  run gen --exec /bin/true --name demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"ExecStart=/bin/true"* ]]
  [[ "$output" == *"Restart=on-failure"* ]]
  [[ "$output" == *"NoNewPrivileges=yes"* ]]
  [[ "$output" == *"ProtectSystem=full"* ]]
  [[ "$output" == *"WantedBy=multi-user.target"* ]]
}

@test "name is derived from the binary" {
  run gen --exec "/bin/true --x"
  [[ "$output" == *"Description=true service"* ]]
}

@test "StartLimit* land in [Unit], not [Service]" {
  out=$(gen --exec /bin/true --name d --start-limit-interval 60s --start-limit-burst 5)
  unit_part=${out%%\[Service\]*}
  [[ "$unit_part" == *"StartLimitIntervalSec=60s"* ]]
  [[ "$unit_part" == *"StartLimitBurst=5"* ]]
}

@test "directive injection through --desc is rejected" {
  run "$SSG" new --stdout --exec /bin/true --desc $'x\nExecStartPre=/bin/evil'
  [ "$status" -eq 2 ]
  [[ "$output" != *"/bin/evil"* ]] || [[ "$output" == *"not allowed"* ]]
}

@test "percent signs are escaped, except in template units" {
  run gen --exec "/bin/echo 100%" --name plain --harden none
  [[ "$output" == *"ExecStart=/bin/echo 100%%"* ]]
  run gen --exec "/bin/echo %i" --name 'tpl@' --harden none
  [[ "$output" == *"ExecStart=/bin/echo %i"* ]]
}

@test "environment values are quoted and escaped" {
  run gen --exec /bin/true --name e --harden none --env 'MSG=say "hi"'
  [[ "$output" == *'Environment="MSG=say \"hi\""'* ]]
}

@test "command after -- is quoted safely" {
  run gen --name x --harden none -- /bin/echo "hello world"
  [[ "$output" == *'ExecStart=/bin/echo "hello world"'* ]]
}

@test "timer: oneshot service, no [Install] on the service, timer is enableable" {
  run gen --exec /bin/true --name job --on-calendar daily --persistent --random-delay 5min
  [[ "$output" == *"# ===== job.timer ====="* ]]
  [[ "$output" == *"OnCalendar=daily"* ]]
  [[ "$output" == *"Persistent=true"* ]]
  [[ "$output" == *"RandomizedDelaySec=5min"* ]]
  [[ "$output" == *"WantedBy=timers.target"* ]]
  svc=${output#*"# ===== job.service ====="}
  [[ "$svc" == *"Type=oneshot"* ]]
  [[ "$svc" != *"[Install]"* ]]
  [[ "$svc" != *"Restart="* ]]
}

@test "timer --every produces boot + interval triggers" {
  run gen --exec /bin/true --name poll --every 15min
  [[ "$output" == *"OnBootSec=15min"* ]]
  [[ "$output" == *"OnUnitActiveSec=15min"* ]]
}

@test "socket and path units are generated" {
  run gen --exec /bin/true --name s --listen 127.0.0.1:8080 --listen udp:5353
  [[ "$output" == *"ListenStream=127.0.0.1:8080"* ]]
  [[ "$output" == *"ListenDatagram=5353"* ]]
  [[ "$output" == *"WantedBy=sockets.target"* ]]
  run gen --exec /bin/true --name p --watch /srv/inbox
  [[ "$output" == *"PathChanged=/srv/inbox"* ]]
  [[ "$output" == *"WantedBy=paths.target"* ]]
}

@test "strict profile adds the heavy hitters; --allow-jit drops W^X" {
  run gen --exec /bin/true --name x --harden strict
  [[ "$output" == *"ProtectSystem=strict"* ]]
  [[ "$output" == *"MemoryDenyWriteExecute=yes"* ]]
  [[ "$output" == *"SystemCallFilter=@system-service"* ]]
  [[ "$output" == *"CapabilityBoundingSet="* ]]
  run gen --exec /bin/true --name x --harden strict --allow-jit
  [[ "$output" != *"MemoryDenyWriteExecute"* ]]
}

@test "--bind-low-ports grants exactly CAP_NET_BIND_SERVICE" {
  run gen --exec /bin/true --name x --harden strict --bind-low-ports
  [[ "$output" == *"CapabilityBoundingSet=CAP_NET_BIND_SERVICE"* ]]
  [[ "$output" == *"AmbientCapabilities=CAP_NET_BIND_SERVICE"* ]]
}

@test "--no-network restricts address families and uses PrivateNetwork" {
  run gen --exec /bin/true --name x --harden strict --no-network
  [[ "$output" == *"RestrictAddressFamilies=AF_UNIX"* ]]
  [[ "$output" == *"PrivateNetwork=yes"* ]]
}

@test "sandbox options newer than the target systemd are skipped" {
  SSG_SYSTEMD_VERSION=230 run gen --exec /bin/true --name x --harden strict
  [[ "$output" != *"ProtectKernelLogs"* ]]
  [[ "$output" != *"ProtectProc"* ]]
  [[ "$output" == *"NoNewPrivileges=yes"* ]]
}

@test "user scope only gets options the user manager can apply" {
  run gen --scope user --exec /bin/true --name x --harden strict
  [[ "$output" == *"NoNewPrivileges=yes"* ]]
  [[ "$output" != *"PrivateTmp"* ]]
  [[ "$output" != *"ProtectSystem"* ]]
  [[ "$output" == *"WantedBy=default.target"* ]]
}

@test "ProtectHome is relaxed when the program lives under /home" {
  run gen --exec /home/me/app --workdir /home/me --name x --harden strict
  [[ "$output" == *"ProtectHome=read-only"* ]]
}

@test "dynamic user and state dir" {
  run gen --exec /bin/true --name x --dynamic-user --state-dir x
  [[ "$output" == *"DynamicUser=yes"* ]]
  [[ "$output" == *"StateDirectory=x"* ]]
}

@test "--dynamic-user with --user is an error" {
  run "$SSG" new --stdout --exec /bin/true --name x --dynamic-user --user bob
  [ "$status" -eq 2 ]
}

@test "presets fill defaults but flags win" {
  run gen --preset node --exec /usr/bin/node --name n
  [[ "$output" == *'Environment="NODE_ENV=production"'* ]]
  [[ "$output" != *"MemoryDenyWriteExecute"* ]]
  run gen --preset node --exec /usr/bin/node --name n --harden strict --env FOO=1
  [[ "$output" == *'Environment="FOO=1"'* ]]
  [[ "$output" != *"NODE_ENV"* ]]
}

@test "docker-compose preset is a oneshot with RemainAfterExit" {
  run gen --preset docker-compose --exec "/usr/bin/docker compose up -d" --name stack --workdir /srv/stack
  [[ "$output" == *"Type=oneshot"* ]]
  [[ "$output" == *"RemainAfterExit=yes"* ]]
  [[ "$output" == *"ExecStop="* ]]
  [[ "$output" == *"Requires=docker.service"* ]]
}

@test "--set escape hatch lands in the right section" {
  run gen --exec /bin/true --name x --harden none --set Service.SuccessExitStatus=143 --set Unit.Documentation=https://e.x
  svc=${output#*\[Service\]}
  [[ "$svc" == *"SuccessExitStatus=143"* ]]
  [[ "${output%%\[Service\]*}" == *"Documentation=https://e.x"* ]]
}

@test "--set with an unknown section is rejected" {
  run "$SSG" new --stdout --exec /bin/true --set Bogus.Key=1
  [ "$status" -eq 2 ]
}

@test "output is deterministic" {
  a=$(gen --exec /bin/true --name x --harden strict)
  b=$(gen --exec /bin/true --name x --harden strict)
  [ "$a" = "$b" ]
}

@test "generated units pass systemd-analyze verify when available" {
  command -v systemd-analyze > /dev/null || skip "no systemd-analyze"
  run "$SSG" new --exec /bin/true --name okunit --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"verify: OK"* ]]
}
