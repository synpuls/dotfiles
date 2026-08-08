#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$(uname)" = "Darwin" ]; then
	VSCODE_SETTING_DIR="$HOME/Library/Application Support/Code/User"
else
	VSCODE_SETTING_DIR="$HOME/.config/Code/User"
fi

mkdir -p "$VSCODE_SETTING_DIR"
ln -fnsv "$SCRIPT_DIR/settings.json" "$VSCODE_SETTING_DIR/settings.json"
ln -fnsv "$SCRIPT_DIR/keybindings.json" "$VSCODE_SETTING_DIR/keybindings.json"

while IFS= read -r extension; do
	code --install-extension "$extension"
done <"$SCRIPT_DIR/extensions"

# extensions はマニフェストなので自動では書き戻さない。固定し直すときだけ --freeze
if [ "${1:-}" = "--freeze" ]; then
	code --list-extensions >"$SCRIPT_DIR/extensions"
	echo "extensions を現在のインストール状態で更新しました"
fi
