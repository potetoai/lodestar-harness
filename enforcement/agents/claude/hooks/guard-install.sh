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
# - the text of `gh pr create` (and of `gh pr edit` with new text) passes
#   the route rules CI checks, before the PR is sent.
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input" | tr -d '\r')
[ -n "$cmd" ] || exit 0
raw=${cmd//$'\\\n'/ }  # a backslash-newline continues the line
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

# PR text: checked with the rules CI uses (route_problem in lodestar-lib.sh),
# so a missing or malformed route or review line is fixed before the PR is
# sent, not after a red CI run. Only a gh command at a command position
# counts (not one named in a commit message). Text the guard cannot read (a
# file not there, stdin, $(...) or a variable) and PRs of another repo (-R)
# are left to CI.
pr_re='(^|[;&|({`]|\$\(|[[:space:]](then|do|else))[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*([^[:space:];|&]*/)?gh(\.exe)?([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+pr[[:space:]]+(create|edit)([[:space:];]|$)'
# heredoc_text TEXT: the lines of the first heredoc in TEXT, or status 1.
heredoc_text() {
  local re="<<(-?)[[:space:]]*[\"']?([A-Za-z_][A-Za-z0-9_]*)[\"']?" t
  [[ $1 =~ $re ]] || return 1
  t=${1#*"${BASH_REMATCH[0]}"}; t=${t#*$'\n'}
  # <<- drops the leading tabs of every line, as bash does.
  awk -v dash="${BASH_REMATCH[1]}" -v d="${BASH_REMATCH[2]}" '
    dash != "" { sub(/^\t+/, "") } $0 == d { f = 1; exit } { print } END { exit !f }' <<<"$t"
}
# pr_text_problem: why the PR text would fail, or nothing.
pr_text_problem() {
  local one m pre seg l1 sub re f v body base head from n out oid commits="?" changed=""
  one=${raw//$'\n'/;}
  [[ $one =~ $pr_re ]] || return 0
  m=${BASH_REMATCH[0]}; pre=${one%%"$m"*}; seg=${raw:$((${#pre} + ${#m}))}; l1=${seg%%$'\n'*}
  [[ $m =~ (create|edit)[[:space:]\;]*$ ]]; sub=${BASH_REMATCH[1]}
  re='(^|[[:space:]])(-R|--repo)([=[:space:]])'; [[ $m =~ $re || $l1 =~ $re ]] && return 0
  re="(^|[[:space:]])(--body-file|-F)(=|[[:space:]]+)(\"[^\"]*\"|'[^']*'|[^[:space:];|&]+)"
  if [[ $l1 =~ $re ]]; then
    f=${BASH_REMATCH[4]//[\"\']/}
    if [ "$f" = - ]; then body=$(heredoc_text "$seg") || return 0
    # A file this command writes (cat > f <<EOF ... && gh pr create -F f)
    # is not there yet: its text is in the command.
    elif grep -qE "(>|tee([[:space:]]+-a)?)[[:space:]]*[\"']?${f//./\.}[\"']?([[:space:]]|$)" <<<"$raw"; then body=$raw
    elif [ -r "$f" ]; then body=$(cat "$f")
    else return 0; fi
  elif re='(^|[[:space:]])(--body|-b)(=|[[:space:]]+)' && [[ $l1 =~ $re ]]; then
    v=${seg#*"${BASH_REMATCH[0]}"}
    case $v in
      "'"*) v=${v:1}; [[ $v == *"'"* ]] || return 0; body=${v%%"'"*} ;;
      '"$(cat <<'*) body=$(heredoc_text "$v") || return 0 ;;
      '"'*) v=${v:1}; [[ $v == *'"'* ]] || return 0; body=${v%%'"'*}
            [[ $body == *'\' || $body == *'$'* || $body == *'`'* ]] && return 0 ;;
      '$'*) return 0 ;;
      *) body=${v%%[[:space:];|&]*} ;;
    esac
  elif [ "$sub" = create ] && ! [[ $l1 =~ (^|[[:space:]])(--web|-w)([[:space:]]|$) ]]; then
    echo "gh pr create has no PR text, and CI needs its route line. Write the text to a file and pass --body-file <file>."; return
  else
    return 0
  fi
  if [ "$sub" = create ]; then
    head=HEAD; re='(^|[[:space:]])(--head|-H)[=[:space:]]'; [[ $l1 =~ $re ]] && head=
    re='(^|[[:space:]])(--base|-B)(=|[[:space:]]+)([^[:space:];|&]+)'
    if [[ $l1 =~ $re ]]; then base=origin/${BASH_REMATCH[4]//[\"\']/}
    else base=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) || base=origin/main; fi
  else
    re='^[[:space:]]*([^-[:space:]][^[:space:];|&]*)'; n=; [[ $l1 =~ $re ]] && n=${BASH_REMATCH[1]//[\"\']/}
    out=$(gh pr view $n --json headRefOid,baseRefName -q '.headRefOid + " " + .baseRefName' 2>/dev/null | tr -d '\r')
    oid=${out%% *}; base=origin/${out#* }; head=
    [ -n "$oid" ] && git cat-file -e "$oid^{commit}" 2>/dev/null && head=$oid
  fi
  if [ -n "$head" ] && from=$(git merge-base "$base" "$head" 2>/dev/null); then
    commits=$(git rev-list "$from..$head"); changed=$(git -c core.quotepath=off diff --name-only "$from" "$head")
  fi
  route_problem "$body" "$commits" "$changed"
}
# The cheap test first, on the command without heredoc text fed to cat or git.
if [ -z "$why" ] && [[ ${cmd//$'\n'/;} =~ $pr_re ]] &&
   . "$(dirname "$0")/lodestar-lib.sh" 2>/dev/null && declare -F route_problem >/dev/null; then
  p=$(pr_text_problem)
  if [ -n "$p" ]; then
    why="this PR text would fail CI (ci-checks.sh): $p"
    fix="Fix the text and run the command again. Both lines are plain text, each on its own line, with nothing after 'risk=<level>'; the review line names the reviewed commit. Open the PR after the review passed (rules/git.md, section 12). Safest: write the text to a file and pass --body-file <file>. If origin is stale, run git fetch first."
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
