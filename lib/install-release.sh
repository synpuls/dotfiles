#!/usr/bin/env bash
# 汎用のリリースバイナリ導入 primitive。version/sha256 は呼び出し側(server/tools.env)が固定する。
# ここは「取得 → sha256 検証 → atomic 設置」だけを担い、tool 固有の URL/asset 名は
# server/installers/*.sh の adapter が組み立てる。source して関数を使う。
#
# 提供する関数:
#   ir_arch                        正規化した arch(x86_64/aarch64)を返す。対応外は失敗。
#   ir_download_verified URL SHA OUT   取得+sha256検証して OUT へ atomic 設置。
#   ir_install_raw_binary URL SHA DEST raw バイナリを実行権つきで DEST へ導入。
#   ir_extract URL SHA FORMAT      取得+検証+展開し、展開先 dir を stdout に返す(呼び出し側で回収)。
#   ir_link_bin SRC NAME           ~/.local/bin/NAME を SRC への symlink にする。
#   ir_opt_dir NAME                ~/.local/opt/NAME を返す(versioned tree 設置先)。

set -euo pipefail

ir_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo x86_64 ;;
    aarch64 | arm64) echo aarch64 ;;
    *)
      echo "install-release: unsupported arch: $(uname -m)" >&2
      return 1
      ;;
  esac
}

ir_curl() {
  curl --fail --location --proto '=https' --tlsv1.2 --retry 3 --silent --show-error "$@"
}

# URL を取得し sha256 を検証して OUT へ atomic に置く（OUT と同一 dir に一時展開=同一 filesystem）。
ir_download_verified() {
  local url="$1" sha="$2" out="$3" dir tmp
  dir="$(dirname "$out")"
  mkdir -p "$dir"
  tmp="$(mktemp "${dir}/.ir.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -f '${tmp}'" RETURN
  ir_curl -o "$tmp" "$url"
  printf '%s  %s\n' "$sha" "$tmp" | sha256sum -c - >/dev/null
  mv -f "$tmp" "$out"
}

# sidecar 無しの raw バイナリ(herdr 等)を DEST へ導入。
ir_install_raw_binary() {
  local url="$1" sha="$2" dest="$3"
  mkdir -p "$(dirname "$dest")"
  ir_download_verified "$url" "$sha" "$dest"
  chmod 0755 "$dest"
}

# アーカイブを取得・検証し、staging dir に展開してそのパスを stdout に返す。
# 絶対パス/.. を含む entry は展開前に拒否する。呼び出し側は使い終えたら rm -rf する。
ir_extract() {
  local url="$1" sha="$2" fmt="$3" work archive
  work="$(mktemp -d)"
  archive="${work}/.archive"
  ir_download_verified "$url" "$sha" "$archive"
  case "$fmt" in
    tar.gz) tar -tzf "$archive" | _ir_reject_unsafe && tar -xzf "$archive" -C "$work" ;;
    tar.xz) tar -tJf "$archive" | _ir_reject_unsafe && tar -xJf "$archive" -C "$work" ;;
    zip) unzip -Z1 "$archive" | _ir_reject_unsafe && unzip -q "$archive" -d "$work" ;;
    *)
      echo "install-release: unsupported archive format: $fmt" >&2
      rm -rf "$work"
      return 1
      ;;
  esac
  rm -f "$archive"
  printf '%s\n' "$work"
}

_ir_reject_unsafe() {
  local entry
  while IFS= read -r entry; do
    case "$entry" in
      /* | *..*)
        echo "install-release: unsafe archive entry rejected: $entry" >&2
        return 1
        ;;
    esac
  done
}

ir_opt_dir() { printf '%s\n' "${HOME}/.local/opt/$1"; }

ir_link_bin() {
  local src="$1" name="$2" bindir="${HOME}/.local/bin"
  mkdir -p "$bindir"
  ln -sfn "$src" "${bindir}/${name}"
}
