#!/usr/bin/env bash
# ZMM owns native builds, model validation, versioned installation and rollback.
# dotfiles supplies dependencies and this entry point; never replace it with an sbt wrapper.
set -euo pipefail
repo="${ZMM_REPO:-$HOME/workspace/github.com/synpuls/zmm}"
built=""
usage() {
  echo "Usage: $0 [--repo ZMM_CHECKOUT] [--from BUILT_DIRECTORY]"
  echo 'Default: build and install the selected checkout with its scripts/install-local.'
  echo '--from installs an existing native binary/library pair without rebuilding.'
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo|--from)
      [[ $# -ge 2 && -n "$2" ]] || { usage >&2; exit 2; }
      case "$1" in --repo) repo="$2" ;; --from) built="$2" ;; esac
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
[[ -f "$repo/Cargo.toml" && -d "$repo/model" && -x "$repo/bin/build" && -x "$repo/scripts/install-local" ]] || {
  echo "zmm: Rust/Souther 版の checkout が必要です: $repo" >&2
  echo 'ghq get https://github.com/synpuls/zmm の後、必要なら --repo DIR を指定してください。' >&2
  exit 1
}
repo="$(cd "$repo" && pwd -P)"
if [[ -n "$built" ]]; then
  exec "$repo/scripts/install-local" --from "$built"
fi
# The build compiler needs Java >=25, while a retained Scala installation may use 17.
if [[ -z "${JAVA_HOME:-}" && "$(uname -s)" == Darwin ]] && command -v brew >/dev/null; then
  java_prefix="$(brew --prefix openjdk)"
  export JAVA_HOME="$java_prefix/libexec/openjdk.jdk/Contents/Home"
fi
if [[ -n "${JAVA_HOME:-}" ]]; then export PATH="$JAVA_HOME/bin:$PATH"; fi
for tool in java mvn cargo; do
  command -v "$tool" >/dev/null || { echo "zmm: ビルドには $tool が必要です。ZMM の docs/rust-migration.md を参照してください。" >&2; exit 1; }
done
java_version="$(java -version 2>&1)"
java_major="$(printf '%s\n' "$java_version" | sed -nE 's/.*version "([0-9]+).*/\1/p' | head -1)"
[[ "$java_major" =~ ^[0-9]+$ ]] && [[ "$java_major" -ge 25 ]] || {
  echo 'zmm: Souther のビルドには Java 25 以上が必要です。JAVA_HOME を確認してください。' >&2
  exit 1
}
exec "$repo/scripts/install-local"
