# server プロファイルの zsh 設定。共通は shared/home/.zshrc.common.zsh。
export PATH="$HOME/.local/bin:$PATH"

# mise（版マネージャ）: node/nvim/lazygit/lazydocker/delta/ghq/starship/herdr を有効化。
# ※ 未 trust の project の mise 設定は既定で使わない（host に client toolchain を持ち込まない）。
eval "$(mise activate zsh)"

# locale（English/US。en_US.UTF-8 は server/init.sh が生成し system default にも設定する）
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

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

alias tf='terraform'
alias ti='terraform import'
alias tin='terraform init'
alias tp='terraform plan'
alias ta='terraform apply'
alias tsmv='terraform state mv'

# terraform の -target= は alias にできない。alias は前方一致の文字列置換なので
# `tpt foo` が `terraform plan -target= foo` になり、= と値が分離して壊れる。
#   tpt aws_s3_bucket.foo               → plan -target=aws_s3_bucket.foo
#   tat aws_s3_bucket.foo module.bar    → apply に -target= を 2 つ（terraform は複数指定可）
#   tpt -var-file=dev.tfvars module.bar → '-' 始まりは terraform へそのまま透過
# tat は -auto-approve を付けない（apply の対話確認は安全弁として残す）。
function _tf_target() {
  local sub=$1 caller=${funcstack[2]:-_tf_target}
  shift
  (( $# )) || { echo "usage: $caller <target> [target...] [terraform flags]" >&2; return 2; }
  local a args=()
  for a in "$@"; do
    case "$a" in
      -*) args+=("$a") ;;
      *) args+=("-target=$a") ;;
    esac
  done
  terraform "$sub" "${args[@]}"
}
function tpt() { _tf_target plan "$@"; }
function tat() { _tf_target apply "$@"; }
