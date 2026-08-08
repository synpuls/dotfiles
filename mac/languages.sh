#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

NODE_VERSION=22.22.3
RUBY_VERSION=3.4.2
GO_VERSION=1.25.6

########################## anyenv ##########################

export PATH="$HOME/.anyenv/bin:$PATH"
eval "$(anyenv init -)"

if [ ! -d "${XDG_CONFIG_HOME:-$HOME/.config}/anyenv/anyenv-install" ]; then
  anyenv install --init
fi

for env in nodenv rbenv goenv; do
  if ! command -v "$env" >/dev/null; then
    echo "${env}をインストールします"
    anyenv install "$env"
  fi
done

mkdir -p "$(anyenv root)/plugins"
git clone https://github.com/znz/anyenv-update.git "$(anyenv root)/plugins/anyenv-update" 2>/dev/null || true
eval "$(anyenv init -)"
anyenv update

########################## install lang ##########################

if ! nodenv versions --bare | grep -qx "$NODE_VERSION"; then
  nodenv install "$NODE_VERSION"
  nodenv global "$NODE_VERSION"
fi

if ! rbenv versions --bare | grep -qx "$RUBY_VERSION"; then
  rbenv install "$RUBY_VERSION"
  rbenv global "$RUBY_VERSION"
fi

if ! goenv versions --bare | grep -qx "$GO_VERSION"; then
  goenv install "$GO_VERSION"
  goenv global "$GO_VERSION"
fi

# 導入済みの再インストールはしない(実行中の CLI を上書きしないため)
while IFS= read -r pkg; do
  npm ls -g --depth=0 "$pkg" >/dev/null 2>&1 || npm install -g "$pkg"
done <"$SCRIPT_DIR/npm_list"

########################## rust ##########################

export PATH="$HOME/.cargo/bin:$PATH"
if ! command -v cargo >/dev/null; then
  # brew の rustup の初期化手順。toolchain と ~/.cargo/bin の proxy を作る
  rustup default stable
fi
