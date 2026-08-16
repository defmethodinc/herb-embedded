---
description: Claim the next ready bead and take it through to an open PR
argument-hint: [optional bead-id]
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

## Context
- Ready queue: !`bd ready`
- Branch: !`git branch --show-current`

## Task

If a bead id was given ($ARGUMENTS), work that one. Otherwise take the
highest-priority bead from the ready queue above. Call it THE BEAD for the
rest of this task.

Claim it first: `bd update <THE BEAD> --status in_progress`. If the claim
fails because another session already took it, take the next one instead.

The acceptance criteria in THE BEAD are the definition of done — not your
judgment of what would be good.

Loop, at most three times:
1. Implement or revise.
2. Run `bundle exec rake`. Fix failures. Do not proceed until green.
3. Use the ac-reviewer subagent to review the diff against THE BEAD.
4. If the verdict is APPROVE, follow the steps in .claude/commands/ship.md
   using THE BEAD as the argument. Report the PR URL.
   If REVISE, address every numbered item and loop.

If you reach three iterations without APPROVE, stop. Do not keep going.
Set it back with `bd update <THE BEAD> --status blocked` and a note saying
what remains contested. Summarize it for me — that usually means the
acceptance criteria were ambiguous, which is my problem to fix, not yours.

Never run `bd close`. The bead closes after merge, not after the PR opens.
