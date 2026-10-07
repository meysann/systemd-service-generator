#!/usr/bin/env bash
# Install ssg from a release tarball, or from a local checkout (--local).
#   curl -fsSL https://raw.githubusercontent.com/meysann/systemd-service-generator/main/scripts/install.sh | bash
# Env: PREFIX (default /usr/local)   VERSION (default: latest release)
set -Eeuo pipefail

REPO="meysann/systemd-service-generator"
PREFIX="${PREFIX:-/usr/local}"
SHARE="$PREFIX/share/ssg"
BIN="$PREFIX/bin/ssg"
COMP_DIR="${COMP_DIR:-$PREFIX/share/bash-completion/completions}"

as_root() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [[ ${1-} == --local ]]; then
  src=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
else
  ver=${VERSION:-}
  if [[ -z $ver ]]; then
    ver=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)
  fi
  [[ -n $ver ]] || {
    echo "Could not determine the latest release." >&2
    exit 1
  }
  echo "Installing ssg $ver …"
  curl -fsSL "https://github.com/$REPO/archive/refs/tags/$ver.tar.gz" -o "$tmp/ssg.tgz"
  tar -xzf "$tmp/ssg.tgz" -C "$tmp"
  src=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)
fi

[[ -x $src/bin/ssg ]] || {
  echo "Not an ssg tree: $src" >&2
  exit 1
}

as_root rm -rf "$SHARE"
as_root install -d "$SHARE" "$(dirname "$BIN")" "$COMP_DIR"
as_root cp -R "$src/bin" "$src/lib" "$src/completions" "$src/VERSION" "$SHARE/"
as_root ln -sf "$SHARE/bin/ssg" "$BIN"
as_root install -m 0644 "$src/completions/ssg.bash" "$COMP_DIR/ssg"

echo "Installed: $BIN → $SHARE   (try: ssg doctor)"
