#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# Shared helpers, sourced by the other hooks and by ci-checks.sh.

# A plan's acceptance criteria (plan on stdin): each bullet under
# "## Acceptance criteria" with its continuation lines (the lines that follow
# it up to a blank line, and indented lines after a blank line), trimmed.
# Prose between the bullets is not a criterion. Checkbox marks are removed,
# so ticking a box off does not change the criteria.
criteria_lines() {
  tr -d '\r' | sed -n '/^## Acceptance criteria/,/^## /p' | awk '
    /^## /                        { item = 0; next }
    /^[[:space:]]*- /             { item = 1; blank = 0; print; next }
    /^[[:space:]]*$/              { blank = 1; next }
    item && (!blank || /^[[:space:]]/) { blank = 0; print; next }
                                  { item = 0 }' |
    sed -E 's/^[[:space:]]*-[[:space:]]*\[[ xX]\][[:space:]]*/- /; s/^[[:space:]]+//; s/[[:space:]]+$//' |
    grep -vE '^- \.\.\.$'
}

# Hash of a plan's acceptance criteria (plan on stdin); prints nothing when
# the plan has no criteria.
criteria_hash() {
  local lines
  lines=$(criteria_lines)
  [ -n "$lines" ] && printf '%s\n' "$lines" | git hash-object --stdin
}

# Does a plan (on stdin) have a filled "## Criteria review" section? The
# critic (lodestar-harness agents/critic.md) fills it before the owner is asked to
# approve. A bullet other than the template's "- ..." counts.
criteria_reviewed() {
  tr -d '\r' | sed -n '/^## Criteria review/,/^## /p' | sed '1d;/^## /d' |
    grep -E '^[[:space:]]*- ' | grep -qvE '^[[:space:]]*- \.\.\.[[:space:]]*$'
}

# Is this criteria hash approved in an approvals log (file content on stdin)?
hash_approved() { [ -n "$1" ] && tr -d '\r' | grep -qE "[[:space:]]$1\$"; }

# Is a plan file (path) approved right now, in the working tree?
plan_approved_now() {
  local h; h=$(criteria_hash < "$1") || return 1
  [ -f .ai/approvals.log ] && hash_approved "$h" < .ai/approvals.log
}

# Is the plan (path) approved as of commit $1, using that commit's files?
plan_approved_at() {
  local c=$1 p=$2 h
  h=$(git show "$c:$p" 2>/dev/null | criteria_hash) || return 1
  git show "$c:.ai/approvals.log" 2>/dev/null | hash_approved "$h"
}

# Test paths listed in a lock file (content on stdin); "#" lines are comments.
lock_paths() { tr -d '\r' | sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d'; }

# The newest valid Tests-First commit on this branch, if any.
last_valid_tests_first() {
  local c
  for c in $(git log --format=%H --grep='^Tests-First:' 2>/dev/null); do
    valid_tests_first "$c" && { echo "$c"; return 0; }
  done
  return 1
}

# Is the test lock in force? Yes while the plan of the last valid Tests-First
# round is still active, or while a new lock is being written (uncommitted)
# for an active plan. A lock left over from a completed task has no effect.
lock_active() {
  local c p
  if [ -n "$(git status --porcelain -- .ai/test-lock 2>/dev/null)" ] &&
     ls .ai/plans/active/*.md >/dev/null 2>&1; then
    return 0
  fi
  c=$(last_valid_tests_first) || return 1
  while IFS= read -r p; do
    [[ $p == .ai/plans/active/*.md ]] && [ -f "$p" ] && return 0
  done < <(git diff-tree --root --no-commit-id --name-only -r "$c")
  return 1
}

# Relock window: the owner approved changed criteria after the last valid
# Tests-First round, so the tester may rewrite locked tests until the new
# round is committed. Without a fresh owner approval it never opens.
relock_window() {
  local c p now then
  c=$(last_valid_tests_first) || return 1
  for p in .ai/plans/active/*.md; do
    [ -f "$p" ] && plan_approved_now "$p" || continue
    now=$(criteria_hash < "$p"); then=$(git show "$c:$p" 2>/dev/null | criteria_hash)
    [ "$now" != "$then" ] && return 0
  done
  return 1
}

# A valid Tests-First commit carries the trailer and changes a plan whose
# criteria are approved at that commit. Anything else cannot lock or relock.
valid_tests_first() {
  local c=$1 p
  git log -1 --format=%B "$c" | grep -q '^Tests-First:' || return 1
  while IFS= read -r p; do
    [[ $p == .ai/plans/*.md ]] && plan_approved_at "$c" "$p" && return 0
  done < <(git diff-tree --root --no-commit-id --name-only -r "$c")
  return 1
}
