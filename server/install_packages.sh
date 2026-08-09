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
# プラグインを非対話で導入（初回対話シェルが .zshrc の Install? プロンプトで止まるのを防ぐ）。
# zplug は登録/導入に PTY を要する（TTY 無しだと zplug install が無言の no-op になる）ため
# script(1) で擬似端末を与える。ZPLUG_AUTO_INSTALL=1 で .zshrc 側は確認を出さず走らせる。
TERM=xterm ZPLUG_AUTO_INSTALL=1 script -qec 'zsh -ic exit' /dev/null >/dev/null 2>&1 || true
