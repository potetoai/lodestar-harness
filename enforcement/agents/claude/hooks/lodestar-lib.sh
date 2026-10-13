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
# approve. A bullet other than the template's "- ..." and the
# "- Reviewed criteria:" line counts.
criteria_reviewed() {
  tr -d '\r' | sed -n '/^## Criteria review/,/^## /p' | sed '1d;/^## /d' |
    grep -E '^[[:space:]]*- ' | grep -qvE '^[[:space:]]*- (\.\.\.[[:space:]]*|Reviewed criteria:.*)$'
}

# Does a plan's criteria review (plan on stdin) cover the criteria with hash
# $1? The review names them in a "- Reviewed criteria: <hash>" line; criteria
# changed after that line was written are not covered.
review_covers() {
  [ -n "$1" ] && tr -d '\r' | sed -n '/^## Criteria review/,/^## /p' |
    grep -qE "^[[:space:]]*- Reviewed criteria:[[:space:]]*\`?$1\`?[[:space:]]*\$"
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

# The newest valid Tests-First commit, only while a plan it changed is still
# active. A round from a completed task is no baseline for the current one.
active_tests_first() {
  local c p
  c=$(last_valid_tests_first) || return 1
  while IFS= read -r p; do
    [[ $p == .ai/plans/active/*.md ]] && [ -f "$p" ] && { echo "$c"; return 0; }
  done < <(git diff-tree --root --no-commit-id --name-only -r "$c")
  return 1
}

# Is the test lock in force? Yes while the plan of the last valid Tests-First
# round is still active, or while a new lock is being written (uncommitted)
# for an active plan. A lock left over from a completed task has no effect.
lock_active() {
  if [ -n "$(git status --porcelain -- .ai/test-lock 2>/dev/null)" ] &&
     ls .ai/plans/active/*.md >/dev/null 2>&1; then
    return 0
  fi
  active_tests_first >/dev/null
}

# Files changed on this branch: uncommitted (untracked included) and committed
# since the merge base with origin/HEAD, else main, else master. Fails when
# no base is found.
branch_changed_files() {
  local b from=""
  for b in origin/HEAD main master; do
    from=$(git merge-base "$b" HEAD 2>/dev/null) && break
  done
  [ -n "$from" ] || return 1
  { git -c core.quotepath=off diff --name-only "$from"
    git -c core.quotepath=off ls-files --others --exclude-standard; } 2>/dev/null | sort -u
}

# Relock window: the owner approved changed criteria after the last valid
# Tests-First round, so the tester may rewrite locked tests until the new
# round is committed. Without a fresh owner approval it never opens: criteria
# already in the approvals log of that round (a copy of the approved plan,
# or a plan put back to an earlier approved version) do not count.
relock_window() {
  local c p now then log
  c=$(last_valid_tests_first) || return 1
  log=$(git show "$c:.ai/approvals.log" 2>/dev/null)
  for p in .ai/plans/active/*.md; do
    [ -f "$p" ] && plan_approved_now "$p" || continue
    now=$(criteria_hash < "$p"); then=$(git show "$c:$p" 2>/dev/null | criteria_hash)
    [ "$now" != "$then" ] && ! hash_approved "$now" <<<"$log" && return 0
  done
  return 1
}

# Append-only edit of the test lock (the hook's input JSON in $1): while the
# plan is approved, a later step may add its test paths. Every path already
# in the lock must still be there, unchanged, in the content after the edit.
# The plan: each active plan the last valid Tests-First round carried
# approved must still be approved; with no such plan (a first lock, not
# committed yet), any approved active plan. An Edit may only insert text
# (its new_string keeps the old_string at one end): the Edit tool does more
# than swap strings when it removes text. An edit whose result cannot be
# worked out, or that holds a control character, counts as a change.
lock_append_only() {
  local c p seen=0 ok=1 new old
  if c=$(last_valid_tests_first); then
    while IFS= read -r p; do
      [[ $p == .ai/plans/active/*.md ]] && [ -f "$p" ] && plan_approved_at "$c" "$p" || continue
      seen=1; plan_approved_now "$p" || return 1
    done < <(git diff-tree --root --no-commit-id --name-only -r "$c")
  fi
  if [ $seen = 0 ]; then
    for p in .ai/plans/active/*.md; do
      [ -f "$p" ] && plan_approved_now "$p" && { ok=0; break; }
    done
    [ $ok = 0 ] || return 1
  fi
  new=$(jq -r --rawfile cur .ai/test-lock '
    def cr: gsub("\r"; "");
    def swap($e):
      (($e.old_string // "") | cr) as $o | (($e.new_string // "") | cr) as $n
      | if ($o | length) == 0 then error("no old_string")
        elif (($n | startswith($o)) or ($n | endswith($o))) | not then error("not an insertion")
        else . end
      | (. / $o) as $parts
      | if ($parts | length) < 2 then error("old_string not found")
        elif $e.replace_all == true then $parts | join($n)
        elif ($parts | length) > 2 then error("old_string not unique")
        else $parts | join($n) end;
    .tool_input as $t
    | if .tool_name == "Write" and ($t.content | type) == "string" then $t.content
      elif .tool_name == "Edit" then ($cur | cr) | swap($t)
      elif .tool_name == "MultiEdit" and ($t.edits | type) == "array" and ($t.edits | length) > 0
        then reduce $t.edits[] as $e ($cur | cr; swap($e))
      else error("result not known") end
    | if any(explode[]; . < 32 and . != 9 and . != 10 and . != 13) then error("control character") else . end
    ' <<<"$1" 2>/dev/null) || return 1
  new=$(lock_paths <<<"$new")
  while IFS= read -r old; do
    grep -qxF -- "$old" <<<"$new" || return 1
  done < <(lock_paths < .ai/test-lock)
  return 0
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
