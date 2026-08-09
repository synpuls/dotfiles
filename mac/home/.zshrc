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

# work: 統合 dev VM(workstation)に herdr --remote で接続する（UI 専用の attach。旧 work の後継）。
#   接続後は VM 上の herdr で ghq get / workspace 作成 / nvim / agent を操作する。
#   開発ポートの転送は work の責務外（別レイヤの fwd/unfwd = 専用 ssh master で管理する）。
work() {
  command -v herdr >/dev/null || { echo "work: herdr が必要です" >&2; return 1; }
  herdr --remote workstation "$@"
}
