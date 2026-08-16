---
description: Gate locally, then push and open a non-draft PR
argument-hint: [bead-id]
allowed-tools: Bash(bundle:*), Bash(rake*), Bash(git:*), Bash(gh:*), Bash(bd:*)
---

## Context
- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Bead: !`bd show $ARGUMENTS`

## Task

1. Run the full local gate: `bundle install && bundle exec rake`
   If anything fails, fix it and re-run. Do not proceed until all pass.
2. Rebase onto latest main: `git pull --rebase origin main`. Resolve conflicts.
3. Re-run the gate after rebasing.
4. Push the branch.
5. Open a PR with `gh pr create`. Never use `--draft`. Title references
   bead $ARGUMENTS. Body lists each acceptance criterion with a one-line
   note on how it was satisfied.

Never stash, and never switch branches. If the working tree contains changes
unrelated to this bead, stop and tell me.

Do not run `bd close`. The bead closes after merge, not after the PR opens.
