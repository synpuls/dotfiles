# server プロファイルの zsh 設定。共通は shared/home/.zshrc.common.zsh。
export PATH="$HOME/.local/bin:$PATH"

# mise（版マネージャ）: node/nvim/lazygit/lazydocker/delta/ghq/starship/herdr を有効化。
# ※ 未 trust の project の mise 設定は既定で使わない（host に client toolchain を持ち込まない）。
eval "$(mise activate zsh)"

# locale（ja が生成済みなら ja、無ければ en にフォールバック）
if locale -a 2>/dev/null | grep -qiE '^ja_JP\.utf-?8$'; then
  export LANG=ja_JP.UTF-8
else
  export LANG=en_US.UTF-8
fi
export LC_ALL="$LANG"

# server host の nvim は汎用編集のみ（project LSP/test/build は devcontainer=dcx 側）。
export SYNPULS_NVIM_PROFILE=host

source $HOME/.zplug/init.zsh
source $HOME/.zshrc.common.zsh

alias d="docker"
alias ld="lazydocker"
alias r="herdr server reload-config && exec $SHELL -l"
alias x="herdr"
alias xx="herdr server stop"

# devcontainer 実行境界（dcx = devcontainer up/exec/shell の薄いラッパ）
alias dcu="dcx up"
alias dcs="dcx shell"
