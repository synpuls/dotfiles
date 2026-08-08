---
name: wtclean
description: "Reclaim finished worktrees from inside herdr: find worktree workspaces whose PR is merged, whose checkout is clean, and whose agent is not working, then remove the worktree, its workspace, and the local branch. Use to tidy up after /wt-dispatched work has landed. Safe by default (shows a plan and asks before removing). Requires HERDR_ENV=1, a git repo, and gh for PR state."
---

# wtclean — reclaim merged worktrees

`/wtclean [--yes]` removes worktree workspaces whose work has landed. safe by
default: it only removes a worktree whose branch has a **merged** PR, whose
checkout is **clean**, and whose agent is **not working**. without `--yes` it
prints the plan and asks before removing anything.

## preconditions (check first; if unmet, say why and stop)

- `HERDR_ENV` is `1`.
- cwd is inside a git repo: `REPO=$(git rev-parse --show-toplevel)`.

## steps

1. list this repo's linked worktrees (this excludes the main checkout):

   ```
   herdr worktree list --json | jq -r '.result.worktrees[]|select(.is_linked_worktree==true)|[.branch,.path,.open_workspace_id]|@tsv'
   ```

2. classify each `(BRANCH, PATH, WS)`:

   - **merged?** `gh pr list --head "$BRANCH" --state merged --json number,mergedAt`
     — non-empty ⇒ merged (record the PR number). empty ⇒ skip (open or none).
   - **clean?** `git -C "$PATH" status --porcelain` — non-empty ⇒ skip (dirty;
     never touch uncommitted work).
   - **idle?** `herdr workspace list --json | jq -r --arg w "$WS" '.result.workspaces[]|select(.workspace_id==$w)|.agent_status'`
     — if `working`, skip (agent busy).

3. show the plan: for each removable worktree print `BRANCH  PR#…  PATH`; also
   list skipped ones with the reason.

4. if `--yes` was not passed, ask the user to confirm before removing.

5. remove each confirmed worktree:

   ```
   herdr worktree remove --workspace "$WS" --force          # removes the checkout + closes the workspace
   git -C "$REPO" branch -d "$BRANCH" 2>/dev/null || true    # drop the local branch if fully merged
   ```

   (`branch -d` refuses an unmerged branch by design — leave those alone.)

6. report: removed (branch + PR#) and skipped (branch + reason).

## notes

- never remove the source/main checkout, a dirty worktree, or one whose agent is
  still working.
- if a herdr command fails with `protocol_mismatch`, the herdr server is older
  than the CLI — tell the user to restart the herdr server, and stop.
