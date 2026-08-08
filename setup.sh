#!/bin/bash
# 本セットアップ(ssh 設定後)
set -eu

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
# 非ログインシェルでも各 CLI を解決できるように PATH を通す。
# - ~/.local/bin: dcx / devcontainer / fd / bat 等
# - ~/.local/share/mise/shims: mise 管理の node/npm/npx 等（後段の npx ベース skill 配線に必要）
# 両ディレクトリは存在しなくても無害（他マシンでは片方だけ or どちらも無い）。
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

MACHINE="$(resolve_machine)"
echo "マシンプロファイル: $MACHINE"

for step in install_packages languages editor; do
  "$ROOT_DIR/$MACHINE/$step.sh"
done

# 別リポジトリ管理の実行可能ファイルを ~/.local/bin へ link
"$ROOT_DIR/lib/link-bin.sh"

# エージェント skill / MCP を各ツールへ配線（skills.toml / mcp.toml 駆動）
if command -v python3 >/dev/null; then
  python3 "$ROOT_DIR/lib/link-skills.py"
  python3 "$ROOT_DIR/lib/link-mcp.py"
else
  echo "python3 が無いため skill/MCP 配線をスキップ"
fi

echo "お疲れ様でした。"
