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
#   the PR's branch has local commits that were never pushed, and a PR that
#   changes sensitive code or a safety file needs the owner's typed
#   "duyệt merge PR <n>" (approval-record.sh records it).
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
# A git push: `push` is git's subcommand (after git's own options such as
# -C dir), not a word later on (git stash push, echo "...push...").
gitpush='(^|[[:space:]])git([[:space:]]+(-c[[:space:]]+[^[:space:]]+|-[^[:space:]]+))*[[:space:]]+push([[:space:]]|$)'

why=""
fix=""
if grep -qE -- '-m[[:space:]]+pip[[:space:]]+install([[:space:]]|$)|(^|[^[:alnum:]_.-])pip3?(\.exe)?[[:space:]]+install([[:space:]]|$)' <<<"$low" &&
   ! grep -q 'venv' <<<"$low"; then
  why="pip install outside the project's .venv installs into the system Python."
elif grep -qE '(^|[^[:alnum:]_.-])npm(\.cmd)?[[:space:]]+(install|i|add)([[:space:]].*)?[[:space:]](-g|--global)([[:space:]]|$)' <<<"$low"; then
  why="npm install -g installs globally, outside the project."
fi

# Merge inside a script the command runs (bash x.sh, ./x.sh, pwsh -File
# x.ps1, python x.py): the checks below cannot see it, so it is blocked even
# when it waits for CI. Catches a merge put in a script by mistake, not one
# hidden on purpose. Files Lodestar manages (they hold merge commands as
# test text) are skipped.
if [ -z "$why" ]; then
  base=${cwd:-${CLAUDE_PROJECT_DIR:-.}}; base=${base//"$bs"//}
  while IFS= read -r name; do
    s=${name//"$bs"//}; [[ $s == /* || $s =~ ^[a-zA-Z]: ]] || s=$base/$s
    [ -f "$s" ] || continue
    [[ $s =~ (^|/)(enforcement|\.claude/hooks|\.codex)/ ]] && continue
    head -3 "$s" | grep -q 'Managed by lodestar-harness' && continue
    if tr -d "\r\"'," < "$s" | tr '[:upper:]' '[:lower:]' |
       grep -qE '(^|[^[:alnum:]_-])gh(\.exe)?[[:space:]]+([^;|&]*[[:space:]])?pr[[:space:]]+merge([^[:alnum:]_-]|$)|pulls/[^[:space:]]+/merge|mergepullrequest|enablepullrequestautomerge'; then
      why="the script $name merges a PR, and a merge inside a script skips the CI-wait and owner-approval checks."
      fix='Run the merge directly as its own command, not from a script file:
if gh pr checks <n> --watch; then gh pr merge <n> --merge; fi'
      break
    fi
  done < <(grep -oE "[^[:space:]\"';|&()]+\.(sh|bash|ps1|py|cmd|bat|js|mjs)([[:space:]\"';|&)]|$)" <<<"$cmd" | sed -E "s/[[:space:]\"';|&)]+$//")
fi

# Merge: drop each gated merge; any merge left is ungated. Matches gh under
# any spelling (gh.exe, /usr/bin/gh, VAR=x gh, gh -R o/r, inside bash -c,
# eval, backticks, an else branch, quoted) and `gh api .../pulls/<n>/merge
# -X PUT`. A GraphQL merge (mergePullRequest, auto-merge) is blocked too.
if [ -z "$why" ]; then
  flat=$(tr '\n' ';' <<<"$low" | tr -d "\"'" | sed -E 's/[0-9]?>&[0-9]//g')
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
  elif grep -qE '(^|[^[:alnum:]_-])gh(\.exe)?[[:space:]]' <<<"$flat" && grep -qE 'mergepullrequest|enablepullrequestautomerge' <<<"$flat"; then
    why="merging through the GraphQL API skips the CI wait and the merge checks."
    fix='Use exactly: if gh pr checks <n> --watch; then gh pr merge <n> --merge; fi'
  fi
fi

# Merge: two checks for each merged PR. gh cannot read the PR, another repo
# (-R, --repo, GH_REPO), or a push in the same command (the PR would change
# after this check): blocked.
# 1. A commit on the PR's branch that was never pushed is left out of the
#    merge without a warning (PR #36 lost one this way). Compares the local
#    branch with its origin copy; none, or a fork PR: skipped.
# 2. Owner-only merge (rules/git.md): a PR that changes (or renames away) a
#    file in sensitive_paths, a locked test, or a safety file (hooks, CI,
#    project rules) merges only after the owner typed "duyệt merge PR <n>"
#    (.ai/approvals.log, written by approval-record.sh), with
#    --match-head-commit <that head>, so GitHub refuses a newer head. No
#    --auto: GitHub would merge later, after this check.
# Known limit: a merge hidden on purpose (a script without a known extension,
# or one written and run in the same command) is not seen; CI and the
# owner's review of PRs stay the backstop.
if [ -z "$why" ] && grep -qE '(^|[^[:alnum:]_-])gh(\.exe)?[[:space:]]+([^;|&]*[[:space:]])?pr[[:space:]]+merge([^[:alnum:]_-]|$)' <<<"$low"; then
  here=${cwd:-${CLAUDE_PROJECT_DIR:-.}}
  proj=${CLAUDE_PROJECT_DIR:-$here}
  to=""; command -v timeout >/dev/null && to="timeout 15"
  if grep -qE "$gitpush" <<<"$low"; then
    why="a push in the same command as the merge changes the PR after this check."
    fix="Push in one command, then merge in the next: if gh pr checks <n> --watch; then gh pr merge <n> --merge; fi"
  elif grep -qE '(^|[^[:alnum:]_])gh_repo=' <<<"$low"; then
    why="a merge with GH_REPO set (another repo) cannot be checked from here."
    fix="Ask the owner to merge it on GitHub."
  fi
  # Owner-only files: the safety files, then the project's sensitive_paths and
  # locked tests, lower case, without ./ and comments. A pattern with no glob
  # also covers the folder of that name.
  pats=$({ printf '%s\n' .claude/ .codex/ .github/ enforcement/ .ai/project.md .ai/enforcement.json .ai/test-lock
    [ -f "$proj/.ai/project.md" ] && sed -n '/^sensitive_paths:/,/^[^[:space:]-]/p' "$proj/.ai/project.md" | sed -n 's/^[[:space:]]*-[[:space:]]*//p'
    [ -f "$proj/.ai/test-lock" ] && sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$proj/.ai/test-lock"
  } | tr -d "\"'\r" | sed -E 's/[[:space:]]+#.*//; s/[[:space:]]+$//; s#^\./##' | tr '[:upper:]' '[:lower:]')
  # Each merge: its selector (number, branch or URL) is the first argument
  # that is not a flag or a flag's value; none means the current branch.
  while [ -z "$why" ] && IFS= read -r m; do
    if grep -qE '(^|[[:space:]])(-R|--repo)([[:space:]=]|$)' <<<"$m"; then
      why="a merge in another repo (-R) cannot be checked from here."
      fix="Ask the owner to merge it on GitHub."; break
    fi
    read -ra toks <<<"$(sed -E 's/.*[[:space:]][pP][rR][[:space:]]+[mM][eE][rR][gG][eE]//' <<<"$m")"
    sel=""; skip=0; match=""; auto=0; prev=""
    for tk in "${toks[@]}"; do
      tk=${tk//[\"\']/}
      if [ $skip = 1 ]; then skip=0; [ "$prev" = --match-head-commit ] && match=$tk; continue; fi
      case $tk in
        -b|--body|-t|--subject|-F|--body-file|-A|--author-email|--match-head-commit) skip=1; prev=$tk ;;
        --match-head-commit=*) match=${tk#*=} ;;
        --auto) auto=1 ;;
        -*) ;;
        *) [ -z "$sel" ] && sel=$tk ;;
      esac
    done
    info=$(cd "$here" 2>/dev/null && $to gh pr view ${sel:+"$sel"} --json number,headRefName,headRefOid,isCrossRepository \
      -q '"\(.number) \(.headRefName) \(.headRefOid) \(.isCrossRepository)"' 2>/dev/null | tr -d '\r')
    read -r num h oid cross <<<"$info"
    # Every file, past gh pr view's 100, with a rename's old path too.
    files=""
    [ -n "$oid" ] && files=$(cd "$here" 2>/dev/null && $to gh api --paginate "repos/{owner}/{repo}/pulls/$num/files" \
      --jq '.[] | .filename, (.previous_filename // empty)' 2>/dev/null | tr -d '\r')
    if [ -z "$oid" ] || [ -z "$files" ]; then
      why="gh could not read the PR or its files, so the merge cannot be checked."
      fix="Check that gh works (gh auth status) and retry, or ask the owner to merge it."; break
    fi
    left=0
    [ "$cross" != true ] && left=$(git -C "$here" rev-list --count "refs/remotes/origin/$h..refs/heads/$h" 2>/dev/null)
    if [ "${left:-0}" -gt 0 ]; then
      why="branch $h has $left local commit(s) that were never pushed; the merge would leave them out."
      fix="Push the branch first (git push), then merge behind the CI wait as usual."; break
    fi
    hit=""
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      lf=${f,,}
      while IFS= read -r pat; do
        [ -n "$pat" ] || continue
        case $pat in
          */) [[ $lf == "$pat"* ]] && hit=$f ;;
          *[*?[]*) [[ $lf == $pat ]] && hit=$f ;;
          *) [[ $lf == "$pat" || $lf == "$pat"/* ]] && hit=$f ;;
        esac
        [ -n "$hit" ] && break
      done <<<"$pats"
      [ -n "$hit" ] && break
    done <<<"$files"
    [ -n "$hit" ] || continue
    if ! tr -d '\r' < "$proj/.ai/approvals.log" 2>/dev/null | grep -qE "[[:space:]]merge-pr[[:space:]]+$num[[:space:]]+$oid\$"; then
      why="PR #$num changes $hit (sensitive code or a safety file), so only the owner approves its merge."
      fix="Tell the owner what the PR changes and how it was checked, then ask them to type \"duyệt merge PR $num\" (or \"approve merge PR $num\"). A new push needs a new approval."; break
    fi
    if [ $auto = 1 ] || [ "${match,,}" != "${oid,,}" ]; then
      why="PR #$num is approved by the owner at $oid only; without --match-head-commit (or with --auto) GitHub could merge a newer head."
      fix="Merge with: if gh pr checks $num --watch; then gh pr merge $num --merge --match-head-commit $oid; fi"; break
    fi
  done < <(tr '\n' ';' <<<"$cmd" | grep -oiE 'gh(\.exe)?[[:space:]]+([^;|&}]*[[:space:]])?pr[[:space:]]+merge([[:space:]][^;|&}]*)?')
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
    grep -qE "$gitpush" <<<"$seg" || continue
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
