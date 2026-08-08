#!/bin/bash
# 下ごしらえ(再起動前まで)。使い方: ./init.sh [machine]
set -eu

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

MACHINE="${1:-$(resolve_machine)}"
if [ ! -d "$ROOT_DIR/$MACHINE/home" ]; then
  echo "不明なマシンです: $MACHINE" >&2
  exit 1
fi
save_machine "$MACHINE"
echo "マシンプロファイル: $MACHINE"

repo_root="$(git -C "$ROOT_DIR" rev-parse --show-toplevel)"
git -C "$repo_root" config core.hooksPath "$ROOT_DIR/githooks"

"$ROOT_DIR/genlocal.sh"

# machine init より先に link しておくと、init が systemd unit 等の link 済み設定を参照できる
"$ROOT_DIR/lib/link.sh" "$MACHINE"

"$ROOT_DIR/$MACHINE/init.sh"

echo "次は ssh の設定をしましょう。"
