#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# PreToolUse (Bash|PowerShell), rules/enforcement.md section 1:
# - installs stay in the project. Blocks pip installs outside a venv and
#   global npm installs. Allowed: anything through .venv, `make setup`,
#   `pip download` (the clean-machine check), local `npm install`.
# - main changes only through a PR. Blocks `git push` to main, master or the
#   remote's default branch, and skipping git hooks (--no-verify, commit -n).
#   This covers repos where GitHub cannot lock main (private repo on GitHub
#   Free, doctor C1).
# - merge only on green CI. Every `gh pr merge` must sit behind the CI wait's
#   own exit code: `if gh pr checks <n> --watch; then gh pr merge <n>; fi`
#   (PowerShell: `gh pr checks <n> --watch; if ($LASTEXITCODE -eq 0) {...}`).
#   `gh pr view && gh pr merge` or `gh pr checks | tail && gh pr merge`
#   exit 0 on a red CI, so they merge anyway.
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0

cmd=$(jq -r '.tool_input.command // empty' | tr -d '\r')
[ -n "$cmd" ] || exit 0
low=${cmd,,}

why=""
fix=""
if grep -qE -- '-m[[:space:]]+pip[[:space:]]+install([[:space:]]|$)|(^|[^[:alnum:]_.-])pip3?(\.exe)?[[:space:]]+install([[:space:]]|$)' <<<"$low" &&
   ! grep -q 'venv' <<<"$low"; then
  why="pip install outside the project's .venv installs into the system Python."
elif grep -qE '(^|[^[:alnum:]_.-])npm(\.cmd)?[[:space:]]+(install|i|add)([[:space:]].*)?[[:space:]](-g|--global)([[:space:]]|$)' <<<"$low"; then
  why="npm install -g installs globally, outside the project."
fi

# Merge: drop each gated merge; any merge left is ungated. Matches gh under
# any spelling (gh.exe, /usr/bin/gh, VAR=x gh, gh -R o/r, inside bash -c,
# eval, backticks, an else branch) and `gh api .../pulls/<n>/merge -X PUT`.
if [ -z "$why" ]; then
  flat=$(tr '\n' ';' <<<"$low" | sed -E 's/[0-9]?>&[0-9]//g')
  wait='gh[[:space:]]+pr[[:space:]]+checks[^;|&]*[[:space:]]--watch[^;|&]*;[[:space:]]*'
  merge='gh[[:space:]]+pr[[:space:]]+merge[^;|&}]*'
  ps='if[[:space:]]*\([[:space:]]*(\$lastexitcode[[:space:]]+-eq[[:space:]]+0|\$\?)[[:space:]]*\)[[:space:]]*\{[[:space:]]*'
  flat=$(sed -E "s/if[[:space:]]+${wait}then[[:space:];]+${merge}//g; s/${wait}${ps}${merge}//g" <<<"$flat")
  if grep -qE '(^|[^[:alnum:]_-])gh(\.exe)?[[:space:]]+([^;|&]*[[:space:]])?pr[[:space:]]+merge([^[:alnum:]_-]|$)' <<<"$flat" ||
     { grep -qE '(^|[^[:alnum:]_-])gh(\.exe)?[[:space:]].*pulls/[^[:space:]]+/merge' <<<"$flat" &&
       grep -qE -- '(-x|--method)[[:space:]=]*put' <<<"$flat"; }; then
    why="this merge does not wait for green CI: a view, checks piped into tail, or an else branch merges on a red CI."
    fix='Use exactly: if gh pr checks <n> --watch; then gh pr merge <n> --merge; fi
(PowerShell: gh pr checks <n> --watch; if ($LASTEXITCODE -eq 0) { gh pr merge <n> --merge })
If "gh pr merge" is only text in a commit message or a file, write that text with the Write tool.'
  fi
fi

# Git: look at each command of a chain (a && b; c | d) on its own.
if [ -z "$why" ]; then
  branch=$(git -C "${CLAUDE_PROJECT_DIR:-.}" symbolic-ref --short HEAD 2>/dev/null)
  # Protected: main, master, and the remote's default branch (develop, trunk...).
  default=$(git -C "${CLAUDE_PROJECT_DIR:-.}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
  default=${default#origin/}; default=${default,,}; default=${default//./\.}
  prot="main|master${default:+|$default}"
  while IFS= read -r seg; do
    grep -qE '(^|[[:space:]])git([[:space:]]|$)' <<<"$seg" || continue
    if grep -qE -- '(^|[[:space:]])--no-verify([[:space:]=]|$)' <<<"$seg" ||
       grep -qE '[[:space:]]commit([[:space:]]+[^"'"'"']*)?[[:space:]]-[a-z]*n[a-z]*([[:space:]]|$)' <<<"$seg"; then
      why="--no-verify (or commit -n) skips the project's git hooks."
      fix="Run the command without it and fix what the hooks report."
      break
    fi
    grep -qE '[[:space:]]push([[:space:]]|$)' <<<"$seg" || continue
    if grep -qE "[[:space:]:+](refs/heads/)?($prot)([[:space:]]|\$)" <<<"$seg"; then
      why="git push to a protected branch ($prot) skips the PR and its CI."
    else
      # No branch named: git pushes the current branch.
      args=$(sed -E 's/.*[[:space:]]push([[:space:]]|$)//' <<<"$seg" | tr ' ' '\n' | grep -v '^-' | grep -c .)
      [ "$args" -le 1 ] && [[ "${branch,,}" =~ ^($prot)$ ]] && why="git push from a protected branch ($prot) skips the PR and its CI."
    fi
    [ -n "$why" ] && { fix="Create a branch, push it, open a PR, and merge when CI is green."; break; }
  done < <(sed -E 's/(&&|\|\||[;|])/\n/g' <<<"$low")
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
