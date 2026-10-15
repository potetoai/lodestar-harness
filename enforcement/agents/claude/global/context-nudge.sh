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
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../hooks/reminder-lib.sh" || { echo 'Lodestar context unavailable: missing reminder helper.' >&2; exit 0; }
reminder_input || { advisory_unavailable 'missing or invalid context transcript/session/dependency'; exit 0; }
[[ $at =~ ^[0-9]+$ ]] && [ "$at" -gt 0 ] || { advisory_unavailable 'invalid context threshold'; exit 0; }

# Context of the last API call: what the next turn re-reads. Only the tail is
# read (this runs after every tool call on transcripts of many MB); a line still
# being written is skipped, not fatal.
if [ "$runtime" = codex ]; then
  # input_tokens already includes cached_input_tokens; totals are cumulative.
  filter='select(.type == "event_msg" and .payload.type == "token_count") | .payload.info.last_token_usage.input_tokens'
else
  filter='select(.type == "assistant" and .message.usage) | .message.usage | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)'
fi
# No usage within the tail (long tool output) stays quiet; no record at all is
# an unsupported transcript.
ctx=$(tail -n 400 "$transcript" | jq -Rrn "[inputs | fromjson? | objects] | if length == 0 then \"none\" else ([.[] | $filter] | last // \"quiet\") end" 2>/dev/null | tr -d '\r')
[ "$ctx" = quiet ] && exit 0
[[ $ctx =~ ^[0-9]+$ ]] || { advisory_unavailable 'unsupported current-context usage'; exit 0; }
[ "$ctx" -ge "$at" ] || exit 0

band=$(( (ctx - at) / step + 1 ))
reminder_claim "context-$at" "$band"; claimed=$?
[ "$claimed" = 1 ] && exit 0
[ "$claimed" = 0 ] || { advisory_unavailable 'cannot persist context reminder state'; exit 0; }

cat >&2 <<EOF
Context is now about $((ctx / 1000))k tokens. Every turn re-reads all of it, so from here each step costs much more.
- Finish the step you are on; do not start a new one.
- Overwrite .ai/handoff.md (short, English: state, open items, next step, do-not-do).
- Tell the owner, in their language: type /clear, then "continue".
If you were dispatched as a worker or subagent: finish your task and report instead.
EOF
exit 2
