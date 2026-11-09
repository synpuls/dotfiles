#!/usr/bin/env bash
# Application owns builds and atomic installation. Private checkout is explicit.
set -euo pipefail
repo=${TODO_REPO:-"$HOME/workspace/github.com/synpuls/todo_manager"}
if [[ "${1:-}" == --repo ]]; then
  [[ $# -ge 2 && -n "$2" ]] || { echo 'todo: --repo requires a checkout path' >&2; exit 2; }
  repo=$2; shift 2
fi
[[ -x "$repo/scripts/install-client" ]] || {
  echo 'todo: checkout synpuls/todo_manager first, or pass --repo DIRECTORY.' >&2; exit 1;
}
exec "$repo/scripts/install-client" "$@"
