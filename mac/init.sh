#!/bin/bash

if [ "$(uname)" != "Darwin" ]; then
  echo "macOSではありません"
  exit 1
fi
echo "macOSの初期設定を開始します"

echo "Mac本体の設定を好みにします"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/mac_settings.sh"

echo "メモリ異常の早期警告を設定します"
"$SCRIPT_DIR/install_memory_watchdog.sh"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Toolsをインストールします"
  xcode-select --install
fi

if ! command -v brew >/dev/null; then
  echo "Homebrewをインストールします"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if [ "$(uname -m)" = "arm64" ] && ! pgrep -xq oahd; then
  echo "Rosettaをインストールします"
  softwareupdate --install-rosetta --agree-to-license
fi
