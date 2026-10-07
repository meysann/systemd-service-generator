# Design notes

**One model, many front-ends.** Everything funnels through `model_set KEY VALUE`, which validates and stores into the associative array `U`. CLI flags, spec files, presets and the wizard are just different ways to call it, so validation can't be bypassed and behaviour is identical everywhere.

**Pipeline:** `parse → (spec, flags) → [wizard] → model_finalize (preset + derived defaults) → model_validate → render_all → self-lint → systemd-analyze verify → write → systemctl`.

**Why Bash.** `ssg` must run on a bare server with nothing installed and be readable by the people who will trust it with root. The cost is care around quoting and `set -e`; the compensation is a test suite (Bats) and a strict ShellCheck/shfmt gate.

**Lists** (env, after, rw_path …) are newline-joined strings inside `U`; values can never contain newlines (rejected by `v_no_ctl`), so the encoding is unambiguous and avoids nested arrays.

**Sandbox table** (`harden.sh`) is data, not code: `Key=Value|min-version|scope`. `harden_lines` filters by target version and scope, then applies model-aware adjustments (JIT, no-network, home paths, capabilities). `SSG_SYSTEMD_VERSION` overrides the detected version to generate for another host.

**Activation wiring.** If a timer/socket/path unit exists, the service gets no `[Install]` and `enable`/`start` target the trigger unit (`model_primary`).

**Determinism.** No timestamps in output: regenerating identical settings yields a byte-identical file, which is what makes the "already up to date" no-op and the backup logic possible.

**Escaping rules.** `%` → `%%` except in template units (`name@`); `Environment="K=V"` escapes `\` and `"`; Exec arguments given after `--` are re-quoted with systemd's quoting rules; control characters are rejected outright.
