---
description: Implement a GitHub issue end to end, with review, up to the PR
argument-hint: [issue-number]
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
disable-model-invocation: true
---

## Context
- Issue: !`gh issue view $ARGUMENTS`
- Branch: !`git branch --show-current`

## Task

Implement issue #$ARGUMENTS. The acceptance criteria in the issue body are the
definition of done — not your judgment of what would be good.

Loop, at most three times:
1. Implement or revise.
2. Run `bundle exec rake`. Fix failures. Do not proceed until green.
3. Use the ac-reviewer subagent to review the diff against issue #$ARGUMENTS.
4. If the verdict is APPROVE, stop and tell me it's ready to ship.
   If REVISE, address every numbered item and loop.

If you reach three iterations without APPROVE, stop. Do not keep going.
Summarize what remains contested and why, and tell me it needs my judgment —
that usually means the acceptance criteria were ambiguous, which is my
problem to fix, not yours.

Never run `/ship` yourself. I do that.
