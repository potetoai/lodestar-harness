#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# Codex adapter: .codex/hooks.json runs the Lodestar hooks through this file.
# Usage: codex-hook.sh <hook name>, e.g. codex-hook.sh protect-tests
# The policy stays in the shared Claude hooks; this file only turns Codex
# events into their input. When a check cannot run it never infers permission:
# - guards (protect-tests, sensitive-gate, guard-install) block, with a repair;
# - verify-before-stop blocks; only Codex's repeated Stop (stop_hook_active)
#   may end, as in Claude;
# - lint-file reports to the agent; feedback-check and approval-record report
#   unavailable and let the work go on.
# Codex differences handled here:
# - no project-dir variable: the project is the git root. A CLAUDE_PROJECT_DIR
#   inherited from a parent Claude session may name another folder.
# - file edits are one apply_patch whose file paths sit inside the patch text:
#   the hook runs once per path, rename destinations too, and the first block
#   wins. For .ai/test-lock the new content is rebuilt (codex-patch.jq), so
#   protect-tests can check that lines were only added.
# - a delegated (child) Codex session gets its prompt from the parent agent:
#   approval-record runs only in the owner's own session.
hook=$1
case $hook in
  protect-tests|sensitive-gate|guard-install) kind=guard ;;
  verify-before-stop) kind=stop ;;
  lint-file) kind=post ;;
  feedback-check|approval-record) kind=advisory ;;
  *) echo "Blocked: unknown Lodestar hook '$hook' in .codex/hooks.json. Repair: rerun enforcement/bootstrap.sh --upgrade in this project." >&2; exit 2 ;;
esac
case $0 in */*) here=${0%/*} ;; *) here=. ;; esac
here=$(cd "$here" && pwd)
input=$(cat)
again=0
grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true' <<<"$input" && again=1
# fail WHY REPAIR: the check could not run.
fail() {
  case $kind in
    advisory) echo "Lodestar $hook unavailable: $1." >&2; exit 0 ;;
    stop) [ $again = 1 ] && exit 0 ;;
  esac
  echo "Blocked: Lodestar $hook cannot check this: $1." >&2
  echo "Repair: $2" >&2
  exit 2
}
command -v jq >/dev/null || fail 'jq is not on PATH' 'run enforcement/setup-machine.sh, then restart Codex.'
jq -e 'type == "object"' <<<"$input" >/dev/null 2>&1 || fail 'the event input is not a JSON object' 'update Codex; if it persists, report the event format.'
again=$(jq -j 'if .stop_hook_active == true then 1 else 0 end' <<<"$input")
root=$(git rev-parse --show-toplevel 2>/dev/null) || fail 'no Git project here' 'start Codex inside the project.'
export CLAUDE_PROJECT_DIR=$root LODESTAR_RUNTIME=codex
cd "$root" || fail "cannot enter $root" 'check the project folder.'
script=.claude/hooks/$hook.sh
[ -r "$script" ] || fail "$script is missing" 'rerun enforcement/bootstrap.sh --upgrade in this project.'
# The guards skip their checks when their library is missing.
[ $kind != guard ] || [ -r .claude/hooks/lodestar-lib.sh ] ||
  fail '.claude/hooks/lodestar-lib.sh is missing' 'rerun enforcement/bootstrap.sh --upgrade in this project.'
if [ $kind = guard ]; then
  want=apply_patch; [ "$hook" = guard-install ] && want=Bash
  jq -e --arg w "$want" '.tool_name == $w and (.tool_input | type) == "object" and (.tool_input.command | type) == "string" and (.tool_input.command | length) > 0' <<<"$input" >/dev/null ||
    fail "expected a $want event with a text command" 'check the matchers in .codex/hooks.json (rerun enforcement/bootstrap.sh --upgrade).'
fi

# run JSON: the shared hook decides; exit 0 or 2 is its answer, anything else a failure.
run() {
  local rc
  bash "$script" <<<"$1"; rc=$?
  case $rc in 0|2) return $rc ;; esac
  fail "$script stopped with exit code $rc" "run it by hand to see the error, or rerun enforcement/bootstrap.sh --upgrade."
}

if [ "$hook" = approval-record ]; then
  t=$(jq -j '.transcript_path // empty' <<<"$input")
  owner=$(jq -js '([.[] | select(.type == "session_meta") | .payload] | last) as $m
    | $m != null and $m.source == "cli" and $m.thread_source == "user" and $m.parent_thread_id == null' "$t" 2>/dev/null)
  if [ "$owner" != true ]; then
    # Say so only when the prompt looks like an approval, not on every prompt.
    low=$(jq -r '.prompt // empty' <<<"$input" | tr -d '\r'); low=${low,,}
    low=${low#"${low%%[![:space:][:punct:]]*}"}
    grep -qE '^(duyệt|duyet|approve|approved)([^[:alpha:]]|$)' <<<"$low" &&
      echo "Lodestar: approvals are recorded only in the owner's own Codex session. This session is delegated or its origin is unknown, so nothing was recorded; ask the owner to approve in their own session."
    exit 0
  fi
fi

if [ "$(jq -j '.tool_name // empty' <<<"$input")" != apply_patch ]; then
  run "$input"; exit
fi
# "a/./b/../c" -> "a/c", so a path cannot slip past a check. Pure bash:
# macOS realpath has no -m. Win32 also drops trailing dots and spaces of a
# name ("approvals.log." is approvals.log).
norm() {
  local IFS=/ seg out=() parts lead=
  [[ $1 == /* ]] && lead=/
  read -ra parts <<<"$1"
  for seg in "${parts[@]}"; do
    [[ $seg == . || $seg == .. ]] || while [[ $seg == *[.\ ] ]]; do seg=${seg%?}; done
    case $seg in
      ''|.) ;;
      ..) [ ${#out[@]} -gt 0 ] && unset 'out[${#out[@]}-1]' ;;
      *) out+=("$seg") ;;
    esac
  done
  printf '%s%s' "$lead" "${out[*]}"
}
reader=$here/codex-patch.jq
[ -r "$reader" ] || fail "$reader is missing" 'rerun enforcement/bootstrap.sh --upgrade in this project.'
patch=$(jq -j '.tool_input.command // empty' <<<"$input")
# jq on Windows ends lines with CRLF; a path ending in \r would miss every check.
heads=$(jq -Rrs --arg mode paths --argjson n 0 --arg cur '' -f "$reader" <<<"$patch" 2>/dev/null) ||
  fail 'this apply_patch has no "*** Begin Patch" line' "write the patch in Codex's apply_patch format."
heads=${heads//$'\r'/}
mapfile -t heads <<<"$heads"
if [ -z "${heads[0]}" ]; then
  echo "Blocked: Lodestar found no file in this apply_patch, so it cannot check it. Use '*** Add File: <path>' (or Update/Delete) lines." >&2
  exit 2
fi
# Relative patch paths are relative to the session folder (cwd), which may be
# a subfolder; the hooks expect absolute paths.
cwd=$(jq -j '.cwd // empty' <<<"$input"); cwd=${cwd//\\//}
proj=$(pwd -W 2>/dev/null || pwd)
# Other Windows names for a project file become the form the guards compare
# with (their own pwd -W): 8.3 short names through cygpath. Stream or device
# syntax ("x::$DATA", "//?/C:/...") cannot be checked.
long() { if command -v cygpath >/dev/null && [ -e "$1" ]; then cygpath -m -l "$1"; else printf '%s' "$1"; fi; }
projlong=$(long "$proj")
kinds=() files=() locks=()
for i in "${!heads[@]}"; do
  kinds[i]=${heads[i]%%$'\t'*}; f=${heads[i]#*$'\t'}; f=${f//\\//}
  [[ $f == /* || $f =~ ^[A-Za-z]: ]] || f=${cwd:-$root}/$f
  if [[ $f == //* ]] || { [[ $f =~ ^[A-Za-z]: ]] && [[ ${f:2} == *:* ]]; }; then
    fail "the path $f uses a Windows network, stream or device form" 'write project paths plainly, relative or C:/...'
  fi
  f=$(norm "$f")
  if [ -e "$f" ]; then f=$(long "$f"); else f=$(long "${f%/*}")/${f##*/}; fi
  if [[ ${f,,} == "${projlong,,}"/* ]]; then
    f=$proj/${f:${#projlong}+1}
  else
    # A subst drive, junction or link can name the project by another path;
    # find a folder above f that is the project itself.
    a=$f rest=
    while [[ $a == */* ]]; do
      if [ -d "$a" ] && [ "$a" -ef "$proj" ]; then f=$proj$rest; break; fi
      rest=/${a##*/}$rest; a=${a%/*}
    done
    [ "$a" ] && [ -d "$a/" ] && [ "$a/" -ef "$proj" ] && f=$proj$rest
  fi
  files[i]=$f
  [ "${files[i],,}" = "${proj,,}/.ai/test-lock" ] && locks+=("$i")
done
# The lock's content after the patch. Fails when Codex might not do what this
# models; protect-tests then gets no content and lock_append_only cannot pass.
lock_content() {
  local i=$1
  [ ${#locks[@]} = 1 ] || return 1
  case ${kinds[i]} in
    'Move to') return 1 ;;
    'Delete File') printf '' ; return 0 ;;
    'Update File') [ "${kinds[i+1]}" = 'Move to' ] && { printf ''; return 0; } ;;
  esac
  jq -Rjs --arg mode apply --argjson n "$i" --arg cur "$(cat .ai/test-lock 2>/dev/null)" -f "$reader" <<<"$patch" 2>/dev/null
}
for i in "${!files[@]}"; do
  f=${files[i]}
  json=$(jq -nc --arg f "$f" '{tool_name: "apply_patch", tool_input: {file_path: $f}}')
  # The trailing "." keeps the content's final newline through $(...).
  if [ "$hook" = protect-tests ] && [[ " ${locks[*]} " == *" $i "* ]] && content=$(lock_content "$i" && echo .); then
    content=${content%.}
    json=$(jq -nc --arg f "$f" --arg c "${content//$'\r'/}" '{tool_name: "Write", tool_input: {file_path: $f, content: $c}}')
  fi
  run "$json" || exit $?
done
