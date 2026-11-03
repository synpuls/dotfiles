#!/usr/bin/env bash
# OS/CPU に合う、dotfiles に固定した CLI だけを導入する。
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
source "$ROOT/lib/install-release.sh"
prefix="$HOME/.local/opt/legacy"
release_file="$ROOT/shared/legacy-release.env"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix|--release-file)
      [[ $# -ge 2 && -n "$2" ]] || { echo "legacy installer: $1 に値が必要です" >&2; exit 2; }
      case "$1" in
        --prefix) prefix=$2 ;;
        --release-file) release_file=$2 ;;
      esac
      shift 2 ;;
    *) echo "Usage: $0 [--prefix DIR] [--release-file reviewed.env]" >&2; exit 2 ;;
  esac
done

# このファイルは dotfiles でレビューした固定値。ネットから取得して source しない。
source "$release_file"
if [[ ! "${LEGACY_VERSION:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ||
      "${LEGACY_RELEASE_TAG:-}" != "cli-v${LEGACY_VERSION:-}" ||
      ! "${LEGACY_SOURCE_COMMIT:-}" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'legacy installer: 配布版が未確定です。shared/legacy.md に従って、初回リリースの固定値を反映してください。' >&2
  exit 1
fi

arch=$(ir_arch)
case "$(uname -s)/$arch" in
  Darwin/aarch64) target=aarch64-apple-darwin; sha=${LEGACY_MACOS_ARM64_SHA256:-} ;;
  Darwin/x86_64) target=x86_64-apple-darwin; sha=${LEGACY_MACOS_X64_SHA256:-} ;;
  Linux/aarch64) target=aarch64-unknown-linux-gnu; sha=${LEGACY_LINUX_ARM64_SHA256:-} ;;
  Linux/x86_64) target=x86_64-unknown-linux-gnu; sha=${LEGACY_LINUX_X64_SHA256:-} ;;
  *) echo 'legacy installer: 対応 OS は macOS / Linux です' >&2; exit 1 ;;
esac
[[ "$sha" =~ ^[0-9a-f]{64}$ ]] || { echo "legacy installer: $target の SHA-256 が未確定です" >&2; exit 1; }
asset="legacy-$target"
repo=synpuls/legacy
mkdir -p "$prefix"
prefix=$(cd "$prefix" && pwd -P)
destination="$prefix/$LEGACY_RELEASE_TAG/$target/legacy"
stage=$(mktemp -d "$prefix/.install.XXXXXX")
trap 'rm -rf "$stage"' EXIT

if [[ ! -x "$destination" ]] || ! ir_verify_sha256 "$destination" "$sha"; then
  # gh は private release の認証にも使う。public release は curl だけでも導入できる。
  if command -v gh >/dev/null && gh release download "$LEGACY_RELEASE_TAG" \
      --repo "$repo" --pattern "$asset" --dir "$stage"; then
    :
  else
    ir_curl -o "$stage/$asset" "https://github.com/$repo/releases/download/$LEGACY_RELEASE_TAG/$asset"
  fi
  ir_verify_sha256 "$stage/$asset" "$sha" || { echo 'legacy installer: SHA-256 が一致しません' >&2; exit 1; }
  chmod 0755 "$stage/$asset"
  [[ "$("$stage/$asset" --version)" == "legacy $LEGACY_VERSION" ]] || {
    echo 'legacy installer: この OS で CLI を起動できないか、版が一致しません' >&2; exit 1;
  }
  mkdir -p "$(dirname "$destination")"
  mv -f "$stage/$asset" "$destination"
fi
# 検証・起動に成功してからリンクを切り替える。失敗時は既存版を保持する。
mkdir -p "$prefix/bin"
ln -s "$destination" "$stage/legacy"
mv -f "$stage/legacy" "$prefix/bin/legacy"
printf 'legacy: %s (%s) を導入しました\n' "$LEGACY_RELEASE_TAG" "$target"
