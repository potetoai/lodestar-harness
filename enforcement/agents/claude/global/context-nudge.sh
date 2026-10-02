#!/usr/bin/env bash
# Global hook (PostToolUse): when the session's context passes a threshold,
# tell the agent once to wrap up, write the handoff and ask the owner for
# /clear. Every turn re-reads the whole context, so long sessions cost most of
# the tokens (measured over real sessions). It never blocks: the tool has
# already run; exit 2 only shows the message to the agent. Nudges again at
# every further step until the session is cleared.
# Registered in ~/.claude/settings.json by install.sh.
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0
at=${LODESTAR_NUDGE_AT:-200000}
step=100000
state_dir=${LODESTAR_STATE_DIR:-$HOME/.claude/lodestar-state}

IFS=$'\t' read -r transcript session < <(jq -r '[.transcript_path // "", .session_id // ""] | @tsv' 2>/dev/null | tr -d '\r')
session=$(tr -cd '[:alnum:]-' <<<"$session")
[ -n "$transcript" ] && [ -f "$transcript" ] && [ -n "$session" ] || exit 0

# Context of the last API call: what the next turn re-reads.
ctx=$(tail -n 400 "$transcript" | tac | jq -r 'select(.type == "assistant" and .message.usage)
  | .message.usage | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)' \
  2>/dev/null | head -n1 | tr -d '\r')
[[ $ctx =~ ^[0-9]+$ ]] && [ "$ctx" -ge "$at" ] || exit 0

band=$(( (ctx - at) / step + 1 ))
state="$state_dir/nudge-$session"
[ "$(cat "$state" 2>/dev/null)" -ge "$band" ] 2>/dev/null && exit 0
mkdir -p "$state_dir" 2>/dev/null && echo "$band" > "$state" 2>/dev/null

cat >&2 <<EOF
Context is now about $((ctx / 1000))k tokens. Every turn re-reads all of it, so from here each step costs much more.
- Finish the step you are on; do not start a new one.
- Overwrite .ai/handoff.md (short, English: state, open items, next step, do-not-do).
- Tell the owner, in their language: type /clear, then "continue".
If you were dispatched as a worker or subagent: finish your task and report instead.
EOF
exit 2
