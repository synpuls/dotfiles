# マシン判定はここにのみ書く。初回の結果を PROFILE_FILE に保存し、以後はそれが正

PROFILE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/machine"

detect_machine() {
  if [ "$(uname)" = "Darwin" ]; then
    echo "mac"
    return
  fi
  # Linux は「Ubuntu 24.04 / x86_64 / 非WSL」の時だけ server を自動判定する。
  # server プロファイルの前提(server/init.sh の preflight)と一致させ、変更適用より前の誤爆を防ぐ。
  # 22.04 / ARM / WSL / desktop 等は自動判定せず、明示指定(./init.sh <machine>)を促す。
  if [ -r /etc/os-release ] &&
    (. /etc/os-release && [ "${ID:-}" = "ubuntu" ] && [ "${VERSION_ID:-}" = "24.04" ]) &&
    [ "$(uname -m)" = "x86_64" ] &&
    ! grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
    echo "server"
    return
  fi
  echo "マシンを自動判定できません。./init.sh <machine> で明示してください(例: server)。" >&2
  return 1
}

resolve_machine() {
  if [ -f "$PROFILE_FILE" ]; then
    cat "$PROFILE_FILE"
  else
    detect_machine
  fi
}

save_machine() {
  mkdir -p "$(dirname "$PROFILE_FILE")"
  echo "$1" >"$PROFILE_FILE"
}
