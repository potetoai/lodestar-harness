#!/usr/bin/env bash
# Register check-readiness.sh in ~/.claude/settings.json: on SessionStart, and
# on UserPromptSubmit (--prompt) so the readiness gate sits next to every
# owner message. Register context-nudge.sh on PostToolUse. Drops entries for
# these scripts at another path (the folder moved or was renamed). Keeps every
# other setting and hook. Backs up the file first.
# Safe to re-run.
set -euo pipefail
here=$(cd "$(dirname "$0")" && { pwd -W 2>/dev/null || pwd; })
settings=${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}
base="bash \"$here/check-readiness.sh\""
nudge="bash \"$here/context-nudge.sh\""

mkdir -p "$(dirname "$settings")"
[ -f "$settings" ] || echo '{}' > "$settings"
new=$(jq --arg s "$base" --arg p "$base --prompt" --arg n "$nudge" '
  def add($ev; $c; $group): if ([.hooks[$ev][]?.hooks[]?.command] | index($c)) != null then .
    else .hooks[$ev] = ((.hooks[$ev] // []) + [$group + {hooks: [{type: "command", command: $c, timeout: 30}]}]) end;
  def stale($c): ($c | test("(check-readiness|context-nudge)\\.sh\"( --prompt)?$")) and $c != $s and $c != $p and $c != $n;
  .hooks |= (if . == null then . else map_values(map(.hooks |= map(select(stale(.command) | not))) | map(select(.hooks | length > 0))) end)
  | add("SessionStart"; $s; {}) | add("UserPromptSubmit"; $p; {}) | add("PostToolUse"; $n; {matcher: "*"})' "$settings" | tr -d '\r')
if [ "$new" = "$(jq . "$settings" | tr -d '\r')" ]; then
  echo "Already installed in $settings"
  exit 0
fi
cp "$settings" "$settings.bak"
printf '%s\n' "$new" > "$settings"
echo "Installed. Backup: $settings.bak"
