#!/usr/bin/env bash
# nvim 本体は mise 管理（install_packages で導入済）。ここは nvim-user-v6 設定を commit 固定で配置する。
# host nvim は汎用編集のみ（project の LSP/formatter/test/build は devcontainer 側 = dcx）。
set -euo pipefail

_here="$(cd "$(dirname "$0")" && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"
# shellcheck source=./tools.env
source "${_here}/tools.env"

# nvim 設定を commit 固定で取得（~/.local/share/nvim-user-v6/<commit>）し ~/.config/nvim を atomic 切替
share="${HOME}/.local/share/nvim-user-v6/${NVIM_USER_COMMIT}"
if [ ! -d "$share" ]; then
  mkdir -p "$(dirname "$share")"
  tmp="$(mktemp -d "$(dirname "$share")/.clone.XXXXXX")"
  git clone --quiet "https://github.com/${NVIM_USER_REPO}.git" "$tmp"
  git -C "$tmp" -c advice.detachedHead=false checkout --quiet "$NVIM_USER_COMMIT"
  rm -rf "${tmp}/.git"
  rm -rf "$share"
  mv "$tmp" "$share"
fi

cfg="${HOME}/.config/nvim"
mkdir -p "${HOME}/.config"
if [ -L "$cfg" ] || [ ! -e "$cfg" ]; then
  ln -sfn "$share" "$cfg"
elif [ -d "$cfg" ]; then
  mv "$cfg" "${cfg}.bak.$(date +%s)"
  ln -sfn "$share" "$cfg"
fi

echo "nvim config: ${NVIM_USER_REPO}@${NVIM_USER_COMMIT}"
echo "注: server host の nvim は汎用編集のみ（project LSP/test/build は dcx = devcontainer 側）。"
