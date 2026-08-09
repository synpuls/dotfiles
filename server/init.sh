#!/usr/bin/env bash
# server プロファイルの system 層 bootstrap（root/OS 依存部分）。
# 上位 init.sh から genlocal → link の後に呼ばれる。ここでは apt prereq / locale / Docker /
# docker group / default shell を収束させる。ユーザーツールは setup.sh(install_packages 等)が担当。
set -euo pipefail

_here="$(cd "$(dirname "$0")" && pwd)"

# --- preflight（server は Ubuntu 24.04 x86_64 前提。不一致なら停止して誤爆を防ぐ） ---
# shellcheck disable=SC1091
. /etc/os-release
if [ "${ID:-}" != ubuntu ] || [ "${VERSION_ID:-}" != "24.04" ]; then
  echo "server profile は Ubuntu 24.04 を前提とします（検出: ${PRETTY_NAME:-unknown}）" >&2
  exit 1
fi
[ "$(uname -m)" = x86_64 ] || { echo "x86_64 のみ対応です" >&2; exit 1; }
sudo -n true 2>/dev/null || { echo "passwordless sudo が必要です（sudoers を確認）" >&2; exit 1; }
curl -fsI https://github.com >/dev/null 2>&1 || { echo "network に到達できません" >&2; exit 1; }

# --- apt prereq + locale（minimal Ubuntu では UTF-8 locale が未生成のことがある） ---
sudo apt-get update
# zsh もここで入れる（後段の chsh がこの時点で zsh を必要とするため。apt_list にもあり冪等）。
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg locales zsh
sudo locale-gen en_US.UTF-8
sudo locale-gen ja_JP.UTF-8 || true

# --- Docker（公式 repo・deb822・rootful。rootless は使わない=devcontainer 運用で単純） ---
if ! command -v docker >/dev/null; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.gpg
EOF
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# daemon log rotation（json-file 既定はディスクを食い潰し得る）。既存があれば衝突表示して停止。
if [ ! -f /etc/docker/daemon.json ]; then
  sudo install -m 0755 -d /etc/docker
  sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
  sudo systemctl restart docker || true
else
  echo "既存の /etc/docker/daemon.json があるため log rotation は手動確認（この script は上書きしない）" >&2
fi

# docker group（=実質 root 権限。README に明記）。再ログインで反映。
sudo usermod -aG docker "$USER"

# default shell を zsh に（sudo で行い、パスワード無しユーザーでも PAM 認証に阻まれないようにする）
zsh_path="$(command -v zsh || true)"
if [ -n "$zsh_path" ] && [ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]; then
  sudo chsh -s "$zsh_path" "$USER" || echo "chsh に失敗（手動で: sudo chsh -s $zsh_path $USER）" >&2
fi

# --- 1Password CLI(op)（公式 apt repo + debsig-verify。bootstrap が 1Password から鍵/名義/sops を配置するのに必要） ---
if ! command -v op >/dev/null; then
  curl -sS https://downloads.1password.com/linux/keys/1password.asc \
    | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
    | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
  sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
  curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol \
    | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol >/dev/null
  sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
  curl -sS https://downloads.1password.com/linux/keys/1password.asc \
    | sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y 1password-cli
fi

cat <<'EOF'

server/init.sh 完了。
docker group 反映と shell 変更のため、一度 logout/login（新しい SSH セッション）してから
  ./setup.sh
を実行してください。
EOF
