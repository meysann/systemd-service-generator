#!/usr/bin/env bash
# shellcheck disable=SC2034  # globals are shared across the sourced modules
# lint.sh — static analysis of existing unit files (any origin, not just ssg).

LINT_ERRORS=0 LINT_WARNINGS=0
declare -gA LV=() LL=() # "Section.Key" → values (newline-joined) / first line

declare -gA KNOWN=(
  [Unit]=" Description Documentation Wants Requires Requisite BindsTo PartOf Upholds Conflicts Before After OnFailure OnSuccess PropagatesReloadTo ReloadPropagatedFrom PropagatesStopTo StopPropagatedFrom JoinsNamespaceOf RequiresMountsFor OnSuccessJobMode OnFailureJobMode IgnoreOnIsolate StopWhenUnneeded RefuseManualStart RefuseManualStop AllowIsolate DefaultDependencies SurviveFinalKillSignal CollectMode FailureAction SuccessAction FailureActionExitStatus SuccessActionExitStatus JobTimeoutSec JobRunningTimeoutSec JobTimeoutAction JobTimeoutRebootArgument StartLimitIntervalSec StartLimitBurst StartLimitAction RebootArgument SourcePath ConditionArchitecture ConditionFirmware ConditionVirtualization ConditionHost ConditionKernelCommandLine ConditionKernelVersion ConditionCredential ConditionEnvironment ConditionSecurity ConditionCapability ConditionACPower ConditionNeedsUpdate ConditionFirstBoot ConditionPathExists ConditionPathExistsGlob ConditionPathIsDirectory ConditionPathIsSymbolicLink ConditionPathIsMountPoint ConditionPathIsReadWrite ConditionPathIsEncrypted ConditionDirectoryNotEmpty ConditionFileNotEmpty ConditionFileIsExecutable ConditionUser ConditionGroup ConditionControlGroupController ConditionMemory ConditionCPUs ConditionCPUFeature ConditionOSRelease ConditionMemoryPressure ConditionCPUPressure ConditionIOPressure AssertArchitecture AssertVirtualization AssertHost AssertKernelCommandLine AssertPathExists AssertPathIsDirectory AssertFileNotEmpty AssertFileIsExecutable AssertUser AssertGroup AssertSecurity AssertCapability AssertACPower AssertNeedsUpdate AssertFirstBoot AssertPathExistsGlob AssertPathIsSymbolicLink AssertPathIsMountPoint AssertPathIsReadWrite AssertDirectoryNotEmpty AssertControlGroupController AssertMemory AssertCPUs AssertOSRelease AssertEnvironment AssertFirmware AssertKernelVersion "
  [Install]=" Alias WantedBy RequiredBy UpheldBy Also DefaultInstance "
  [Timer]=" OnActiveSec OnBootSec OnStartupSec OnUnitActiveSec OnUnitInactiveSec OnCalendar AccuracySec RandomizedDelaySec FixedRandomDelay OnClockChange OnTimezoneChange Unit Persistent WakeSystem RemainAfterElapse "
  [Path]=" PathExists PathExistsGlob PathChanged PathModified DirectoryNotEmpty Unit MakeDirectory DirectoryMode TriggerLimitIntervalSec TriggerLimitBurst "
  [Socket]=" ListenStream ListenDatagram ListenSequentialPacket ListenFIFO ListenSpecial ListenNetlink ListenMessageQueue ListenUSBFunction SocketProtocol BindIPv6Only Backlog BindToDevice SocketUser SocketGroup SocketMode DirectoryMode Accept Writable FlushPending MaxConnections MaxConnectionsPerSource KeepAlive KeepAliveTimeSec KeepAliveIntervalSec KeepAliveProbes NoDelay Priority DeferAcceptSec ReceiveBuffer SendBuffer IPTOS IPTTL Mark ReusePort SmackLabel SmackLabelIPIn SmackLabelIPOut SELinuxContextFromNet PipeSize MessageQueueMaxMessages MessageQueueMessageSize FreeBind Transparent Broadcast PassCredentials PassSecurity PassPacketInfo Timestamping TCPCongestion ExecStartPre ExecStartPost ExecStopPre ExecStopPost TimeoutSec Service RemoveOnStop Symlinks FileDescriptorName TriggerLimitIntervalSec TriggerLimitBurst PollLimitIntervalSec PollLimitBurst "
  [Service]=" Type ExitType RemainAfterExit GuessMainPID PIDFile BusName ExecStart ExecStartPre ExecStartPost ExecCondition ExecReload ExecStop ExecStopPost RestartSec RestartSteps RestartMaxDelaySec TimeoutStartSec TimeoutStopSec TimeoutAbortSec TimeoutSec TimeoutStartFailureMode TimeoutStopFailureMode RuntimeMaxSec RuntimeRandomizedExtraSec WatchdogSec Restart RestartMode SuccessExitStatus RestartPreventExitStatus RestartForceExitStatus RootDirectoryStartOnly NonBlocking NotifyAccess Sockets FileDescriptorStoreMax FileDescriptorStorePreserve USBFunctionDescriptors USBFunctionStrings OOMPolicy OpenFile ReloadSignal DelegateSubgroup User Group DynamicUser SupplementaryGroups PAMName SetLoginEnvironment WorkingDirectory RootDirectory RootImage RootImageOptions RootEphemeral RootHash RootHashSignature RootVerity RootImagePolicy MountImages ExtensionImages ExtensionDirectories ExtensionImagePolicy MountAPIVFS BindLogSockets ProtectProc ProcSubset ProtectSystem ProtectHome ProtectHostname ProtectClock ProtectKernelTunables ProtectKernelModules ProtectKernelLogs ProtectControlGroups PrivateTmp PrivateDevices PrivateNetwork PrivateUsers PrivateMounts PrivateIPC PrivatePIDs NetworkNamespacePath IPCNamespacePath ReadWritePaths ReadOnlyPaths InaccessiblePaths ExecPaths NoExecPaths TemporaryFileSystem BindPaths BindReadOnlyPaths StateDirectory StateDirectoryMode CacheDirectory CacheDirectoryMode LogsDirectory LogsDirectoryMode RuntimeDirectory RuntimeDirectoryMode RuntimeDirectoryPreserve ConfigurationDirectory ConfigurationDirectoryMode NoNewPrivileges SecureBits CapabilityBoundingSet AmbientCapabilities KeyringMode UMask Environment EnvironmentFile PassEnvironment UnsetEnvironment StandardInput StandardOutput StandardError StandardInputText StandardInputData SyslogIdentifier SyslogFacility SyslogLevel SyslogLevelPrefix LogLevelMax LogExtraFields LogRateLimitIntervalSec LogRateLimitBurst LogFilterPatterns LogNamespace Nice OOMScoreAdjust CPUSchedulingPolicy CPUSchedulingPriority CPUSchedulingResetOnFork CPUAffinity NUMAPolicy NUMAMask IOSchedulingClass IOSchedulingPriority TimerSlackNSec LimitCPU LimitFSIZE LimitDATA LimitSTACK LimitCORE LimitRSS LimitNOFILE LimitAS LimitNPROC LimitMEMLOCK LimitLOCKS LimitSIGPENDING LimitMSGQUEUE LimitNICE LimitRTPRIO LimitRTTIME Personality LockPersonality MemoryDenyWriteExecute RestrictRealtime RestrictSUIDSGID RestrictNamespaces RestrictAddressFamilies RestrictFileSystems RestrictNetworkInterfaces SystemCallFilter SystemCallErrorNumber SystemCallArchitectures SystemCallLog IPAddressAllow IPAddressDeny IPIngressFilterPath IPEgressFilterPath RemoveIPC SELinuxContext AppArmorProfile SmackProcessLabel DevicePolicy DeviceAllow Slice Delegate CPUAccounting CPUWeight StartupCPUWeight CPUQuota CPUQuotaPeriodSec AllowedCPUs StartupAllowedCPUs MemoryAccounting MemoryMin MemoryLow MemoryHigh MemoryMax MemorySwapMax MemoryZSwapMax MemoryZSwapWriteback AllowedMemoryNodes StartupAllowedMemoryNodes IOAccounting IOWeight StartupIOWeight IODeviceWeight IOReadBandwidthMax IOWriteBandwidthMax IOReadIOPSMax IOWriteIOPSMax IODeviceLatencyTargetSec TasksAccounting TasksMax IPAccounting DisableControllers ManagedOOMSwap ManagedOOMMemoryPressure ManagedOOMMemoryPressureLimit ManagedOOMPreference NetClass CoredumpFilter CoredumpReceive LoadCredential LoadCredentialEncrypted ImportCredential SetCredential SetCredentialEncrypted TTYPath TTYReset TTYVHangup TTYVTDisallocate TTYColumns TTYRows UtmpIdentifier UtmpMode ProtectProc MemoryPressureWatch MemoryPressureThresholdSec "
)

declare -gA DEPRECATED=(
  [MemoryLimit]="MemoryMax"
  [CPUShares]="CPUWeight"
  [StartupCPUShares]="StartupCPUWeight"
  [BlockIOWeight]="IOWeight"
  [BlockIOAccounting]="IOAccounting"
  [StartLimitInterval]="StartLimitIntervalSec (in [Unit])"
  [PermissionsStartOnly]="the '+' prefix on the Exec line"
  [StartLimitBurst]=""
  [StartLimitIntervalSec]=""
)

# levenshtein A B → distance (small strings only)
_lev() {
  local a=$1 b=$2 i j cost
  local -a prev cur
  for ((j = 0; j <= ${#b}; j++)); do prev[j]=$j; done
  for ((i = 1; i <= ${#a}; i++)); do
    cur[0]=$i
    for ((j = 1; j <= ${#b}; j++)); do
      cost=1
      [[ ${a:i-1:1} == "${b:j-1:1}" ]] && cost=0
      cur[j]=$((prev[j] + 1))
      ((cur[j - 1] + 1 < cur[j])) && cur[j]=$((cur[j - 1] + 1))
      ((prev[j - 1] + cost < cur[j])) && cur[j]=$((prev[j - 1] + cost))
    done
    prev=("${cur[@]}")
  done
  printf '%s' "${prev[${#b}]}"
}

_suggest() { # section key → closest known directive (case-insensitive, distance <= 2)
  local k best="" bd=3 d
  for k in ${KNOWN[$1]}; do
    if [[ ${k,,} == "${2,,}" ]]; then
      printf '%s' "$k"
      return
    fi
    if ((${#k} - ${#2} > 2 || ${#2} - ${#k} > 2)); then continue; fi
    d=$(_lev "${k,,}" "${2,,}")
    if ((d < bd)); then bd=$d best=$k; fi
  done
  printf '%s' "$best"
}

_lint() { # level code line message
  local lvl=$1 code=$2 line=$3 msg=$4 col
  case $lvl in error)
    col=$C_R
    LINT_ERRORS=$((LINT_ERRORS + 1))
    ;;
  warning)
    col=$C_Y
    LINT_WARNINGS=$((LINT_WARNINGS + 1))
    ;;
  *) col=$C_C ;; esac
  printf '%s:%s: %s%s%s: [%s] %s\n' "$LINT_FILE" "${line:-1}" "$col" "$lvl" "$C_0" "$code" "$msg"
}

lint_has() { [[ -n ${LV[$1]+x} ]]; }
lint_val() {
  local v=${LV[$1]:-}
  printf '%s' "${v%%$'\n'*}"
}
lint_ln() { printf '%s' "${LL[$1]:-1}"; }

lint_parse() {
  LV=()
  LL=()
  declare -gA LSEC=()
  LSEC=()
  local sec="" line n=0 key val pending="" pn=0
  while IFS= read -r line || [[ -n $line ]]; do
    n=$((n + 1))
    line=${line%$'\r'}
    if [[ -n $pending ]]; then
      line="$pending${line#"${line%%[![:space:]]*}"}"
      n=$pn
      pending=""
    fi
    if [[ $line == *\\ ]]; then
      pending="${line%\\} "
      pn=$n
      continue
    fi
    line=${line#"${line%%[![:space:]]*}"}
    [[ -z $line || $line == \#* || $line == \;* ]] && continue
    if [[ $line =~ ^\[([A-Za-z0-9._-]+)\][[:space:]]*$ ]]; then
      sec=${BASH_REMATCH[1]}
      LSEC[$sec]=$n
      continue
    fi
    if [[ $line =~ ^([A-Za-z0-9_-]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      key=${BASH_REMATCH[1]}
      val=${BASH_REMATCH[2]}
      if [[ -z $sec ]]; then
        _lint error SSG100 "$n" "Directive '$key' appears before any [Section]."
        continue
      fi
      LV[$sec.$key]+="${LV[$sec.$key]:+$'\n'}$val"
      [[ -n ${LL[$sec.$key]:-} ]] || LL[$sec.$key]=$n
      # unknown / mis-cased / deprecated directive checks
      if [[ -n ${KNOWN[$sec]:-} && $key != X-* ]]; then
        if [[ ${KNOWN[$sec]} != *" $key "* ]]; then
          if [[ -n ${DEPRECATED[$key]+x} ]]; then
            if [[ -n ${DEPRECATED[$key]} ]]; then
              _lint warning SSG107 "$n" "$key= is deprecated; use ${DEPRECATED[$key]}."
            fi
          else
            local hint="" k
            k=$(_suggest "$sec" "$key")
            if [[ -n $k ]]; then hint=" Did you mean $k?"; fi
            _lint warning SSG106 "$n" "Unknown directive '$key' in [$sec].$hint"
          fi
        fi
      fi
    else
      _lint error SSG101 "$n" "Cannot parse line: $line"
    fi
  done < "$LINT_FILE"
}

lint_service() {
  local scope=$1 type exec bin k present=0 missing=() has_exec=0
  lint_has Service.Type && type=$(lint_val Service.Type) || type=simple
  lint_has Service.ExecStart && has_exec=1
  if [[ -z ${LSEC[Service]:-} ]]; then
    _lint error SSG102 1 "A .service file needs a [Service] section."
    return
  fi
  if ((!has_exec)) && [[ $type != oneshot ]]; then
    _lint error SSG110 "$(lint_ln Service.Type)" "No ExecStart= (only Type=oneshot may omit it)."
  fi
  if ((has_exec)); then
    exec=$(lint_val Service.ExecStart)
    bin=$(exec_binary "$exec")
    if [[ $bin != /* && $bin != %* && -n $bin ]]; then
      _lint error SSG111 "$(lint_ln Service.ExecStart)" "ExecStart= should start with an absolute path (found '$bin')."
    fi
    if [[ $exec =~ (^|[[:space:]])(\||\|\||\&\&|\;|\>|\>\>|\<|2\>\&1)([[:space:]]|$) ]]; then
      _lint warning SSG112 "$(lint_ln Service.ExecStart)" "Shell operators are not interpreted by systemd; wrap in /bin/sh -c '…'."
    fi
  fi
  if [[ $type == forking ]] && ! lint_has Service.PIDFile; then
    _lint warning SSG113 "$(lint_ln Service.Type)" "Type=forking without PIDFile= makes main-PID detection unreliable."
  fi
  if lint_has Service.Restart && [[ $(lint_val Service.Restart) != no ]] && ! lint_has Service.RestartSec; then
    _lint warning SSG114 "$(lint_ln Service.Restart)" "Restart= without RestartSec= (default 100ms) can spin in a tight crash loop."
  fi
  for k in StartLimitIntervalSec StartLimitBurst StartLimitInterval; do
    if lint_has Service.$k; then
      _lint warning SSG115 "$(lint_ln Service.$k)" "$k= belongs in [Unit], not [Service]."
    fi
  done
  if [[ $type == oneshot ]] && lint_has Service.Restart && [[ $(lint_val Service.Restart) == always ]]; then
    _lint error SSG116 "$(lint_ln Service.Restart)" "Restart=always is not valid for Type=oneshot."
  fi
  if lint_has Unit.After && [[ $(lint_val Unit.After) == *network-online.target* ]] && ! lint_has Unit.Wants; then
    _lint warning SSG117 "$(lint_ln Unit.After)" "After=network-online.target has no effect unless Wants=network-online.target is also set."
  fi
  if [[ $scope == system ]] && ! lint_has Service.User && [[ $(lint_val Service.DynamicUser) != yes && $(lint_val Service.DynamicUser) != true ]]; then
    _lint warning SSG120 "$(lint_ln Service.Type)" "Runs as root. Use User=/Group= or DynamicUser=yes."
  fi
  # sandbox coverage
  for k in "${SANDBOX_KEYS[@]}"; do
    if lint_has "Service.$k"; then present=$((present + 1)); else missing+=("$k"); fi
  done
  LINT_COVERAGE="$present/${#SANDBOX_KEYS[@]}"
  if [[ $scope == system ]] && ((present * 2 < ${#SANDBOX_KEYS[@]})); then
    _lint warning SSG121 "$(lint_ln Service.Type)" "Weak sandbox ($LINT_COVERAGE hardening directives). Missing e.g.: ${missing[*]:0:6}. Try: ssg new --harden strict"
  fi
  if [[ $(lint_val Service.ProtectSystem) == strict ]] && ! lint_has Service.ReadWritePaths && ! lint_has Service.StateDirectory &&
    ! lint_has Service.RuntimeDirectory && ! lint_has Service.CacheDirectory && ! lint_has Service.LogsDirectory; then
    _lint info SSG122 "$(lint_ln Service.ProtectSystem)" "ProtectSystem=strict makes / read-only; the service has no writable path."
  fi
  if [[ $(lint_val Service.ProtectHome) =~ ^(yes|true|tmpfs)$ ]] && [[ $(lint_val Service.WorkingDirectory)$exec == */home/* ]]; then
    _lint error SSG123 "$(lint_ln Service.ProtectHome)" "ProtectHome hides /home but the unit uses a path under /home."
  fi
}

lint_timer() {
  local k found=0
  for k in OnActiveSec OnBootSec OnStartupSec OnUnitActiveSec OnUnitInactiveSec OnCalendar OnClockChange OnTimezoneChange; do
    lint_has Timer.$k && found=1
  done
  if [[ -z ${LSEC[Timer]:-} ]]; then
    _lint error SSG102 1 "A .timer file needs a [Timer] section."
    return
  fi
  ((found)) || _lint error SSG130 "${LSEC[Timer]}" "Timer has no trigger (OnCalendar=, OnBootSec=, OnUnitActiveSec=, …)."
  if lint_has Timer.Persistent && ! lint_has Timer.OnCalendar; then
    _lint warning SSG131 "$(lint_ln Timer.Persistent)" "Persistent= only has an effect together with OnCalendar=."
  fi
  if ! lint_has Install.WantedBy; then
    _lint warning SSG132 1 "No [Install] WantedBy=timers.target — the timer can't be enabled."
  fi
}

lint_socket() {
  local k found=0
  for k in ListenStream ListenDatagram ListenSequentialPacket ListenFIFO ListenSpecial ListenNetlink ListenMessageQueue; do
    lint_has Socket.$k && found=1
  done
  ((found)) || _lint error SSG140 "${LSEC[Socket]:-1}" "Socket has no Listen*= directive."
}

lint_path() {
  local k found=0
  for k in PathExists PathExistsGlob PathChanged PathModified DirectoryNotEmpty; do lint_has Path.$k && found=1; done
  ((found)) || _lint error SSG150 "${LSEC[Path]:-1}" "Path unit has no Path*=/DirectoryNotEmpty= directive."
}

# lint_file FILE [SCOPE]   — prints findings; sets LINT_ERRORS / LINT_WARNINGS
lint_file() {
  LINT_FILE=$1
  local scope=${2:-}
  LINT_COVERAGE=""
  [[ -r $LINT_FILE ]] || {
    err "Cannot read $LINT_FILE"
    LINT_ERRORS=$((LINT_ERRORS + 1))
    return 1
  }
  if [[ -z $scope ]]; then
    if [[ $LINT_FILE == */systemd/user/* || $LINT_FILE == */.config/systemd/* ]]; then scope=user; else scope=system; fi
  fi
  lint_parse
  case $LINT_FILE in
    *.service) lint_service "$scope" ;;
    *.timer) lint_timer ;;
    *.socket) lint_socket ;;
    *.path) lint_path ;;
    *) warn "$LINT_FILE: unrecognised unit type; only generic checks were run." ;;
  esac
}

cmd_lint() {
  local scope="" strict=0 a files=()
  while (($#)); do
    a=$1
    shift
    case $a in
      --scope)
        scope=${1:?--scope needs a value}
        shift
        ;;
      --scope=*) scope=${a#*=} ;;
      --strict) strict=1 ;;
      -h | --help)
        printf 'Usage: ssg lint [--scope system|user] [--strict] FILE...\n'
        return 0
        ;;
      -*) die "Unknown option: $a" 2 ;;
      *) files+=("$a") ;;
    esac
  done
  ((${#files[@]})) || die "Usage: ssg lint FILE..." 2
  [[ -z $scope ]] || v_scope "$scope" || die "$VERR" 2
  local f
  for f in "${files[@]}"; do
    lint_file "$f" "$scope"
    if [[ -n $LINT_COVERAGE ]]; then
      printf '%s: sandbox coverage %s\n' "$f" "$LINT_COVERAGE"
    fi
  done
  printf '%d error(s), %d warning(s)\n' "$LINT_ERRORS" "$LINT_WARNINGS"
  if ((LINT_ERRORS > 0)) || { ((strict)) && ((LINT_WARNINGS > 0)); }; then return 1; fi
  return 0
}
