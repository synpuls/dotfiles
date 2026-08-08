#!/usr/bin/env bash
# Dev Container CLI を npm（mise の node）で ~/.local prefix に pin 導入（root 不要）。
set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_here}/../tools.env"

command -v mise >/dev/null || { echo "devcontainer.sh: mise が無い（先に install_packages）" >&2; exit 1; }

cur="$(mise exec -- devcontainer --version 2>/dev/null || true)"
if [ "$cur" != "$DEVCONTAINER_CLI_VERSION" ]; then
  mise exec -- npm install -g --prefix "${HOME}/.local" "@devcontainers/cli@${DEVCONTAINER_CLI_VERSION}"
fi

mise exec -- devcontainer --version | grep -qx "$DEVCONTAINER_CLI_VERSION"
echo "devcontainer: $(mise exec -- devcontainer --version)"
