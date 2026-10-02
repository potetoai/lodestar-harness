#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# PreToolUse (Edit|Write|MultiEdit): tests-first gate for sensitive code
# (rules/testing.md, "Tests-first mode"). Editing a non-test file in
# sensitive_paths needs:
#   1. a plan in .ai/plans/active/ whose acceptance criteria the owner
#      approved (hash recorded in .ai/approvals.log by approval-record.sh)
#   2. failing tests written and locked (.ai/test-lock), or a line
#      "No-Test-Reason: <reason>" in that plan.
# Test files are never gated, so the tester can write them first.
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ -f .ai/project.md ] || exit 0

file=$(jq -j '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -z "$file" ] && exit 0
proj=$(pwd -W 2>/dev/null || pwd)
f=${file//\\//} p=${proj//\\//}
if [[ ${f,,} == "${p,,}"/* ]]; then f=${f:${#p}+1}; else exit 0; fi

# Keep in sync with ci-checks.sh.
[[ $f =~ (^|/)(tests?|__tests__)/ || $f =~ (^|/)test_[^/]*\.py$ || $f =~ _test\.(py|go)$ || $f =~ \.(test|spec)\.[cm]?[jt]sx?$ ]] && exit 0

hit=0
while IFS= read -r pat; do
  [ -n "$pat" ] || continue
  case "$pat" in
    */) [[ $f == "$pat"* ]] && hit=1 ;;
    *) [[ $f == $pat ]] && hit=1 ;;
  esac
  [ $hit = 1 ] && break
done < <(sed -n '/^sensitive_paths:/,/^[^[:space:]-]/p' .ai/project.md | sed -n 's/^[[:space:]]*-[[:space:]]*//p' | tr -d "\"'\r")
[ $hit = 1 ] || exit 0

. .claude/hooks/lodestar-lib.sh || exit 0
plan=""
for p in .ai/plans/active/*.md; do
  [ -f "$p" ] && plan_approved_now "$p" && { plan=$p; break; }
done
if [ -z "$plan" ]; then
  cat >&2 <<EOF
Blocked: $f is in sensitive_paths, so this task runs in tests-first mode.
1. Write the acceptance criteria in a plan (.ai/plans/active/, from .ai/plans/TEMPLATE.md).
2. Show them to the owner in their language, English lines next to it, and ask for the
   approval word ("duyệt" when owner_language is vi, else "approve").
   A hook records that approval; you cannot record it yourself. If you edit the
   criteria after that, the owner must approve again.
3. Write failing tests and list them in .ai/test-lock. Then change this file.
EOF
  exit 2
fi
if [ ! -s .ai/test-lock ] && ! grep -q '^No-Test-Reason:' "$plan"; then
  cat >&2 <<EOF
Blocked: $f is in sensitive_paths. The plan is approved ($plan), but no tests are locked yet.
Write failing tests for the criteria and list them in .ai/test-lock first.
If the owner agreed no test is needed, add "No-Test-Reason: <reason>" to the plan.
EOF
  exit 2
fi
exit 0
