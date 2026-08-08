#!/bin/bash

export PATH="$HOME/.cargo/bin:$HOME/go/bin:$PATH"

echo "starship"
if ! command -v starship >/dev/null; then
	curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

echo "ghq"
if ! command -v ghq >/dev/null; then
	go install github.com/x-motemen/ghq@latest
fi

echo "lazydocker"
if ! command -v lazydocker >/dev/null; then
	go install github.com/jesseduffield/lazydocker@latest
fi

echo "docker"
if ! command -v docker >/dev/null; then
	dockerd-rootless-setuptool.sh install
fi

echo "lazygit"
if ! command -v lazygit >/dev/null; then
	LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
	curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
	tar xf lazygit.tar.gz lazygit
	sudo install lazygit /usr/local/bin
fi

echo "wezterm"
if ! command -v wezterm >/dev/null; then
	WEZTERM_VERSION=$(curl -s "https://api.github.com/repos/wez/wezterm/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
	UBUNTU_VERSION=$(. /etc/os-release && echo "$VERSION_ID")
	curl -LO "https://github.com/wez/wezterm/releases/download/${WEZTERM_VERSION}/wezterm-${WEZTERM_VERSION}.Ubuntu${UBUNTU_VERSION}.deb"
	sudo apt install -y "./wezterm-${WEZTERM_VERSION}.Ubuntu${UBUNTU_VERSION}.deb"
fi

echo "herdr"
if ! command -v herdr >/dev/null; then
	curl -fsSL https://herdr.dev/install.sh | sh
fi

echo "anyenv"
if [ ! -d "$HOME/.anyenv" ]; then
	git clone https://github.com/anyenv/anyenv ~/.anyenv
fi

echo "rustup"
if ! command -v rustup >/dev/null; then
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

echo "delta"
if ! command -v delta >/dev/null; then
	cargo install git-delta
fi

echo "xremap"
if ! command -v xremap >/dev/null; then
	cargo install xremap --features x11
fi

echo "zplug"
if [ ! -d "$HOME/.zplug" ]; then
	curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
fi
