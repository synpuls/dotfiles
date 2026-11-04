#!/usr/bin/env bash
# 固定したソースから CLI だけをビルドする。既存 checkout は変更しない。
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
source "$ROOT/shared/legacy-source.env"
prefix="$HOME/.local/opt/legacy"
source_url=$LEGACY_GIT_URL
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix|--source)
      [[ $# -ge 2 && -n "$2" ]] || { echo "legacy: $1 に値が必要です" >&2; exit 2; }
      case "$1" in --prefix) prefix=$2 ;; --source) source_url=$2 ;; esac
      shift 2 ;;
    *) echo "Usage: $0 [--prefix DIR] [--source Git-URL]" >&2; exit 2 ;;
  esac
done
[[ "$LEGACY_GIT_REV" =~ ^[0-9a-f]{40}$ &&
   "$LEGACY_RUST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ &&
   "$LEGACY_CLI_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo 'legacy: shared/legacy-source.env の固定値が不正です' >&2; exit 1;
}
platform="$(uname -s)-$(uname -m)"
case "$platform" in
  Darwin-arm64|Darwin-x86_64|Linux-aarch64|Linux-x86_64) ;;
  *) echo "legacy: 未対応の環境です: $platform" >&2; exit 1 ;;
esac
mkdir -p "$prefix"
prefix=$(cd "$prefix" && pwd -P)
destination="$prefix/$LEGACY_GIT_REV/$LEGACY_RUST_VERSION/$platform/legacy"
stage=$(mktemp -d "$prefix/.install.XXXXXX")
trap 'rm -rf "$stage"' EXIT

if [[ ! -x "$destination" ]] || [[ "$("$destination" --version 2>/dev/null)" != "legacy $LEGACY_CLI_VERSION" ]]; then
  if ! command -v rustup >/dev/null && [[ -x "$HOME/.cargo/bin/rustup" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
  fi
  command -v rustup >/dev/null || {
    echo 'legacy: rustup が必要です。Mac は dotfiles の brew / languages、Linux は Rust 環境を先に導入してください。' >&2; exit 1;
  }
  command -v git >/dev/null || { echo 'legacy: git が必要です' >&2; exit 1; }
  if ! rustup run "$LEGACY_RUST_VERSION" rustc --version >/dev/null 2>&1; then
    rustup toolchain install "$LEGACY_RUST_VERSION" --profile minimal
  fi
  # Git は既存の SSH 設定を使う。ビルドは呼出元の Cargo 設定や target を使わない。
  (
    cd "$stage"
    CARGO_NET_GIT_FETCH_WITH_CLI=true CARGO_TARGET_DIR="$stage/target" \
      rustup run "$LEGACY_RUST_VERSION" cargo install \
      --git "$source_url" --rev "$LEGACY_GIT_REV" --locked \
      --bin legacy --root "$stage/install" legacy-client
  )
  [[ "$("$stage/install/bin/legacy" --version)" == "legacy $LEGACY_CLI_VERSION" ]] || {
    echo 'legacy: ビルドした CLI の起動または版の確認に失敗しました' >&2; exit 1;
  }
  mkdir -p "$(dirname "$destination")"
  mv -f "$stage/install/bin/legacy" "$destination"
fi
# 成功した後だけ切り替える。取得・ビルド失敗時は既存版を保持する。
mkdir -p "$prefix/bin"
ln -s "$destination" "$stage/legacy"
mv -f "$stage/legacy" "$prefix/bin/legacy"
printf 'legacy: %s (%s) を導入しました\n' "$LEGACY_GIT_REV" "$platform"
