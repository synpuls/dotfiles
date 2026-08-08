#!/bin/bash

NODE_VERSION=22.22.3
RUBY_VERSION=3.4.2

########################## anyenv ##########################

export PATH="$HOME/.anyenv/bin:$PATH"
eval "$(anyenv init -)"

if [ ! -d "${XDG_CONFIG_HOME:-$HOME/.config}/anyenv/anyenv-install" ]; then
	anyenv install --init
fi

for env in nodenv rbenv; do
	if ! command -v "$env" >/dev/null; then
		echo "${env}をインストールします"
		anyenv install "$env"
	fi
done

mkdir -p "$(anyenv root)/plugins"
git clone https://github.com/znz/anyenv-update.git "$(anyenv root)/plugins/anyenv-update" 2>/dev/null || true
eval "$(anyenv init -)"
anyenv update

######################### haskell ##########################

if ! command -v ghc >/dev/null; then
	curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
fi

########################## install lang ##########################

if ! nodenv versions --bare | grep -qx "$NODE_VERSION"; then
	nodenv install "$NODE_VERSION"
	nodenv global "$NODE_VERSION"
fi

if ! rbenv versions --bare | grep -qx "$RUBY_VERSION"; then
	rbenv install "$RUBY_VERSION"
	rbenv global "$RUBY_VERSION"
fi
