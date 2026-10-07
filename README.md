# ssg — the systemd unit generator

Generate **secure, validated** systemd units — services, timers, sockets and path units — from a guided wizard *or* a single scriptable command. Pure Bash, zero dependencies.

[![CI](https://img.shields.io/github/actions/workflow/status/meysann/systemd-service-generator/ci.yml?branch=main)](https://github.com/meysann/systemd-service-generator/actions)
![License](https://img.shields.io/badge/license-MIT-blue)
![Shell](https://img.shields.io/badge/shell-bash%204.4%2B-4EAA25)

```console
$ ssg new --preset webserver --name web --listen 80 --user www-data --stdout -- /usr/local/bin/web --port 8080
```

## Why ssg

| | |
|---|---|
| **Secure by default** | `standard` sandbox out of the box; `strict` adds a read-only filesystem, syscall filter, empty capability set and W^X. |
| **Version-aware** | Every sandbox directive carries the systemd version that introduced it; units generated for an old target never contain options it would reject. User-scope units only get options the user manager can apply. |
| **Correct** | Inputs are validated; values are escaped (no directive injection, `%` specifiers handled, `Environment=` quoted). `StartLimit*` goes in `[Unit]` where it belongs. |
| **Whole unit family** | `.service` + `.timer` / `.socket` / `.path` from one command, wired together correctly (the service gets no `[Install]` when something else activates it). |
| **Verified** | Output is self-linted and checked with `systemd-analyze verify` *before* anything is written. |
| **Safe to run** | Diff + timestamped backup before overwriting; idempotent re-runs; `--dry-run`, `--stdout`, `--output DIR`. |
| **Scriptable & reproducible** | Every wizard answer is a flag or a line in a spec file (`--save-spec` / `--from`). Output is deterministic. |
| **Also a linter** | `ssg lint` audits *any* unit file: typos with suggestions, deprecated/misplaced directives, weak sandboxes. |

## Install

```bash
git clone https://github.com/meysann/systemd-service-generator.git
cd systemd-service-generator && sudo make install      # or: bash bin/ssg   (run in place)
# or: curl -fsSL https://raw.githubusercontent.com/meysann/systemd-service-generator/main/scripts/install.sh | bash
ssg doctor
```
Requires Bash ≥ 4.4. `systemctl` is only needed to install/activate; generation works anywhere.

## Quick start

```bash
ssg                                     # guided wizard (on a terminal)

# long-running service, as a dynamic user, started now
ssg new --exec '/usr/bin/node /srv/app/server.js' --preset node \
        --dynamic-user --state-dir myapp --yes --now

# nightly job
ssg new --preset cron-job --name backup --exec /usr/local/bin/backup.sh \
        --on-calendar '*-*-* 02:30' --yes --enable

# socket-activated daemon, no network access, strictest sandbox
ssg new --name echo --listen /run/echo.sock --no-network --harden strict --stdout -- /usr/local/bin/echod

# run a job when a file appears
ssg new --preset watcher --name ingest --watch-exists /srv/inbox/ready --exec /usr/local/bin/ingest.sh --yes

# per-user service (no root)
ssg new --scope user --name syncthing --exec /usr/bin/syncthing --yes --now
```

## Commands

| Command | |
|---|---|
| `ssg [new]` | Generate units (wizard when run bare on a terminal) |
| `ssg lint FILE…` | Static analysis of any unit file; `--strict` fails on warnings (CI-friendly) |
| `ssg score UNIT\|FILE` | `systemd-analyze security` for installed units, offline coverage for files |
| `ssg explain DIRECTIVE` | Plain-English notes (and the ssg flag) for ~45 directives |
| `ssg profiles [LEVEL]` | Exactly which directives each `--harden` level sets, with min versions |
| `ssg presets` | Preset list |
| `ssg uninstall NAME` | Stop, disable, remove |
| `ssg doctor` | Environment check |
| `ssg completion bash` | Shell completion |

## Sandbox levels

| Level | Adds |
|---|---|
| `none` | nothing |
| `basic` | `NoNewPrivileges`, `PrivateTmp`, `RestrictSUIDSGID`, `RestrictRealtime`, `LockPersonality`, kernel tunables/modules/cgroups protection |
| `standard` *(default)* | + `ProtectSystem=full`, `ProtectHome=read-only`, `PrivateDevices`, `ProtectKernelLogs/Clock/Hostname`, `RestrictNamespaces`, native syscall ABI |
| `strict` | + `ProtectSystem=strict`, `ProtectHome=yes`, `ProtectProc=invisible`, `ProcSubset=pid`, `RemoveIPC`, `MemoryDenyWriteExecute`, address-family and syscall filters, **no capabilities**, `UMask=0077` |

Escape hatches: `--allow-jit` (Node, Java, …), `--no-network`, `--cap CAP_X` / `--bind-low-ports`, `--state-dir` / `--rw-path` for writable locations, and `--set Section.Key=Value` for anything else. Run `ssg profiles` for the exact lists.

## Presets

`binary` · `node` · `python` · `java` · `webserver` · `docker-compose` · `cron-job` · `watcher` — a preset only fills in what you did not set, so every flag still wins.

## Spec files

```ini
# app.spec
name=api
exec=/opt/api/bin/api --port 8080
user=api
env=LOG_LEVEL=info
env=TZ=UTC
harden=strict
state_dir=api
```
`ssg new --from app.spec --yes --now` — flags override the file; `--save-spec FILE` writes one from any invocation.

## Exit codes
`0` success · `1` runtime failure (verification, systemctl, lint errors) · `2` usage or validation error.

## Development
`scripts/dev-check.sh` runs shfmt, ShellCheck and the Bats suite (same as CI). See [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/DESIGN.md](docs/DESIGN.md).

## License
MIT
