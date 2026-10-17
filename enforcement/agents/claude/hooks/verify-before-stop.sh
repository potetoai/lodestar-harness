#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# Stop: do not let the agent finish while `make verify` fails, or while
# commits exist only on this machine (push them; rules/git.md section 12).
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
export NO_COLOR=1 FORCE_COLOR=0  # plain text for the agent

# A prototype branch (proto/*) is thrown away, never pushed (guard-install
# blocks it) or merged, so its work is not verified (workflows/prototype.md).
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

[ -f Makefile ] || { push_check; exit; }
# Never skip silently: a Makefile that make cannot run (for example a folder
# name with accents on Windows) must reach the agent.
if ! err=$(make -n verify 2>&1 >/dev/null); then
  echo "make cannot run 'verify' in this project: $(head -n1 <<<"$err")" >&2
  echo "Run 'bash .claude/hooks/doctor.sh' to see why, fix it, then finish." >&2
  exit 2
fi
# Hold once per state. When the files and the failure (digits ignored, so
# timings do not count) are the same as at the last hold, nothing was done
# since: let the stop end instead of sending the agent back again (for
# example while it waits for a tests-first tester). Any change holds again.
# Without git there is no memory and every failed stop holds. CI is the gate.
held=$(git rev-parse --absolute-git-dir 2>/dev/null) && held=$held/lodestar-verify-held
state() { # HEAD, each changed or untracked file's content (not the index), the failure
  git rev-parse -q --verify HEAD
  ( cd "$(git rev-parse --show-toplevel)" || exit
    { git -c core.quotePath=false diff --name-only HEAD 2>/dev/null || git ls-files -c
      git -c core.quotePath=false ls-files -o --exclude-standard; } | sort -u > "$held.paths"
    while IFS= read -r f; do [ -f "$f" ] || echo "$f gone"; done < "$held.paths"
    while IFS= read -r f; do [ -f "$f" ] && echo "$f"; done < "$held.paths" > "$held.files"
    cat "$held.files"; git hash-object --stdin-paths < "$held.files" )
  rm -f "$held.paths" "$held.files"
  tr -d '0-9' <<<"$1"
}
# A pass is remembered the same way: when nothing changed since 'make verify'
# last passed (for example the agent only answered a question), do not run
# it again. The full run takes minutes in real projects.
passed=${held%held}passed
if [ -n "$held" ] && [ -f "$passed" ] && [ "$(cat "$passed")" = "$(state "" | git hash-object --stdin)" ]; then
  push_check; exit
fi
if ! out=$(make --no-print-directory verify 2>&1); then
  rm -f "${passed:-/nonexistent}"
  if [ -n "$held" ]; then
    now=$(state "$out" | git hash-object --stdin)
    if [ -n "$now" ] && [ "$(cat "$held" 2>/dev/null)" = "$now" ]; then
      echo "Lodestar: 'make verify' still fails, nothing changed since the last hold; stop allowed." >&2
      exit 0
    fi
    echo "$now" > "$held"
  fi
  echo "Not done yet: 'make verify' fails. Fix the problems below, then finish:" >&2
  echo "$out" | tail -n 60 >&2
  exit 2
fi
[ -n "$held" ] && { rm -f "$held"; state "" | git hash-object --stdin > "$passed"; }
push_check
