#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# UserPromptSubmit: when the OWNER types an approval ("duyệt", "approve"),
# record which acceptance criteria were approved: one line per active plan in
# .ai/approvals.log with the criteria hash. The agent cannot produce this by
# assuming approval; the sensitive-code gate and CI accept only criteria whose
# hash is recorded here. Editing a plan's criteria afterwards needs a new
# approval. A plan without a filled "## Criteria review" (the critic's
# findings) is never recorded. Stdout goes into the agent's context.
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ -f .claude/hooks/lodestar-lib.sh ] || exit 0
. .claude/hooks/lodestar-lib.sh || exit 0

prompt=$(jq -r '.prompt // empty' | tr -d '\r')
[ -n "$prompt" ] || exit 0
# A message from another Claude session arrives as a prompt too; only the owner approves.
grep -q '<cross-session-message' <<<"$prompt" && exit 0
low=${prompt,,}
# Only a message that STARTS with the approval word approves: "để mình duyệt"
# or "chờ duyệt" inside a longer message asks for approval, it does not give it.
start=${low#"${low%%[![:space:][:punct:]]*}"}
grep -qE '^(duyệt|duyet|approve|approved)([^[:alpha:]]|$)' <<<"$start" || exit 0
# "chưa duyệt", "không duyệt", "not approve"... are not approvals.
grep -qE '(chưa|chua|không|khong|đừng|dung|not|don.t|do not)[[:space:]]+(duyệt|duyet|approve)' <<<"$low" && exit 0

if ! ls .ai/plans/active/*.md >/dev/null 2>&1; then
  echo "Lodestar: the owner approved, but no plan exists in .ai/plans/active/, so nothing was recorded."
  echo "If this approves acceptance criteria: write them under '## Acceptance criteria' in a plan"
  echo "file first, then ask the owner again for the approval word (\"duyệt\" when owner_language"
  echo "is vi, else \"approve\"). Always write the plan before asking."
  exit 0
fi

# Plans whose current criteria are not approved yet. With several waiting, the
# owner names each one ("approve my-plan"), so one word never approves a
# plan they have not read.
pending=() named=()
for p in .ai/plans/active/*.md; do
  h=$(criteria_hash < "$p") || continue
  [ -f .ai/approvals.log ] && hash_approved "$h" < .ai/approvals.log && continue
  pending+=("$p")
  n=$(basename "$p" .md); n=${n,,}; n=${n#[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-}
  grep -qE "(^|[^[:alnum:]-])$n([^[:alnum:]-]|\$)" <<<"$low" && named+=("$p")
done
if [ ${#named[@]} = 0 ] && [ ${#pending[@]} -gt 1 ]; then
  echo "Lodestar: the owner approved, but ${#pending[@]} plans are waiting, so nothing was recorded."
  echo "Ask the owner to reply with the approval word (\"duyệt\" when owner_language is vi, else"
  echo "\"approve\") followed by the plan's name, once for each plan they approve. Waiting plans:"
  for p in "${pending[@]}"; do n=$(basename "$p" .md); echo "  ${n#[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-}"; done
  exit 0
fi
[ ${#named[@]} -gt 0 ] && pending=("${named[@]}")

now=$(date '+%Y-%m-%d %H:%M')
for p in "${pending[@]}"; do
  if ! criteria_reviewed < "$p"; then
    echo "Lodestar: the owner approved, but $p has no '## Criteria review', so nothing was recorded for it."
    echo "Run the critic first (lodestar-harness agents/critic.md, in a fresh subagent), fix the criteria,"
    echo "fill that section, show the owner the result, then ask for the approval word again."
    continue
  fi
  h=$(criteria_hash < "$p")
  echo "$now $p $h" >> .ai/approvals.log
  echo "Lodestar: recorded the owner's approval of the acceptance criteria in $p ($h)."
  echo "If you change those criteria later, the owner must approve them again."
done
exit 0
