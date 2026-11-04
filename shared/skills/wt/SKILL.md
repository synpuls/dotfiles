---
name: wt
description: "Dispatch a task to a fresh git worktree with its own agent, from inside herdr. Given a task description, derive a branch, create a worktree-backed herdr workspace, start a coding agent in it, and hand it the task — then return to reception without switching focus. Use when you (the dispatcher) want to spin off isolated parallel work. Requires HERDR_ENV=1 and a git repo."
---

# wt — dispatch a worktree agent

you are the reception (dispatcher). `/wt <task>` spins the task off into its own
git worktree, opens a herdr workspace for it, starts a coding agent there, and
hands it the task. you then return to reception — do **not** do the task yourself.

if any command below fails or yields an empty / `null` value where one is
needed, say which and stop — do not continue with a guessed value.

## preconditions (check first; if unmet, say why and stop)

- `HERDR_ENV` is `1` (running inside herdr).
- cwd is inside a git repo. resolve the main checkout (the parent repo), even
  when cwd is a linked worktree:

  ```
  MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
  ```

  (assumes the usual `<checkout>/.git` layout; a `--separate-git-dir` repo or a
  submodule is out of scope — stop if `$MAIN` is not a checkout.)

- the parent repo has an open herdr workspace. herdr only creates worktrees from
  it (from a linked worktree it fails with `linked_worktree_source`).
  `worktree list` without `--cwd` lists the focused workspace's repo, so always
  pass `--cwd "$MAIN"`:

  ```
  SRC_WS=$(herdr worktree list --cwd "$MAIN" --json | jq -r --arg p "$MAIN" '.result.worktrees[]|select(.path==$p)|.open_workspace_id // empty')
  ```

  if empty, tell the user to open a herdr workspace on `$MAIN`, and stop.

- the remote default branch is known. `origin/HEAD` may be unset; then ask the
  remote. keep the steps separate so a failure is not hidden by a pipe:

  ```
  git -C "$MAIN" fetch --quiet origin
  DEFAULT=$(git -C "$MAIN" symbolic-ref --short -q refs/remotes/origin/HEAD) \
    || { git -C "$MAIN" remote set-head origin --auto >/dev/null \
         && DEFAULT=$(git -C "$MAIN" symbolic-ref --short -q refs/remotes/origin/HEAD); }
  DEFAULT=${DEFAULT#origin/}
  git -C "$MAIN" rev-parse --verify -q "origin/$DEFAULT" >/dev/null
  ```

  if any of these fails or `DEFAULT` is empty, stop. do not fall back to `main`.

## steps

1. base branch = the current branch, unless its work has already landed on the
   default branch. then base on the remote default branch. "landed" means
   either the current commit is an ancestor of `origin/$DEFAULT`, or a merged PR
   has the current commit as its head (squash / rebase merges):

   ```
   HEAD_OID=$(git rev-parse --verify HEAD)
   CUR=$(git symbolic-ref --short -q HEAD)   # empty on a detached HEAD
   BASE=${CUR:-$HEAD_OID}
   if git merge-base --is-ancestor HEAD "origin/$DEFAULT"; then
     BASE="origin/$DEFAULT"
   elif [ -n "$CUR" ] && gh pr list --head "$CUR" --state merged --json headRefOid --jq '.[].headRefOid' | grep -qx "$HEAD_OID"; then
     BASE="origin/$DEFAULT"
   fi
   ```

   (`git` without `-C` reads cwd, so HEAD is the commit you are on even in a
   linked worktree.) if the current branch has unmerged commits but is unrelated
   to the task, prefer `origin/$DEFAULT` too — say which base you chose.

2. derive a short branch NAME from the task: 2–4 kebab-case ascii words, with a
   type prefix when obvious (`fix-`, `feat-`, `chore-`, `docs-`). japanese input
   is fine — translate to a slug. e.g. "CIのキャッシュが壊れてる" → `fix-ci-cache`.

   the worktree goes next to the parent repo, as `<repo>-<NAME>`:

   ```
   WT="$(dirname "$MAIN")/$(basename "$MAIN")-$NAME"
   ```

   ensure NAME is free — it must not match an existing branch nor worktree, and
   `$WT` must not exist:

   ```
   git -C "$MAIN" branch --all --list "*$NAME"
   herdr worktree list --cwd "$MAIN" --json | jq -r '.result.worktrees[].branch'
   test -e "$WT"
   ```

   if taken, append `-2`, `-3`, … (and recompute `$WT`).

   also derive a human-readable LABEL for the herdr sidebar: a short phrase in
   the user's language (japanese for japanese input), naming what the work is,
   e.g. "CIのキャッシュの修正". keep it short (about 20 characters). it is display
   only and does not need to be unique. once a PR exists, the label is renamed
   to `#<PR number> $LABEL` (see step 6).

3. create the worktree-backed workspace from the parent repo's workspace (opens
   a pane; `--no-focus` so you stay in reception):

   ```
   herdr worktree create --workspace "$SRC_WS" --branch "$NAME" --base "$BASE" --path "$WT" --label "$LABEL" --no-focus --json
   ```

   capture the new workspace id. the reliable source is `worktree list` (shape
   confirmed):

   ```
   WS=$(herdr worktree list --cwd "$MAIN" --json | jq -r --arg b "$NAME" '.result.worktrees[]|select(.branch==$b)|.open_workspace_id // empty')
   ```

4. find the pane in that workspace:

   ```
   PANE=$(herdr pane list --workspace "$WS" | jq -r '.result.panes[0].pane_id // empty')
   ```

   (`pane list` prints JSON by default and rejects `--json`.)

5. start a coding agent in that pane. kind defaults to `claude`; use `codex` if
   you prefer:

   ```
   herdr agent start "$NAME" --kind claude --pane "$PANE"
   ```

   (`agent start` rejects `--json` too. extra agent args go after `--`, e.g.
   `-- --model haiku`.)

6. hand it the task as its first prompt — fire and forget (no `--wait`), so you
   return immediately. put the task into a variable with a **quoted** heredoc,
   so backticks, `$(...)` and quotes in it are passed as text, never run:

   ```
   TASK=$(cat <<'TASK_EOF'
   <the task, verbatim>
   TASK_EOF
   )
   herdr agent prompt "$NAME" "$TASK

   Work only inside this worktree ($WT) on branch $NAME. When done: run the repo's checks, commit, push the branch with git push -u origin $NAME, and open a PR with gh. After opening the PR, rename this herdr workspace to show the PR number: herdr workspace rename $WS \"#<PR number> $LABEL\". Then stop and report."
   ```

   (if the task itself contains a line `TASK_EOF`, pick another delimiter.)

7. report to the user: branch `$NAME`, label `$LABEL`, base `$BASE`, worktree
   `$WT`, workspace `$WS`, agent started. do not switch focus.

## notes

- if the PR is opened later by someone other than the worktree agent (or the
  agent skipped the rename), rename the workspace yourself:
  `herdr workspace rename "$WS" "#<PR number> $LABEL"`.
- one task per worktree. keep NAME stable — it is the branch and the agent name,
  and `/wtclean` matches worktrees by branch, workspace id and agent cwd. the
  workspace label is display only, so `/wtclean` does not depend on it.
- if any herdr command fails with `protocol_mismatch`, the herdr server is on an
  older version than the CLI — tell the user to restart the herdr server, and stop.
