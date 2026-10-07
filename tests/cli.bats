#!/usr/bin/env bats
load helpers

setup() { T=$(mktemp -d); }
teardown() { rm -rf "$T"; }

@test "--version / version / help" {
  run "$SSG" --version; [ "$status" -eq 0 ]; [[ "$output" == "ssg "* ]]
  run "$SSG" version; [ "$status" -eq 0 ]
  run "$SSG" --help; [ "$status" -eq 0 ]; [[ "$output" == *"Commands"* ]]
}

@test "unknown command / option exit 2" {
  run "$SSG" frobnicate; [ "$status" -eq 2 ]
  run "$SSG" new --nope; [ "$status" -eq 2 ]
}

@test "missing command is an error when not interactive" {
  run "$SSG" new --stdout < /dev/null
  [ "$status" -eq 2 ]
  [[ "$output" == *"No command to run"* ]]
}

@test "--opt=value form works" {
  run gen --exec=/bin/true --name=eq --harden=basic
  [[ "$output" == *"Description=eq service"* ]]
}

@test "refuses to install non-interactively without --yes" {
  run "$SSG" new --exec /bin/true --name x --no-verify < /dev/null
  [ "$status" -eq 2 ]
  [[ "$output" == *"--yes"* ]]
}

@test "--output writes files; second identical run is a no-op; changes keep a backup" {
  run "$SSG" new --exec /bin/true --name app --output "$T" --yes --no-verify
  [ "$status" -eq 0 ]
  [ -f "$T/app.service" ]
  run "$SSG" new --exec /bin/true --name app --output "$T" --yes --no-verify
  [[ "$output" == *"already up to date"* ]]
  run "$SSG" new --exec /bin/true --name app --output "$T" --yes --no-verify --restart always
  [ "$status" -eq 0 ]
  ls "$T"/app.service.bak-* > /dev/null
  grep -q "Restart=always" "$T/app.service"
}

@test "--dry-run writes nothing" {
  run "$SSG" new --exec /bin/true --name app --output "$T" --dry-run --no-verify
  [ "$status" -eq 0 ]
  [ ! -e "$T/app.service" ]
}

@test "spec files round-trip and flags override them" {
  "$SSG" new --exec /bin/true --name rt --env A=1 --env B=2 --after postgresql --harden strict \
    --save-spec "$T/rt.spec" --stdout --no-verify > "$T/first.txt" 2> /dev/null
  grep -q '^env=A=1' "$T/rt.spec"
  run gen --from "$T/rt.spec"
  [ "$output" = "$(cat "$T/first.txt")" ]
  run gen --from "$T/rt.spec" --harden basic
  [[ "$output" != *"ProtectSystem=strict"* ]]
}

@test "spec parser rejects garbage with file:line" {
  printf 'name=ok\nthis is wrong\n' > "$T/bad.spec"
  run "$SSG" new --from "$T/bad.spec" --stdout
  [ "$status" -eq 2 ]
  [[ "$output" == *"bad.spec:2"* ]]
}

@test "explain / presets / profiles" {
  run "$SSG" explain ProtectSystem; [ "$status" -eq 0 ]; [[ "$output" == *strict* ]]
  run "$SSG" explain NoSuchThing; [ "$status" -eq 1 ]
  run "$SSG" presets; [[ "$output" == *cron-job* ]]
  run "$SSG" profiles strict; [[ "$output" == *"MemoryDenyWriteExecute"* ]]
}

@test "bash completion script is valid" {
  run bash -n "$ROOT/completions/ssg.bash"; [ "$status" -eq 0 ]
  run "$SSG" completion bash; [[ "$output" == *"complete -F _ssg ssg"* ]]
}

@test "works through a symlink" {
  ln -s "$SSG" "$T/ssg"
  run "$T/ssg" --version; [ "$status" -eq 0 ]
}

@test "install + uninstall flow against a stubbed systemctl (user scope)" {
  mkdir "$T/stub"
  printf '#!/bin/sh\necho "[stub] $*" >&2\n' > "$T/stub/systemctl"
  chmod +x "$T/stub/systemctl"
  export XDG_CONFIG_HOME="$T/cfg" PATH="$T/stub:$PATH"
  run "$SSG" new --scope user --exec /bin/true --name e2e --yes --now --no-verify
  [ "$status" -eq 0 ]
  [ -f "$T/cfg/systemd/user/e2e.service" ]
  [[ "$output" == *"[stub] --user daemon-reload"* ]]
  [[ "$output" == *"[stub] --user enable e2e.service"* ]]
  [[ "$output" == *"[stub] --user start e2e.service"* ]]
  run "$SSG" uninstall e2e --scope user --yes
  [ "$status" -eq 0 ]
  [ ! -e "$T/cfg/systemd/user/e2e.service" ]
}

@test "timer set: enable/start target the timer unit" {
  mkdir "$T/stub"
  printf '#!/bin/sh\necho "[stub] $*" >&2\n' > "$T/stub/systemctl"
  chmod +x "$T/stub/systemctl"
  export XDG_CONFIG_HOME="$T/cfg" PATH="$T/stub:$PATH"
  run "$SSG" new --scope user --exec /bin/true --name tj --on-calendar hourly --yes --now --no-verify
  [[ "$output" == *"[stub] --user enable tj.timer"* ]]
  [[ "$output" == *"[stub] --user start tj.timer"* ]]
}
