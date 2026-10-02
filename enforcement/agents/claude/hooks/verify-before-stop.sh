#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# Stop: do not let the agent finish while `make verify` fails.
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
export NO_COLOR=1 FORCE_COLOR=0  # plain text for the agent

# Prevent an endless loop: if the agent was already sent back once, let it
# stop. CI is the final gate.
[ "$(jq -j '.stop_hook_active // false')" = "true" ] && exit 0

# Tests locked by the last VALID Tests-First commit (it carries an owner-
# approved plan) stay unchanged while the task is active (a plan in
# .ai/plans/active/), even if .ai/test-lock is removed. Reads git history, so
# it works without CI. A Tests-First trailer without an approved plan change
# cannot reset the lock. During a relock window (owner approved changed
# criteria) the tester may rewrite them.
if ls .ai/plans/active/*.md >/dev/null 2>&1 && [ -f .claude/hooks/lodestar-lib.sh ] &&
   . .claude/hooks/lodestar-lib.sh && lock_active && ! relock_window && c=$(last_valid_tests_first); then
  mapfile -t locked < <(git show "$c:.ai/test-lock" 2>/dev/null | lock_paths)
  if [ ${#locked[@]} -gt 0 ]; then
    touched=$(git diff --name-only "$c" -- "${locked[@]}" 2>/dev/null)
    if [ -n "$touched" ]; then
      echo "Not done yet: tests locked by commit $(git log -1 --format='%h %s' "$c") were changed:" >&2
      echo "$touched" >&2
      echo "Undo those changes (git checkout $c -- <file>). If a test or criterion is wrong, ask the" >&2
      echo "owner to approve changed criteria (they reply \"duyệt\" or \"approve\"); then the tester commits a new" >&2
      echo "Tests-First round that includes the updated plan." >&2
      exit 2
    fi
  fi
fi

[ -f Makefile ] || exit 0
# Never skip silently: a Makefile that make cannot run (for example a folder
# name with accents on Windows) must reach the agent.
if ! err=$(make -n verify 2>&1 >/dev/null); then
  echo "make cannot run 'verify' in this project: $(head -n1 <<<"$err")" >&2
  echo "Run 'bash .claude/hooks/doctor.sh' to see why, fix it, then finish." >&2
  exit 2
fi
if ! out=$(make --no-print-directory verify 2>&1); then
  echo "Not done yet: 'make verify' fails. Fix the problems below, then finish:" >&2
  echo "$out" | tail -n 60 >&2
  exit 2
fi
exit 0
