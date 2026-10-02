#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# PreToolUse (Edit|Write|MultiEdit): guard the tests-first mode
# (rules/testing.md, "Tests-first mode").
# - .ai/approvals.log: never edited by the agent (approval-record.sh writes it).
# - Tests in .ai/test-lock and the lock itself: blocked while the task is
#   active (a plan in .ai/plans/active/). The lock expires when the plan moves
#   to completed/. It reopens only when the owner approved changed criteria
#   (relock window), so the tester can write the new round of tests.
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

file=$(jq -j '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -z "$file" ] && exit 0

# Path relative to the project, forward slashes, compared case-insensitively.
proj=$(pwd -W 2>/dev/null || pwd)
f=${file//\\//} p=${proj//\\//}
[[ ${f,,} == "${p,,}"/* ]] && f=${f:${#p}+1}

if [ "${f,,}" = ".ai/approvals.log" ]; then
  echo "Blocked: .ai/approvals.log records the owner's own approvals. Only the approval hook writes it." >&2
  echo "Ask the owner to reply with the approval word (\"duyệt\" when owner_language is vi, else \"approve\")." >&2
  exit 2
fi

[ -s .ai/test-lock ] || exit 0
. .claude/hooks/lodestar-lib.sh 2>/dev/null || exit 0
lock_active || exit 0      # task done: lock expired, even if the file remains
locked=0
[ "${f,,}" = ".ai/test-lock" ] && locked=1
lock_paths < .ai/test-lock | grep -qixF -- "$f" && locked=1
if [ $locked = 1 ]; then
  relock_window && exit 0
  echo "Blocked: $f is locked by the tests-first mode (.ai/test-lock)." >&2
  echo "Make the code pass the tests; do not change them. If a test or criterion is wrong, stop" >&2
  echo "and ask the owner. Once they approve the changed criteria, the tester writes a new round." >&2
  exit 2
fi
exit 0
