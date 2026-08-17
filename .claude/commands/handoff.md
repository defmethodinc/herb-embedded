---
description: Write a handoff note and sync bead state
allowed-tools: Bash(git:*), Bash(bd:*), Read, Write, Edit
disable-model-invocation: true
---

Take a beat. Then:

1. Append the current contents of docs/handoffs/latest.md to
   docs/handoffs/archive.md, if it exists.
2. Write a new docs/handoffs/latest.md covering:
   - What you worked on and what state it's in
   - What you learned that isn't obvious from the code or the beads
   - What you'd do next, and why
   - Anything you were uncertain about
3. Run `bd dolt push` and report the result.
4. Run `git status` and report anything uncommitted.
