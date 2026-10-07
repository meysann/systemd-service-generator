#!/usr/bin/env bats
load helpers

setup() { T=$(mktemp -d); }
teardown() { rm -rf "$T"; }

@test "wizard builds a unit from piped answers" {
  # preset=none, scope=system, when=always, exec, desc, workdir, run-as=dynamic,
  # state-dir, restart=on-failure, env KEY, env done, network=n, harden=standard, limits=n
  run bash -c "printf '%s\n' 1 1 1 /bin/true 'My app' '' 1 '' 1 FOO=bar '' n 3 n | \
    SSG_FORCE_INTERACTIVE=1 '$SSG' new --wizard --name wiz --stdout --no-verify 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Description=My app"* ]]
  [[ "$output" == *"DynamicUser=yes"* ]]
  [[ "$output" == *'Environment="FOO=bar"'* ]]
  [[ "$output" == *"ProtectSystem=full"* ]]
}

@test "wizard re-asks on invalid input" {
  run bash -c "printf '%s\n' 1 1 1 'not-absolute' '' '' '' '' 1 '' 1 '' n 3 n | \
    SSG_FORCE_INTERACTIVE=1 '$SSG' new --wizard --name wiz --stdout --no-verify --exec /bin/true --desc x 2>&1 >/dev/null"
  [ "$status" -eq 0 ]
}

@test "wizard aborts cleanly on EOF" {
  run bash -c "SSG_FORCE_INTERACTIVE=1 '$SSG' new --wizard --stdout < /dev/null"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Input closed"* ]]
}
