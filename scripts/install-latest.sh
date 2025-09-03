#!/usr/bin/env bash
set -Eeuo pipefail
REPO="meysann/systemd-service-generator"
PREFIX="${PREFIX:-/usr/local/share/systemd-service-generator}"
BIN_DEST="${BIN_DEST:-/usr/local/bin/ssg}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

url="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" |
  awk -F'"' '/browser_download_url/ && /tar\.gz/ {print $4; exit}')"
[[ -n "$url" ]] || {
  echo "Could not find latest release tarball" >&2
  exit 1
}

cd "$TMP"
curl -fsSL "$url" -o pkg.tgz
tar -xzf pkg.tgz

rootdir="."
[[ -d "./bin" ]] || rootdir="$(find . -type d -name bin -print0 -quit | xargs -0 -r dirname)"

# install tree + symlink
if [[ $EUID -ne 0 ]]; then
  sudo rm -rf "$PREFIX"
  sudo mkdir -p "$PREFIX"
  sudo cp -R "$rootdir/bin" "$rootdir/lib" "$rootdir/steps" "$PREFIX/"
  sudo ln -sf "$PREFIX/bin/ssg" "$BIN_DEST"
  sudo chmod 0755 "$PREFIX/bin/ssg"
else
  rm -rf "$PREFIX"
  mkdir -p "$PREFIX"
  cp -R "$rootdir/bin" "$rootdir/lib" "$rootdir/steps" "$PREFIX/"
  ln -sf "$PREFIX/bin/ssg" "$BIN_DEST"
  chmod 0755 "$PREFIX/bin/ssg"
fi

echo "Installed ssg → $BIN_DEST (prefix: $PREFIX)"
