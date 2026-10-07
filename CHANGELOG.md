# Changelog

## v1.0.0 — complete redesign
**Breaking:** `bin/ssg` is now a flag-driven CLI with an optional wizard; the old
`steps/` pipeline is gone. Run `ssg` with no arguments for the wizard.

### Added
- Non-interactive generation: every setting is a flag or a `--from` spec file; `--stdout`, `--dry-run`, `--output DIR`.
- Services **and** timers, sockets and path units from one command.
- Sandbox profiles `none | basic | standard | strict`, version-aware (options newer than the target systemd are skipped) and scope-aware (user manager gets only what it can apply).
- Presets: binary, node, python, java, webserver, docker-compose, cron-job, watcher.
- `ssg lint` for any unit file (typo suggestions, deprecated and misplaced directives, weak sandbox), `ssg score`, `ssg explain`, `ssg profiles`, `ssg presets`, `ssg doctor`, `ssg uninstall`, bash completion.
- Generated units are self-linted and verified with `systemd-analyze verify` before anything is written.
- Safe writes: diff, timestamped backup, idempotent re-runs, atomic `install`.
- 59-test Bats suite; CI on Ubuntu 22.04 and 24.04.

### Fixed
- `StartLimitIntervalSec`/`StartLimitBurst` were written to `[Service]` (ignored); they now go to `[Unit]`.
- Values are validated and escaped: no newline/directive injection, `%` specifiers escaped, `Environment=` quoted properly.
- Existing unit files are never silently overwritten.
- The 2.9 MB `shfmt` binary no longer lives in the repository.

## v0.1.0 — initial release
- Interactive systemd service wizard core
- CI (lint/format/tests) + contributor docs
