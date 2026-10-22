#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# UserPromptSubmit: when the OWNER types an approval ("duyệt", "approve"),
# record which acceptance criteria were approved: one line per active plan in
# .ai/approvals.log with the criteria hash. The agent cannot produce this by
# assuming approval; the sensitive-code gate and CI accept only criteria whose
# hash is recorded here. Editing a plan's criteria afterwards needs a new
# approval. A plan without a filled "## Criteria review" (the critic's
# findings), or whose review covers other criteria than the current ones, is
# never recorded. Stdout goes into the agent's context.
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

# "duyệt merge PR 52": the owner approves merging that PR as it is now (its
# head commit). guard-install.sh lets a PR that changes sensitive code or a
# safety file merge only with this line. It approves no plan; "merge"
# without a PR number falls through to the plan approval below.
# Only numbers right after "merge PR"/"merge #", or listed straight after one
# ("merge PR 9, PR 10", "merge #9 và #10"): "see issue #12" or "but not
# PR 6" approve nothing. Only the first "merge" counts ("không merge PR 6").
nums=$(grep -oE '(^|[^[:alpha:]])merge[[:space:]]+(pr[[:space:]]*#?|#)[0-9]+([[:space:]]*(,|and|và|&)[[:space:]]*(pr[[:space:]]*#?|#)?[0-9]+)*' <<<"$low" |
  head -n1 | sed -E 's/^[^m]*merge//' | grep -oE '[0-9]+')
if [ -n "$nums" ]; then
  now=$(date '+%Y-%m-%d %H:%M')
  for n in $nums; do
    oid=$(gh pr view "$n" --json headRefOid -q .headRefOid 2>/dev/null | tr -d '\r')
    if [ -z "$oid" ]; then
      echo "Lodestar: gh could not read PR #$n, so the owner's merge approval was not recorded."
      echo "Fix gh (gh auth status), then ask the owner to type the approval again."
      continue
    fi
    echo "$now merge-pr $n $oid" >> .ai/approvals.log
    echo "Lodestar: recorded the owner's approval to merge PR #$n at ${oid:0:7}. A new push needs a new approval."
  done
  exit 0
fi

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
# A named plan already approved as it is now is reported, never swapped for
# another waiting plan the owner did not name.
pending=() named=() named_done=()
for p in .ai/plans/active/*.md; do
  h=$(criteria_hash < "$p") || continue
  n=$(basename "$p" .md); n=${n,,}; n=${n#[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-}
  said=0; grep -qE "(^|[^[:alnum:]-])$n([^[:alnum:]-]|\$)" <<<"$low" && said=1
  if [ -f .ai/approvals.log ] && hash_approved "$h" < .ai/approvals.log; then
    [ $said = 1 ] && named_done+=("$p"); continue
  fi
  pending+=("$p")
  [ $said = 1 ] && named+=("$p")
done
if [ ${#named[@]} = 0 ] && [ ${#named_done[@]} -gt 0 ]; then
  for p in "${named_done[@]}"; do
    echo "Lodestar: the owner approved $p, but its criteria as they are now were already approved, so nothing was recorded."
  done
  echo "An approval opens a relock window only for changed criteria (rules/testing.md, 'When a test or"
  echo "criterion turns out wrong'). If a locked test is wrong, update the criterion it got wrong (make it"
  echo "more precise), run the critic on the change, show the owner, then ask for the approval word again."
  exit 0
fi
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
  if ! review_covers "$h" < "$p"; then
    echo "Lodestar: the owner approved, but the '## Criteria review' in $p does not cover the criteria as"
    echo "they are now (no '- Reviewed criteria:' line with their hash), so nothing was recorded for it."
    echo "Run the critic on the change first (lodestar-harness agents/critic.md, 'Re-run after a criteria"
    echo "change' and 'Output'), show the owner the result, then ask for the approval word again."
    continue
  fi
  echo "$now $p $h" >> .ai/approvals.log
  echo "Lodestar: recorded the owner's approval of the acceptance criteria in $p ($h)."
  echo "If you change those criteria later, the owner must approve them again."
done
exit 0
