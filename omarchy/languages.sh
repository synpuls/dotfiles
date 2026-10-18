#!/bin/bash
# 言語ランタイムを mise で導入する（Mac と同じ版）。
# global は ~/.config/mise/config.toml + mise.lock が正本。
set -euo pipefail

command -v mise >/dev/null || { echo "mise がありません（Omarchy 同梱のはず）" >&2; exit 1; }

# cwd の project config に左右されないよう HOME で実行する
cd "$HOME"
mise install
mise reshim
