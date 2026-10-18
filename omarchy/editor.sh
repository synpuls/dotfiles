#!/bin/bash
# nvim 本体は Omarchy 同梱。設定(nvim-user-v6)は ~/workspace/<owner>/<repo> に clone して link する。
# Omarchy は ~/.config/nvim に LazyVim を置くため、lib/nvim.sh(既存なら何もしない)は使わない。
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

USER_REPO="synpuls/nvim-user-v6"
USER_REPO_PATH="$HOME/workspace/$USER_REPO"

if [ ! -d "$USER_REPO_PATH" ]; then
  git clone "git@github.com:${USER_REPO}.git" "$USER_REPO_PATH"
fi

if [ "$(readlink "$HOME/.config/nvim" 2>/dev/null)" != "$USER_REPO_PATH" ]; then
  # Omarchy の LazyVim(設定・データ・状態・キャッシュ)を退避してから link する
  backup="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backups/nvim-omarchy-$(date +%Y%m%d-%H%M%S)"
  for dir in "$HOME/.config/nvim" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
    if [ -e "$dir" ] || [ -L "$dir" ]; then
      mkdir -p "$backup"
      mv "$dir" "$backup/$(echo "${dir#"$HOME"/}" | tr / _)"
      echo "backed up: $dir -> $backup"
    fi
  done
  ln -fnsv "$USER_REPO_PATH" "$HOME/.config/nvim"
  nvim --headless "+Lazy! restore" +qa
fi

if command -v code >/dev/null; then
  bash "$ROOT_DIR/shared/vscode/install.sh"
else
  echo "code が無いため vscode 設定をスキップ"
fi
