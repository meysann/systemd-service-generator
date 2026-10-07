# bash completion for ssg — install: ssg completion bash | sudo tee /etc/bash_completion.d/ssg
_ssg() {
  local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD - 1]}
  local cmds="new lint score explain presets profiles uninstall doctor completion version help"
  local opts="--name --desc --exec --user --group --workdir --type --restart --restart-sec --stop-timeout
    --start-limit-interval --start-limit-burst --env --env-file --after --wants --requires --on-failure --doc
    --pre --post --reload --stop --syslog-id --log-file --harden --state-dir --cache-dir --logs-dir
    --runtime-dir --config-dir --rw-path --ro-path --cap --memory-max --cpu-quota --tasks-max --nofile
    --umask --nice --scope --wantedby --preset --on-calendar --every --random-delay --accuracy --listen
    --watch --watch-modified --watch-exists --watch-dir --set --dynamic-user --allow-jit --no-network
    --network --persistent --remain-after-exit --bind-low-ports --stdout --dry-run --output --yes --enable
    --start --now --force --no-verify --score --from --save-spec --wizard --no-wizard --help"
  case $prev in
    --harden)
      mapfile -t COMPREPLY < <(compgen -W "none basic standard strict" -- "$cur")
      return
      ;;
    --scope)
      mapfile -t COMPREPLY < <(compgen -W "system user" -- "$cur")
      return
      ;;
    --type)
      mapfile -t COMPREPLY < <(compgen -W "simple exec forking oneshot notify dbus idle" -- "$cur")
      return
      ;;
    --restart)
      mapfile -t COMPREPLY < <(compgen -W "no on-failure always on-success on-abnormal on-abort on-watchdog" -- "$cur")
      return
      ;;
    --preset)
      mapfile -t COMPREPLY < <(compgen -W "binary node python java webserver docker-compose cron-job watcher" -- "$cur")
      return
      ;;
    --from | --save-spec | --env-file | --output | --workdir)
      mapfile -t COMPREPLY < <(compgen -f -- "$cur")
      return
      ;;
  esac
  if ((COMP_CWORD == 1)); then
    mapfile -t COMPREPLY < <(compgen -W "$cmds $opts" -- "$cur")
  elif [[ ${COMP_WORDS[1]} == lint ]]; then
    mapfile -t COMPREPLY < <(compgen -f -- "$cur")
  else
    mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
  fi
}
complete -F _ssg ssg
