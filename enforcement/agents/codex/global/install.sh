#!/usr/bin/env bash
# Register the Lodestar reminders in a Codex home's hooks.json: readiness on
# SessionStart and on each owner prompt (--prompt), the context nudge on
# PostToolUse. Codex home: CODEX_HOME, or ~/.codex when unset.
# Keeps every other setting and hook (Orca's too); replaces our entries from
# an older or moved source; refuses malformed hooks.json without changing it.
# Never touches config.toml: the owner trusts the hooks in Codex (/hooks).
# Backs up the file first. Safe to re-run.
# Usage: install.sh [--check]   --check: exit 1 when an install would change it
set -euo pipefail
here=$(cd "$(dirname "$0")" && { pwd -W 2>/dev/null || pwd; })
agents=$(cd "$(dirname "$0")/../.." && pwd)
home=${CODEX_HOME:-$HOME/.codex}
target="$home/hooks.json"
command -v jq >/dev/null || { echo "jq is required." >&2; exit 1; }
case $here in *[\"\$\`\\]*) echo "Cannot register hooks from a path with \" \$ \` or \\: $here" >&2; exit 1 ;; esac

script="$here/codex-global-hook.sh"
ps=${script//\'/\'\'}
hook() {   # hook CHECK [ARG]: one command with its Windows entry point
  jq -n --arg c "bash \"$script\" $*" --arg w "\$b = Join-Path (git --exec-path) ../../../bin/bash.exe; & \$b '$ps' $*; exit \$LASTEXITCODE" \
    '{type: "command", command: $c, commandWindows: $w, timeout: 30}'
}
ours=$(jq -n --argjson r "$(hook check-readiness)" --argjson p "$(hook check-readiness --prompt)" --argjson n "$(hook context-nudge)" \
  '{hooks: {SessionStart: [{hooks: [$r]}], UserPromptSubmit: [{hooks: [$p]}], PostToolUse: [{matcher: "*", hooks: [$n]}]}}')

tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$ours" > "$tmp"
# An empty file has no hooks; jq would print nothing for it.
current='{}'; [ -f "$target" ] && grep -q '[^[:space:]]' "$target" && current=$(cat "$target")
new=$(jq --arg kind global --slurpfile ours "$tmp" -f "$agents/merge-hooks.jq" <<<"$current" 2>&1 | tr -d '\r') ||
  { echo "$target: $new. Fix it by hand and run this again; nothing was changed." >&2; exit 1; }
[ -n "$new" ] || { echo "$target: could not merge the hooks; nothing was changed." >&2; exit 1; }
if [ -f "$target" ] && [ "$new" = "$(jq . "$target" | tr -d '\r')" ]; then
  echo "Already installed in $target"
  exit 0
fi
[ "${1:-}" = --check ] && { echo "Lodestar reminder hooks are missing or outdated in $target"; exit 1; }
mkdir -p "$home"
[ -f "$target" ] && cp "$target" "$target.bak"
printf '%s\n' "$new" > "$target"
echo "Installed in $target. Review and trust them in Codex: /hooks"
