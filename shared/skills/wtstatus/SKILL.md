---
name: wtstatus
description: "Show the progress of every worktree from inside herdr as one table: workspace label, branch, what each agent is doing now (read from its terminal), local git state (uncommitted files, unpushed commits) and PR state (number, draft, base, mergeability, review). Read-only — changes nothing. Use when the user asks how the /wt-dispatched worktrees are doing. Requires HERDR_ENV=1, a git repo, and gh for PR state."
---

# wtstatus — progress of every worktree

`/wtstatus` reports, as one table, how each worktree of the current repo is
doing. it is read-only: do not commit, push, rename, prompt agents or remove
anything. if the user wants an action, they ask for it separately.

if any command below fails or yields an empty / `null` value where one is
needed, say which and stop — do not continue with a guessed value.

## preconditions (check first; if unmet, say why and stop)

- `HERDR_ENV` is `1` (running inside herdr).
- cwd is inside a git repo. resolve the main checkout (the parent repo), even
  when cwd is a linked worktree:

  ```
  MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
  ```

- the remote default branch is known (same steps as `/wt`):

  ```
  git -C "$MAIN" fetch --quiet origin
  DEFAULT=$(git -C "$MAIN" symbolic-ref --short -q refs/remotes/origin/HEAD) \
    || { git -C "$MAIN" remote set-head origin --auto >/dev/null \
         && DEFAULT=$(git -C "$MAIN" symbolic-ref --short -q refs/remotes/origin/HEAD); }
  DEFAULT=${DEFAULT#origin/}
  git -C "$MAIN" rev-parse --verify -q "origin/$DEFAULT" >/dev/null
  ```

## steps

1. collect one line per linked worktree. `worktree list` without `--cwd` lists
   the focused workspace's repo, so always pass `--cwd "$MAIN"`. the label
   comes from the workspace (it is display only and may be japanese, e.g.
   `#23 月次予算の JST リセット`):

   ```
   herdr worktree list --cwd "$MAIN" --json \
     | jq -r '.result.worktrees[]|select(.is_linked_worktree==true)|[.branch,.path,(.open_workspace_id//"")]|@tsv' \
     | while IFS=$'\t' read -r B P WS; do
         LABEL=$( [ -n "$WS" ] && herdr workspace get "$WS" | jq -r '.result.workspace.label // ""' )
         AGENT=$(herdr agent list | jq -r --arg w "$WS" --arg p "$P" \
           '[.result.agents[]|select(.workspace_id==$w or .cwd==$p or (.cwd|startswith($p+"/")))|"\(.name):\(.agent_status)"]|join(",")')
         DIRTY=$(git -C "$P" status --porcelain | wc -l)
         AHEAD=$(git -C "$P" rev-list --count "origin/$DEFAULT..HEAD")
         if git -C "$MAIN" rev-parse --verify -q "refs/remotes/origin/$B" >/dev/null; then
           UNPUSHED=$(git -C "$P" rev-list --count "origin/$B..HEAD")
         else
           UNPUSHED=not-pushed
         fi
         PR=$(gh pr list --head "$B" --state all \
           --json number,state,isDraft,baseRefName,mergeStateStatus,reviewDecision,reviewRequests,latestReviews \
           --jq '.[0] // empty | "#\(.number) \(.state) draft=\(.isDraft) base=\(.baseRefName) merge=\(.mergeStateStatus) decision=\(.reviewDecision) requested=\([.reviewRequests[]|(.login // .name)]|join(",")) reviews=\([.latestReviews[]|.state]|join(","))"')
         printf '%s\t%s\t%s\t%s\tdirty=%s ahead=%s unpushed=%s\t%s\n' "$LABEL" "$B" "$WS" "$AGENT" "$DIRTY" "$AHEAD" "$UNPUSHED" "$PR"
       done
   ```

   (`herdr agent list` and `pane list` print JSON by default and reject
   `--json`. `gh pr list --head` matches the branch name; the newest PR comes
   first. unpushed commits are counted against `origin/<branch>`, not `@{u}`:
   a branch made by `/wt` tracks `origin/<default>` until it is pushed.)

   then read what each agent is doing. `agent_status` alone is too coarse: an
   agent shows `idle` while it waits for a background shell (build, tests) or a
   background subagent, and `working` says nothing about which step it is on.
   for every agent found above (`<name>:<status>`), except the agent of this
   session (its pane is `herdr pane current`), read the end of its terminal:

   ```
   herdr agent read "<name>" --lines 40
   ```

   from that output, take only the latest step, e.g. "subagent レビューの
   1 往復目が終わり、指摘を直している", "build:test の完了待ち", "PR を作って報告済み",
   "ユーザーの確認待ち（質問している）". useful markers in Claude Code's screen:
   - `● Agent(<description>)` / `Agent "<description>" finished` — a subagent
     (e.g. a /subagent-consultation review round) started / finished.
   - `✻ Waiting for N background agent` and `N shell still running` in the
     status line — it is waiting for background work, even when `idle`.
   - a question or a permission prompt at the end — it is waiting for the user.
   - the last `●` message — the agent's own summary of what it is doing next.
   - ignore text on the `❯` input line. Claude Code fills it with a suggested
     next prompt, and `agent read` drops the gray color that marks it as a
     suggestion, so it looks like an unsent message. it is neither the user's
     input nor the agent's state.
   describe only what the screen shows. do not guess further; if it is unclear,
   say so (e.g. 画面からは作業内容が分からない).

2. turn the lines into one table for the user, in the user's language. one row
   per worktree, sorted by PR number (worktrees without a PR last). do not add
   a column for the agent state; it is used only for the notes in step 3 and
   the `/wtclean` hint. columns:

   | column | content |
   |---|---|
   | workspace | `$LABEL` (fall back to the branch when empty) |
   | branch | `$B` |
   | PR | one mark, the PR number and one state word from the list below, e.g. `🟢 #23 レビュー依頼前` |
   | 状況 | one or two short sentences built from the facts below |

   for PR, pick the first state that matches. the marks follow GitHub's PR
   icon colors (open green, draft gray, merged purple, closed red) and its
   review marks; exactly one mark per PR:
   - no PR → なし (no mark)
   - `MERGED` → 🟣 マージ済み; `CLOSED` → 🔴 クローズ
   - draft → ⚪️ draft
   - `decision=CHANGES_REQUESTED`, or `CHANGES_REQUESTED` in `reviews` → 🙏 変更要求あり
   - `decision=APPROVED`, or `APPROVED` in `reviews` → ✅ 承認済み
   - `requested` is not empty → 🟢 レビュー依頼中（add the reviewer, e.g. `🟢 #19 レビュー依頼中（example-reviewer）`）
   - otherwise (open, not draft, nobody requested) → 🟢 レビュー依頼前

   write ⚪️ and ⚠️ with the emoji variation selector (U+FE0F) after the
   symbol. without it a terminal may draw them as plain, uncolored glyphs.

   for 状況, state only what the facts show, without repeating the PR column.
   start with the agent's latest step from its terminal (none → エージェントなし),
   then the git and PR facts. put a mark at the head of 状況 when:
   - the agent is waiting for the user (a question, a permission prompt, or a
     list of decisions it asks the user to make) → ❓
   - the PR has a conflict (`DIRTY`) → ⚠️

   the git and PR facts:
   - the base branch when it is not the default branch (a stacked PR).
   - `mergeStateStatus`: `CLEAN` → main と衝突なし, `DIRTY` → 衝突あり,
     `BEHIND` → base より古い, `BLOCKED` → 必須チェックやレビューの待ち,
     `UNKNOWN` → 判定中.
   - local state: uncommitted files (`DIRTY`), unpushed commits
     (`UNPUSHED`; `not-pushed` → branch をまだ push していない), and no commits
     beyond the default branch (`AHEAD` = 0 → main から変更なし).
   - a merged PR with a clean checkout and an idle agent can be removed with
     `/wtclean` — mention it.

3. after the table, add short notes only for what needs the user's attention:
   an agent waiting for the user (a question or a permission prompt), a
   worktree whose PR has a conflict, an agent that has finished (idle, nothing
   running in the background) with uncommitted or unpushed work, a draft PR
   whose agent has finished, or the worktree of the current session (say that
   it is this session's).

## notes

- worktrees that were not made by `/wt` (no workspace, or a label that is not a
  task name) still get a row; leave the label as it is.
- read-only. never rename workspaces, prompt agents, or touch branches here.
