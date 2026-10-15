# Merge Lodestar hook registrations into a runtime's hook configuration.
# Usage: jq --arg kind project|global --slurpfile ours TEMPLATE -f merge-hooks.jq TARGET
#
# Ownership: a hook is Lodestar's when its command has the generated shape
# (project: .claude/hooks/<script> relative to the project; global: a
# codex-global-hook.sh inside a Lodestar enforcement tree). Its key is the
# script and check, not the path, so a moved source is replaced in place.
# Same-named commands elsewhere (/custom/codex-hook.sh) are not Lodestar's.
# Each key keeps its first registration on the template's event and matcher,
# updated to the template fields; other copies are removed; missing ones are
# appended. Everything else is kept as it is. Malformed input is an error.

def re:
  if $kind == "global"
  then "^bash \"[^\"]+/enforcement/agents/codex/global/codex-global-hook\\.sh\" (?<k>[a-z-]+(?: --prompt)?)$"
  else "(?:\"\\$CLAUDE_PROJECT_DIR/|exec bash )\\.claude/hooks/(?<k>[a-z-]+\\.sh(?: [a-z-]+)?)['\"]$" end;
def hkey: if (.command | type) == "string" then ([.command | capture(re)][0].k // null) else null end;
def valid:
  type == "object" and ((.hooks // {}) | type == "object" and all(.[];
    type == "array" and all(.[]; type == "object" and (.hooks | type == "array")
      and all(.hooks[]; type == "object" and ((.command // "") | type == "string")))));

if valid | not then error("hook configuration is malformed (expected {hooks: {Event: [{hooks: [{command}]}]}})") else . end
| $ours[0] as $ours
| ([$ours.hooks | to_entries[] | .key as $e | .value[] | (.matcher // null) as $m
    | .hooks[] | {k: hkey, e: $e, m: $m, h: .}] | INDEX(.k)) as $T
| [.hooks // {} | to_entries[] | .key as $e | .value | to_entries[] | .key as $gi
    | (.value.matcher // null) as $m | .value.hooks | to_entries[]
    | (.value | hkey) as $k | select($k != null and $T[$k] != null)
    | {p: [$e, $gi, "hooks", .key], k: $k, ok: ($T[$k].e == $e and $T[$k].m == $m)}] as $managed
| (reduce ($managed[] | select(.ok)) as $x ({}; if has($x.k) then . else .[$x.k] = $x.p end)) as $keep
| [$managed[] | select($keep[.k] != .p) | .p] as $drop
| reduce ($keep | to_entries[]) as $x (.; setpath(["hooks"] + $x.value; $T[$x.key].h))
| delpaths([$drop[] | ["hooks"] + .])
# A group or event emptied by a removal goes too; an owner's empty one stays.
| ([$drop[] | .[0:2]] | unique) as $dg
| . as $d | delpaths([$dg[] | select(. as $q | $d.hooks | getpath($q + ["hooks"]) | length == 0) | ["hooks"] + .])
| . as $d | delpaths([$dg[] | .[0] | select($d.hooks[.] == []) | ["hooks", .]] | unique)
| .hooks = reduce ($ours.hooks | to_entries[]) as $e (.hooks // {};
    .[$e.key] = (.[$e.key] // []) + [$e.value[]
      | .hooks |= map(select(hkey as $k | $keep | has($k) | not))
      | select(.hooks | length > 0)])
