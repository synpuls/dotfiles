# Omarchy の zsh 設定。共通は shared/home/.zshrc.common.zsh。
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nvim

# Omarchy のコマンド群(omarchy-*)
export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
export PATH="$OMARCHY_PATH/bin:$PATH"

# ssh-agent(openssh 同梱の user unit。install_packages.sh で有効化)。AddKeysToAgent で鍵を覚えさせる
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

# mise（版マネージャ）: node/ruby/go と claude/codex/gh を有効化。
eval "$(mise activate zsh)"

source $HOME/.zplug/init.zsh
source $HOME/.zshrc.common.zsh

function c() {
  echo -n "$*" | wl-copy
}
