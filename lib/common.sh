# マシン判定はここにのみ書く。初回の結果を PROFILE_FILE に保存し、以後はそれが正

PROFILE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/machine"

detect_machine() {
  if [ "$(uname)" = "Darwin" ]; then
    echo "mac"
    return
  fi
  # 非 Darwin は既定で server。デスクトップ機は初回のみ `./init.sh ubuntu-desktop` で明示保存する
  echo "server"
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
