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

# A finished task is the natural point for a fresh session. Seen from the
# command: the agent merged a PR (gh pr merge, not --auto, no error printed),
# saw the owner's merge of a PR this session opened (gh pr view printing
# MERGED; reading an old or another project's PR is not a finished task), or
# moved a plan to completed. Once per PR or plan. A subagent reports to its
# dispatcher instead. jq runs only when the text appears at all.
if [ -z "$agent" ] && [[ $input == *'gh pr '* || $input == *'plans/completed'* ]]; then
  finished=$(jq -r '(.tool_input.command // "" | strings) as $c
    | ((.tool_response // "") | if type == "string" then . else tostring end) as $r
    | def run($p): "(^|[;&|(\\n])\\s*" + $p;  # only where a command starts, not quoted text
      ($c | [match(run("gh pr (merge|view)\\s+#?([0-9]+)")).captures[2].string] | first // "") as $n
    | if ($c | test(run("gh pr merge"))) and ($c | test("--auto") | not)
         and ($r | test("GraphQL:|error|failed|not mergeable"; "i") | not) then "PR \($n) merged"
      elif ($c | test(run("gh pr create"))) then
        ($r | [scan("github\\.com/[^/\\s\"\\\\]+/[^/\\s\"\\\\]+/pull/[0-9]+")] | first // empty | "opened \(.)")
      elif ($c | test(run("gh pr view"))) and ($r | test("MERGED")) then
        "view\t\($c | [match(run("gh pr view([^;&|\\n]*)")).captures[1].string] | first)"
      elif ($c | test(run("(git )?mv [^;&|\\n]*plans/active/[^;&|\\n]*plans/completed"))) then
        "plan closed: \($c | [scan("plans/active/[^ ;&|]+")] | first // "")"
      else empty end' <<<"$input" 2>/dev/null | tr -d '\r')
  # PRs this session opened, one owner/repo/pull/N per line. A view counts
  # when it names one of them: by link, by -R repo and number, or by number
  # alone (the same number in another repo is not told apart); a view with
  # neither (the branch's PR) counts once the session opened any PR.
  case $finished in
    'opened '*)
      if reminder_state && mkdir -p "$reminder_dir" 2>/dev/null; then
        echo "${finished#opened github.com/}" >> "$reminder_dir/$reminder_key-opened"
      fi
      finished= ;;
    view$'\t'*)
      args=${finished#view$'\t'}; finished=
      reminder_state && opened=$(cat "$reminder_dir/$reminder_key-opened" 2>/dev/null) && [ -n "$opened" ] || opened=
      url=$(grep -oE 'github\.com/[^/ ]+/[^/ ]+/pull/[0-9]+' <<<"$args" | head -n1)
      repo=$(grep -oE '(-R|--repo)[= ]+[^ ]+' <<<"$args" | head -n1 | sed -E 's/^(-R|--repo)[= ]+//; s#^(https?://)?github\.com/##')
      n=$(grep -oE '(^| )#?[0-9]+( |$)' <<<"$args" | head -n1 | tr -dc '0-9')
      if [ -n "$url" ]; then hit=$(grep -Fx "${url#github.com/}" <<<"$opened")
      elif [ -n "$n" ] && [ -n "$repo" ]; then hit=$(grep -Fx "$repo/pull/$n" <<<"$opened")
      elif [ -n "$n" ]; then hit=$(grep -E "/pull/$n\$" <<<"$opened")
      elif [ -n "$repo" ]; then hit=
      else hit=$opened; n=${opened##*/pull/}; fi
      [ -n "$hit" ] && finished="PR ${n:-${url##*/}} merged" ;;
  esac
  if [ -n "$finished" ]; then
    reminder_claim task-done "$finished"; claimed=$?
    if [ "$claimed" = 0 ]; then
      cat >&2 <<EOF
A task just finished ($finished). This is the point for a fresh session: every turn re-reads the whole context.
- Finish the step you are on; do not start a new task in this session.
- A plan this PR finished leaves .ai/plans/active/: git mv it to completed/ (a small PR if not done in this one).
- Overwrite .ai/handoff.md (short, English: state, open items, next step, do-not-do).
- Tell the owner, in their language: the task is done; type /clear, then "continue" or the next task.
If the owner already asked for more in this turn, finish that first, then say it.
EOF
      exit 2
    fi
    [ "$claimed" = 1 ] || advisory_unavailable 'cannot persist task-done reminder state'
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
