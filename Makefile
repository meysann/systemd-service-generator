PREFIX ?= /usr/local

.PHONY: check test lint fmt install uninstall
check: ; scripts/dev-check.sh
test: ; bats -r tests
lint: ; shellcheck -x -e SC1090 -e SC1091 bin/ssg lib/*.sh scripts/*.sh completions/ssg.bash
fmt: ; shfmt -w -i 2 -ci -sr bin/ssg lib/*.sh scripts/*.sh completions/ssg.bash tests/helpers.bash
install: ; PREFIX=$(PREFIX) scripts/install.sh --local
uninstall:
	rm -rf $(PREFIX)/share/ssg $(PREFIX)/bin/ssg $(PREFIX)/share/bash-completion/completions/ssg
