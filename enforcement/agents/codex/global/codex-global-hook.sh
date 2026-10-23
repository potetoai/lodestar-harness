#!/usr/bin/env bash
# Normalize Codex global events; policy remains in the shared Claude scripts.
here=$(cd "$(dirname "$0")" && pwd)
hook=${1:-}; shift || :
unavailable() { echo "Lodestar global advisory unavailable: $*" >&2; exit 0; }
case $hook in check-readiness|context-nudge) ;; *) unavailable 'unsupported hook' ;; esac
export LODESTAR_RUNTIME=codex
input=$(cat)
command -v jq >/dev/null || unavailable 'jq missing'
jq -e 'type == "object"' <<<"$input" >/dev/null 2>&1 || unavailable 'invalid event input'
# Both hooks look at the project: readiness needs it; the task-done nudge
# looks there for merge-pr.sh's marker (no cwd: where the hook runs).
cwd=$(jq -er '.cwd | select(type == "string" and length > 0)' <<<"$input")
if [ "$hook" = check-readiness ]; then
  [ -n "$cwd" ] || unavailable 'missing cwd'
  cd "$cwd" 2>/dev/null || unavailable 'cannot resolve cwd'
  root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
  export CLAUDE_PROJECT_DIR=$root
elif [ -n "$cwd" ]; then
  cd "$cwd" 2>/dev/null || unavailable 'cannot resolve cwd'
fi
script="$here/../../claude/global/$hook.sh"
[ -r "$script" ] || unavailable 'missing shared script'
bash "$script" "$@" <<<"$input"; rc=$?
case $rc in 0|2) exit "$rc" ;; *) unavailable 'shared check could not execute' ;; esac
