#!/usr/bin/env bash
# server のユーザーツール。apt CLI + fd/bat の実名 symlink + mise で全ツール導入 + zplug。
set -euo pipefail

_here="$(cd "$(dirname "$0")" && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"

# --- apt user CLI ---
sudo apt-get update
xargs -a "${_here}/apt_list" sudo DEBIAN_FRONTEND=noninteractive apt-get install -y

# --- fd/bat: Ubuntu では fdfind/batcat。nvim 等 subprocess から見えるよう実名で symlink ---
mkdir -p "${HOME}/.local/bin"
[ -x /usr/bin/fdfind ] && ln -sfn /usr/bin/fdfind "${HOME}/.local/bin/fd"
[ -x /usr/bin/batcat ] && ln -sfn /usr/bin/batcat "${HOME}/.local/bin/bat"

# --- mise 本体 → 全ツール（node/nvim/lazygit/... は ~/.config/mise/config.toml + mise.lock で pin） ---
"${_here}/installers/mise.sh"
mise install

# --- zplug（zsh プラグインマネージャ） ---
if [ ! -d "${HOME}/.zplug" ]; then
  git clone --depth 1 https://github.com/zplug/zplug "${HOME}/.zplug"
fi
