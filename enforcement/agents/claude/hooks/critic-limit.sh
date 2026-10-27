#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# PreToolUse (Agent|Task): the critic run limit (lodestar-harness
# agents/critic.md, "Re-run after a criteria change"). A critic dispatch
# whose brief names a plan by its .ai/plans/active/ path that already has as many
# runs as critic_limit allows is blocked: the open findings go to the owner.
# A brief that names no active plan is let through.
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

input=$(cat)
brief=$(jq -r '.tool_input.prompt // empty' <<<"$input" 2>/dev/null | tr -d '\r' | tr '\\' '/')
brief=${brief,,}
# A critic dispatch: the critic subagent type, or a brief that casts the
# critic ("You are the critic", agents/critic.md). A tester or builder brief
# that only cites critic.md is not one.
[ "$(jq -r '.tool_input.subagent_type // empty' <<<"$input" 2>/dev/null)" = critic ] ||
  grep -qE 'you are (the |a )?(lodestar )?critic([^[:alnum:]-]|$)' <<<"$brief" || exit 0
. .claude/hooks/lodestar-lib.sh 2>/dev/null && declare -F critic_limit >/dev/null || exit 0

out=""
for p in .ai/plans/active/*.md; do
  [ -f "$p" ] || continue
  n=$(basename "$p"); grep -qF -- ".ai/plans/active/${n,,}" <<<"$brief" || continue
  runs=$(critic_runs < "$p"); limit=$(critic_limit "$p")
  [ "$runs" -ge "$limit" ] && out+="  $p: $runs runs, limit $limit"$'\n'
done
[ -n "$out" ] || exit 0
echo "Blocked: the critic run limit is reached (agents/critic.md, 'Re-run after a criteria change'):" >&2
printf '%s' "$out" >&2
cat >&2 <<'EOF'
Do not change the criteria again. Write each open finding with "left to the owner (run limit)",
add the '- Reviewed criteria:' line, and show the owner the open findings with the criteria, in
plain words, each with your advice (fix or keep). The owner approves as written, or names fixes.
After a fix the owner asks for, ask them to type "duyệt critic <plan name>" in their own message
(the hook records it): that allows one more narrowed run. Each approval of the criteria also
allows one more run, for a criteria change during the build.
EOF
exit 2
