autoload -Uz compinit && compinit
autoload -Uz colors && colors
autoload -Uz add-zsh-hook

HISTSIZE=100000
SAVEHIST=100000
HISTFILE=$HOME/.zsh_history
setopt append_history
setopt share_history
setopt hist_ignore_all_dups

bindkey -e

alias r="exec \$SHELL -l"
alias b="bat"
alias t="tree -ACL 2 -I node_modules"
alias tt="tree -aACL 2 -I node_modules"
alias f="fg"
alias g="grep"
alias h="herdr"
alias ll="ls -alF -G"
alias v="nvim"
alias vi="nvim"
alias ..="cd .."
alias ...="cd ../.."

function chpwd() {
  tree -ACL 1
}

# when enter
function do_enter() {
  zle accept-line
  if [ -z "$BUFFER" ]; then
    tree -ACL 1
  fi
}

zle -N do_enter
bindkey '^m' do_enter
bindkey '^j' do_enter

typeset -g HERDR_LAST_TAB_LABEL=""

function herdr-rename-tab() {
  [[ -n ${HERDR_TAB_ID:-} ]] || return
  command -v herdr >/dev/null || return

  local label="$1"
  [[ -n $label ]] || return
  [[ $HERDR_LAST_TAB_LABEL == "$label" ]] && return

  HERDR_LAST_TAB_LABEL="$label"
  herdr tab rename "$HERDR_TAB_ID" "$label" >/dev/null 2>&1 &!
}

function herdr-rename-tab-for-command() {
  local words command_name
  words=("${(z)1}")

  if [[ ${words[1]:-} == cd ]]; then
    local i
    for i in {1..${#words[@]}}; do
      if [[ ${words[$i]} == "&&" ]]; then
        words=("${words[@]:$i}")
        break
      fi
    done
  fi

  while [[ ${#words[@]} -gt 0 ]]; do
    command_name=${words[1]}
    case "$command_name" in
      command|exec|env|noglob|time|sudo)
        words=("${words[@]:1}")
        ;;
      *=*)
        words=("${words[@]:1}")
        ;;
      *)
        break
        ;;
    esac
  done

  [[ -n ${command_name:-} ]] || return
  if [[ -n ${aliases[$command_name]:-} ]]; then
    words=("${(z)aliases[$command_name]}")
    command_name=${words[1]}
  fi
  command_name=${command_name:t}
  herdr-rename-tab "$command_name"
}
add-zsh-hook preexec herdr-rename-tab-for-command

function herdr-rename-tab-for-prompt() {
  herdr-rename-tab "${SHELL:t}"
}
add-zsh-hook precmd herdr-rename-tab-for-prompt

# ghq
function peco-ghq-look() {
  local project dir repository workspace workspace_id response current_label created pane pane_id
  project=$(ghq list -p | peco --prompt='Project >')

  if [[ $project == "" ]]; then
    return 1
  else
    dir=$project
  fi

  if [[ -n ${HERDR_ENV:-} ]] && command -v herdr >/dev/null && command -v jq >/dev/null; then
    repository=${dir##*/}
    workspace=${repository//./-}
    workspace_id=$(herdr workspace list \
      | jq -r --arg label "$workspace" '.result.workspaces[]? | select(.label == $label) | .workspace_id' \
      | head -n 1)

    if [[ -n $workspace_id ]]; then
      herdr workspace focus "$workspace_id" >/dev/null
    else
      created=1
      current_label=$(herdr workspace get "${HERDR_WORKSPACE_ID:-}" 2>/dev/null \
        | jq -r '.result.workspace.label // empty')
      # home workspace (Cmd+Shift+T) は cwd=$HOME なので label が "~" になる
      if [[ -n ${HERDR_WORKSPACE_ID:-} && ( -z $current_label || $current_label == "~" ) ]]; then
        # 現在の workspace が未バインド(home)なら新規作成せず今の workspace を上書きする
        workspace_id=$HERDR_WORKSPACE_ID
        herdr workspace rename "$workspace_id" "$workspace" >/dev/null
      else
        response=$(herdr workspace create --cwd "$dir" --label "$workspace" --focus)
        workspace_id=$(printf '%s' "$response" | jq -r '.result.workspace.workspace_id // empty')
      fi
    fi

    # 新規作成/再利用した workspace の pane を repo dir へ移す（nvim 等は起動しない）。
    if [[ -n ${created:-} ]]; then
      pane=$(herdr pane list --workspace "$workspace_id" \
        | jq -c '.result.panes | (map(select(.focused == true))[0] // .[0]) // empty')
      pane_id=$(printf '%s' "$pane" | jq -r '.pane_id // empty')
      [[ -n $pane_id ]] && herdr pane run "$pane_id" "cd ${(q)dir}" >/dev/null
    fi
  else
    cd $dir
  fi
}
zle -N peco-ghq-look
bindkey '^G' peco-ghq-look

# 空の新規 Herdr workspace を $HOME で作る(wezterm の Cmd+Shift+T が ^X^T を送って呼ぶ)。
# new_cwd="follow" のため native new_workspace は現 cwd を継承する(=複製に見える)ので、
# 明示的に --cwd $HOME で作る。pane 内 = server socket 経由なので herdr --remote でも効く。
# 制約: zsh プロンプト上でのみ発火(peco-ghq-look=^G と同じ)。
function herdr-new-home-workspace() {
  if [[ -n ${HERDR_ENV:-} ]] && command -v herdr >/dev/null; then
    herdr workspace create --cwd "$HOME" --focus >/dev/null 2>&1
  fi
  zle reset-prompt 2>/dev/null
}
zle -N herdr-new-home-workspace
bindkey '^X^T' herdr-new-home-workspace

# dev: 現在の Herdr workspace に開発用の 4 tab(nvim / claude / codex / zsh)を作る。
#   実行 tab が余らないよう、dev を実行したこの tab を先頭の nvim tab として再利用し、
#   claude / codex / zsh を続けて新規作成する（順番: nvim, claude, codex, zsh）。
#   zsh tab は 左 | 右上/右下 の 3 pane。
function dev() {
  [[ -n ${HERDR_ENV:-} && -n ${HERDR_WORKSPACE_ID:-} ]] || {
    echo "dev: Herdr の workspace 内で実行してください" >&2; return 1; }
  command -v herdr >/dev/null && command -v jq >/dev/null || {
    echo "dev: herdr と jq が必要です" >&2; return 1; }

  local ws="$HERDR_WORKSPACE_ID" cwd="$PWD"
  local spec label cmd resp pane right

  # 現在の tab(dev を実行したこの tab)を nvim tab として再利用 → 先頭が nvim になる。
  # nvim は現在の pane で起動する(nvim 終了時はシェルに戻る)。
  [[ -n ${HERDR_PANE_ID:-} ]] && herdr pane run "$HERDR_PANE_ID" nvim >/dev/null

  # claude / codex を新規 tab で作成(no-focus)。
  for spec in "claude:claude" "codex:codex"; do
    label=${spec%%:*}; cmd=${spec#*:}
    resp=$(herdr tab create --workspace "$ws" --cwd "$cwd" --label "$label" --no-focus)
    pane=$(printf '%s' "$resp" | jq -r '.result.root_pane.pane_id // empty')
    [[ -n $pane ]] && herdr pane run "$pane" "$cmd" >/dev/null
  done

  # zsh tab(新規): 左 pane | 右 pane、さらに右を上下に分割 → 左 | (右上 / 右下)
  resp=$(herdr tab create --workspace "$ws" --cwd "$cwd" --label zsh --no-focus)
  pane=$(printf '%s' "$resp" | jq -r '.result.root_pane.pane_id // empty')
  if [[ -n $pane ]]; then
    right=$(herdr pane split "$pane" --direction right --cwd "$cwd" --no-focus \
      | jq -r '.result.pane.pane_id // empty')
    [[ -n $right ]] && herdr pane split "$right" --direction down --cwd "$cwd" --no-focus >/dev/null
  fi
  # nvim(現在 tab)に居るので focus 変更は不要。
}


eval "$(starship init zsh)"

zplug "zsh-users/zsh-history-substring-search"
zplug "zsh-users/zsh-syntax-highlighting", defer:2
zplug "zsh-users/zsh-autosuggestions"
if ! zplug check --verbose; then
  if [[ -n ${ZPLUG_AUTO_INSTALL:-} ]]; then
    zplug install            # provisioning 中は非対話で導入
  elif [[ -t 0 ]]; then
    printf "Install? [y/N]: "
    if read -q; then
      echo; zplug install
    fi
  fi
fi
bindkey '^[OA' history-substring-search-up
bindkey '^P' history-substring-search-up
bindkey '^[OB' history-substring-search-down
bindkey '^N' history-substring-search-down

zplug load

[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# sops: age 秘密鍵の場所(復号用)
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

# マシンローカル設定(git 管理外)
if [ -f $HOME/.zshrc.local ]; then
  source $HOME/.zshrc.local
fi
