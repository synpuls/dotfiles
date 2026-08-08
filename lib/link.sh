#!/bin/bash
# shared/home → <machine>/home の順に $HOME へ symlink する(後勝ち)。
# dotfiles 管理外の実ファイル/ディレクトリは、上書き前に backup へ退避してから link する
# （新マシンや他人が実行しても既存ファイルを破壊しないための安全策）。
set -eu

MACHINE="${1:?usage: link.sh <machine>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# 退避先はこの実行ごとに1つ（同一 timestamp）。実際に退避が発生した時だけ作成される。
BACKUP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backups/$(date +%Y%m%d-%H%M%S)-$$"

# dotfiles 管理外の実体を backup へ移す（管理下 symlink は対象外）。
backup_unmanaged() {
  local target="$1" rel
  rel="${target#"$HOME"/}"
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  mv "$target" "$BACKUP_DIR/$rel"
  echo "backed up unmanaged: $target -> $BACKUP_DIR/$rel" >&2
}

link_path() {
  local source="$1"
  local target="$2"
  local child target_link

  if [ -d "$source" ]; then
    # ディレクトリは実体を作って中身だけ link し、~/.ssh や ~/.config 等で
    # リポジトリ外のファイルと共存できるようにする
    if [ -L "$target" ]; then
      target_link="$(readlink "$target")"
      case "$target_link" in
        "$ROOT_DIR"/*) ;;
        *)
          echo "Refusing to replace non-dotfiles symlink: $target -> $target_link" >&2
          exit 1
          ;;
      esac
      unlink "$target"
    elif [ -e "$target" ] && [ ! -d "$target" ]; then
      # source はディレクトリだが target が実ファイル → 退避してから mkdir
      backup_unmanaged "$target"
    fi
    mkdir -p "$target"
    for child in "$source"/* "$source"/.[!.]* "$source"/..?*; do
      [ -e "$child" ] || [ -L "$child" ] || continue
      link_path "$child" "$target/$(basename "$child")"
    done
  else
    if [ -L "$target" ]; then
      # 管理下(ROOT_DIR 配下)の symlink は張り替え、管理外 symlink は退避(dir 側と同じ扱い)
      target_link="$(readlink "$target")"
      case "$target_link" in
        "$ROOT_DIR"/*) unlink "$target" ;;
        *) backup_unmanaged "$target" ;;
      esac
    elif [ -e "$target" ]; then
      # dotfiles 管理外の実ファイル → 上書き前に退避
      backup_unmanaged "$target"
    fi
    ln -fnsv "$source" "$target"
  fi
}

link_layer() {
  local layer="$1"
  echo "Linking layer: $layer"

  local dotfile base
  for dotfile in "$layer"/.[!.]* "$layer"/..?*; do
    [ -e "$dotfile" ] || [ -L "$dotfile" ] || continue
    base="$(basename "$dotfile")"
    link_path "$dotfile" "$HOME/$base"
  done
}

link_layer "$ROOT_DIR/shared/home"
link_layer "$ROOT_DIR/$MACHINE/home"
