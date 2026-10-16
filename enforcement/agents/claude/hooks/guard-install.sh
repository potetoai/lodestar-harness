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
#   exit 0 on a red CI, so they merge anyway. A merge is also blocked while
#   the PR's branch has local commits that were never pushed.
# - a prototype branch (proto/*) stays local: blocks pushing or renaming one,
#   and any push run in its checkout or worktree (or --all while one exists).
# - a Tests-First commit must carry an owner-approved plan. Blocks
#   `git commit` with a "Tests-First:" message when no changed plan has
#   approved criteria, or when the plan or .ai/approvals.log would be left
#   out of the commit (CI would fail the PR; this catches it first).
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input" | tr -d '\r')
# The session folder: a push is judged from where it runs (a prototype lives
# in its own worktree). Falls back to the project folder.
bs='\'   # Windows paths: backslashes become slashes
cwd=$(jq -r '.cwd // empty' <<<"$input"); cwd=${cwd//"$bs"//}
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

# Merge: a commit on the PR's branch that was never pushed is left out of the
# merge without a warning (PR #36 lost one this way). Compares the local branch
# with its origin copy; no origin copy, another repo (-R), a fork PR, or gh
# cannot name the branch: allowed. A push before the merge in the same command
# is trusted (the hook runs before it).
pre=$(sed -E 's/pr[[:space:]]+merge.*//' <<<"$low")
if [ -z "$why" ] && grep -qE '(^|[^[:alnum:]_-])gh(\.exe)?[[:space:]]+([^;|&]*[[:space:]])?pr[[:space:]]+merge([^[:alnum:]_-]|$)' <<<"$low" &&
   ! grep -qE '(^|[[:space:]])git[[:space:]]+([^;|&]*[[:space:]])?push([[:space:]]|$)' <<<"$pre"; then
  here=${cwd:-${CLAUDE_PROJECT_DIR:-.}}
  if [ -n "$(git -C "$here" for-each-ref --count=1 refs/remotes/origin/ 2>/dev/null)" ]; then
    to=""; command -v timeout >/dev/null && to="timeout 8"
    heads=""
    # Each merge: its selector (number, branch or URL) is the first argument
    # that is not a flag or a flag's value; none means the current branch.
    while IFS= read -r m; do
      grep -qE '(^|[[:space:]])(-R|--repo)([[:space:]=]|$)' <<<"$m" && continue
      read -ra toks <<<"$(sed -E 's/.*[[:space:]][pP][rR][[:space:]]+[mM][eE][rR][gG][eE]//' <<<"$m")"
      sel=""; skip=0
      for tk in "${toks[@]}"; do
        [ $skip = 1 ] && { skip=0; continue; }
        case $tk in
          -b|--body|-t|--subject|-F|--body-file|-A|--author-email|--match-head-commit) skip=1 ;;
          -*) ;;
          *) sel=${tk//[\"\']/}; break ;;
        esac
      done
      if [ -n "$sel" ]; then
        heads+=$(cd "$here" 2>/dev/null && $to gh pr view "$sel" --json headRefName,isCrossRepository \
          -q 'if .isCrossRepository then "" else .headRefName end' 2>/dev/null | tr -d '\r')$'\n'
      else
        heads+=$(git -C "$here" symbolic-ref --short -q HEAD 2>/dev/null)$'\n'
      fi
    done < <(tr '\n' ';' <<<"$cmd" | grep -oiE 'gh(\.exe)?[[:space:]]+([^;|&}]*[[:space:]])?pr[[:space:]]+merge([[:space:]][^;|&}]*)?')
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      left=$(git -C "$here" rev-list --count "refs/remotes/origin/$h..refs/heads/$h" 2>/dev/null)
      if [ "${left:-0}" -gt 0 ]; then
        why="branch $h has $left local commit(s) that were never pushed; the merge would leave them out."
        fix="Push the branch first (git push), then merge behind the CI wait as usual."
        break
      fi
    done <<<"$heads"
  fi
fi

# Git: look at each command of a chain (a && b; c | d) on its own.
if [ -z "$why" ]; then
  dir=${cwd:-${CLAUDE_PROJECT_DIR:-.}}
  # dir_of PATH: a folder the command names (cd X, git -C X), resolved against $dir.
  dir_of() { local d=${1//[\"\']/}; d=${d//"$bs"//}; [[ $d == /* || $d =~ ^[A-Za-z]: ]] && echo "$d" || echo "$dir/$d"; }
  # Protected: main, master, and the remote's default branch (develop, trunk...).
  default=$(git -C "${CLAUDE_PROJECT_DIR:-.}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
  default=${default#origin/}; default=${default,,}; default=${default//./\.}
  prot="main|master${default:+|$default}"
  while IFS= read -r raw; do
    seg=${raw,,}
    if [[ $raw =~ ^[[:space:]]*cd[[:space:]]+([^[:space:]]+)[[:space:]]*$ ]]; then dir=$(dir_of "${BASH_REMATCH[1]}"); continue; fi
    grep -qE '(^|[[:space:]])git([[:space:]]|$)' <<<"$seg" || continue
    at=$dir
    [[ $raw =~ (^|[[:space:]])git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]] && at=$(dir_of "${BASH_REMATCH[2]}")
    branch=$(git -C "$at" symbolic-ref --short -q HEAD 2>/dev/null)
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
    grep -qE '[[:space:]]push([[:space:]]|$)' <<<"$seg" || continue
    # A prototype branch never leaves the machine (workflows/prototype.md):
    # no push of a proto/* branch, and no push at all while on one.
    if grep -qE '[[:space:]:+"'"'"'=](refs/heads/)?proto/' <<<"$seg" || [[ "${branch,,}" == proto/* ]] ||
       { grep -qE -- '(^|[[:space:]])--(all|mirror)([[:space:]=]|$)' <<<"$seg" &&
         [ -n "$(git -C "$at" for-each-ref --count=1 refs/heads/proto/ 2>/dev/null)" ]; }; then
      why="a prototype branch (proto/*) is thrown away, never pushed or merged."
      fix="Write down what the prototype showed, then build the real change on a new branch from main (workflows/prototype.md)."
      break
    fi
    if grep -qE "[[:space:]:+](refs/heads/)?($prot)([[:space:]]|\$)" <<<"$seg"; then
      why="git push to a protected branch ($prot) skips the PR and its CI."
    else
      # No branch named: git pushes the current branch.
      args=$(sed -E 's/.*[[:space:]]push([[:space:]]|$)//' <<<"$seg" | tr ' ' '\n' | grep -v '^-' | grep -c .)
      [ "$args" -le 1 ] && [[ "${branch,,}" =~ ^($prot)$ ]] && why="git push from a protected branch ($prot) skips the PR and its CI."
    fi
    [ -n "$why" ] && { fix="Create a branch, push it, open a PR, and merge when CI is green."; break; }
  done < <(sed -E 's/(&&|\|\||[;|])/\n/g' <<<"$cmd")
fi

# Tests-First commit: the plan and approvals.log must be in it, approved.
if [ -z "$why" ] && grep -qE '(^|[[:space:]])git[[:space:]]+([^;|&]*[[:space:]])?commit([[:space:]]|$)' <<<"$cmd" &&
   grep -qE '(^|["'"'"'[:space:]])Tests-First:' <<<"$cmd"; then
  why=$(cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null && . .claude/hooks/lodestar-lib.sh 2>/dev/null && {
    st=$(git -c core.quotepath=off status --porcelain -uall 2>/dev/null)
    staging=1; grep -qE 'git[[:space:]]+add([[:space:]]|$)|commit[[:space:]]+([^;|&]*[[:space:]])?-[a-z]*a' <<<"$low" && staging=0
    ok=0; left=""
    while IFS= read -r p; do
      [[ $p == .ai/plans/*.md ]] && [ -f "$p" ] && plan_approved_now "$p" && ok=1
    done < <(sed -n 's/^.. //p' <<<"$st")
    if git check-ignore -q .ai/approvals.log 2>/dev/null; then
      echo ".ai/approvals.log is gitignored, so the approval cannot be part of the commit."
    elif [ $ok = 0 ]; then
      echo "no changed plan under .ai/plans/ has criteria the owner approved (.ai/approvals.log)."
    elif [ $staging = 1 ]; then
      while IFS= read -r l; do
        f=${l:3}
        [[ $f == .ai/approvals.log || $f == .ai/plans/*.md ]] || continue
        [ "${l:1:1}" != " " ] && left+=" $f"
      done <<<"$st"
      [ -n "$left" ] && echo "not staged for this commit:$left."
    fi
  })
  if [ -n "$why" ]; then
    why="a Tests-First commit would fail CI: $why"
    fix='Get the owner approval first (they reply "duyệt" or "approve"), then `git add` the plan and .ai/approvals.log, then commit.'
  fi
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
