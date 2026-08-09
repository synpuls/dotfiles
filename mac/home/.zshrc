# Homebrew
if ! command -v brew >/dev/null; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# config
export XDG_CONFIG_HOME="$HOME/.config"

# ghcup-env
[ -f "$HOME/.ghcup/env" ] && source "$HOME/.ghcup/env"

# mise（版マネージャ）: node/ruby/go を有効化（anyenv から移行）。
eval "$(mise activate zsh)"

# zplug
export ZPLUG_HOME=$HOMEBREW_PREFIX/opt/zplug
source $ZPLUG_HOME/init.zsh

source $HOME/.zshrc.common.zsh

export EDITOR=nvim

# zmm local commands
export PATH="$HOME/.local/bin:$PATH"
