#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# Stop: do not let the agent finish while the checks fail, while commits
# exist only on this machine (push them; rules/git.md section 12), or while a
# reviewed plan lacks its "- Reviewed criteria:" line (agents/critic.md, Output).
# The checks are 'make verify-quick CHANGED="<files>"' when the project has
# that target (format, lint, types, the tests of the changed files: seconds,
# not minutes; CI runs everything on the PR), else 'make verify'. While CI
# cannot run (no GitHub Actions minutes: merge-pr.sh marks it, or
# --ci-off), every stop runs the full 'make verify' instead. Switches:
#   --ci-off [reason]  CI cannot run: stops run the full 'make verify'
#   --ci-on            CI runs again: back to verify-quick
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
export NO_COLOR=1 FORCE_COLOR=0  # plain text for the agent

# The CI-off mark lives in the shared git folder (all worktrees see it), never
# in a commit. Without git there is no mark: the full verify always runs.
ci_off= && cgd=$(git rev-parse --git-common-dir 2>/dev/null) && [ -n "$cgd" ] && cgd=$(cd "$cgd" && pwd) && ci_off=$cgd/lodestar-ci-off
case ${1:-} in
  --ci-off) [ -n "$ci_off" ] || { echo "verify-before-stop: not a git folder; nothing to mark." >&2; exit 1; }
    echo "${2:-marked by hand} ($(date +%Y-%m-%d))" > "$ci_off"
    echo "Lodestar: CI marked as unable to run; every stop now runs the full 'make verify'. Undo: --ci-on." >&2; exit 0 ;;
  --ci-on) [ -z "$ci_off" ] || rm -f "$ci_off"
    echo "Lodestar: CI marked as running; stops run 'make verify-quick' again (when the project has it)." >&2; exit 0 ;;
esac

# Hold once per state. When the files and the failure (digits ignored, so
# timings do not count) are the same as at the last hold, nothing was done
# since: let the stop end instead of sending the agent back again (for
# example while it waits for a tests-first tester). Any change holds again.
# Without git there is no memory and every failed stop holds. CI is the gate.
held=$(git rev-parse --absolute-git-dir 2>/dev/null) && held=$held/lodestar-verify-held
state() { # the working files (tracked and untracked, not ignored) as a tree, the failure
  # A copy of the index, so the real one is untouched. A commit does not change
  # the tree: verify, then commit, then stop does not run verify again.
  cp -p "${held%/*}/index" "$held.index" 2>/dev/null
  ( cd "$(git rev-parse --show-toplevel)" && export GIT_INDEX_FILE=$held.index &&
    git add -A . >/dev/null 2>&1 && git write-tree ) || echo "no tree $$ $RANDOM $(date +%s%N)"
  rm -f "$held.index"
  tr -d '0-9' <<<"$1"
}
# A pass is remembered as its tree: when nothing changed since 'make verify'
# last passed (for example the agent only answered a question), or only notes
# changed (see docs_only), do not run it again. The full run takes minutes in
# real projects.
passed=${held%held}passed
quick=${held:+${held%held}quick-passed}  # a pass of verify-quick: counts only in quick mode
# True when every file that differs between tree $1 and tree $2 is a note:
# .ai/ or docs/ at the project root, or a *.md file. Code cannot break on
# them; the edit hook formats each file, and CI still runs everything.
# Plain-text match (no regex: a folder name may hold [ or .), and -z so git
# does not quote accented names. No list (diff-tree failed): not docs only.
docs_only() {
  local pre f any=
  pre=$(git rev-parse --show-prefix 2>/dev/null) || return 1
  while IFS= read -r -d '' f; do
    any=1
    case $f in "$pre".ai/*|"$pre"docs/*|*.md) ;; *) return 1 ;; esac
  done < <(git diff-tree -r -z --name-only "$1" "$2" 2>/dev/null)
  [ -n "$any" ]
}
# Files whose failure was already let go once: later stops on them (the agent
# waiting for the owner, answering questions) do not run verify again only to
# get the same failure. Any change runs it again.
released=${held%held}released
# 'make verify' ends with this script --record-pass (top-level make only), so
# a run the agent made itself counts: the stop right after does not repeat it.
if [ "$1" = --record-pass ]; then
  [ -n "$held" ] && { rm -f "$held" "$released"; state "" > "$passed"; }
  exit 0
fi

# A prototype branch (proto/*) is thrown away, never pushed (the pre-push
# hook blocks it) or merged, so its work is not verified (workflows/prototype.md).
case $(git symbolic-ref --short -q HEAD 2>/dev/null) in proto/*) exit 0 ;; esac

# Prevent an endless loop: if the agent was already sent back once, let it
# stop. CI is the final gate.
input=$(cat)
[ "$(jq -j '.stop_hook_active // false' <<<"$input")" = "true" ] && exit 0

# Tests locked by the last VALID Tests-First commit (it carries an owner-
# approved plan) stay unchanged while the task is active (a plan in
# .ai/plans/active/), even if .ai/test-lock is removed. Reads git history, so
# it works without CI. A Tests-First trailer without an approved plan change
# cannot reset the lock. During a relock window (owner approved changed
# criteria) the tester may rewrite them; a test the owner approved to fix
# ("duyệt sửa test <path>") may change until the next round.
if ls .ai/plans/active/*.md >/dev/null 2>&1 && [ -f .claude/hooks/lodestar-lib.sh ] &&
   . .claude/hooks/lodestar-lib.sh && lock_active && ! relock_window && c=$(active_tests_first); then
  mapfile -t locked < <(git show "$c:.ai/test-lock" 2>/dev/null | lock_paths)
  if [ ${#locked[@]} -gt 0 ]; then
    touched=$(git diff --name-only "$c" -- "${locked[@]}" 2>/dev/null |
      while IFS= read -r t; do test_fix_window "$t" || echo "$t"; done)
    if [ -n "$touched" ]; then
      echo "Not done yet: tests locked by commit $(git log -1 --format='%h %s' "$c") were changed:" >&2
      echo "$touched" >&2
      echo "Undo those changes (git checkout $c -- <file>). If a test or criterion is wrong, ask the" >&2
      echo "owner to approve changed criteria (they reply \"approve\", or \"duyệt\"); then the tester commits a new" >&2
      echo "Tests-First round that includes the updated plan. A wrong test under right criteria: ask the" >&2
      echo "owner to type \"duyệt sửa test <path>\" (\"approve test fix <path>\"), and commit the fix in a new round." >&2
      exit 2
    fi
  fi
fi

# Commits that exist only on this machine are lost with it, and finished work
# waits for a push nobody asked for. Pushing one's own branch is always
# allowed, so send the agent back once per HEAD to push it. Reads only local
# refs (no network). No remote, or a detached HEAD: nothing to push to.
push_check() {
  local b n gd main
  b=$(git symbolic-ref --short -q HEAD 2>/dev/null) || return 0
  [ -n "$(git remote 2>/dev/null)" ] || return 0
  # Upstream deleted (PR merged with --delete-branch, squashed): nothing to push.
  [ "$(git for-each-ref --format='%(upstream:track)' "refs/heads/$b")" = "[gone]" ] && return 0
  n=$(git rev-list --count HEAD --not --remotes 2>/dev/null) || return 0
  [ "$n" -gt 0 ] 2>/dev/null || return 0
  gd=$(git rev-parse --absolute-git-dir) || return 0
  [ "$(cat "$gd/lodestar-push-held" 2>/dev/null)" = "$(git rev-parse HEAD)" ] && return 0
  git rev-parse HEAD > "$gd/lodestar-push-held"
  main=$(git symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null); main=${main#origin/}
  if [ "$b" = "${main:-main}" ] || [ "$b" = master ]; then
    echo "Not done yet: $n commit(s) on $b exist only on this machine, and $b takes changes only through a PR." >&2
    echo "Move them to a feature branch (git switch -c <name>), push it and open a PR." >&2
  else
    echo "Not done yet: $n commit(s) on $b exist only on this machine. Push the branch" >&2
    echo "(git push -u origin $b; pushing your own branch is always allowed, no need to ask)." >&2
    echo "If the work is finished and verified, open the PR, and merge it when lodestar rules/git.md section 12 allows." >&2
    echo "If you wait for the owner, push first, then wait. If these are not your commits" >&2
    echo "(the owner's own work), leave them and tell the owner." >&2
  fi
  return 2
}

# A plan the critic reviewed but whose review has no "- Reviewed criteria:"
# line for its criteria as they are now: the approval hook would refuse the
# owner's "duyệt", so they would type it twice. Send the agent back once per
# plan and criteria, so it adds the line (or re-runs the critic) before asking.
review_check() {
  local p h gd mark out="" new=""
  [ -f .claude/hooks/lodestar-lib.sh ] && . .claude/hooks/lodestar-lib.sh || return 0
  gd=$(git rev-parse --absolute-git-dir 2>/dev/null) && mark=$gd/lodestar-review-held
  for p in .ai/plans/active/*.md; do
    [ -f "$p" ] && h=$(criteria_hash < "$p") || continue
    [ -f .ai/approvals.log ] && hash_approved "$h" < .ai/approvals.log && continue
    criteria_reviewed < "$p" || continue
    review_covers "$h" < "$p" && continue
    [ -n "$mark" ] && grep -qxF "$p $h" "$mark" 2>/dev/null && continue
    out+="  $p (criteria hash $h)"$'\n'; new+="$p $h"$'\n'
  done
  [ -n "$out" ] && asks_approval || return 0
  # Only a hold uses up the plan's one hold for these criteria.
  [ -n "$mark" ] && printf '%s' "$new" >> "$mark"
  echo "Not done yet: these plans have a '## Criteria review' but no '- Reviewed criteria:' line for" >&2
  echo "their criteria as they are now, so the approval hook would refuse the owner's approval word:" >&2
  printf '%s' "$out" >&2
  echo "Before asking the owner to approve: if the last critic run covers these criteria, end the review" >&2
  echo "with '- Reviewed criteria: <hash>'; if the criteria changed after it, re-run the critic first" >&2
  echo "(lodestar-harness agents/critic.md, Output). Not asking for approval yet? Then just finish." >&2
  return 2
}

# Does the agent's last message ask the owner for an approval word? Asking for
# the next critic run ("duyệt critic") or a merge ("duyệt merge PR") is not
# one: after fixed findings only a new critic run can write the line, so a
# hold there costs a turn for nothing. Without the message, assume it does.
asks_approval() {
  local m
  m=$(jq -j '.last_assistant_message // empty' <<<"$input" 2>/dev/null)
  [ -n "$m" ] || return 0
  grep -oiE '(duyệt|duyet|approve)[[:alpha:]]*([^[:alnum:]]+[[:alnum:]-]+)?' <<<"$m" |
    grep -qviE '[^[:alnum:]](critic|merge)$'
}

# The checks every allowed stop runs; either one sends the agent back.
finish() {
  local r=0
  review_check || r=2
  push_check || r=2
  exit $r
}

[ -f Makefile ] || finish
# Right after a valid Tests-First commit, with nothing changed since, its
# tests fail by design until the builder step: do not run verify or hold.
# Any edit (the builder starting) makes the stop check verify again.
if [ -n "${c:-}" ] && [ "$c" = "$(git rev-parse HEAD 2>/dev/null)" ] &&
   [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  echo "Lodestar: HEAD is the Tests-First commit and nothing changed since; its tests are expected to fail before the builder step." >&2
  finish
fi
# Never skip silently: a Makefile that make cannot run (for example a folder
# name with accents on Windows) must reach the agent.
if ! err=$(make -n verify 2>&1 >/dev/null); then
  echo "make cannot run 'verify' in this project: $(head -n1 <<<"$err")" >&2
  echo "Run 'bash .claude/hooks/doctor.sh' to see why, fix it, then finish." >&2
  exit 2
fi
# Which check: verify-quick when the project has it and CI runs; the full
# verify without git (no changed-file list), or while CI is marked off.
target=verify
if [ -n "$ci_off" ] && [ -f "$ci_off" ]; then
  echo "Lodestar: CI is marked as unable to run ($(head -n1 "$ci_off")); this stop runs the full 'make verify'. When CI runs again: bash .claude/hooks/verify-before-stop.sh --ci-on" >&2
elif [ -n "$held" ] && make -n verify-quick >/dev/null 2>&1; then
  target=verify-quick
fi
# skip_passed FILE: true when FILE holds a pass for the files as they are now
# (or only notes changed since).
skip_passed() {
  local was now
  [ -f "$1" ] || return 1
  was=$(cat "$1"); now=$(state "")
  [ "$was" = "$now" ] || docs_only "$was" "$now" || return 1
  [ "$was" = "$now" ] || echo "Lodestar: only notes (.ai/, docs/, *.md) changed since 'make $target' passed; not run again (CI runs it)." >&2
}
# A full pass covers the quick check too; a quick pass never covers the full one.
if [ -n "$held" ]; then
  skip_passed "$passed" && finish
  [ $target = verify-quick ] && skip_passed "$quick" && finish
fi
if [ -n "$held" ] && [ -f "$released" ] && [ "$(cat "$released")" = "$(state "$target" | git hash-object --stdin)" ]; then
  echo "Lodestar: 'make $target' failed on these same files and the stop was let go; not run again until a file changes." >&2
  exit 0
fi
# changed_files: this project's files that differ from where the branch left
# the default branch, or are not committed, and still exist, space-separated
# and relative to the project (names with spaces split into words).
changed_files() {
  local main base
  main=$(git symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null) || main=origin/main
  base=$(git merge-base HEAD "$main" 2>/dev/null) || base=HEAD
  { git -c core.quotePath=false diff --relative --name-only "$base" -- 2>/dev/null
    git -c core.quotePath=false ls-files --others --exclude-standard 2>/dev/null; } |
    sort -u | while IFS= read -r f; do [ -f "$f" ] && printf '%s ' "$f"; done
}
if [ $target = verify-quick ]; then
  out=$(make --no-print-directory verify-quick CHANGED="$(changed_files)" 2>&1)
else
  out=$(make --no-print-directory verify 2>&1)
fi || {
  [ $target = verify ] && rm -f "${passed:-/nonexistent}"
  rm -f "${quick:-/nonexistent}"
  if [ -n "$held" ]; then
    now=$(state "$target $out" | git hash-object --stdin)
    if [ -n "$now" ] && [ "$(cat "$held" 2>/dev/null)" = "$now" ]; then
      echo "Lodestar: 'make $target' still fails, nothing changed since the last hold; stop allowed." >&2
      state "$target" | git hash-object --stdin > "$released"
      exit 0
    fi
    echo "$now" > "$held"; rm -f "$released"
  fi
  echo "Not done yet: 'make $target' fails. Fix the problems below, then finish:" >&2
  echo "$out" | tail -n 60 >&2
  exit 2
}
if [ -n "$held" ]; then
  rm -f "$held" "$released"
  if [ $target = verify ]; then state "" > "$passed"; else state "" > "$quick"; fi
fi
finish
