#!/usr/bin/env bash
# CI check (steady-1 phase 1): a PR that changes enforcement/VERSION must say
# why in its text, and a batch release must wait for the release rhythm
# (enforcement/README.md section 3: at most once a week, release day Saturday).
#   Lodestar release: batch               last raise on <base> 6 days old or more
#   Lodestar release: urgent, <reason>    any time; the reason names an item
#                                         of the rule's list
# 6 days, not 7, so a weekly release day passes even when it runs a few hours
# earlier than the last one.
# Usage: PR_BODY=<pr text> bash scripts/check-release-rhythm.sh <base-ref>
# RHYTHM_NOW=<epoch seconds> sets the clock (tests). Exit 1 on a fail.
set -uo pipefail
base=${1:?usage: check-release-rhythm.sh <base-ref>}
now=${RHYTHM_NOW:-$(date +%s)}
min_days=6
fail() { echo "release-rhythm: $1" >&2; exit 1; }
git rev-parse -q --verify "$base^{commit}" >/dev/null || fail "base '$base' not found (fetch full history)."
if git diff --quiet "$base"...HEAD -- enforcement/VERSION; then
  echo "release-rhythm: enforcement/VERSION not changed; nothing to check."; exit 0
fi
line=$(printf '%s\n' "${PR_BODY-}" | tr -d '\r' | grep -m1 -E '^Lodestar release: ' || true)
case $line in
  "Lodestar release: batch") ;;
  "Lodestar release: urgent, "*[![:space:]]*)
    echo "release-rhythm: urgent release ($line)."; exit 0 ;;
  *) fail "this PR raises enforcement/VERSION; its text needs one line: 'Lodestar release: batch' or 'Lodestar release: urgent, <reason from enforcement/README.md section 3>'." ;;
esac
# --first-parent: the time the raise reached <base> (its merge), not when
# the branch commit was written.
last=$(git log -1 --first-parent --format=%ct "$base" -- enforcement/VERSION)
[ -n "$last" ] || { echo "release-rhythm: first VERSION on $base; batch ok."; exit 0; }
age=$(( (now - last) / 3600 ))
[ "$age" -ge $((min_days * 24)) ] ||
  fail "the last VERSION raise on $base is $((age / 24))d $((age % 24))h old (batch needs ${min_days}d). Wait for the release day, or, for a fault on the rule's list, write 'Lodestar release: urgent, <reason>'."
echo "release-rhythm: batch release, last raise $((age / 24))d old."
