#!/usr/bin/env bash
# Tests for scripts/check-release-rhythm.sh on a fake history in a temp repo.
# Usage: bash scripts/test-release-rhythm.sh    Exit 1 if a case fails.
set -uo pipefail
check=$(cd "$(dirname "$0")" && pwd)/check-release-rhythm.sh
tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
cd "$tmp" || exit 1
day=86400 t0=1767225600   # 2026-01-01 00:00 UTC
g() { GIT_AUTHOR_DATE="@$1 +0000" GIT_COMMITTER_DATE="@$1 +0000" git -c user.name=t -c user.email=t@t "${@:2}"; }
git init -q -b main . && git config core.autocrlf false && mkdir enforcement
echo 1.0.0 > enforcement/VERSION && git add . && g $t0 commit -qm v1
echo 1.0.1 > enforcement/VERSION && g $((t0 + day)) commit -qam v2   # last raise: day 1
git checkout -q -b pr && echo 1.0.2 > enforcement/VERSION && g $((t0 + 2 * day)) commit -qam v3
fails=0
run() { # <name> <want exit> <now> <body> [base]
  local got
  RHYTHM_NOW=$3 PR_BODY=$4 bash "$check" "${5:-main}" >/dev/null 2>&1; got=$?
  [ "$got" = "$2" ] && echo "ok   $1" || { echo "FAIL $1 (exit $got, want $2)"; fails=$((fails + 1)); }
}
early=$((t0 + 4 * day)) late=$((t0 + 7 * day)) edge=$((t0 + 7 * day - 3600))
run "no release line"                 1 $late  "Lodestar route: SIMPLE risk=low"
run "batch, 3 days after last raise"  1 $early "Lodestar release: batch"
run "batch, 6 days after"             0 $late  "Lodestar release: batch"
run "batch, 5d 23h after"             1 $edge  "Lodestar release: batch"
run "batch, CRLF text"                0 $late  $'x\r\nLodestar release: batch\r\n'
run "urgent with reason, early"       0 $early "Lodestar release: urgent, a hook blocks correct work"
run "urgent without reason"           1 $early "Lodestar release: urgent, "
run "line not at line start"          1 $late  "see Lodestar release: batch"
run "missing base"                    1 $late  "Lodestar release: batch" nope
git checkout -q main && git checkout -q -b docs && echo x > a.md && git add a.md && g $((t0 + 2 * day)) commit -qm docs
run "VERSION unchanged"               0 $early ""
# A raise merged into main: its age counts from the merge, not the branch commit.
git checkout -q main && git checkout -q -b old && echo 1.0.5 > enforcement/VERSION && g $((t0 + 2 * day)) commit -qam v5
git checkout -q main && g $((t0 + 9 * day)) merge -q --no-ff -m "merge v5" old
git checkout -q -b pr2 && echo 1.0.6 > enforcement/VERSION && g $((t0 + 10 * day)) commit -qam v6
run "merge time counts"               1 $((t0 + 12 * day)) "Lodestar release: batch"
[ $fails = 0 ] && echo "release-rhythm tests: all pass" || { echo "release-rhythm tests: $fails failed"; exit 1; }
