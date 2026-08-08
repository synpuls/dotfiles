#!/usr/bin/env bash
# host の言語は Node の control-plane のみ（node は mise 管理・install_packages で導入済）。
# ここでは devcontainer CLI を npm(mise の node)で導入する。
# プロジェクトの言語 toolchain は各 repo の devcontainer が持つ（Codespaces と同一）。
set -euo pipefail

_here="$(cd "$(dirname "$0")" && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"

"${_here}/installers/devcontainer.sh"
