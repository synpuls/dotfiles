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

# 標準入力をクリップボードへ。この host は headless でシステムクリップボードが無いため、
# OSC 52 で端末に渡して Mac 側へ届ける(herdr → WezTerm → Mac)。nvim の clipboard
# provider と同じ経路。端末側の受信上限を超えると切り詰められ得る点に注意。
function _osc52_copy() {
  local b64
  b64=$(base64 -w0) || return 1
  { printf '\033]52;c;%s\a' "$b64" >/dev/tty; } 2>/dev/null ||
    printf '\033]52;c;%s\a' "$b64"
}

# terraform plan -generate-config-out= は書き込み先にパスを要求し、既存ファイルには書かない。
# 作業ディレクトリに tmp.tf を残さないよう mktemp -d の中に生成させ、中身をクリップボードへ
# 送ってから tmp ごと捨てる。引数は terraform へ透過する(-target 等)。
function tpg() {
  local dir out rc
  dir=$(mktemp -d) || return 1
  out="$dir/generated.tf"
  terraform plan -generate-config-out="$out" "$@"
  rc=$?
  if (( rc == 0 )) && [[ -s $out ]]; then
    if _osc52_copy <"$out"; then
      echo "tpg: クリップボードへコピーしました($(wc -l <"$out") 行 / $(wc -c <"$out") bytes)" >&2
    else
      echo "tpg: クリップボードへ送れませんでした。以下に出力します" >&2
      cat "$out"
      rc=1
    fi
  elif (( rc == 0 )); then
    echo "tpg: 生成された config が空です(import ブロックはありますか)" >&2
    rc=1
  fi
  rm -rf "$dir"
  return $rc
}
