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

# Critic runs of a plan (plan on stdin): the "- Run <n> (full|narrowed, ...)"
# lines under "## Criteria review" (lodestar-harness agents/critic.md, Output).
critic_runs() {
  tr -d '\r' | sed -n '/^## Criteria review/,/^## /p' |
    grep -cE '^[[:space:]]*- Run [0-9]+ \((full|narrowed)' || true
}

# Critic runs a plan (path) may have: 3, plus one for each owner approval of
# its criteria (a change during the build) and each "duyệt critic" the owner
# typed for it (approval-record.sh), both in .ai/approvals.log. A "duyệt
# critic" line also holds the run count when it was typed, so it always
# allows the next run, even for a plan with more past runs than its limit.
critic_limit() {
  local n=3
  [ -f .ai/approvals.log ] && n=$(tr -d '\r' < .ai/approvals.log | awk -v p="$1" '
    $3 == p || ($3 == "critic-run" && $4 == p) { n++ }
    $3 == "critic-run" && $4 == p && $5 ~ /^[0-9]+$/ && $5 + 1 > next1 { next1 = $5 + 1 }
    END { n += 3; print (next1 > n ? next1 : n) }')
  echo "$n"
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

# The lock baseline: the newest valid Tests-First commit (up to revision $1,
# default HEAD), while some valid round changed a plan still active. Rounds
# of completed tasks only are no baseline for the current one, but closing
# one plan does not unlock another active plan's round. The newest round is
# the baseline even when its plan is closed: it is owner-approved, so the
# tests it rewrote are not edits.
active_tests_first() {
  local c p newest=""
  for c in $(git log --format=%H --grep='^Tests-First:' "${1:-HEAD}" -- 2>/dev/null); do
    valid_tests_first "$c" || continue
    newest=${newest:-$c}
    while IFS= read -r p; do
      [[ $p == .ai/plans/active/*.md ]] && [ -f "$p" ] && { echo "$newest"; return 0; }
    done < <(git diff-tree --root --no-commit-id --name-only -r "$c")
  done
  return 1
}

# Is the test lock in force? Yes while a plan of a valid Tests-First round is
# still active, or while a new lock is being written (uncommitted) for an
# active plan. A lock left over from completed tasks only has no effect.
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

# Test-fix window for one locked test (path $1): the owner typed "duyệt sửa
# test <path>" (approval-record.sh wrote "<when> test-fix <path>") after the
# last valid Tests-First round. The criteria stay as approved; only that test
# opens, until the tester commits the fix in a new round. A line already in
# that round's approvals log is used up.
test_fix_window() {
  local c log
  [ -f .ai/approvals.log ] && c=$(last_valid_tests_first) || return 1
  log=$(git show "$c:.ai/approvals.log" 2>/dev/null | tr -d '\r')
  new_test_fixes "$log" < .ai/approvals.log | grep -qixF -- "$1"
}

# Paths of the test-fix lines in an approvals log (stdin) that the log text
# $1 does not hold. A path may hold spaces: it is the rest of the line.
new_test_fixes() {
  tr -d '\r' | grep -vxFf <(printf '%s\n' "$1") |
    awk '$3 == "test-fix" { print substr($0, index($0, " test-fix ") + 10) }'
}

# Locked tests the owner approved to fix (one path per line) in round $1 since
# round $2: test-fix lines in $1's approvals log that $2's log did not hold.
fresh_test_fixes() {
  git show "$1:.ai/approvals.log" 2>/dev/null |
    new_test_fixes "$(git show "$2:.ai/approvals.log" 2>/dev/null | tr -d '\r')"
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

# owner_only_parse: read the owner_only_paths key of a .ai/project.md (on
# stdin). First line "<state>\t<count>\t<why>": state absent (no key at
# column 0), ok (valid: `[]`, or the bare key with items) or bad (with why);
# count is the item lines seen. Then the valid items, lower case, without
# quotes, ./ or comments. Fences do not hide a key (merge-pr.sh reads lists
# the same way). The list ends at the first other line at column 0.
owner_only_parse() {
  tr -d '\r' | awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function no(w) { if (why == "") why = w }
    /^owner_only_paths:/ {
      keys++; if (keys > 1) no("the key appears twice")
      v = substr($0, 18); sub(/[ \t]+#.*/, "", v); v = trim(v)
      if (v == "[]") { inl = 1; empty = 1; gap = 0 }
      else if (v == "") { inl = 1; empty = 0; gap = 0 }
      else { inl = 0; no("the key line holds \"" v "\", not [] or a list") }
      next }
    inl && /^[ \t]*-/ {
      n++; if (empty) no("items follow []"); if (gap) no("a blank or column-0 comment line splits the list")
      it = $0; sub(/^[ \t]*-/, "", it); it = trim(it)
      if (it ~ /^#/) it = ""; sub(/[ \t]+#.*/, "", it); gsub(/["\047]/, "", it); it = trim(it); sub(/^\.\//, "", it)
      if (it == "") no("item " n " is empty")
      else if (it ~ /^[[\/]/) no("item " n " starts with [ or /")
      else if (index(it, "\\")) no("item " n " holds a backslash")
      else items = items tolower(it) "\n"
      next }
    inl && /^[ \t]*$/ { gap = 1; next }
    inl && /^#/ { gap = 1; next }
    inl && /^[ \t]+#/ { next }
    inl && /^[ \t]/ { no("line " NR " in the list is not an item"); next }
    inl { inl = 0 }
    END {
      if (!keys) { print "absent\t0\t"; exit }
      if (why == "" && !empty && n == 0) no("the key has no items")
      printf "%s\t%d\t%s\n%s", (why == "" ? "ok" : "bad"), n, why, items }'
}

# path_matches PATH PATTERN (both lower case): as sensitive_paths in
# merge-pr.sh. A pattern ending in / covers that folder; one with a glob
# matches the whole path; any other covers the file or the folder of that name.
path_matches() {
  case $2 in
    */) [[ $1 == "$2"* ]] ;;
    *[*?[]*) [[ $1 == $2 ]] ;;
    *) [[ $1 == "$2" || $1 == "$2"/* ]] ;;
  esac
}

# PR text rules (router/ROUTER.md), one copy for ci-checks.sh, merge-pr.sh
# and the guard that checks `gh pr create` and `gh pr edit` (guard-install.sh).
# route_line BODY: "WORKFLOW risk" of the last 'Lodestar route:' line, or
# nothing when that line is missing or malformed.
route_line() {
  local l
  l=$(tr -d '\r' <<<"$1" | grep -E '^Lodestar route: ' | tail -n1)
  [[ $l =~ ^Lodestar\ route:\ (SIMPLE|BUILD_REVIEW|INDEPENDENT_COMPARE|COMPLEX|PROTOTYPE|ONBOARDING|MAINTENANCE)\ risk=(low|medium|high|critical)(\ escalated-from=[A-Z_]+)?[[:space:]]*$ ]] &&
    echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
}

# review_problem BODY COMMITS: why the last 'Lodestar review:' line does not
# count, or nothing; "none" when there is no line. It counts when it starts
# with a pass verdict and names a commit of this PR (a hex id of 7 to 64,
# matched as a prefix). COMMITS "?" (unknown) skips the commit match.
review_problem() {
  local line v tok c
  line=$(tr -d '\r' <<<"$1" | grep -E '^Lodestar review: ' | tail -n1)
  [ -n "$line" ] || { echo none; return; }
  v=$(tr '[:upper:]' '[:lower:]' <<<"${line#Lodestar review: }")
  [[ $v =~ ^(approve|approved|pass|passed)([^a-z]|$) ]] ||
    { echo "The 'Lodestar review:' line must start with the verdict 'approve' or 'pass' (the review passed, after its findings were fixed). A review with open findings is not a pass: fix them and review again."; return; }
  [ "$2" = "?" ] && return
  for tok in $(tr -c '0-9a-z' '\n' <<<"$v" | grep -xE '[0-9a-f]{7,64}'); do
    for c in $2; do [[ $c == "$tok"* ]] && return; done
  done
  echo "The 'Lodestar review:' line names no commit of this PR. Name the commit the reviewer read (git rev-parse --short HEAD at review time), e.g. 'Lodestar review: pass, reviewer subagent, 1a2b3c4'. After a rebase or amend the old id is gone: review the new head."
}

# route_problem BODY COMMITS CHANGED: why the PR text fails the route rules,
# or nothing when it passes. COMMITS: the PR's commit ids; CHANGED: its
# changed files, one per line. COMMITS "?" (unknown) skips the commit match
# and the file count.
route_problem() {
  local rl wf risk n rp why
  rl=$(route_line "$1")
  if [ -z "$rl" ]; then
    rl=$(tr -d '\r' <<<"$1" | grep -m1 'Lodestar route:')
    [ -n "$rl" ] && echo "The PR text has no valid route line: '$rl' must be exactly 'Lodestar route: <WORKFLOW> risk=<level>', plain text on its own line, nothing after the level (router/ROUTER.md)." ||
      echo "The PR text has no route line. Add one line, plain text: 'Lodestar route: <WORKFLOW> risk=<level>' (router/ROUTER.md)."
    return
  fi
  wf=${rl% *}; risk=${rl#* }
  rp=$(review_problem "$1" "$2")
  why=$rp; [ "$rp" = none ] && why="Add a line: 'Lodestar review: <verdict>, <who>, <commit>'."
  # Bookkeeping under .ai/ (approvals, plans) is not part of the change; for
  # MAINTENANCE and ONBOARDING neither are the files Lodestar manages.
  case $wf in
    MAINTENANCE|ONBOARDING) n=$(grep -cvE '^(\.ai/|\.claude/|\.codex/|\.github/|$)' <<<"$3") ;;
    *) n=$(grep -cvE '^(\.ai/|$)' <<<"$3") ;;
  esac
  [ "$2" = "?" ] && n=0
  case $wf in
    SIMPLE|PROTOTYPE|MAINTENANCE|ONBOARDING)
      if [[ $wf == SIMPLE || $wf == PROTOTYPE ]] && [[ $risk == high || $risk == critical ]]; then
        echo "$wf with risk=$risk: high risk needs at least BUILD_REVIEW (router/ROUTER.md, rule 16)."
      elif [ "$n" -ge 3 ] && [ $wf = SIMPLE ]; then
        echo "SIMPLE, but $n files changed (outside .ai/): 3 or more need at least BUILD_REVIEW with a review (router/ROUTER.md, SIMPLE). A 'Lodestar review:' line does not make SIMPLE pass; change the route line."
      elif [ "$n" -ge 3 ] && [ -n "$rp" ]; then
        echo "$wf, but $n files changed (outside .ai/ and, for MAINTENANCE and ONBOARDING, Lodestar's own files): 3 or more need a review. $why"
      fi ;;
    *) [ -z "$rp" ] || echo "$wf needs an independent review (workflows/build-review.md). Fix its findings. $why" ;;
  esac
}
