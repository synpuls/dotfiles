#!/bin/bash

export PATH="$HOME/.cargo/bin:$PATH"

brew bundle --global

echo "delta"
if ! command -v delta >/dev/null; then
  cargo install git-delta
fi
