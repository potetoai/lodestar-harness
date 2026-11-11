#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# PostToolUse (Bash|PowerShell): a shell command (a Python script, sed, cp...)
# can change a locked tests-first test that protect-tests.sh, which sees only
# file-edit tools, never checks. Without parsing the command, compare the
# locked tests with the round that locked them right after it runs, and tell
# the agent at once. The Stop hook, pre-push and CI hold the same change later.
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
cat >/dev/null
[ -f .claude/hooks/lodestar-lib.sh ] && . .claude/hooks/lodestar-lib.sh || exit 0
locked_tests_changed || exit 0
echo "Lodestar: tests locked by commit $(git log -1 --format='%h %s' "$lock_base") were changed:" >&2
echo "$lock_touched" >&2
echo "Undo it now (git checkout $lock_base -- <file>); a script may not change a locked test. If a test" >&2
echo "is wrong, stop and ask the owner: \"duyệt sửa test <path>\" (\"approve test fix <path>\") for one test" >&2
echo "under right criteria, or approved changed criteria and a new Tests-First round (rules/testing.md)." >&2
exit 2
