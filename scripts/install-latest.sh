#!/usr/bin/env bash
set -Eeuo pipefail
REPO="meysann/systemd-service-generator"
DEST="${1:-/usr/local/bin/ssg}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
url="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | awk -F'"' '/browser_download_url/ && /tar\.gz/ {print $4; exit}')"
[[ -n "$url" ]] || { echo "Could not find latest release tarball" >&2; exit 1; }
cd "$TMP"
curl -fsSL "$url" -o pkg.tgz
tar -xzf pkg.tgz
binpath="$(find . -type f -path "*/bin/ssg" | head -n1)"
[[ -n "$binpath" ]] || { echo "bin/ssg not found in tarball" >&2; exit 1; }
if [[ $EUID -ne 0 ]]; then sudo install -m 0755 "$binpath" "$DEST"; else install -m 0755 "$binpath" "$DEST"; fi
echo "Installed at $DEST"
