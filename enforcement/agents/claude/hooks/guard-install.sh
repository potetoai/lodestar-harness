#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# PreToolUse (Bash|PowerShell), rules/enforcement.md section 6:
# - installs stay in the project. Blocks pip installs outside a venv and
#   global npm installs. Allowed: anything through .venv, `make setup`,
#   `pip download` (the clean-machine check), local `npm install`.
# - a PR is merged only by merge-pr.sh, which checks state (green CI, no
#   unpushed commits, the owner's approval). Every other merge command is
#   blocked, however it is written.
# - git hooks stay on: blocks --no-verify, commit -n and changing
#   core.hooksPath. Pushes to main and of prototype branches are blocked by
#   git's own pre-push hook (pre-push.sh), which sees the pushed refs.
# - a prototype branch (proto/*) is never renamed to or from real work.
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input" | tr -d '\r')
[ -n "$cmd" ] || exit 0
# Text, not commands: the body of a quoted heredoc fed to cat or tee
# (cat <<'EOF' > file, git commit -m "$(cat <<'EOF' ...)") or to
# git commit -F - is never run, so the checks below skip it; a handoff or a
# commit message may quote a merge.
# A heredoc fed to a shell or an interpreter (bash, python), unquoted (its
# $(...) runs), or piped on to another command stays checked.
cmd=$(awk '
  function word(s,  a) {
    sub(/^[[:space:]]+/, "", s)
    while (match(s, /^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+/)) s = substr(s, RLENGTH + 1)
    split(s, a, /[[:space:]]+/); s = tolower(a[1]); gsub(/["\047]/, "", s)
    sub(/.*\//, "", s); sub(/\.exe$/, "", s); return s
  }
  skip { t = $0; if (dash) sub(/^\t+/, "", t); if (t == delim) skip = 0; next }
  { print }
  match($0, /<<-?[[:space:]]*(\047[A-Za-z_][A-Za-z0-9_]*\047|"[A-Za-z_][A-Za-z0-9_]*")/) {
    pre = substr($0, 1, RSTART - 1); op = substr($0, RSTART, RLENGTH); post = substr($0, RSTART + RLENGTH)
    if (pre ~ /<$/ || post ~ /\||<</) next
    n = split(pre, parts, /;|&&|\|\||\|/); outer = word(parts[n]); inner = parts[n]
    if (match(inner, /.*[(`]/)) inner = substr(inner, RLENGTH + 1)
    inner = word(inner)
    if (((inner == "cat" || inner == "tee") && (outer == "cat" || outer == "tee" || outer == "git")) ||
        (inner == "git" && parts[n] ~ /[[:space:]]commit[[:space:]]/)) {
      dash = (op ~ /^<<-/); delim = op; sub(/^<<-?[[:space:]]*/, "", delim); gsub(/["\047]/, "", delim); skip = 1
    }
  }' <<<"$cmd")
low=${cmd,,}

why=""
fix=""
if grep -qE -- '-m[[:space:]]+pip[[:space:]]+install([[:space:]]|$)|(^|[^[:alnum:]_.-])pip3?(\.exe)?[[:space:]]+install([[:space:]]|$)' <<<"$low" &&
   ! grep -q 'venv' <<<"$low"; then
  why="pip install outside the project's .venv installs into the system Python."
elif grep -qE '(^|[^[:alnum:]_.-])npm(\.cmd)?[[:space:]]+(install|i|add)([[:space:]].*)?[[:space:]](-g|--global)([[:space:]]|$)' <<<"$low"; then
  why="npm install -g installs globally, outside the project."
fi

# Merge: only through merge-pr.sh. Matches gh under any spelling (gh.exe,
# /usr/bin/gh, VAR=x gh, gh -R o/r, inside bash -c, eval, backticks, quoted),
# `gh api .../pulls/<n>/merge -X PUT`, and the GraphQL merge mutations.
# Running merge-pr.sh itself is not a merge command here.
if [ -z "$why" ]; then
  flat=$(tr '\n' ';' <<<"$low" | tr -d "\"'")
  if grep -qE '(^|[^[:alnum:]_-])gh(\.exe)?[[:space:]]+([^;|&]*[[:space:]])?pr[[:space:]]+merge([^[:alnum:]_-]|$)' <<<"$flat" ||
     { grep -qE '(^|[^[:alnum:]_-])gh(\.exe)?[[:space:]].*pulls/[^[:space:]]+/merge' <<<"$flat" &&
       grep -qE -- '(-x|--method)[[:space:]=]*put' <<<"$flat"; } ||
     { grep -qE '(^|[^[:alnum:]_-])gh(\.exe)?[[:space:]]' <<<"$flat" && grep -qE 'mergepullrequest|enablepullrequestautomerge' <<<"$flat"; }; then
    why="a PR is merged only by the merge script: it waits for green CI and checks unpushed commits and the owner's approval."
    fix='Run: bash .claude/hooks/merge-pr.sh <n>   (options: --squash, --rebase, --delete-branch)
It waits for CI, so give the command a long timeout (or run it in the background).
If "gh pr merge" is only text in a commit message or a file, write that text with the Write tool.'
  fi
fi

# Git: look at each command of a chain (a && b; c | d) on its own.
if [ -z "$why" ]; then
  while IFS= read -r seg; do
    seg=${seg,,}
    grep -qE '(^|[[:space:]])git([[:space:]]|$)' <<<"$seg" || continue
    # A prototype is never renamed into real work, or real work into one.
    if grep -qE '[[:space:]]branch[[:space:]]' <<<"$seg" && grep -qE '(^|[[:space:]])(-[a-z]*[mc][a-z]*|--move|--copy)([[:space:]]|$)' <<<"$seg" &&
       grep -qE '(^|[[:space:]])(refs/heads/)?proto/' <<<"$seg"; then
      why="renaming or copying a branch to or from proto/* mixes a throwaway prototype with real work."
      fix="Keep the prototype on its proto/* branch and delete it when done; build the real change on a new branch from main (workflows/prototype.md)."
      break
    fi
    if grep -qE -- '(^|[[:space:]])--no-verify([[:space:]=]|$)' <<<"$seg" ||
       grep -qE '[[:space:]]commit([[:space:]]+[^"'"'"']*)?[[:space:]]-[a-z]*n[a-z]*([[:space:]]|$)' <<<"$seg"; then
      why="--no-verify (or commit -n) skips the project's git hooks."
      fix="Run the command without it and fix what the hooks report."
      break
    fi
    # core.hooksPath moves git away from .git/hooks, where pre-push lives.
    if grep -qE -- '-c[[:space:]]+core\.hookspath=|[[:space:]]config[[:space:]].*core\.hookspath[[:space:]]+[^[:space:]-]|--unset(-all)?[[:space:]]+core\.hookspath' <<<"$seg"; then
      why="changing core.hooksPath turns off the project's git hooks (the pre-push check)."
      fix="Leave core.hooksPath as it is."
      break
    fi
  done < <(sed -E 's/(&&|\|\||[;|])/\n/g' <<<"$cmd")
fi

[ -z "$why" ] && exit 0

if [ -n "$fix" ]; then
  printf 'Blocked: %s\n%s\nIf the owner really wants it, ask them to run it themselves.\n' "$why" "$fix" >&2
  exit 2
fi
cat >&2 <<EOT
Blocked: $why
Install into the project instead: run \`make setup\`, or use the venv's python
(.venv/Scripts/python.exe -m pip install ... on Windows, .venv/bin/python on
macOS/Linux) and local node_modules (npm install, no -g). If the project needs
packages that exist only in the system Python, create the venv with
VENV_ARGS=--system-site-packages. If the owner really wants a machine-wide
install, ask them to run it themselves.
EOT
exit 2
