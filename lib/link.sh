#!/bin/bash
# shared/home → <machine>/home の順に $HOME へ symlink する(後勝ち)
set -eu

MACHINE="${1:?usage: link.sh <machine>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

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
    fi
    mkdir -p "$target"
    for child in "$source"/* "$source"/.[!.]* "$source"/..?*; do
      [ -e "$child" ] || [ -L "$child" ] || continue
      link_path "$child" "$target/$(basename "$child")"
    done
  else
    if [ -L "$target" ]; then
      unlink "$target"
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
