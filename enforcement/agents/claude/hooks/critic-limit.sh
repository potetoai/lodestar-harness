#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# PreToolUse (Agent|Task|SendMessage): the critic run limit (lodestar-harness
# agents/critic.md, "Re-run after a criteria change"). A critic dispatch
# whose brief names a plan by its .ai/plans/active/ path that already has as many
# runs as critic_limit allows is blocked: the open findings go to the owner.
# Only the first such path counts (the plan under review); other plans the
# brief cites as material are not runs. A brief that names no active plan
# is let through.
# A SendMessage that resumes a critic is a run too, though it names no
# subagent type: one sent to an agent whose name has "critic" is always
# blocked (a run is a fresh dispatch the hook can count), and one whose text
# reads as a critic run is blocked when the plan it names, or any active
# plan when it names none, has reached its limit.
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

input=$(cat)
resume=""
if [ "$(jq -r '.tool_name // empty' <<<"$input" 2>/dev/null)" = SendMessage ]; then
  brief=$(jq -r '.tool_input.message // empty | if type == "string" then . else tojson end' <<<"$input" 2>/dev/null | tr -d '\r' | tr '\\' '/')
  to=$(jq -r '.tool_input.to // empty | tostring' <<<"$input" 2>/dev/null)
  brief=${brief,,}; to=${to,,}
  if [[ $to == *critic* ]]; then
    cat >&2 <<'EOF'
Blocked: a critic run is a fresh dispatch, not a resume with SendMessage (agents/critic.md,
'Re-run after a criteria change'): the hook counts only dispatches. Dispatch a new critic with
the Agent tool; its brief starts "You are the critic" and names the plan by its
.ai/plans/active/ path. The run limit still applies.
EOF
    exit 2
  fi
  grep -qE 'critic|criteria|narrowed|full run' <<<"$brief" && resume=1 || exit 0
else
  brief=$(jq -r '.tool_input.prompt // empty' <<<"$input" 2>/dev/null | tr -d '\r' | tr '\\' '/')
  brief=${brief,,}
  # A critic dispatch: the critic subagent type, or a brief that casts the
  # critic ("You are the critic", agents/critic.md). A tester or builder brief
  # that only cites critic.md is not one.
  [ "$(jq -r '.tool_input.subagent_type // empty' <<<"$input" 2>/dev/null)" = critic ] ||
    grep -qE 'you are (the |a )?(lodestar )?critic([^[:alnum:]-]|$)' <<<"$brief" || exit 0
fi
. .claude/hooks/lodestar-lib.sh 2>/dev/null && declare -F critic_limit >/dev/null || exit 0

# The first .ai/plans/active/ path in the brief: the plan under review.
first=$(grep -oE '\.ai/plans/active/[^/[:space:]]+\.md' <<<"$brief" | head -n1)
out=""
for p in .ai/plans/active/*.md; do
  [ -f "$p" ] || continue
  n=$(basename "$p")
  # A resume that names no plan may be a run of any active plan.
  [ ".ai/plans/active/${n,,}" = "$first" ] || { [ -n "$resume" ] && [ -z "$first" ]; } || continue
  runs=$(critic_runs < "$p"); limit=$(critic_limit "$p")
  short=${n%.md}; short=${short,,}; short=${short#[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-}
  [ "$runs" -ge "$limit" ] && out+="  $p: $runs runs, limit $limit; the owner types (\"duyệt critic\" when owner_language is vi): approve critic $short"$'\n'
done
[ -n "$out" ] || exit 0
echo "Blocked: the critic run limit is reached (agents/critic.md, 'Re-run after a criteria change'):" >&2
printf '%s' "$out" >&2
[ -n "$resume" ] && echo "A critic run is a fresh Agent dispatch, never a SendMessage resume (agents/critic.md)." >&2
cat >&2 <<'EOF'
Do not change the criteria again. Write each open finding with "left to the owner (run limit)",
add the '- Reviewed criteria:' line, and show the owner the open findings with the criteria, in
plain words, each with your advice (fix or keep). The owner approves as written, or names fixes.
A MINOR finding past run 3 stays as written: it needs no fix and no run.
After a fix the owner asks for (BLOCKER or MAJOR only), ask them to type the "approve critic" line above in their own message
(the hook records it): that allows the next narrowed run, however many runs came before. Each approval of the criteria also
allows one more run, for a criteria change during the build.
EOF
exit 2
