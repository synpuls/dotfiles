#!/bin/bash
# Mac の言語ランタイムとユーザー CLI を mise で導入する（anyenv から移行）。
# ~/.config/mise/config.toml + mise.lock を唯一の正本とし、cwd の project config に
# 左右されないよう HOME を基準に冪等 install する。mise 管理外の rust もここで揃える。
set -euo pipefail

command -v mise >/dev/null ||
  { echo "mise が無い。先に brew bundle を実行してください" >&2; exit 1; }

########################## install mise tools ##########################
# 既存版は再インストールされない（--force を付けない）。
mise install -C "$HOME"

########################## rust ##########################
export PATH="$HOME/.cargo/bin:$PATH"
if ! command -v cargo >/dev/null; then
  # brew の rustup の初期化手順。toolchain と ~/.cargo/bin の proxy を作る
  rustup default stable
fi
