#!/bin/bash

NVIM_REPO="neovim/neovim"
USER_REPO="synpuls/nvim-user-v6"

if ! command -v nvim >/dev/null; then
	ghq get "git@github.com:${NVIM_REPO}.git"
	cd "$(ghq list --full-path | grep --color=never -E "${NVIM_REPO}")" || exit
	make CMAKE_BUILD_TYPE=RelWithDebInfo
	sudo make install
fi

if [ ! -d ~/.config/nvim ]; then
	ghq get "git@github.com:${USER_REPO}.git"
	USER_REPO_PATH="$(ghq list --full-path | grep --color=never -E "${USER_REPO}")"
	ln -fnsv "$USER_REPO_PATH" "${HOME}/.config/nvim"
fi
