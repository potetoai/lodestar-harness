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
# Applies to everyone who pushes from this checkout. The owner can still
# push by hand with --no-verify; guard-install.sh blocks that flag for agents.
remote=${1:-origin}
default=$(git symbolic-ref --short -q "refs/remotes/$remote/HEAD" 2>/dev/null); default=${default#"$remote"/}
prot=" main master ${default,,} "
branch=$(git symbolic-ref --short -q HEAD 2>/dev/null)
why=""
[[ ${branch,,} == proto/* ]] && why="the checked-out branch $branch is a prototype (proto/*); nothing is pushed from it."
while read -r lref _ rref _; do
  [ -n "$why" ] && continue   # read all of stdin
  l=${lref#refs/heads/}; r=${rref#refs/heads/}
  if [[ ${l,,} == proto/* || ( $rref == refs/heads/* && ${r,,} == proto/* ) ]]; then
    why="a prototype branch (proto/*) is thrown away, never pushed ($lref -> $rref)."
  elif [[ $rref == refs/heads/* && $prot == *" ${r,,} "* ]]; then
    why="a push to $r skips the PR and its CI."
  fi
done
[ -z "$why" ] && exit 0
cat >&2 <<EOF
Lodestar pre-push: blocked: $why
Create a branch from main, push it, open a PR, and merge when CI is green (bash .claude/hooks/merge-pr.sh <n>).
A prototype: write down what it showed, then build the real change on a new branch from main (workflows/prototype.md).
If the owner really wants this push, they run it themselves with --no-verify.
EOF
exit 1
