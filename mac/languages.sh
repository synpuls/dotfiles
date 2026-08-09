#!/bin/bash
# Mac の言語ランタイムを mise で導入する（anyenv から移行）。
# global 3 版は ~/.config/mise/config.toml + mise.lock が正本。ここでは明示版で
# 冪等 install し（cwd の project config に左右されない）、npm globals と rust を揃える。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

NODE_VERSION=22.22.3
RUBY_VERSION=3.4.2
GO_VERSION=1.25.6

command -v mise >/dev/null ||
  { echo "mise が無い。先に brew bundle を実行してください" >&2; exit 1; }

########################## install lang ##########################
# 既存版は再インストールされない（--force を付けない）。
mise install \
  "node@$NODE_VERSION" \
  "ruby@$RUBY_VERSION" \
  "go@$GO_VERSION"

########################## npm globals ##########################
# mise の global Node に対して不足分だけ導入（実行中の CLI を上書きしない）。
while IFS= read -r pkg; do
  [ -z "$pkg" ] && continue
  mise exec "node@$NODE_VERSION" -- npm ls -g --depth=0 "$pkg" >/dev/null 2>&1 ||
    mise exec "node@$NODE_VERSION" -- npm install -g "$pkg"
done <"$SCRIPT_DIR/npm_list"

mise reshim

########################## rust ##########################
export PATH="$HOME/.cargo/bin:$PATH"
if ! command -v cargo >/dev/null; then
  # brew の rustup の初期化手順。toolchain と ~/.cargo/bin の proxy を作る
  rustup default stable
fi
