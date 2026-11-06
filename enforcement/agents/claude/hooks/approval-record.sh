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
# head commit). merge-pr.sh lets a PR that changes sensitive code or a
# safety file merge only with this line. It approves no plan; "merge"
# without a PR number falls through to the plan approval below.
# Only numbers right after "merge PR"/"merge #", or listed straight after one
# ("merge PR 9, PR 10", "merge #9 và #10"): "see issue #12" or "but not
# PR 6" approve nothing. Only the first "merge" of a line counts ("không
# merge PR 6"). Each line that itself starts with the approval word is one
# approval ("duyệt merge PR 1" / "duyệt merge PR 2" on two lines approves both);
# other lines approve nothing. After the first line, a quoted or bulleted line
# ("> duyệt merge PR 9", from a pasted prompt) is not the owner's own words.
first=1
nums=$(while IFS= read -r line; do
  if [ $first = 1 ]; then ls=$start; first=0; else ls=${line#"${line%%[![:space:]]*}"}; fi
  grep -qE '^(duyệt|duyet|approve|approved)([^[:alpha:]]|$)' <<<"$ls" || continue
  grep -qE '(chưa|chua|không|khong|đừng|dung|not|don.t|do not)[[:space:]]+(duyệt|duyet|approve)' <<<"$ls" && continue
  grep -oE '(^|[^[:alpha:]])merge[[:space:]]+(pr[[:space:]]*#?|#)[0-9]+([[:space:]]*(,|and|và|&)[[:space:]]*(pr[[:space:]]*#?|#)?[0-9]+)*' <<<"$ls" |
    head -n1 | sed -E 's/^[^m]*merge//' | grep -oE '[0-9]+'
done <<<"$low" | awk '!seen[$0]++')
if [ -n "$nums" ]; then
  now=$(date '+%Y-%m-%d %H:%M')
  mkdir -p .ai
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

# Plan approvals need the Lodestar library; the lodestar-harness source repo
# has none and records only merge approvals (its AGENTS.md).
[ -f .claude/hooks/lodestar-lib.sh ] || exit 0
. .claude/hooks/lodestar-lib.sh || exit 0

# The owner names a plan by its file name, with or without the date prefix
# ("2026-10-31-share-sheet-android" or "share-sheet-android").
short_name() { local n; n=$(basename "$1" .md); n=${n,,}; echo "${n#[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-}"; }
named_in_prompt() {
  local full short; full=$(basename "$1" .md); full=${full,,}; short=$(short_name "$1")
  full=$(sed 's/[][\.^$*+?(){}|]/\\&/g' <<<"$full"); short=$(sed 's/[][\.^$*+?(){}|]/\\&/g' <<<"$short")
  grep -qE "(^|[^[:alnum:]-])($full|$short)([^[:alnum:]-]|\$)" <<<"$low"
}

if ! ls .ai/plans/active/*.md >/dev/null 2>&1; then
  echo "Lodestar: the owner approved, but no plan exists in .ai/plans/active/, so nothing was recorded."
  echo "If this approves acceptance criteria: write them under '## Acceptance criteria' in a plan"
  echo "file first, then ask the owner again for the approval word (\"duyệt\" when owner_language"
  echo "is vi, else \"approve\"). Always write the plan before asking."
  exit 0
fi

# "duyệt sửa test <path>...": the owner approves fixing locked tests that are
# wrong while the criteria are right (rules/testing.md, "When a test or
# criterion turns out wrong"). It approves no criteria and uses no critic run.
# Each name, on the first line, must match one locked path: the whole path,
# its file name, or the file name up to its first dot; "*", "?" and "[" match
# nothing. "duyệt sửa 3 test" without names opens no test and lists the lines.
# A message that names no locked test but names an active plan ("approve
# fix tests for plan login") goes on to the plan approval below.
fixre='^(duyệt|duyet|approve|approved)[[:space:]]+((sửa|sua|fix)[[:space:]]+([0-9]+[[:space:]]+)?tests?|tests?[[:space:]]+fix(es)?)([^[:alnum:]_-]|$)'
line1=${start%%$'\n'*}
if grep -qE "$fixre" <<<"$line1" && [ -s .ai/test-lock ] && lock_active; then
  mapfile -t lockp < <(lock_paths < .ai/test-lock)
  now=$(date '+%Y-%m-%d %H:%M') bad=() n=0
  read -ra toks <<<"$(sed -E "s/$fixre//" <<<"$line1" | tr ",;\`\"'" '     ')"
  for tok in "${toks[@]}"; do
    tok=${tok%[.:]}
    case $tok in và|va|and|'&'|'') continue ;; *[][*?]*) bad+=("$tok"); continue ;; esac
    hits=()
    for lp in "${lockp[@]}"; do
      b=${lp##*/}; b=${b,,}
      [ "${lp,,}" = "$tok" ] || [ "$b" = "$tok" ] || [ "${b%%.*}" = "$tok" ] && hits+=("$lp")
    done
    if [ ${#hits[@]} = 1 ]; then
      echo "$now test-fix ${hits[0]}" >> .ai/approvals.log; n=$((n + 1))
      echo "Lodestar: recorded the owner's approval to fix the locked test ${hits[0]} (criteria unchanged)."
    else
      bad+=("$tok")
    fi
  done
  if [ $n = 0 ] || [ ${#bad[@]} -gt 0 ]; then
    [ ${#bad[@]} -gt 0 ] && echo "Lodestar: these names match no single locked test, so nothing was recorded for them: ${bad[*]}"
    [ $n = 0 ] && echo "Lodestar: the owner approved fixing tests, but named none that is locked, so no test was opened."
    echo "If a locked test is wrong, ask the owner to type one line per test, with its path from"
    echo ".ai/test-lock (\"duyệt sửa test\" when owner_language is vi, else \"approve test fix\"), e.g.:"
    echo "  duyệt sửa test ${lockp[0]}"
  fi
  if [ $n -gt 0 ]; then
    echo "The tester fixes only those tests (they must still test their criterion) and commits a new"
    echo "Tests-First round with the plan and .ai/approvals.log."
    exit 0
  fi
  # A mistyped test name must not approve criteria (that opens every locked
  # test): go on only when the message names an active plan.
  for p in .ai/plans/active/*.md; do named_in_prompt "$p" && named_plan=1; done
  [ -n "${named_plan:-}" ] || exit 0
fi

# "duyệt critic <plan>": the owner allows one more critic run of a plan past
# the run limit (agents/critic.md; critic-limit.sh counts it). It approves no
# criteria. With several active plans the owner names the plan. Only
# "critic" as the word right after the approval word counts: "duyệt, critic
# ổn rồi" and "duyệt critic-limit" (a plan's name) approve criteria as usual.
if grep -qE '^(duyệt|duyet|approve|approved)[[:space:]]+critic([^[:alnum:]-]|$)' <<<"$start"; then
  all=() said=()
  for p in .ai/plans/active/*.md; do
    all+=("$p"); named_in_prompt "$p" && said+=("$p")
  done
  [ ${#said[@]} = 0 ] && [ ${#all[@]} = 1 ] && said=("${all[@]}")
  if [ ${#said[@]} = 0 ]; then
    echo "Lodestar: the owner allowed another critic run, but ${#all[@]} plans are active, so nothing was recorded."
    echo "Ask the owner to type one of these lines (the plan's name, with or without its date; \"duyệt critic\" when owner_language is vi):"
    for p in "${all[@]}"; do echo "  approve critic $(short_name "$p")"; done
    exit 0
  fi
  now=$(date '+%Y-%m-%d %H:%M')
  for p in "${said[@]}"; do
    # The run count now: this approval allows the next run, however many came before.
    echo "$now critic-run $p $(critic_runs < "$p")" >> .ai/approvals.log
    echo "Lodestar: recorded the owner's approval of one more critic run for $p (no criteria approved)."
  done
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
  said=0; named_in_prompt "$p" && said=1
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
  echo "criterion turns out wrong'). If a locked test is wrong while its criterion is right, ask the owner to"
  echo "type \"duyệt sửa test <path>\" (\"approve test fix <path>\"). If the criterion is wrong, update it,"
  echo "run the critic on the change, show the owner, then ask for the approval word again."
  exit 0
fi
if [ ${#named[@]} = 0 ] && [ ${#pending[@]} -gt 1 ]; then
  echo "Lodestar: the owner approved, but ${#pending[@]} plans are waiting, so nothing was recorded."
  echo "Ask the owner to reply with the approval word (\"duyệt\" when owner_language is vi, else"
  echo "\"approve\") followed by the plan's name, once for each plan they approve. Waiting plans:"
  for p in "${pending[@]}"; do echo "  $(short_name "$p")"; done
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
