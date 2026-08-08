#!/usr/bin/env bash
# mise（版マネージャ）本体を pin+sha のリリースバイナリで ~/.local/bin へ導入。
# node/nvim/CLI 群の実体は mise が config.toml + mise.lock に従って入れる。
set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_here}/../../lib/install-release.sh"
source "${_here}/../tools.env"
[ "$(ir_arch)" = x86_64 ] || { echo "mise.sh: x86_64 のみ対応" >&2; exit 1; }

dest="${HOME}/.local/bin/mise"
if ! { [ -x "$dest" ] && "$dest" --version 2>/dev/null | grep -q "$MISE_VERSION"; }; then
  url="https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64"
  ir_install_raw_binary "$url" "$MISE_LINUX_X64_SHA256" "$dest"
fi
"$dest" --version | grep -q "$MISE_VERSION"
echo "mise: $("$dest" --version)"
