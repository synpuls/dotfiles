#!/bin/bash
# HackGen を GitHub Release から ~/.fonts に取得する
set -eu

HACKGEN_VERSION="v2.9.0"
FONT_DIR="$HOME/.fonts"

if ls "$FONT_DIR"/HackGen*NF*.ttf >/dev/null 2>&1; then
	echo "HackGen は導入済みです"
	exit 0
fi

mkdir -p "$FONT_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -Lo "$tmp/hackgen.zip" \
	"https://github.com/yuru7/HackGen/releases/download/${HACKGEN_VERSION}/HackGen_NF_${HACKGEN_VERSION}.zip"
unzip -j "$tmp/hackgen.zip" '*.ttf' -d "$FONT_DIR"
fc-cache -f
