# systemd-service-generator

Create safe, modern **systemd** services (and timers) interactively—no docs diving required.

[![CI](https://img.shields.io/github/actions/workflow/status/meysann/systemd-service-generator/ci.yml?branch=main)](https://github.com/meysann/systemd-service-generator/actions)
![License](https://img.shields.io/badge/license-MIT-blue)
![Shell](https://img.shields.io/badge/shell-bash-4EAA25)

## Quick start

```bash
git clone https://github.com/meysann/systemd-service-generator.git
cd systemd-service-generator
bash bin/ssg
```

## Features
- Interactive, beginner-friendly prompts (scope, ExecStart, restart, logging, hardening…)
- Safe defaults; ShellCheck/shfmt clean
- Generates `.service` now; `.timer` on the roadmap

## Compatibility
- Linux with **systemd** (`systemctl` required)
- Bash 4+

## Contributing
PRs welcome! Good first issues will be labeled. CI runs ShellCheck/shfmt/Bats.

### Show available options
```bash
ssg --features
```
