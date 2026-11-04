---
name: wtclean
description: "Reclaim worktrees from inside herdr: remove worktree workspaces whose PR is merged (clean checkout, agent not working), and offer to discard unmerged ones — e.g. an abandoned prototype — after showing what would be lost and asking per worktree. Removes the worktree, its workspace, and the local branch. Use to tidy up after /wt-dispatched work has landed or been abandoned. Safe by default (shows a plan and asks before removing). Requires HERDR_ENV=1, a git repo, and gh for PR state."
---

# wtclean — reclaim worktrees

`/wtclean [--yes]` removes worktree workspaces whose work has landed, and offers
to discard ones whose work was abandoned.

- **merged** (a merged PR's head is exactly the worktree's HEAD, nothing
  uncommitted, no agent working) — removed after one confirmation for the
  whole plan; `--yes` skips it unless ignored files would be deleted.
- **unmerged** (everything else) — never removed silently. show what would be
  lost and ask **per worktree** whether to discard it, even with `--yes`.

**fail closed:** if any check below fails (non-zero exit, error, unexpected
JSON), you cannot tell what would be lost — skip that worktree with the reason
"could not check". an empty output counts as "nothing" only when the command
succeeded.

## preconditions (check first; if unmet, say why and stop)

- `HERDR_ENV` is `1`.
- cwd is inside a git repo. resolve the main checkout (the parent repo), even
  when cwd is a linked worktree:

  ```
  MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
  ```

  (assumes the usual `<checkout>/.git` layout; a `--separate-git-dir` repo or a
  submodule is out of scope — stop if `$MAIN` is not a checkout.)

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

1. list this repo's linked worktrees (this excludes the main checkout).
   `worktree list` without `--cwd` lists the focused workspace's repo, so pass
   `--cwd "$MAIN"`. emit one JSON object per worktree (not TSV — an empty
   branch on a detached HEAD would shift the columns):

   ```
   herdr worktree list --cwd "$MAIN" --json | jq -c '.result.worktrees[]|select(.is_linked_worktree==true)|{branch:(.branch // ""),wt:.path,ws:(.open_workspace_id // "")}'
   ```

   below, `BRANCH`, `WT`, `WS` are those fields (`BRANCH` / `WS` may be empty).

2. classify each worktree. first the hard skips — never removed, not even with
   confirmation:

   - **working?** any agent whose workspace is `$WS` or whose cwd is inside
     `$WT` is `working` (check every agent, not the workspace's summary
     status — another pane can be busy):

     ```
     herdr agent list | jq -r --arg w "$WS" --arg p "$WT" '.result.agents[]|select(.workspace_id==$w or .cwd==$p or (.cwd|startswith($p+"/")))|.agent_status'
     ```

     (`agent list` prints JSON by default.)
   - **current?** cwd is inside `$WT` — compare physical paths on a directory
     boundary, not a string prefix:

     ```
     case "$(pwd -P)/" in "$(realpath "$WT")/"*) echo current ;; esac
     ```

     (use `realpath`, not `$(cd "$WT" && pwd -P)` — a shell `cd` hook can
     print into the substitution.)

   then collect, for each remaining worktree:

   ```
   HEAD_OID=$(git -C "$WT" rev-parse --verify HEAD)
   git -C "$WT" log --oneline "origin/$DEFAULT..HEAD"                        # commits not on the default branch
   git -C "$WT" status --porcelain --untracked-files=all                     # uncommitted + untracked (overrides status.showUntrackedFiles)
   git -C "$WT" status --porcelain --ignored --untracked-files=no | grep '^!!'  # ignored files (.env, build output, …)
   ```

   and, when `BRANCH` is non-empty:

   ```
   gh pr list --head "$BRANCH" --state merged --json number,headRefOid --jq '.[]|"\(.headRefOid) \(.number)"' \
     | awk -v h="$HEAD_OID" '$1==h{print $2}'                                # merged PR whose head is this HEAD
   gh pr list --head "$BRANCH" --state open --json number,url                # open PR? (left open)
   git -C "$MAIN" ls-remote --heads origin "$BRANCH"                         # pushed? (the remote branch is kept)
   ```

   (a PR number printed ⇒ match. the `grep` exits 1 when there are no ignored
   files — that is not a failure.)

   sort:

   - **merged** — a merged PR matched `HEAD_OID` (record its number) **and**
     the uncommitted/untracked status is empty. a merged PR whose head differs
     from HEAD does **not** count: commits were added after the merge.
   - **unmerged** — everything else, including detached worktrees (no
     `BRANCH`). if the log and the uncommitted/untracked status are both empty,
     say no commits or changes are lost (ignored files may still be).

3. show the plan:
   - merged: `BRANCH  PR#…  WT`, plus the ignored files, if any.
   - unmerged: per worktree, `BRANCH` (or "detached at <short oid>")  `WT`,
     then the commits, the uncommitted/untracked files, the ignored files, and
     whether a remote branch or open PR exists.
   - skipped: branch + reason.

4. confirm:
   - merged: ask once for the whole list. `--yes` skips this, unless some
     merged worktree has ignored files — then ask anyway.
   - unmerged: ask per worktree whether to discard it (`--yes` does not apply).
     default is to keep. never discard one the user did not explicitly approve.

5. for each approved worktree, **re-check right before removing**: re-run the
   step 2 checks. if anything changed (HEAD, files, an agent now `working`),
   do not remove it — show the new state and ask again.

   then remove it:

   ```
   herdr worktree remove --workspace "$WS" --force   # removes the checkout + closes the workspace
   ```

   if `WS` is empty (no open workspace), `herdr worktree remove` cannot target
   it — use `git -C "$MAIN" worktree remove --force "$WT"` instead.

   only if that succeeded, drop the local branch (skip when `BRANCH` is empty):

   ```
   git -C "$MAIN" branch -D "$BRANCH"
   ```

   `-D` is safe here: a merged one's HEAD equals its PR head, and an unmerged
   one was approved for discard. (`branch -d` is no proof of merge — it checks
   the upstream, and refuses squash-merged branches.) never delete the remote
   branch or close a PR — mention them in the report instead.

6. report: removed (branch + PR# or "discarded"), kept (branch + reason), and
   any remote branches / open PRs left behind.

## notes

- never remove the source/main checkout, or one whose agent is still working.
- an unmerged or dirty worktree is removed only after the user approved that
  specific worktree.
- if a herdr command fails with `protocol_mismatch`, the herdr server is older
  than the CLI — tell the user to restart the herdr server, and stop.
