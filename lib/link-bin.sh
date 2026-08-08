#!/bin/bash
# dotfiles 内蔵の実行可能ファイルと、マシン固有(非公開)の実行可能ファイルを ~/.local/bin へ link する。
# ~/.local/bin は PATH 上にある前提(無ければ作る)。実体が無ければ黙って飛ばす。
set -eu

BIN_DIR="$HOME/.local/bin"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$BIN_DIR"

# dotfiles が公開する内蔵 bin(このリポジトリ内)。
BINS=(
  "dcx=${ROOT}/shared/bin/dcx"
)

# マシン固有・非公開の bin は ~/.config/dotfiles/bins.local に "name=path"(1行1件)で書く。
# 例) kj=~/workspace/github.com/you/private-repo/scripts/kj
# public リポジトリに private repo の path をハードコードしないための仕組み。
LOCAL_BINS="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/bins.local"
if [ -f "$LOCAL_BINS" ]; then
  while IFS= read -r line; do
    case "$line" in '' | \#*) continue ;; esac
    BINS+=("$line")
  done <"$LOCAL_BINS"
fi

for entry in "${BINS[@]}"; do
  name="${entry%%=*}"
  source="${entry#*=}"
  name="${name%$'\r'}"     # CRLF 対策
  source="${source%$'\r'}"
  # name の検証: 空 / スラッシュ / .. を拒否(BIN_DIR 外への path traversal 防止)
  case "$name" in
    '' | */* | *..*)
      echo "スキップ(不正な bin 名): '$name'" >&2
      continue
      ;;
  esac
  source="${source/#\~/$HOME}" # 先頭の ~ を展開
  if [ ! -e "$source" ]; then
    echo "スキップ(実体なし): $name -> $source"
    continue
  fi
  ln -fnsv "$source" "$BIN_DIR/$name"
done
