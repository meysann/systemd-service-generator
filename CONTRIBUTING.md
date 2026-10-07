# Contributing

Thanks for helping! `ssg` is plain Bash (≥ 4.4) with no runtime dependencies beyond coreutils and systemd.

## Setup
```bash
sudo apt-get install shellcheck bats shfmt     # or your distro's equivalents
scripts/dev-check.sh                           # shfmt + shellcheck + bats — same as CI
```

## Layout
| Path | Role |
|---|---|
| `bin/ssg` | entry point, command dispatch |
| `lib/model.sh` | the unit model (`U[]`), `model_set`, spec files, defaults, validation |
| `lib/validate.sh` | validators (`v_*`) and escaping (`esc_*`) — **all user input passes through here** |
| `lib/harden.sh` | sandbox profiles with per-directive minimum systemd version |
| `lib/render.sh` | model → unit text |
| `lib/presets.sh` | presets (only fill unset values) |
| `lib/lint.sh` | `ssg lint` rules (`SSGnnn`) |
| `lib/install.sh` | verify, write, backup, systemctl |
| `lib/wizard.sh`, `lib/cli.sh` | interactive and flag front-ends |

## Adding things
- **A setting:** add it to `model_set` (validator + storage), an `OPT_VAL`/`OPT_FLAG` entry in `cli.sh`, render it in `render.sh`, document it in `new_usage`, add a test.
- **A sandbox directive:** add `Key=Value|min-systemd-version|b|s` to the right tier in `harden.sh`, and an entry in `explain.sh`.
- **A lint rule:** add it to `lint_service`/`lint_timer`/… with a new `SSGnnn` code and a test in `tests/lint.bats`.
- **A preset:** `preset_<name>` using `p_default`, plus `PRESET_NAMES/DESC/EXEC`.

## Rules
- Never interpolate unvalidated input into a unit file. Values must come through `model_set`.
- Generated output must be deterministic (no timestamps) and must lint clean.
- Format with `shfmt -i 2 -ci -sr`. Quote associative-array keys that contain `-` (shfmt would otherwise treat them as arithmetic).
- Under `set -e`, don't end a function with `[[ … ]] && cmd`; use `if`.
- Conventional Commits (`feat:`, `fix:`, `docs:` …). Update `CHANGELOG.md` for user-visible changes.
