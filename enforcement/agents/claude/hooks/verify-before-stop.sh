#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# Stop: do not let the agent finish while `make verify` fails, while commits
# exist only on this machine (push them; rules/git.md section 12), or while a
# reviewed plan lacks its "- Reviewed criteria:" line (agents/critic.md, Output).
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
export NO_COLOR=1 FORCE_COLOR=0  # plain text for the agent

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
# A pass is remembered the same way: when nothing changed since 'make verify'
# last passed (for example the agent only answered a question), do not run
# it again. The full run takes minutes in real projects.
passed=${held%held}passed
# Files whose failure was already let go once: later stops on them (the agent
# waiting for the owner, answering questions) do not run verify again only to
# get the same failure. Any change runs it again.
released=${held%held}released
# 'make verify' ends with this script --record-pass (top-level make only), so
# a run the agent made itself counts: the stop right after does not repeat it.
if [ "$1" = --record-pass ]; then
  [ -n "$held" ] && { rm -f "$held" "$released"; state "" | git hash-object --stdin > "$passed"; }
  exit 0
fi

# A prototype branch (proto/*) is thrown away, never pushed (the pre-push
# hook blocks it) or merged, so its work is not verified (workflows/prototype.md).
case $(git symbolic-ref --short -q HEAD 2>/dev/null) in proto/*) exit 0 ;; esac

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
   . .claude/hooks/lodestar-lib.sh && lock_active && ! relock_window && c=$(active_tests_first); then
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
  local p h gd mark out=""
  [ -f .claude/hooks/lodestar-lib.sh ] && . .claude/hooks/lodestar-lib.sh || return 0
  gd=$(git rev-parse --absolute-git-dir 2>/dev/null) && mark=$gd/lodestar-review-held
  for p in .ai/plans/active/*.md; do
    [ -f "$p" ] && h=$(criteria_hash < "$p") || continue
    [ -f .ai/approvals.log ] && hash_approved "$h" < .ai/approvals.log && continue
    criteria_reviewed < "$p" || continue
    review_covers "$h" < "$p" && continue
    [ -n "$mark" ] && grep -qxF "$p $h" "$mark" 2>/dev/null && continue
    [ -n "$mark" ] && echo "$p $h" >> "$mark"
    out+="  $p (criteria hash $h)"$'\n'
  done
  [ -n "$out" ] || return 0
  echo "Not done yet: these plans have a '## Criteria review' but no '- Reviewed criteria:' line for" >&2
  echo "their criteria as they are now, so the approval hook would refuse the owner's approval word:" >&2
  printf '%s' "$out" >&2
  echo "Before asking the owner to approve: if the last critic run covers these criteria, end the review" >&2
  echo "with '- Reviewed criteria: <hash>'; if the criteria changed after it, re-run the critic first" >&2
  echo "(lodestar-harness agents/critic.md, Output). Not asking for approval yet? Then just finish." >&2
  return 2
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
if [ -n "$held" ] && [ -f "$passed" ] && [ "$(cat "$passed")" = "$(state "" | git hash-object --stdin)" ]; then
  finish
fi
if [ -n "$held" ] && [ -f "$released" ] && [ "$(cat "$released")" = "$(state "" | git hash-object --stdin)" ]; then
  echo "Lodestar: 'make verify' failed on these same files and the stop was let go; not run again until a file changes." >&2
  exit 0
fi
if ! out=$(make --no-print-directory verify 2>&1); then
  rm -f "${passed:-/nonexistent}"
  if [ -n "$held" ]; then
    now=$(state "$out" | git hash-object --stdin)
    if [ -n "$now" ] && [ "$(cat "$held" 2>/dev/null)" = "$now" ]; then
      echo "Lodestar: 'make verify' still fails, nothing changed since the last hold; stop allowed." >&2
      state "" | git hash-object --stdin > "$released"
      exit 0
    fi
    echo "$now" > "$held"
  fi
  echo "Not done yet: 'make verify' fails. Fix the problems below, then finish:" >&2
  echo "$out" | tail -n 60 >&2
  exit 2
fi
[ -n "$held" ] && { rm -f "$held" "$released"; state "" | git hash-object --stdin > "$passed"; }
finish
