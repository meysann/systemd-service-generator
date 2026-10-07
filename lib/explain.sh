#!/usr/bin/env bash
# shellcheck disable=SC2034  # globals are shared across the sourced modules
# explain.sh — `ssg explain DIRECTIVE`: plain-English notes on the directives ssg emits.

# Format: Directive|what it does|ssg flag / how to set it
EXPLAIN=(
  'Type|How systemd decides the service has started. simple: ready at fork. exec: ready after execve. forking: daemon double-forks. oneshot: runs to completion. notify: program signals READY via sd_notify.|--type'
  'ExecStart|The command line. Must start with an absolute path; no shell syntax (|, &&, >) unless you wrap it in /bin/sh -c.|--exec or after --'
  'Restart|When to restart: no, on-failure (non-zero exit/signal), always, …. on-failure is the right default for daemons.|--restart'
  'RestartSec|Delay before restarting. Too small → crash loops hammer the machine.|--restart-sec'
  'StartLimitIntervalSec|With StartLimitBurst: give up if a unit is started more than Burst times in Interval. Lives in [Unit], not [Service].|--start-limit-interval'
  'User|Unix user to run as. Never run network daemons as root.|--user'
  'DynamicUser|Allocate a throw-away user at start; implies strict sandboxing of state. Pair with --state-dir.|--dynamic-user'
  'WorkingDirectory|chdir() before exec.|--workdir'
  'Environment|One variable per line: Environment="KEY=value". Values are quoted/escaped by ssg.|--env KEY=VALUE'
  'EnvironmentFile|Load KEY=VALUE pairs from a file (prefix path with - to make it optional). Good for secrets (chmod 600).|--env-file'
  'StateDirectory|Creates /var/lib/NAME owned by the service user and makes it writable even under ProtectSystem=strict.|--state-dir'
  'NoNewPrivileges|Blocks setuid/file-capability privilege gain in the service and its children.|--harden basic+'
  'PrivateTmp|Private /tmp and /var/tmp, removed on stop.|--harden basic+'
  'PrivateDevices|Hides physical devices; only /dev/null, /dev/zero, … remain.|--harden standard+'
  'ProtectSystem|full: /usr and /boot read-only (+/etc). strict: whole file system read-only except API mounts and *Directory= paths.|--harden standard (full) / strict'
  'ProtectHome|read-only / yes (inaccessible) / tmpfs for /home, /root, /run/user.|--harden standard / strict'
  'ProtectKernelTunables|/proc/sys, /sys etc. read-only.|--harden basic+'
  'ProtectKernelModules|Forbids loading kernel modules.|--harden basic+'
  'ProtectKernelLogs|Denies access to the kernel ring buffer.|--harden standard+'
  'ProtectControlGroups|cgroup file system read-only.|--harden basic+'
  'ProtectClock|Forbids changing the system clock.|--harden standard+'
  'ProtectHostname|Forbids changing the hostname.|--harden standard+'
  'ProtectProc|invisible: hides other users'"'"' processes in /proc.|--harden strict'
  'RestrictNamespaces|Forbids creating new namespaces.|--harden standard+'
  'RestrictRealtime|Forbids realtime scheduling.|--harden basic+'
  'RestrictSUIDSGID|Forbids creating setuid/setgid files.|--harden basic+'
  'RestrictAddressFamilies|Allowed socket families. ssg uses AF_UNIX AF_INET AF_INET6 (or AF_UNIX with --no-network).|--harden strict'
  'LockPersonality|Locks the execution domain (blocks legacy personality() tricks).|--harden basic+'
  'MemoryDenyWriteExecute|Forbids W+X memory — breaks JIT runtimes (Node, Java, PyPy). ssg skips it with --allow-jit.|--harden strict, --allow-jit'
  'SystemCallFilter|seccomp allow/deny list. @system-service is the sane baseline; ~@privileged @resources removes admin syscalls.|--harden strict'
  'SystemCallArchitectures|native blocks 32-bit syscall ABI bypasses.|--harden standard+'
  'CapabilityBoundingSet|Capabilities the service may ever hold. Empty = none. Add with --cap or --bind-low-ports.|--cap, --bind-low-ports'
  'AmbientCapabilities|Capabilities granted to a non-root service at exec.|--cap'
  'UMask|Default permission mask for files the service creates. 0077 = owner-only.|--umask'
  'MemoryMax|Hard memory limit; the cgroup is OOM-killed above it.|--memory-max'
  'CPUQuota|Cap CPU time, e.g. 50% of one core, 200% of two.|--cpu-quota'
  'TasksMax|Max processes/threads (fork-bomb protection).|--tasks-max'
  'LimitNOFILE|Max open file descriptors.|--nofile'
  'ReadWritePaths|Paths that stay writable under ProtectSystem=strict.|--rw-path'
  'OnCalendar|Wall-clock schedule: daily, hourly, Mon *-*-* 03:00, *:0/15. Test: systemd-analyze calendar "…".|--on-calendar'
  'OnUnitActiveSec|Re-run this long after the service last started — a simple interval.|--every'
  'Persistent|Run a missed calendar job at next boot/start.|--persistent'
  'RandomizedDelaySec|Spread timer start by a random delay to avoid thundering herds.|--random-delay'
  'ListenStream|Socket activation: systemd listens, starts the service on first connection. PORT, ADDR:PORT or a path.|--listen'
  'PathChanged|Trigger when a file is written and closed.|--watch'
  'WantedBy|Which target pulls this unit in on enable. multi-user.target (system), default.target (user), timers.target for timers.|--wantedby'
)

cmd_explain() {
  local q=${1-} e k found=0
  if [[ -z $q || $q == --list ]]; then
    printf 'Directives ssg can explain:\n'
    for e in "${EXPLAIN[@]}"; do printf '  %s\n' "${e%%|*}"; done | column -c 100 2> /dev/null || for e in "${EXPLAIN[@]}"; do printf '  %s\n' "${e%%|*}"; done
    return 0
  fi
  q=${q%%=*}
  for e in "${EXPLAIN[@]}"; do
    k=${e%%|*}
    if [[ ${k,,} == "${q,,}" ]]; then
      local rest=${e#*|}
      printf '%s%s%s\n  %s\n  %sssg:%s %s\n' "$C_B" "$k" "$C_0" "${rest%|*}" "$C_D" "$C_0" "${rest##*|}"
      found=1
    fi
  done
  if ((!found)); then
    printf 'No built-in note for %s. Full reference: man systemd.exec, man systemd.service, man systemd.unit\n' "$q"
    return 1
  fi
}
