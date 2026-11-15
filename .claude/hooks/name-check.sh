#!/usr/bin/env bash
# This repo only (plans/active/steady-7-plan-hygiene.md, phase 2; not a
# project template). PreToolUse (Bash): refuses a `git commit` or a
# `gh pr create|edit` whose command text, message file or added lines hold a
# name from .ai/private-names.txt (gitignored, one name per line, # comments).
# The list is read from this checkout, else from the main checkout, so
# worktrees share it. With no list the check does nothing. Names match as
# plain text, any case, no word bounds (keep names long enough to be rare).
# Removed lines never count: taking a name out passes. A commit is checked
# against every change to tracked files and, only when the command also runs
# `git add`, every new untracked file, since the hook runs before a chained
# `git add ... && git commit`. Needs jq; without it the check does nothing.
# Price of that: a name in an unrelated unstaged change still blocks a plain
# commit; an untracked scratch file blocks only a command that adds files.
input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)
[ -n "$cmd" ] || exit 0
re_commit='(^|[;&|(]|[[:space:]])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+commit([[:space:]]|$)'
re_pr='(^|[;&|(]|[[:space:]])gh[[:space:]]+pr[[:space:]]+(create|edit)([[:space:]]|$)'
kind=""
[[ $cmd =~ $re_commit ]] && kind=commit
[[ $cmd =~ $re_pr ]] && kind=${kind:+$kind+}pr
re_add='(^|[;&|(]|[[:space:]])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+(add|stage)([[:space:]]|$)'
[ -n "$kind" ] || exit 0

dir=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
[ -n "$dir" ] && [ -d "$dir" ] || dir=${CLAUDE_PROJECT_DIR:-.}
# A leading `cd <dir> &&` moves the command; follow it.
re_cd='^[[:space:]]*cd[[:space:]]+"?([^"&;]*[^"&;[:space:]])"?[[:space:]]*&&'
if [[ $cmd =~ $re_cd ]]; then
  d=${BASH_REMATCH[1]}
  [[ $d == /* || $d =~ ^[A-Za-z]: ]] || d=$dir/$d
  [ -d "$d" ] && dir=$d
fi
# `git -C <dir> commit` runs there.
re_gc='git[[:space:]]+-C[[:space:]]+"?([^"[:space:]]+)"?'
if [[ $kind == *commit* && $cmd =~ $re_gc ]]; then
  d=${BASH_REMATCH[1]}
  [[ $d == /* || $d =~ ^[A-Za-z]: ]] || d=$dir/$d
  [ -d "$d" ] && dir=$d
fi
cd "$dir" 2>/dev/null || exit 0
top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
list=$top/.ai/private-names.txt
if [ ! -f "$list" ]; then
  common=$(cd "$top" && cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd)
  list=${common%/.git}/.ai/private-names.txt
fi
[ -f "$list" ] || exit 0
pf=$(mktemp) || exit 0
trap 'rm -f "$pf"' EXIT
# Drop CR, a UTF-8 BOM, padding, comments and blank lines (a blank pattern
# would match everything).
tr -d '\r' < "$list" | LC_ALL=C sed -e $'1s/^\xEF\xBB\xBF//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^#/d' -e '/^$/d' > "$pf"
[ -s "$pf" ] || exit 0

# Added lines and the changed paths (a name in a file name counts too).
added() {
  git diff --no-color --no-ext-diff -U0 "$@" 2>/dev/null | grep '^+' | grep -vE '^\+\+\+ (a/|b/|/dev/null)'
  git -c core.quotepath=off diff --name-only --no-renames "$@" 2>/dev/null
}
text=$cmd
# A message or body read from a file (-F, --file, --body-file).
re_file='(--body-file|--file|-F)[= ]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^[:space:]]+)'
while IFS= read -r f; do
  f=${f#\"}; f=${f%\"}; f=${f#\'}; f=${f%\'}
  [ -n "$f" ] && [ -f "$f" ] && text+=$'\n'$(cat -- "$f")
done < <(grep -oE "$re_file" <<<"$cmd" | sed -E 's/^(--body-file|--file|-F)[= ]+//')
if [[ $kind == *commit* ]]; then
  # Staged and unstaged (commit -a, a chained git add); new files only when
  # the command runs `git add` too.
  if git rev-parse --verify -q HEAD >/dev/null; then text+=$'\n'$(added HEAD); else text+=$'\n'$(added --cached); fi
  if [[ $cmd =~ $re_add ]]; then
    new=$(git -C "$top" -c core.quotepath=off ls-files -o --exclude-standard 2>/dev/null | grep -vxF .ai/private-names.txt)
    text+=$'\n'$new
  fi
fi
if [[ $kind == *pr* ]]; then
  base=main
  git rev-parse --verify -q origin/main >/dev/null && base=origin/main
  text+=$'\n'$(added "$base...HEAD")
fi
hits=$( {
  grep -oiF -f "$pf" <<<"$text"
  # New files' content; binary files are skipped.
  [ -n "${new:-}" ] && (cd "$top" && while IFS= read -r f; do [ -f "$f" ] && grep -IhoiF -f "$pf" -- "$f"; done <<<"$new")
} | sort -fu | paste -sd, -)
[ -n "$hits" ] || exit 0
cat >&2 <<MSG
Blocked: this ${kind/+/ and } holds a private project name ($hits), listed in
.ai/private-names.txt. This repo is public (AGENTS.md): write "a consuming
project" or the fixed letter (project A, B, C) instead, in the message, the
PR text and the added lines, then run it again.
MSG
exit 2
