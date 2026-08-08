---
name: wt
description: "Dispatch a task to a fresh git worktree with its own agent, from inside herdr. Given a task description, derive a branch, create a worktree-backed herdr workspace, start a coding agent in it, and hand it the task — then return to reception without switching focus. Use when you (the dispatcher) want to spin off isolated parallel work. Requires HERDR_ENV=1 and a git repo."
---

# wt — dispatch a worktree agent

you are the reception (dispatcher). `/wt <task>` spins the task off into its own
git worktree, opens a herdr workspace for it, starts a coding agent there, and
hands it the task. you then return to reception — do **not** do the task yourself.

## preconditions (check first; if unmet, say why and stop)

- `HERDR_ENV` is `1` (running inside herdr).
- cwd is inside a git repo: `REPO=$(git rev-parse --show-toplevel)`.

## steps

1. base branch = the current branch:

   ```
   BASE=$(git -C "$REPO" symbolic-ref --short HEAD)
   ```

2. derive a short branch NAME from the task: 2–4 kebab-case ascii words, with a
   type prefix when obvious (`fix-`, `feat-`, `chore-`, `docs-`). japanese input
   is fine — translate to a slug. e.g. "CIのキャッシュが壊れてる" → `fix-ci-cache`.

   ensure it is free — it must not match an existing branch nor worktree:

   ```
   git -C "$REPO" branch --all --list "*$NAME"
   herdr worktree list --json | jq -r '.result.worktrees[].branch'
   ```

   if taken, append `-2`, `-3`, …

3. create the worktree-backed workspace (opens a pane; `--no-focus` so you stay
   in reception):

   ```
   herdr worktree create --branch "$NAME" --base "$BASE" --label "$NAME" --no-focus --json
   ```

   capture the new workspace id and the worktree path. the reliable source is
   `worktree list` (shape confirmed): 

   ```
   WS=$(herdr worktree list --json | jq -r --arg b "$NAME" '.result.worktrees[]|select(.branch==$b)|.open_workspace_id')
   WT=$(herdr worktree list --json | jq -r --arg b "$NAME" '.result.worktrees[]|select(.branch==$b)|.path')
   ```

4. find the pane in that workspace:

   ```
   PANE=$(herdr pane list --workspace "$WS" --json | jq -r '.result.panes[0].pane_id')
   ```

   (if that jq path is empty, run `herdr pane list --workspace "$WS" --json` once
   and read the actual field name, then use it.)

5. start a coding agent in that pane. kind defaults to `claude`; use `codex` if
   you prefer:

   ```
   herdr agent start "$NAME" --kind claude --pane "$PANE"
   ```

6. hand it the task as its first prompt — fire and forget (no `--wait`), so you
   return immediately:

   ```
   herdr agent prompt "$NAME" "<the task, verbatim>. Work only inside this worktree ($WT) on branch $NAME. When done: run the repo's checks, commit, push the branch, and open a PR with gh. Then stop and report."
   ```

7. report to the user: branch `$NAME`, worktree `$WT`, workspace `$WS`, agent
   started. do not switch focus.

## notes

- one task per worktree. keep NAME stable — it is the branch, the workspace
  label, and the agent name, so `/wtclean` can match them all later.
- if any herdr command fails with `protocol_mismatch`, the herdr server is on an
  older version than the CLI — tell the user to restart the herdr server, and stop.
