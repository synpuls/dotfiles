#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

bash "$ROOT_DIR/lib/nvim.sh"
bash "$ROOT_DIR/shared/vscode/install.sh"
