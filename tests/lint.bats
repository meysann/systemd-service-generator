#!/usr/bin/env bats
load helpers

setup() { T=$(mktemp -d); }
teardown() { rm -rf "$T"; }

@test "every unit ssg generates lints clean (no errors)" {
  for args in "--harden strict" "--harden none" "--on-calendar daily" "--listen 8080" "--watch /srv/x" "--preset webserver"; do
    gen --exec /bin/true --name lintme $args > "$T/all.txt"
    csplit -s -z -f "$T/u" "$T/all.txt" '/^# =====/' '{*}' 2> /dev/null || cp "$T/all.txt" "$T/u00"
    rm -f "$T"/lintme.*
    # single-file output: split on the marker, otherwise whole file is the service
    if grep -q '^# ===== ' "$T/all.txt"; then
      awk -v d="$T" '/^# ===== /{f=d"/"$3; next} f{print > f}' "$T/all.txt"
    else
      cp "$T/all.txt" "$T/lintme.service"
    fi
    for f in "$T"/lintme.*; do
      run "$SSG" lint --scope system "$f"
      [ "$status" -eq 0 ] || { echo "$args: $output"; false; }
    done
  done
}

@test "lint finds the classics" {
  cat > "$T/bad.service" << 'U'
[Service]
ExecStart=foo | bar
Type=forking
Restart=always
StartLimitBurst=3
MemoryLimit=1G
PrivatTmp=yes
U
  run "$SSG" lint "$T/bad.service"
  [ "$status" -eq 1 ]
  [[ "$output" == *SSG111* ]]   # not absolute
  [[ "$output" == *SSG112* ]]   # shell operator
  [[ "$output" == *SSG113* ]]   # forking w/o PIDFile
  [[ "$output" == *SSG114* ]]   # Restart without RestartSec
  [[ "$output" == *SSG115* ]]   # StartLimit in wrong section
  [[ "$output" == *SSG107* ]]   # deprecated MemoryLimit
  [[ "$output" == *"Did you mean PrivateTmp"* ]]
  [[ "$output" == *SSG120* ]]   # root
}

@test "lint: missing ExecStart is an error, oneshot is exempt" {
  printf '[Service]\nUser=x\n' > "$T/a.service"
  run "$SSG" lint "$T/a.service"; [ "$status" -eq 1 ]; [[ "$output" == *SSG110* ]]
  printf '[Service]\nType=oneshot\nUser=x\n' > "$T/b.service"
  run "$SSG" lint "$T/b.service"; [[ "$output" != *SSG110* ]]
}

@test "lint: timer without trigger, socket without Listen" {
  printf '[Timer]\nPersistent=true\n[Install]\nWantedBy=timers.target\n' > "$T/t.timer"
  run "$SSG" lint "$T/t.timer"; [ "$status" -eq 1 ]; [[ "$output" == *SSG130* && "$output" == *SSG131* ]]
  printf '[Socket]\nAccept=no\n' > "$T/s.socket"
  run "$SSG" lint "$T/s.socket"; [ "$status" -eq 1 ]; [[ "$output" == *SSG140* ]]
}

@test "lint: line continuations and comments parse" {
  printf '# c\n[Service]\nExecStart=/bin/true \\\n  --flag\nUser=u\n' > "$T/c.service"
  run "$SSG" lint "$T/c.service"
  [[ "$output" != *SSG101* && "$output" != *SSG110* ]]
}

@test "lint --strict fails on warnings" {
  printf '[Service]\nExecStart=/bin/true\nUser=u\n' > "$T/w.service"
  run "$SSG" lint "$T/w.service"; [ "$status" -eq 0 ]
  run "$SSG" lint --strict "$T/w.service"; [ "$status" -eq 1 ]
}
