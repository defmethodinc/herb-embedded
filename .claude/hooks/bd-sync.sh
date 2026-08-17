#!/usr/bin/env bash
# Sync bead state after a mutating bd command.
# Non-blocking: a sync failure should surface, not stop work.
cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null)
if printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])bd[[:space:]]+(close|create|update|dep|defer|supersede|remember)'; then
  bd dolt push 2>&1 | tail -2
fi
exit 0
