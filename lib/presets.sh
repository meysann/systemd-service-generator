#!/usr/bin/env bash
# shellcheck disable=SC2034  # globals are shared across the sourced modules
# presets.sh — opinionated starting points. A preset only fills in values the
# user has not set, so every flag still wins.

PRESET_NAMES=(binary node python java webserver docker-compose cron-job watcher)
declare -gA PRESET_DESC=(
  [binary]="Self-contained daemon / Go / Rust binary — strict sandbox"
  [node]="Node.js app — standard sandbox, JIT allowed, NODE_ENV=production"
  [python]="Python app — standard sandbox, unbuffered output"
  [java]="JVM app — standard sandbox, JIT allowed, exit 143 = clean stop"
  [webserver]="Listens on ports < 1024 via CAP_NET_BIND_SERVICE, strict sandbox"
  ["docker-compose"]="docker compose up/down wrapper (oneshot + RemainAfterExit)"
  ["cron-job"]="Scheduled oneshot job: daily, persistent, 5 min random delay"
  [watcher]="Run a oneshot job whenever a path changes"
)
declare -gA PRESET_EXEC=(
  [binary]="/usr/local/bin/myapp --config /etc/myapp.conf"
  [node]="/usr/bin/node /srv/app/server.js"
  [python]="/usr/bin/python3 /srv/app/main.py"
  [java]="/usr/bin/java -jar /srv/app/app.jar"
  [webserver]="/usr/local/bin/myserver --listen :80"
  ["docker-compose"]="/usr/bin/docker compose up -d"
  ["cron-job"]="/usr/local/bin/backup.sh"
  [watcher]="/usr/local/bin/process-inbox.sh"
)

preset_binary() {
  p_default harden strict
  p_default network yes
}
preset_node() {
  p_default harden standard
  p_default allow_jit yes
  p_default network yes
  p_default env NODE_ENV=production
}
preset_python() {
  p_default harden standard
  p_default network yes
  p_default env PYTHONUNBUFFERED=1
}
preset_java() {
  p_default harden standard
  p_default allow_jit yes
  p_default network yes
  p_default stop_timeout 30s
  p_default set Service.SuccessExitStatus=143
}
preset_webserver() {
  p_default harden strict
  p_default network yes
  p_default caps CAP_NET_BIND_SERVICE
}
preset_docker_compose() {
  p_default type oneshot
  p_default restart no
  p_default remain yes
  p_default harden none
  p_default after docker.service
  p_default requires docker.service
  p_default stop "/usr/bin/docker compose down"
  p_default stop_timeout 120s
}
preset_cron_job() {
  p_default on_calendar daily
  p_default persistent yes
  p_default random_delay 5min
  p_default harden standard
}
preset_watcher() {
  p_default type oneshot
  p_default harden standard
}
