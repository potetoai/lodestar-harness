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
input=$(cat)
reminder_input <<<"$input" || { advisory_unavailable 'missing or invalid context transcript/session/dependency'; exit 0; }
[[ $at =~ ^[0-9]+$ ]] && [ "$at" -gt 0 ] || { advisory_unavailable 'invalid context threshold'; exit 0; }

# Inside a Claude subagent the input names it (agent_id), but transcript_path
# is the parent session's: measure the subagent's own transcript, never the
# parent's (measured: nudges said 200k at a subagent's 36k; runs past 300k got
# none). No file for it stays quiet.
# jq reads only the top-level field (a tool's input may hold its own
# agent_id); it runs only when the text appears at all.
agent=
if [ "$runtime" = claude ] && [[ $input == *'"agent_id"'* ]]; then
  agent=$(jq -r '.agent_id // empty | strings | select(test("^[A-Za-z0-9_-]+$"))' <<<"$input" 2>/dev/null | tr -d '\r')
fi
if [ -n "$agent" ]; then
  case $transcript in
    *agent-"$agent".jsonl) ;;
    *) transcript="${transcript%.jsonl}/subagents/agent-$agent.jsonl" ;;
  esac
  [ -r "$transcript" ] && [ -s "$transcript" ] || exit 0
fi

# A finished task is the natural point for a fresh session. Seen from state:
# merge-pr.sh (the only way an agent merges) leaves a marker in the project's
# git folder of its worktree after a merge. The first main-session hook there takes it,
# so it speaks once; a subagent leaves it for its dispatcher.
if [ -z "$agent" ] && gd=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --git-dir 2>/dev/null); then
  [[ $gd == /* || $gd =~ ^[A-Za-z]: ]] || gd=${CLAUDE_PROJECT_DIR:-.}/$gd
  mark=$gd/lodestar-task-done
  if [ -f "$mark" ] && mv "$mark" "$mark.$$" 2>/dev/null; then
    finished=$(head -c 200 "$mark.$$" | tr -d '\r\n'); rm -f "$mark.$$"
    # A project on a template before completed.md still moves plans to completed/.
    close="git rm it, one row in .ai/plans/completed.md"
    [ -f "${CLAUDE_PROJECT_DIR:-.}/.ai/plans/completed.md" ] || close="git mv it to .ai/plans/completed/ with a Closed row in its progress log"
    cat >&2 <<EOF
A task just finished (${finished:-a PR merged}). This is the point for a fresh session: every turn re-reads the whole context.
- Finish the step you are on; do not start a new task in this session.
- A plan this PR finished leaves .ai/plans/active/: $close (a small PR if not done in this one).
- Overwrite .ai/handoff.md (short, English: state, open items, next step, do-not-do).
- Tell the owner, in their language: the task is done; type /clear, then "continue" or the next task.
If the owner already asked for more in this turn, finish that first, then say it.
EOF
    exit 2
  fi
fi

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
reminder_claim "context-$at${agent:+-$agent}" "$band"; claimed=$?
[ "$claimed" = 1 ] && exit 0
[ "$claimed" = 0 ] || { advisory_unavailable 'cannot persist context reminder state'; exit 0; }

if [ -n "$agent" ]; then
  cat >&2 <<EOF
Context of this subagent is now about $((ctx / 1000))k tokens. Every call re-reads all of it.
- Finish the step you are on; do not start a new one.
- Report now: what is done, what is left, and what the next agent needs to know, so the dispatcher can send a fresh subagent for the rest.
- Do not write .ai/handoff.md or ask the owner for /clear.
EOF
  exit 2
fi

cat >&2 <<EOF
Context is now about $((ctx / 1000))k tokens. Every turn re-reads all of it, so from here each step costs much more.
- Finish the step you are on; do not start a new one.
- Overwrite .ai/handoff.md (short, English: state, open items, next step, do-not-do).
- Tell the owner, in their language: type /clear, then "continue".
If you were dispatched as a worker or subagent: finish your task and report instead.
EOF
exit 2
