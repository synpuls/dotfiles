#!/bin/bash
# 別リポジトリで管理している実行可能ファイルを ~/.local/bin へ link する。
# ~/.local/bin は PATH 上にある前提(無ければ作る)。
# 追加は BINS に "リンク名=実体パス" を足すだけ。実体が無ければ黙って飛ばす。
set -eu

BIN_DIR="$HOME/.local/bin"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

BINS=(
  # dotfiles 内の実行可能ファイル（$HOME 直下ではなく ~/.local/bin へ置きたいもの）。
  # ~/.local/bin/ は `.local/` を含み link.sh(home ミラー)が扱えない(規約で ignore)ため、ここで link する。
  "dcx=${ROOT}/shared/bin/dcx"
  # 別リポジトリ管理の実行可能ファイル。
  "kj=$HOME/workspace/github.com/synpuls/kinjito/scripts/kj"
)

mkdir -p "$BIN_DIR"

for entry in "${BINS[@]}"; do
  name="${entry%%=*}"
  source="${entry#*=}"
  if [ ! -e "$source" ]; then
    echo "スキップ(実体なし): $name -> $source"
    continue
  fi
  ln -fnsv "$source" "$BIN_DIR/$name"
done
