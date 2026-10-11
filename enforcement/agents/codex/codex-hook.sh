#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# Codex adapter: .codex/hooks.json runs the Lodestar hooks through this file.
# Usage: codex-hook.sh <hook name>, e.g. codex-hook.sh protect-tests
# Codex sends the same JSON as Claude, with two differences handled here:
# - no project-dir variable: the project is the git root. A CLAUDE_PROJECT_DIR
#   inherited from a parent Claude session may name another folder.
# - file edits are one apply_patch whose file paths sit inside the patch text:
#   the hook runs once per file, and the first block wins.
hook=$1
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
export CLAUDE_PROJECT_DIR=$root
cd "$root" || exit 0
[ -f ".claude/hooks/$hook.sh" ] || exit 0
input=$(cat)
# Without jq every hook reads empty input and lets everything through. Say so
# instead; a Stop already sent back once may end (no loop).
if ! command -v jq >/dev/null; then
  grep -q '"stop_hook_active": *true' <<<"$input" && exit 0
  echo "Lodestar hooks need jq, which this shell cannot find. Run enforcement/setup-machine.sh, then restart Codex." >&2
  exit 2
fi
if [ "$(jq -j '.tool_name // empty' <<<"$input")" != apply_patch ]; then
  printf '%s' "$input" | bash ".claude/hooks/$hook.sh"
  exit
fi
# "a/./b/../c" -> "a/c", so a path cannot slip past a check. Pure bash:
# macOS realpath has no -m.
norm() {
  local IFS=/ seg out=() parts lead=
  [[ $1 == /* ]] && lead=/
  read -ra parts <<<"$1"
  for seg in "${parts[@]}"; do
    case $seg in
      ''|.) ;;
      ..) [ ${#out[@]} -gt 0 ] && unset 'out[${#out[@]}-1]' ;;
      *) out+=("$seg") ;;
    esac
  done
  printf '%s%s' "$lead" "${out[*]}"
}
# Relative patch paths are relative to the session folder (cwd), which may be
# a subfolder; the hooks expect absolute paths. Header lines may carry spaces
# around them.
cwd=$(jq -j '.cwd // empty' <<<"$input"); cwd=${cwd//\\//}
mapfile -t files < <(jq -j '.tool_input.command // empty' <<<"$input" | tr -d '\r' |
  sed -n -E 's/^[[:space:]]*\*\*\*[[:space:]]*(Add|Update|Delete) File:[[:space:]]*//p; s/^[[:space:]]*\*\*\*[[:space:]]*Move to:[[:space:]]*//p')
if [ ${#files[@]} = 0 ]; then
  echo "Blocked: Lodestar found no file in this apply_patch, so it cannot check it. Use '*** Add File: <path>' (or Update/Delete) lines." >&2
  exit 2
fi
for f in "${files[@]}"; do
  f=${f%"${f##*[![:space:]]}"}; f=${f//\\//}
  [[ $f == /* || $f =~ ^[A-Za-z]: ]] || f=${cwd:-$root}/$f
  f=$(norm "$f")
  jq -n --arg f "$f" '{tool_name: "apply_patch", tool_input: {file_path: $f}}' |
    bash ".claude/hooks/$hook.sh" || exit $?
done
