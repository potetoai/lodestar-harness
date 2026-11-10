#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# git pre-push hook, rules/enforcement.md section 6. bootstrap.sh installs a
# small .git/hooks/pre-push that runs this file. Git names the refs it
# pushes on stdin ("<local ref> <sha> <remote ref> <sha>"), so no command
# text is read:
# - main changes only through a PR: no push that creates, updates or
#   deletes main, master or the remote's default branch. This covers repos
#   where GitHub cannot lock main (private repo on GitHub Free, doctor C1).
# - a prototype branch (proto/*) stays local: no push of one under any name,
#   no push to a proto/* name, and no push at all while one is checked out.
# - the PR checks (ci-checks.sh) pass before the branch leaves the machine,
#   so a bad commit (a Tests-First commit without its plan...) is fixed with
#   a new commit, not a force-push. The PR text is not read here: CI checks
#   the route and review lines. Run only for the checked-out commit, against
#   <remote>/<default branch>, fetched first so an old local copy does not
#   count commits already on main (offline: the local copy as it is).
# Pushed to a URL, not a remote name: the remote with that URL, else origin.
# Applies to everyone who pushes from this checkout. The owner can still
# push by hand with --no-verify; guard-install.sh blocks that flag for agents.
remote=${1:-origin}
if ! git remote | grep -qxF -- "$remote"; then
  url=$remote; remote=origin
  for r in $(git remote); do
    [ "$(git remote get-url "$r" 2>/dev/null)" = "$url" ] || [ "$(git remote get-url --push "$r" 2>/dev/null)" = "$url" ] && { remote=$r; break; }
  done
fi
default=$(git symbolic-ref --short -q "refs/remotes/$remote/HEAD" 2>/dev/null); default=${default#"$remote"/}
prot=" main master ${default,,} "
branch=$(git symbolic-ref --short -q HEAD 2>/dev/null)
why=""
[[ ${branch,,} == proto/* ]] && why="the checked-out branch $branch is a prototype (proto/*); nothing is pushed from it."
head=$(git rev-parse -q --verify HEAD 2>/dev/null)
check=""
while read -r lref lsha rref _; do
  [ -n "$why" ] && continue   # read all of stdin
  [[ $rref == refs/heads/* && -n $head && $lsha == "$head" ]] && check=1
  l=${lref#refs/heads/}; r=${rref#refs/heads/}
  if [[ ${l,,} == proto/* || ( $rref == refs/heads/* && ${r,,} == proto/* ) ]]; then
    why="a prototype branch (proto/*) is thrown away, never pushed ($lref -> $rref)."
  elif [[ $rref == refs/heads/* && $prot == *" ${r,,} "* ]]; then
    why="a push to $r skips the PR and its CI."
  fi
done
ci=$(dirname "$0")/ci-checks.sh
if [ -z "$why" ] && [ -n "$check" ] && [ -f "$ci" ]; then
  base=""
  for b in "$default" main master; do
    [ -n "$b" ] && git rev-parse -q --verify "refs/remotes/$remote/$b" >/dev/null || continue
    GIT_TERMINAL_PROMPT=0 git fetch -q --no-tags "$remote" "$b" </dev/null >/dev/null 2>&1
    base=$remote/$b; break
  done
  if [ -n "$base" ]; then
    out=$(env -u PR_NUMBER -u LODESTAR_PR_BODY -u GITHUB_STEP_SUMMARY -u LODESTAR_TEST_MUTATION -u PR_AUTHOR \
      bash "$ci" "$base" </dev/null 2>&1) && exit 0
    printf '%s\n\n' "$out" >&2
    cat >&2 <<EOF
Lodestar pre-push: blocked: the PR checks (ci-checks.sh $base) fail; CI would fail the same way.
These commits are not pushed yet: fix them here (a new commit, or git commit --amend for the last one), then push again; no force-push is needed.
If a failure names a commit that is already on main, $base is old: git fetch $remote, then push again.
If the owner really wants this push, they run it themselves with --no-verify.
EOF
    exit 1
  fi
fi
[ -z "$why" ] && exit 0
cat >&2 <<EOF
Lodestar pre-push: blocked: $why
Create a branch from main, push it, open a PR, and merge when CI is green (bash .claude/hooks/merge-pr.sh <n>).
A prototype: write down what it showed, then build the real change on a new branch from main (workflows/prototype.md).
If the owner really wants this push, they run it themselves with --no-verify.
EOF
exit 1
