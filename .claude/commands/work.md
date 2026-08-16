---
description: Implement a bead end to end, with review, through to an open PR
argument-hint: [bead-id]
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

## Context
- Bead: !`bd show $ARGUMENTS`
- Branch: !`git branch --show-current`

## Task

Implement bead $ARGUMENTS. The acceptance criteria in the bead body are the
definition of done — not your judgment of what would be good.

First, mark it in progress: `bd update $ARGUMENTS --status in_progress`.

Loop, at most three times:
1. Implement or revise.
2. Run `bundle exec rake`. Fix failures. Do not proceed until green.
3. Use the ac-reviewer subagent to review the diff against bead $ARGUMENTS.
4. If the verdict is APPROVE, run the steps in .claude/commands/ship.md
   and report the PR URL.
   If REVISE, address every numbered item and loop.

If you reach three iterations without APPROVE, stop. Do not keep going.
Set the bead back with `bd update $ARGUMENTS --status blocked` and a note
saying what remains contested. Summarize it for me — that usually means the
acceptance criteria were ambiguous, which is my problem to fix, not yours.

Never run `bd close`. The bead closes after merge, not after the PR opens.
