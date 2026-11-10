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
#    Owner-only paths (opt-in): a project whose .ai/project.md on GitHub
#    declares owner_only_paths validly, at the target tip and at the PR's
#    base, keeps the owner's approval for those paths, safety files and locked
#    tests; other sensitive_paths code merges without the owner when every
#    condition in no_owner_problems holds (rules/enforcement.md).
#    The review line is agent text: this checks it names the head, not that
#    the reviewer was independent or right.
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
. "$(dirname "$0")/lodestar-lib.sh" || die "lodestar-lib.sh is missing next to merge-pr.sh." "Run bootstrap.sh --upgrade."

# view: "<number> <branch> <head> <fork> <base branch> <base commit> <state>"
view() { gh pr view "$n" --json number,headRefName,headRefOid,isCrossRepository,baseRefName,baseRefOid,state \
  -q '"\(.number) \(.headRefName) \(.headRefOid) \(.isCrossRepository) \(.baseRefName) \(.baseRefOid) \(.state)"' 2>/dev/null | tr -d '\r'; }
read -r num h oid cross bname boid state <<<"$(view)"
[ "$num" = "$n" ] && [ -n "$boid" ] || die "gh could not read PR #$n." "$cant"
[ "$state" = OPEN ] || die "PR #$n is $state, not open."

# Route and review lines, as ci-checks.sh reads them (route_line and
# review_problem in lodestar-lib.sh; the last line counts). PRs opened by
# bots are skipped, as in CI. First line: the author and the PR's commits
# (gh lists the first 100); then the text.
pb=$(gh pr view "$n" --json author,body,commits -q '([.author.login] + [.commits[]?.oid] | join(" ")) + "\n" + (.body // "")' 2>/dev/null) || die "gh could not read the text of PR #$n." "$cant"
pb=$(tr -d '\r' <<<"$pb"); l1=${pb%%$'\n'*}; who=${l1%% *}; commits=${l1#"$who"}
rl=$(grep -E '^Lodestar route: ' <<<"$pb" | tail -n1); rv=$(grep -E '^Lodestar review: ' <<<"$pb" | tail -n1)
rt=$(route_line "$pb")
bot=; [[ $who == *'[bot]' || $who == app/* ]] && bot=1
if [ -z "$bot" ]; then
  fix="Fix the PR text with 'gh pr edit $n --body-file <file>', then run this again."
  [ -n "$rt" ] ||
    die "PR #$n has no route line 'Lodestar route: <WORKFLOW> risk=<level>' (router/ROUTER.md); not merged." "$fix"
  case ${rt% *} in BUILD_REVIEW|INDEPENDENT_COMPARE|COMPLEX)
    wf=${rt% *}; rp=$(review_problem "$pb" "$commits")
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

gherr=$(mktemp) || die "cannot make a temp file."; trap 'rm -f "$gherr"' EXIT
# ghf PATH REF: the file at REF on GitHub into $got; status 1 when it does not
# exist there (HTTP 404). Any other read error stops the merge.
ghf() {
  local enc p
  enc=$(jq -rn --arg r "$2" '$r | @uri'); p=$(jq -rn --arg p "$1" '$p | split("/") | map(@uri) | join("/")')
  if got=$(gh api "repos/{owner}/{repo}/contents/$p?ref=$enc" -H "Accept: application/vnd.github.raw" 2>"$gherr"); then return 0; fi
  got=; grep -q 'HTTP 404' "$gherr" && return 1
  die "gh could not read $1 at $2; not merged." "$cant"
}
# Patterns, lower case, without ./ and comments.
norm() { tr -d "\"'\r" | sed -E -e '/^[[:space:]]*#/d' -e 's/[[:space:]]+#.*//; s/[[:space:]]+$//; s#^\./##' | tr '[:upper:]' '[:lower:]'; }
sens_of() { sed -n '/^sensitive_paths:/,/^[^[:space:]-]/p' | sed -n 's/^[[:space:]]*-[[:space:]]*//p' | norm; }
# .ai/project.md on GitHub at the target tip and the PR's base (none: HTTP
# 404). sensitive_paths: both copies plus the local file (a path listed only
# locally still counts). owner_only_paths: on only when both copies declare it
# validly; its items are those of either copy.
ghf .ai/project.md "$bname"; ptip=$got
ghf .ai/project.md "$boid"; pbase=$got
otip=$(owner_only_parse <<<"$ptip"); obase=$(owner_only_parse <<<"$pbase")
IFS=$'\t' read -r st_tip n_tip why_tip <<<"${otip%%$'\n'*}"
IFS=$'\t' read -r st_base n_base why_base <<<"${obase%%$'\n'*}"
optin=; [ "$st_tip" = ok ] && [ "$st_base" = ok ] && optin=1
counts="owner_only_paths items: target tip ($bname) $n_tip, base ($boid) $n_base"
mapfile -t own_a < <({ tail -n +2 <<<"$otip"; tail -n +2 <<<"$obase"; } | sed '/^$/d' | sort -u)
mapfile -t sens_a < <({ sens_of <<<"$ptip"; sens_of <<<"$pbase"; [ -f "$proj/.ai/project.md" ] && sens_of < "$proj/.ai/project.md"; } | sed '/^$/d' | sort -u)
safe_a=(.claude/ .codex/ .github/ enforcement/ .ai/project.md .ai/enforcement.json .ai/test-lock)
# Locked tests: .ai/test-lock on GitHub at the target branch's tip and at the
# PR's base commit. No lock (HTTP 404) is fine.
lock=""
for ref in "$bname" "$boid"; do ghf .ai/test-lock "$ref" && lock+=$got$'\n'; done
mapfile -t lock_a < <(norm <<<"$lock" | sed '/^$/d')
# covered PATH CHANGE PATTERN...: PATH (lower case) matches a pattern
# (path_matches). With CHANGE (safety files only): .claude/docs/ is free of
# .claude/, and a lock that only gains lines ("grown") is free of .ai/test-lock.
covered() {
  local f=$1 ch=$2 pat; shift 2
  for pat; do
    [ -n "$pat" ] || continue
    if [ -n "$ch" ]; then
      [ "$pat" = .claude/ ] && [[ $f == .claude/docs/* ]] && continue
      [ "$pat" = .ai/test-lock ] && [ "$ch" = grown ] && continue
    fi
    path_matches "$f" "$pat" && return 0
  done
  return 1
}
# Same rule as ci-checks.sh.
is_test() {
  [[ $1 =~ (^|/)(tests?|__tests__)/ || $1 =~ (^|/)test_[^/]*\.py$ || $1 =~ _test\.(py|go)$ || $1 =~ \.(test|spec)\.[cm]?[jt]sx?$ ]]
}
# Every file is checked; the strictest result wins, whatever the order.
hit="" kind="" sens_hits=() plans=() tests=0 projmd=
while IFS=$'\t' read -r ch f; do
  [ -n "$f" ] || continue
  lf=${f,,}
  if [ -z "$hit" ]; then
    if covered "$lf" "$ch" "${safe_a[@]}"; then hit=$f kind=safety
    elif [ "$ch" != added ] && covered "$lf" "" "${lock_a[@]}"; then hit=$f kind=lock
    elif covered "$lf" "" "${own_a[@]}"; then hit=$f kind=owner
    fi
  fi
  covered "$lf" "" "${sens_a[@]}" && sens_hits+=("$f")
  [ "$ch" = added ] && [[ $f == .ai/plans/*.md ]] && plans+=("$f")
  [ "$ch" != removed ] && is_test "$f" && tests=1
  [ "$lf" = .ai/project.md ] && projmd=1
done <<<"$files"
mapfile -t sens_hits < <(printf '%s\n' "${sens_hits[@]}" | sed '/^$/d' | sort -u)
approved() { tr -d '\r' 2>/dev/null < "$proj/.ai/approvals.log" | grep -qE "[[:space:]]merge-pr[[:space:]]+$n[[:space:]]+$oid\$"; }
say="Tell the owner what the PR changes and how it was checked, then ask them to type \"approve merge PR $n\" (\"duyệt merge PR $n\" when owner_language is vi). A new push needs a new approval."
# A PR that changes owner_only_paths changes which code merges without the
# owner: say so in plain words, with the paths added and removed.
items() { tail -n +2 <<<"$1" | sed '/^$/d' | sort -u; }
keynote=
if [ -n "$projmd" ]; then
  ghf .ai/project.md "$oid"; ohead=$(owner_only_parse <<<"$got")
  if [ "$ohead" != "$otip" ]; then
    st_head=${ohead%%$'\t'*}
    added=$(comm -13 <(items "$otip") <(items "$ohead") | paste -sd ' ' -)
    removed=$(comm -23 <(items "$otip") <(items "$ohead") | paste -sd ' ' -)
    keynote="This PR changes owner_only_paths, which decides what sensitive code merges without the owner"
    [ "$st_head" = ok ] && [ "$st_tip" != ok ] && keynote+=" (it turns merges without the owner on)"
    [ "$st_head" != ok ] && [ "$st_tip" = ok ] && keynote+=" (it turns merges without the owner off)"
    keynote+=". Paths added: ${added:-none}. Paths removed: ${removed:-none}. "
  fi
fi
# no_owner_problems: why a sensitive PR in an opted-in project cannot merge
# without the owner, one entry of probs per reason; none when every condition
# holds (CI green is checked below for every PR).
no_owner_problems() {
  local wf= risk= tok ok c ntr cf p h pr why
  [[ $rl =~ ^Lodestar\ route:\ ([A-Z_]+)\ risk=([a-z]+) ]] && wf=${BASH_REMATCH[1]} risk=${BASH_REMATCH[2]}
  case $wf in BUILD_REVIEW|INDEPENDENT_COMPARE|COMPLEX) ;; *) probs+=("the route is ${wf:-missing}, not BUILD_REVIEW, INDEPENDENT_COMPARE or COMPLEX") ;; esac
  case $risk in high|critical) ;; *) probs+=("the risk is ${risk:-missing}, not high or critical") ;; esac
  ok=
  for tok in $(tr '[:upper:]' '[:lower:]' <<<"${rv#Lodestar review: }" | tr -c '0-9a-z' '\n' | grep -xE '[0-9a-f]{7,64}'); do
    [[ $oid == "$tok"* ]] && ok=1
  done
  [ -n "$ok" ] || probs+=("the review line does not name the PR's head ${oid:0:7}; review the head again after every push")
  [ "$cross" != true ] || probs+=("the PR comes from a fork")
  [ -z "$bot" ] || probs+=("the PR was opened by a bot ($who)")
  pr=$(gh pr view "$n" --json changedFiles,commits -q '"\(.changedFiles)", (.commits[]? | .oid + " " + (if ((.messageHeadline // "") + "\n" + (.messageBody // "") | split("\n") | any(test("^No-Test-Reason:"))) then "1" else "0" end))' 2>/dev/null) ||
    die "gh could not read the commits of PR #$n." "$cant"
  pr=$(tr -d '\r' <<<"$pr")
  [ "$(head -n1 <<<"$pr")" -lt 3000 ] 2>/dev/null || probs+=("the PR changes $(head -n1 <<<"$pr") files (3000 or more, past what GitHub lists)")
  [ "$(tail -n +2 <<<"$pr" | grep -c .)" -lt 100 ] || probs+=("the PR has 100 or more commits (GitHub lists only the first 100)")
  while read -r c ntr; do
    [ "$ntr" = 1 ] || continue
    cf=$(gh api --paginate "repos/{owner}/{repo}/commits/$c" -q '.files[]? | .filename, (.previous_filename // empty)' 2>/dev/null) ||
      die "gh could not read commit $c of PR #$n." "$cant"
    while IFS= read -r p; do
      p=${p%$'\r'}
      [ -n "$p" ] && covered "${p,,}" "" "${sens_a[@]}" && { probs+=("commit ${c:0:7} carries No-Test-Reason: and changes $p"); break; }
    done <<<"$cf"
  done < <(tail -n +2 <<<"$pr")
  # The plan: added by this PR, its criteria hash (read at the head) approved
  # in the local .ai/approvals.log, and in that log neither at the target tip
  # nor at the base (an old approved plan copied under a new name does not
  # count). Whether the plan fits the code is not checked.
  ok= why=
  if [ ${#plans[@]} = 0 ]; then why="the PR adds no plan (.ai/plans/); a later PR of a multi-PR plan needs the owner"
  else
    for p in "${plans[@]}"; do
      ghf "$p" "$oid"; h=$(criteria_hash <<<"$got")
      if [ -z "$h" ]; then why+="plan $p has no acceptance criteria; "; continue; fi
      if ! { [ -f "$proj/.ai/approvals.log" ] && hash_approved "$h" < "$proj/.ai/approvals.log"; }; then
        why+="the criteria of plan $p are not approved by the owner (local .ai/approvals.log); "; continue
      fi
      [ -n "${alog_tip+x}" ] || { ghf .ai/approvals.log "$bname"; alog_tip=$got; ghf .ai/approvals.log "$boid"; alog_base=$got; }
      if hash_approved "$h" <<<"$alog_tip" || hash_approved "$h" <<<"$alog_base"; then
        why+="the criteria of plan $p were approved before this PR (an older plan); "; continue
      fi
      ok=1; break
    done
  fi
  [ -n "$ok" ] || probs+=("${why%; }")
  [ $tests = 1 ] || probs+=("the PR changes no test file")
}
noowner=
if [ -n "$hit" ] && ! approved; then
  case $kind in
    safety) what="$hit, a safety file (hooks, CI, project rules)" ;;
    lock) what="$hit, a test locked in .ai/test-lock" ;;
    owner) what="$hit, which is on owner_only_paths in .ai/project.md" ;;
  esac
  die "PR #$n changes $what, so only the owner approves its merge." "$keynote$say"
elif [ -z "$hit" ] && [ ${#sens_hits[@]} -gt 0 ] && ! approved; then
  what="PR #$n changes ${sens_hits[0]} (sensitive_paths in .ai/project.md)"
  if [ -z "$optin" ]; then
    note=
    if [ "$st_tip" != absent ] || [ "$st_base" != absent ]; then
      note="owner_only_paths is not on (the project is not opted in):"
      for side in tip base; do
        if [ $side = tip ]; then s=$st_tip w=$why_tip at="the target tip ($bname)"; else s=$st_base w=$why_base at="the PR's base ($boid)"; fi
        case $s in absent) note+=" $at has no owner_only_paths key;" ;; bad) note+=" the copy at $at is malformed: $w;" ;; esac
      done
      note="${note%;}. $counts. "
    fi
    die "$what, so only the owner approves its merge." "$note$say"
  fi
  probs=(); no_owner_problems
  if [ ${#probs[@]} -gt 0 ]; then
    die "$what. It can merge without the owner only when every condition holds; these do not:$(printf '\n  - %s' "${probs[@]}")" \
      "Fix them, or: $say"
  fi
  noowner=1
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
# Merging without the owner: the target tip's lists again, since a PR merged
# while CI ran may have changed them.
if [ -n "$noowner" ]; then
  ghf .ai/project.md "$bname"
  [ "$(owner_only_parse <<<"$got")" = "$otip" ] && [ "$(sens_of <<<"$got")" = "$(sens_of <<<"$ptip")" ] ||
    die "owner_only_paths or sensitive_paths changed on $bname while CI ran; not merged." "Run this again."
fi
# --delete-branch makes gh switch this folder to the base branch after the
# merge; git refuses while .ai/approvals.log has the approval lines the hook
# added (seen in a consuming project). Set the log aside, then append its uncommitted
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
  trap 'carry_back; rm -f "$gherr"' EXIT
  if git -C "$top" ls-files --error-unmatch .ai/approvals.log >/dev/null 2>&1; then git -C "$top" checkout -q HEAD -- .ai/approvals.log; else rm -f "$lg"; fi
fi
if ! gh pr merge "$n" "$method" $del --match-head-commit "$oid"; then
  carry_back
  read -r _ _ _ _ _ _ now <<<"$(view)"
  [ "$now" = MERGED ] || die "gh pr merge failed for PR #$n."
  printf 'merge-pr: PR #%s is merged on GitHub, but gh could not finish here (see above).\n%s\n' "$n" \
    "Finish by hand: commit or stash other changes, git switch $bname, git pull, git branch -D $h${del:+, git push origin --delete $h}." >&2
fi
carry_back; rm -f "$gherr"
gd=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd) && echo "PR $n merged" > "$gd/lodestar-task-done"
echo "merge-pr: PR #$n merged at $oid."
# A merge without the owner leaves a trace the owner can read on GitHub.
if [ -n "$noowner" ]; then
  line="merge-pr: PR #$n merged without the owner (owner_only_paths is on). Sensitive files: $(printf '%s
' "${sens_hits[@]}" | paste -sd ' ' -). Review: ${rv#Lodestar review: }. $counts."
  echo "$line"
  gh pr comment "$n" --body "$line" >/dev/null 2>&1 || echo "merge-pr: could not post that line as a PR comment; the merge stands. Tell the owner the line above." >&2
fi
