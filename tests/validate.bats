#!/usr/bin/env bats
load helpers

setup() { load_libs; }

@test "v_name accepts sane names and rejects bad ones" {
  run v_name "my-app_1.2@x"; [ "$status" -eq 0 ]
  run v_name "bad name"; [ "$status" -eq 1 ]
  run v_name "-leading"; [ "$status" -eq 1 ]
  run v_name ".hidden"; [ "$status" -eq 1 ]
  run v_name 'a/b'; [ "$status" -eq 1 ]
}

@test "v_no_ctl rejects newlines (directive injection)" {
  run v_no_ctl $'ok\nExecStart=/bin/evil'
  [ "$status" -eq 1 ]
  run v_no_ctl "fine text"
  [ "$status" -eq 0 ]
}

@test "v_abs_path" {
  run v_abs_path /srv/app; [ "$status" -eq 0 ]
  run v_abs_path relative/path; [ "$status" -eq 1 ]
}

@test "v_user" {
  run v_user www-data; [ "$status" -eq 0 ]
  run v_user "Bad User"; [ "$status" -eq 1 ]
  run v_user 1000; [ "$status" -eq 0 ]
}

@test "v_timespan / v_calendar" {
  run v_timespan 5min; [ "$status" -eq 0 ]
  run v_timespan "1h 30min"; [ "$status" -eq 0 ]
  run v_timespan banana; [ "$status" -eq 1 ]
  run v_calendar daily; [ "$status" -eq 0 ]
  run v_calendar "Mon *-*-* 03:00"; [ "$status" -eq 0 ]
  run v_calendar "not a schedule"; [ "$status" -eq 1 ]
}

@test "v_mem / v_cpu / v_nofile / v_umask / v_nice" {
  run v_mem 512M; [ "$status" -eq 0 ]
  run v_mem 50%; [ "$status" -eq 0 ]
  run v_mem lots; [ "$status" -eq 1 ]
  run v_cpu 200%; [ "$status" -eq 0 ]
  run v_cpu 2; [ "$status" -eq 1 ]
  run v_nofile 65536; [ "$status" -eq 0 ]
  run v_umask 0027; [ "$status" -eq 0 ]
  run v_umask 0899; [ "$status" -eq 1 ]
  run v_nice -5; [ "$status" -eq 0 ]
  run v_nice 40; [ "$status" -eq 1 ]
}

@test "v_listen" {
  run v_listen 8080; [ "$status" -eq 0 ]
  run v_listen 127.0.0.1:8080; [ "$status" -eq 0 ]
  run v_listen "[::1]:8080"; [ "$status" -eq 0 ]
  run v_listen /run/x.sock; [ "$status" -eq 0 ]
  run v_listen udp:5353; [ "$status" -eq 0 ]
  run v_listen "host:port"; [ "$status" -eq 1 ]
}

@test "sanitize_name" {
  [ "$(sanitize_name 'My Cool App!.service')" = "My-Cool-App-" ]
  [ "$(sanitize_name '..x')" = "x" ]
}

@test "esc_pct doubles % except in template units" {
  declare -gA U=([name]=plain)
  [ "$(esc_pct '100%')" = "100%%" ]
  U[name]='tpl@'
  [ "$(esc_pct '%i')" = "%i" ]
}

@test "esc_env escapes quotes and backslashes" {
  declare -gA U=([name]=plain)
  [ "$(esc_env 'a"b\c')" = 'a\"b\\c' ]
}

@test "quote_exec_arg quotes only when needed" {
  [ "$(quote_exec_arg plain)" = "plain" ]
  [ "$(quote_exec_arg 'two words')" = '"two words"' ]
  [ "$(quote_exec_arg 'a"b')" = '"a\"b"' ]
}

@test "resolve_exec turns bare names into absolute paths and keeps modifiers" {
  run resolve_exec "env --flag"
  [[ "$output" == /*env\ --flag ]]
  run resolve_exec "-/bin/true x"
  [ "$output" = "-/bin/true x" ]
}
