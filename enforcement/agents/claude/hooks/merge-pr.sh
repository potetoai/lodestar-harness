#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# The only way an agent merges a PR (rules/git.md; guard-install.sh blocks
# every other merge command). Usage, from the project folder:
#   bash .claude/hooks/merge-pr.sh <n> [--squash|--rebase] [--delete-branch]
# It decides from state, never from command text:
# 1. The PR is open, in this repo (no GH_REPO), and its branch has no local
#    commit that was never pushed (the merge would leave it out, PR #36).
# 2. Owner-only merge: a PR that changes (or renames away) a file in
#    sensitive_paths, a locked test, or a safety file (hooks, CI, project
#    rules; under .claude/ all but .claude/docs/) needs the owner's typed
#    "duyệt merge PR <n>" for its current head (.ai/approvals.log, written by
#    approval-record.sh). Locked tests come from .ai/test-lock on GitHub (the
#    target branch's tip and the PR's base), never the local copy. A test the
#    PR adds, or a lock that only gains lines, is not owner-only.
# 3. Waits for CI (gh pr checks --watch); merges only when it exits 0.
# 4. Merges with --match-head-commit <the head checked above>, so GitHub
#    refuses a head pushed after the checks.
# After a merge it leaves a marker in the git folder; the global
# context-nudge.sh hook then asks for a fresh session (task done).
# Takes as long as CI: run it with a long timeout or in the background.
set -u
die() { printf 'merge-pr: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; exit 1; }
n=; method=--merge; del=
for a in "$@"; do
  case $a in
    --merge|--squash|--rebase) method=$a ;;
    -d|--delete-branch) del=--delete-branch ;;
    *) [ -z "$n" ] && [[ $a =~ ^#?[0-9]+$ ]] && n=${a#\#} || die "unknown argument '$a'." "Usage: bash .claude/hooks/merge-pr.sh <n> [--squash|--rebase] [--delete-branch]" ;;
  esac
done
[ -n "$n" ] || die "no PR number." "Usage: bash .claude/hooks/merge-pr.sh <n> [--squash|--rebase] [--delete-branch]"
command -v gh >/dev/null && command -v jq >/dev/null || die "gh and jq are required."
top=$(git rev-parse --show-toplevel 2>/dev/null) || die "run it inside the project's git folder."
proj=${CLAUDE_PROJECT_DIR:-$top}
[ -z "${GH_REPO:-}" ] || die "GH_REPO is set (another repo); this checks only the repo of this folder." "Unset it, or ask the owner to merge on GitHub."
cant="Check that gh works (gh auth status) and retry, or ask the owner to merge it."

# view: "<number> <branch> <head> <fork> <base branch> <base commit> <state>"
view() { gh pr view "$n" --json number,headRefName,headRefOid,isCrossRepository,baseRefName,baseRefOid,state \
  -q '"\(.number) \(.headRefName) \(.headRefOid) \(.isCrossRepository) \(.baseRefName) \(.baseRefOid) \(.state)"' 2>/dev/null | tr -d '\r'; }
read -r num h oid cross bname boid state <<<"$(view)"
[ "$num" = "$n" ] && [ -n "$boid" ] || die "gh could not read PR #$n." "$cant"
[ "$state" = OPEN ] || die "PR #$n is $state, not open."

# Local commits the PR's head lacks; compared with the head itself, else
# with origin's copy. A local branch that cannot be compared stops the merge.
left=0
if [ "$cross" != true ] && git show-ref --verify -q "refs/heads/$h"; then
  left=$(git rev-list --count "$oid..refs/heads/$h" 2>/dev/null || git rev-list --count "refs/remotes/origin/$h..refs/heads/$h" 2>/dev/null) ||
    die "cannot compare the local branch $h with the PR's head $oid." "Run git fetch, then this again."
fi
[ "${left:-0}" -gt 0 ] && die "branch $h has $left local commit(s) that were never pushed; the merge would leave them out." "Push the branch first (git push), then run this again."

# Every file, past gh pr view's 100, as "<change>\t<path>"; a rename's old
# path counts as removed, and no change type as changed. The lock is "grown"
# when gh shows it added, or modified with a diff where every line it removes
# (not a comment or blank) is added back unchanged.
raw=$(gh api --paginate "repos/{owner}/{repo}/pulls/$n/files?per_page=100" 2>/dev/null) || die "gh could not list the files of PR #$n." "$cant"
files=$(jq -r '.[] |
  (if (.filename | ascii_downcase) == ".ai/test-lock" and (.status == "added" or (.status == "modified" and (.patch // "") != "" and
      ((.patch | split("\n") | map(rtrimstr("\r"))) as $l | [$l[] | select(startswith("+")) | .[1:]] as $add |
       all($l[] | select(startswith("-")) | .[1:] | select(test("^\\s*(#|$)") | not); . as $r | any($add[]; . == $r)))))
   then "grown" elif (.status // "") == "" then "changed" else .status end) + "\t" + .filename,
  (.previous_filename // empty | "removed\t" + .)' <<<"$raw" 2>/dev/null | tr -d '\r')
[ -n "$files" ] || die "gh gave no files for PR #$n." "$cant"

# Owner-only patterns, lower case, without ./ and comments: the safety files,
# the project's sensitive_paths, and the locked tests.
norm() { tr -d "\"'\r" | sed -E -e '/^[[:space:]]*#/d' -e 's/[[:space:]]+#.*//; s/[[:space:]]+$//; s#^\./##' | tr '[:upper:]' '[:lower:]'; }
safe=$(printf '%s\n' .claude/ .codex/ .github/ enforcement/ .ai/project.md .ai/enforcement.json .ai/test-lock)
sens=$([ -f "$proj/.ai/project.md" ] && sed -n '/^sensitive_paths:/,/^[^[:space:]-]/p' "$proj/.ai/project.md" | sed -n 's/^[[:space:]]*-[[:space:]]*//p' | norm)
# Locked tests: .ai/test-lock on GitHub at the target branch's tip and at the
# PR's base commit. No lock (HTTP 404) is fine; any other read error stops.
lock=""
for ref in "$bname" "$boid"; do
  enc=$(jq -rn --arg r "$ref" '$r | @uri')
  if out=$(gh api "repos/{owner}/{repo}/contents/.ai/test-lock?ref=$enc" -H "Accept: application/vnd.github.raw" 2>&1); then lock+=$out$'\n'
  elif ! grep -q 'HTTP 404' <<<"$out"; then die "gh could not read .ai/test-lock at $ref." "$cant"
  fi
done
lockpats=$(norm <<<"$lock")
# covered PATH PATTERNS [CHANGE]: PATH (lower case) matches a pattern. A
# pattern with no glob also covers the folder of that name. With CHANGE
# (safety files only): .claude/docs/ is free of .claude/, and a lock that only
# gains lines ("grown") is free of .ai/test-lock.
covered() {
  local pat
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    if [ -n "${3:-}" ]; then
      [ "$pat" = .claude/ ] && [[ $1 == .claude/docs/* ]] && continue
      [ "$pat" = .ai/test-lock ] && [ "$3" = grown ] && continue
    fi
    case $pat in
      */) [[ $1 == "$pat"* ]] && return 0 ;;
      *[*?[]*) [[ $1 == $pat ]] && return 0 ;;
      *) [[ $1 == "$pat" || $1 == "$pat"/* ]] && return 0 ;;
    esac
  done <<<"$2"
  return 1
}
hit=""
while IFS=$'\t' read -r ch f; do
  [ -n "$f" ] || continue
  lf=${f,,}
  if covered "$lf" "$safe" "$ch" || covered "$lf" "$sens" || { [ "$ch" != added ] && covered "$lf" "$lockpats"; }; then hit=$f; break; fi
done <<<"$files"
if [ -n "$hit" ] && ! tr -d '\r' 2>/dev/null < "$proj/.ai/approvals.log" | grep -qE "[[:space:]]merge-pr[[:space:]]+$n[[:space:]]+$oid\$"; then
  die "PR #$n changes $hit (sensitive code, a locked test or a safety file), so only the owner approves its merge." \
    "Tell the owner what the PR changes and how it was checked, then ask them to type \"duyệt merge PR $n\" (or \"approve merge PR $n\"). A new push needs a new approval."
fi

# CI: right after a push GitHub may not list the checks yet; ask again.
echo "merge-pr: waiting for CI on PR #$n ($oid)..."
for try in 1 2 3 4 5 6; do
  out=$(gh pr checks "$n" --watch --interval 15 2>&1); rc=$?
  grep -qi 'no checks reported' <<<"$out" || break
  [ $try = 6 ] || sleep "${LODESTAR_CHECKS_RETRY:-10}"
done
[ $rc = 0 ] || die "CI is not green on PR #$n (gh pr checks exit $rc); not merged." "$(tail -n 15 <<<"$out")"
# A push while CI ran: the checks above were for another head.
read -r _ _ now _ <<<"$(view)"
[ "$now" = "$oid" ] || die "PR #$n got a new push while CI ran ($oid -> ${now:-unreadable}); not merged." "Run this again${hit:+; the owner must approve the new head}."
gh pr merge "$n" "$method" $del --match-head-commit "$oid" || die "gh pr merge failed for PR #$n."
gd=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd) && echo "PR $n merged" > "$gd/lodestar-task-done"
echo "merge-pr: PR #$n merged at $oid."
