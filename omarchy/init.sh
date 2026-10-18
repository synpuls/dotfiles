#!/usr/bin/env bash
# omarchy プロファイルの system 層 bootstrap（root/OS 依存部分）。
# 上位 init.sh から genlocal → link の後に呼ばれる。pacman/AUR パッケージ / xremap 用 uinput /
# default shell を収束させる。ユーザー層は setup.sh(install_packages 等)が担当。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- preflight（Omarchy = Arch + Hyprland 前提） ---
# shellcheck disable=SC1091
. /etc/os-release
if [ "${ID:-}" != omarchy ]; then
  echo "omarchy profile は Omarchy を前提とします（検出: ${PRETTY_NAME:-unknown}）" >&2
  exit 1
fi

# --- パッケージ ---
# Omarchy は pacman -Syu の直接実行を hook で拒否する。system 更新は omarchy update
# (snapshot / keyring / migration 込み)に任せ、最新化した上で不足分だけ入れる(部分更新を避ける)。
omarchy update -y

mapfile -t pkgs < <(grep -v '^\s*\(#\|$\)' "$SCRIPT_DIR/pacman_list")
omarchy pkg add "${pkgs[@]}"

mapfile -t aur_pkgs < <(grep -v '^\s*\(#\|$\)' "$SCRIPT_DIR/aur_list")
omarchy pkg aur add "${aur_pkgs[@]}"

# --- xremap: uinput を一般ユーザーで使えるようにする ---
echo uinput | sudo tee /etc/modules-load.d/uinput.conf >/dev/null
sudo modprobe uinput
echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' |
  sudo tee /etc/udev/rules.d/99-input.rules >/dev/null
sudo udevadm control --reload-rules && sudo udevadm trigger
sudo usermod -a -G input "$USER"

# --- pkexec の認証を数分保持する ---
# エージェント(Claude Code 等)は TTY が無く sudo を使えないため pkexec で昇格する。既定の
# auth_admin は毎回パスワードを聞くので、wheel に限り auth_admin_keep(polkit 既定で約 5 分、
# 同じログインセッション内)にする。
sudo tee /etc/polkit-1/rules.d/49-pkexec-keep.rules >/dev/null <<'RULES'
// wheel の pkexec は一度認証したら数分間(同じセッション内)パスワードを聞かない
polkit.addRule(function(action, subject) {
  if (action.id == "org.freedesktop.policykit.exec" && subject.isInGroup("wheel")) {
    return polkit.Result.AUTH_ADMIN_KEEP;
  }
});
RULES

# --- default shell ---
if [ "$(getent passwd "$USER" | cut -d: -f7)" != /usr/bin/zsh ]; then
  sudo chsh -s /usr/bin/zsh "$USER"
fi

echo "input group と default shell(zsh)を反映するため、一度 logout/login してください。"
