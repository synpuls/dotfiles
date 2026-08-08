#!/bin/bash
# git 管理外の *.local ファイルを生成する。既存ファイルには触れない。
# 使い方: ./genlocal.sh [repo-file...]  (引数なしなら規定の拡張ポイント)
set -eu

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

# 除外リストは各層直下の .genlocalignore
IGNORE_FILE=".genlocalignore"

rel_path() {
  local abs
  abs="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  echo "${abs#"$ROOT_DIR"/}"
}

is_blacklisted() {
  local rel="$1"
  local layer="${rel%%/*}"
  local ignore_file="$ROOT_DIR/$layer/$IGNORE_FILE"
  [ -f "$ignore_file" ] || return 1

  local line entry
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -z "$line" ] && continue

    entry="$layer/$line"
    if [ "$rel" = "$entry" ] || [[ "$rel" == "$entry"/* ]]; then
      return 0
    fi
  done <"$ignore_file"
  return 1
}

default_targets() {
  local machine
  machine="$(resolve_machine)"
  echo "$ROOT_DIR/$machine/home/.zshrc.local"     # .zshrc.common.zsh の最後に source される
  echo "$ROOT_DIR/$machine/home/.gitconfig.local" # .gitconfig の [include] から読まれる
}

generate() {
  local target="$1"
  if [ -e "$target" ]; then
    echo "skip (already exists): $target"
    return
  fi

  mkdir -p "$(dirname "$target")"
  case "$target" in
  *.json)
    printf '{}\n' >"$target"
    ;;
  *)
    echo "# $(basename "$target") — このマシンだけの設定(git 管理外)" >"$target"
    ;;
  esac
  echo "created: $target"
}

if [ "$#" -eq 0 ]; then
  while IFS= read -r target; do
    generate "$target"
  done < <(default_targets)
else
  for src in "$@"; do
    case "$src" in
    *.local | *.local.*)
      echo "skip (それ自体がローカル版です): $src"
      continue
      ;;
    esac
    if [ ! -e "$src" ]; then
      echo "skip (公開側のファイルが見つかりません): $src" >&2
      continue
    fi
    if is_blacklisted "$(rel_path "$src")"; then
      echo "skip (.genlocalignore の対象です): $src"
      continue
    fi
    generate "${src}.local"
  done
fi
