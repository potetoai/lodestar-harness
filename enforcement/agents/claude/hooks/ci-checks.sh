#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# Pull-request checks (rules/testing.md, rules/enforcement.md):
#   1. A change to sensitive_paths needs a test change, or a commit trailer
#      "No-Test-Reason: <reason>".
#   2. A new lint suppression (noqa, eslint-disable, ts-ignore...) needs a
#      reason on the same line: "# noqa: F401 -- <reason>".
#   3. Every "Tests-First:" commit includes a plan whose criteria the owner
#      approved (.ai/approvals.log). Tests it locks (.ai/test-lock) must not
#      change later, except in another such commit (a new approved round).
#   4. New TODO/FIXME/HACK comments are listed for the reviewer (no failure).
#   5. A plain-English summary of the criteria and their approval goes to
#      the PR's check summary, so the owner can read it without code.
#   6. Mutation testing (`make test-mutation`) on changed sensitive code, only when
#      LODESTAR_TEST_MUTATION=true (CI: the PR label "test-mutation"): score and surviving
#      mutants go to the summary (no failure).
# Usage: ci-checks.sh <base-ref>     (for example origin/main)
base=${1:?usage: ci-checks.sh <base-ref>}
from=$(git merge-base "$base" HEAD) || { echo "ci-checks: cannot find merge base with $base" >&2; exit 1; }
. "$(dirname "$0")/lodestar-lib.sh" || { echo "ci-checks: lodestar-lib.sh missing" >&2; exit 1; }
fails=0
fail() { echo "❌ $*"; fails=$((fails + 1)); }

is_test() {
  [[ $1 =~ (^|/)(tests?|__tests__)/ || $1 =~ (^|/)test_[^/]*\.py$ || $1 =~ _test\.(py|go)$ || $1 =~ \.(test|spec)\.[cm]?[jt]sx?$ ]]
}
# Paths scanned for new suppressions and TODOs: code only. Docs, and the
# files Lodestar manages (they contain these patterns as text), are skipped.
SCAN=(. ":(exclude)*.md" ":(exclude).claude/hooks/*" ":(exclude).github/workflows/*")
# Keep this pattern in sync with lint-file.sh.
SUPPRESS='(#[[:space:]]*noqa|#[[:space:]]*type:[[:space:]]*ignore|#[[:space:]]*pylint:[[:space:]]*disable|eslint-disable|oxlint-disable|@ts-ignore|@ts-expect-error|//[[:space:]]*nolint)'

changed=$(git diff --name-only "$from" HEAD)

# 1. Sensitive paths need tests.
patterns=$(sed -n '/^sensitive_paths:/,/^[^[:space:]-]/p' .ai/project.md 2>/dev/null |
  sed -n 's/^[[:space:]]*-[[:space:]]*//p' | tr -d "\"'\r")
sensitive() {
  local f=$1 pat
  is_test "$f" && return 1   # tests may live in sensitive paths; they are not the risky change
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    case "$pat" in
      */) [[ $f == "$pat"* ]] && return 0 ;;
      *) [[ $f == $pat ]] && return 0 ;;
    esac
  done <<<"$patterns"
  return 1
}
# A "No-Test-Reason:" trailer excuses only the commit that carries it.
hits=()
for c in $(git rev-list --no-merges "$from..HEAD"); do
  msg=$(git log -1 --format=%B "$c")
  reason=$(sed -n 's/^No-Test-Reason:[[:space:]]*//p' <<<"$msg" | head -n1)
  while IFS= read -r f; do
    [ -n "$f" ] && sensitive "$f" || continue
    if [ -n "$reason" ]; then
      echo "⚠️  $(git log -1 --format=%h "$c") changes $f; No-Test-Reason: $reason"
    else
      hits+=("$f")
    fi
  done < <(git diff-tree --root --no-commit-id --name-only -r "$c")
done
mapfile -t hits < <(printf '%s\n' "${hits[@]}" | sed '/^$/d' | sort -u)
if [ ${#hits[@]} -gt 0 ]; then
  tests_changed=0
  while IFS= read -r f; do is_test "$f" && tests_changed=1; done <<<"$changed"
  # Tests-first mode: the owner-approved plan must be part of the PR.
  plan_ok=0
  while IFS= read -r f; do
    [[ $f == .ai/plans/*.md ]] && [ -f "$f" ] && plan_approved_at HEAD "$f" && plan_ok=1
  done <<<"$changed"
  if [ $tests_changed = 0 ]; then
    fail "Sensitive paths changed without any test change:"
    printf '     %s\n' "${hits[@]}"
    echo "   Add a test, or a commit trailer 'No-Test-Reason: <why no test is needed>'."
  elif [ $plan_ok = 0 ]; then
    fail "Sensitive paths changed without an owner-approved plan in this PR:"
    printf '     %s\n' "${hits[@]}"
    echo "   Add .ai/plans/active/<task>.md with the criteria, approved by the owner (they reply \"duyệt\" or \"approve\")."
  else
    echo "✅ sensitive paths changed, with tests and an approved plan"
  fi
else
  echo "✅ no sensitive paths changed"
fi

# 2. New lint suppressions need a reason (" -- <reason>" on the same line).
new=$(git diff -U0 "$from" HEAD -- "${SCAN[@]}" | awk -v re="$SUPPRESS" '
  /^\+\+\+ b\// { file = substr($0, 7); next }
  /^\+/ && !/^\+\+\+/ && $0 ~ re { print file ": " substr($0, 2) }')
if [ -n "$new" ]; then
  echo "New lint suppressions (for the reviewer):"
  printf '     %s\n' "$new"
  missing=$(grep -vE -- '--[[:space:]]*[^[:space:]]' <<<"$new")
  if [ -n "$missing" ]; then
    fail "Lint suppressions without a reason. Fix the code, or add ' -- <reason>':"
    printf '     %s\n' "$missing"
  fi
else
  echo "✅ no new lint suppressions"
fi

# 3. Tests-First commits carry an approved plan; locked tests stay unchanged.
locked_ok=1
for c in $(git log --reverse --format=%H --grep='^Tests-First:' "$from..HEAD"); do
  if ! valid_tests_first "$c"; then
    fail "Commit $(git log -1 --format='%h %s' "$c") is marked Tests-First but has no owner-approved plan change."
    echo "   A Tests-First commit must include the plan whose criteria the owner approved (.ai/approvals.log)."
    locked_ok=0; continue
  fi
  lock=$(git show "$c:.ai/test-lock" 2>/dev/null | lock_paths)
  [ -n "$lock" ] || continue
  for later in $(git rev-list "$c..HEAD"); do
    valid_tests_first "$later" && continue   # a new round of tests with newly approved criteria
    touched=$(git diff-tree --root --no-commit-id --name-only -r "$later" | grep -Fxf <(printf '%s\n' "$lock"))
    if [ -n "$touched" ]; then
      fail "Commit $(git log -1 --format='%h %s' "$later") changes locked tests:"
      printf '     %s\n' $touched
      locked_ok=0
    fi
  done
done
[ $locked_ok = 1 ] && echo "✅ tests-first rounds approved; locked tests unchanged"

# 4. New TODO/FIXME/HACK: list them; debt left on purpose belongs in tech-debt.md.
todos=$(git diff -U0 "$from" HEAD -- "${SCAN[@]}" | awk '
  /^\+\+\+ b\// { file = substr($0, 7); next }
  /^\+/ && !/^\+\+\+/ && /(TODO|FIXME|HACK)/ { print file ": " substr($0, 2) }')
if [ -n "$todos" ]; then
  echo "⚠️  New TODO/FIXME/HACK (reviewer: each needs an entry in .ai/tech-debt.md):"
  printf '     %s\n' "$todos"
  grep -q '^\.ai/tech-debt\.md$' <<<"$changed" || echo "   Note: .ai/tech-debt.md did not change in this PR."
fi

# 5. Owner-readable summary of the criteria in this PR (English, like all PR text).
summary=""
while IFS= read -r f; do
  [[ $f == .ai/plans/*.md ]] && [ -f "$f" ] || continue
  h=$(criteria_hash < "$f") || continue      # the template and empty plans have no criteria
  crit=$(criteria_lines < "$f")
  [ -n "$crit" ] || continue
  when=$(git show HEAD:.ai/approvals.log 2>/dev/null | tr -d '\r' | grep -E "[[:space:]]$h\$" | head -n1 | cut -d' ' -f1-2)
  if [ -n "$when" ]; then status="✅ The owner approved exactly these criteria at $when"
  else status="❌ Not approved by the owner, or changed after approval"; fi
  summary+=$(printf '### Acceptance criteria: `%s`\n%s\n\n%s\n\n' "$f" "$status" "$crit")$'\n\n'
done <<<"$changed"
if [ -n "$summary" ]; then
  printf '%s\n' "$summary"
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '## Summary for the owner\n\n%s\n' "$summary" >> "$GITHUB_STEP_SUMMARY"
fi

# 6. Mutation testing on changed sensitive files: report only, never fails.
mfiles=$(while IFS= read -r f; do [ -f "$f" ] && sensitive "$f" && echo "$f"; done <<<"$changed")
if [ "${LODESTAR_TEST_MUTATION:-}" != true ]; then
  mut="Mutation testing off (add the PR label 'test-mutation' to run it)."
elif [ -z "$mfiles" ]; then
  mut="No sensitive code changed; mutation testing skipped."
elif ! make -n test-mutation FILES=x >/dev/null 2>&1; then
  mut="Mutation testing not set up (no 'make test-mutation' target)."
else
  # ponytail: paths with spaces split here and in the Makefiles; quote them if a project needs it.
  mut=$(timeout -k 10 "${LODESTAR_TEST_MUTATION_TIMEOUT:-900}" make -s test-mutation FILES="$(echo $mfiles)" 2>&1); rc=$?
  # A run stopped mid-mutation leaves a broken file; later CI steps need the real code.
  git checkout -q -- $mfiles
  [ $rc = 0 ] || mut+=$'\n'"Mutation testing did not finish (exit $rc; 124 = time limit)."
  [ -n "$mut" ] || mut="No part of the repo ran mutation testing (no 'make test-mutation' in the part)."
fi
echo "Mutation testing (report only):"; sed 's/^/     /' <<<"$mut"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] &&
  printf '## Mutation testing (report only)\n\n```\n%s\n```\n' "$(head -n 300 <<<"$mut")" >> "$GITHUB_STEP_SUMMARY"

[ $fails = 0 ] || { echo "PR checks failed: $fails"; exit 1; }
echo "PR checks passed."
