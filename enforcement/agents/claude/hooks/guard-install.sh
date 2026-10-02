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
