#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# The only way an agent merges a PR (rules/git.md; guard-install.sh blocks
# every other merge command). Usage, from the project folder:
#   bash .claude/hooks/merge-pr.sh <n> [--squash|--rebase] [--delete-branch]
# It decides from state, never from command text:
# 1. The PR is open, in this repo (no GH_REPO), and its branch has no local
#    commit that was never pushed (the merge would leave it out, PR #36).
#    Its text has the route line and, for BUILD_REVIEW and up, the review
#    line (CI checks more; this still holds when CI cannot run).
# 2. Owner-only merge: a PR that changes (or renames away) a file in
#    sensitive_paths, a locked test, or a safety file (hooks, CI, project
#    rules; under .claude/ all but .claude/docs/) needs the owner's typed
#    "duyệt merge PR <n>" for its current head (.ai/approvals.log, written by
#    approval-record.sh). Locked tests come from .ai/test-lock on GitHub (the
#    target branch's tip and the PR's base), never the local copy. A test the
#    PR adds, or a lock that only gains lines, is not owner-only.
# 3. Waits for CI (gh pr checks --watch); merges only when it exits 0. When
#    GitHub did not start the jobs (no Actions minutes, billing), it marks CI
#    off, so every Stop runs the full 'make verify'; a green CI clears it.
# 4. Merges with --match-head-commit <the head checked above>, so GitHub
#    refuses a head pushed after the checks.
# 5. With --delete-branch, the approval lines not yet committed are set
#    aside so gh can switch to the base branch, then put back. If gh fails
#    after GitHub merged the PR, it says so and how to finish by hand.
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

# review_problem BODY COMMITS: why the last 'Lodestar review:' line does not
# count, or nothing; "none" when there is no line. Same rule as ci-checks.sh.
review_problem() {
  local line v tok c
  line=$(grep -E '^Lodestar review: ' <<<"$1" | tail -n1)
  [ -n "$line" ] || { echo none; return; }
  v=$(tr '[:upper:]' '[:lower:]' <<<"${line#Lodestar review: }")
  [[ $v =~ ^(approve|approved|pass|passed)([^a-z]|$) ]] ||
    { echo "The 'Lodestar review:' line must start with the verdict 'approve' or 'pass' (the review passed, after its findings were fixed). A review with open findings is not a pass: fix them and review again."; return; }
  for tok in $(tr -c '0-9a-z' '\n' <<<"$v" | grep -xE '[0-9a-f]{7,64}'); do
    for c in $2; do [[ $c == "$tok"* ]] && return; done
  done
  echo "The 'Lodestar review:' line names no commit of this PR. Name the commit the reviewer read (git rev-parse --short HEAD at review time), e.g. 'Lodestar review: pass, reviewer subagent, 1a2b3c4'. After a rebase or amend the old id is gone: review the new head."
}

# Route and review lines, as ci-checks.sh reads them (the last route line
# counts). PRs opened by bots are skipped, as in CI. First line: the author
# and the PR's commits (gh lists the first 100); then the text.
pb=$(gh pr view "$n" --json author,body,commits -q '([.author.login] + [.commits[]?.oid] | join(" ")) + "\n" + (.body // "")' 2>/dev/null) || die "gh could not read the text of PR #$n." "$cant"
pb=$(tr -d '\r' <<<"$pb"); l1=${pb%%$'\n'*}; who=${l1%% *}; commits=${l1#"$who"}
if ! [[ $who == *'[bot]' || $who == app/* ]]; then
  rl=$(grep -E '^Lodestar route: ' <<<"$pb" | tail -n1)
  fix="Fix the PR text with 'gh pr edit $n --body-file <file>', then run this again."
  [[ $rl =~ ^Lodestar\ route:\ (SIMPLE|BUILD_REVIEW|INDEPENDENT_COMPARE|COMPLEX|PROTOTYPE|ONBOARDING|MAINTENANCE)\ risk=(low|medium|high|critical)(\ escalated-from=[A-Z_]+)?[[:space:]]*$ ]] ||
    die "PR #$n has no route line 'Lodestar route: <WORKFLOW> risk=<level>' (router/ROUTER.md); not merged." "$fix"
  case ${BASH_REMATCH[1]} in BUILD_REVIEW|INDEPENDENT_COMPARE|COMPLEX)
    wf=${BASH_REMATCH[1]}; rp=$(review_problem "$pb" "$commits")
    [ "$rp" != none ] || die "PR #$n is $wf but has no line 'Lodestar review: <verdict>, <who>, <commit>'; not merged." "Run the independent review (workflows/build-review.md), fix its findings, add the line. $fix"
    [ -z "$rp" ] || die "PR #$n is $wf, but its review line does not count; not merged. $rp" "$fix" ;;
  esac
fi

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
    "Tell the owner what the PR changes and how it was checked, then ask them to type \"approve merge PR $n\" (\"duyệt merge PR $n\" when owner_language is vi). A new push needs a new approval."
fi

# CI: right after a push GitHub may not list the checks yet; ask again.
echo "merge-pr: waiting for CI on PR #$n ($oid)..."
for try in 1 2 3 4 5 6; do
  out=$(gh pr checks "$n" --watch --interval 15 2>&1); rc=$?
  grep -qi 'no checks reported' <<<"$out" || break
  [ $try = 6 ] || sleep "${LODESTAR_CHECKS_RETRY:-10}"
done
# CI-off mark (verify-before-stop.sh): while GitHub refuses to start the jobs
# (no Actions minutes, spending limit, billing), every Stop runs the full
# 'make verify'; a green CI clears it. GitHub says why in the failed check
# runs' annotations.
mark=$(git rev-parse --git-common-dir 2>/dev/null) && mark=$(cd "$mark" && pwd)/lodestar-ci-off || mark=
not_started() {
  local id
  for id in $(gh api "repos/{owner}/{repo}/commits/$oid/check-runs" \
      -q '.check_runs[] | select(.conclusion == "failure" or .conclusion == "startup_failure") | .id' 2>/dev/null | tr -d '\r'); do
    gh api "repos/{owner}/{repo}/check-runs/$id/annotations" -q '.[].message' 2>/dev/null
  done | grep -qi 'The job was not started because'  # GitHub's own words; a test named billing is no match
}
if [ $rc = 0 ]; then
  [ -n "$mark" ] && [ -f "$mark" ] && rm -f "$mark" && echo "merge-pr: CI ran again; the Stop hook is back to its quick check."
elif [ -n "$mark" ] && not_started; then
  echo "GitHub did not start CI on PR #$n, Actions minutes or billing ($(date +%Y-%m-%d))" > "$mark"
  echo "merge-pr: GitHub did not start CI (no Actions minutes or a billing limit). Until CI runs again, every stop runs the full 'make verify'." >&2
fi
[ $rc = 0 ] || die "CI is not green on PR #$n (gh pr checks exit $rc); not merged." "$(tail -n 15 <<<"$out")
If CI could not run at all (for example no Actions minutes left), run on the PR's branch:
  make verify && PR_NUMBER=$n GITHUB_REPOSITORY=<owner>/<repo> bash .claude/hooks/ci-checks.sh origin/$bname
Tell the owner both results; only the owner merges it, by hand on GitHub."
# A push while CI ran: the checks above were for another head.
read -r _ _ now _ <<<"$(view)"
[ "$now" = "$oid" ] || die "PR #$n got a new push while CI ran ($oid -> ${now:-unreadable}); not merged." "Run this again${hit:+; the owner must approve the new head}."
# --delete-branch makes gh switch this folder to the base branch after the
# merge; git refuses while .ai/approvals.log has the approval lines the hook
# added (App01 PR #147). Set the log aside, then append its uncommitted
# lines that the (new) branch's copy lacks; on a failure the copy stays.
lg=$top/.ai/approvals.log; saved=
carry_back() {
  [ -n "$saved" ] || return 0
  local add
  add=$(grep -vxFf <(tr -d '\r' 2>/dev/null < "$lg") <<<"$extra" | grep .)  # 2> first: the log may be missing
  if mkdir -p "${lg%/*}" && touch "$lg" && { [ ! -s "$lg" ] || [ -z "$(tail -c1 "$lg")" ] || echo >> "$lg"; } &&
    { [ -z "$add" ] || printf '%s\n' "$add" >> "$lg"; }
  then rm -f "$saved"
  else printf 'merge-pr: could not put back .ai/approvals.log; its copy is %s\n' "$saved" >&2
  fi
  saved=
}
if [ -n "$del" ] && [ -f "$lg" ] && [ -n "$(git -C "$top" status --porcelain -- .ai/approvals.log 2>/dev/null)" ]; then
  saved=$(mktemp) && cp "$lg" "$saved" || die "cannot copy .ai/approvals.log aside; not merged."
  extra=$(tr -d '\r' < "$lg" | grep -vxFf <(git -C "$top" show HEAD:.ai/approvals.log 2>/dev/null | tr -d '\r'))
  trap carry_back EXIT
  if git -C "$top" ls-files --error-unmatch .ai/approvals.log >/dev/null 2>&1; then git -C "$top" checkout -q HEAD -- .ai/approvals.log; else rm -f "$lg"; fi
fi
if ! gh pr merge "$n" "$method" $del --match-head-commit "$oid"; then
  carry_back
  read -r _ _ _ _ _ _ now <<<"$(view)"
  [ "$now" = MERGED ] || die "gh pr merge failed for PR #$n."
  printf 'merge-pr: PR #%s is merged on GitHub, but gh could not finish here (see above).\n%s\n' "$n" \
    "Finish by hand: commit or stash other changes, git switch $bname, git pull, git branch -D $h${del:+, git push origin --delete $h}." >&2
fi
carry_back
gd=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd) && echo "PR $n merged" > "$gd/lodestar-task-done"
echo "merge-pr: PR #$n merged at $oid."
