#!/usr/bin/env bash
# Global hook: tell the agent when a project is not ready, and carry Lodestar
# bug reports from projects to lodestar-harness. It never blocks (always
# exit 0); stdout goes into the agent's context.
#   (no args)  SessionStart: readiness, plus maintenance due (overdue, repeats).
#   --prompt   UserPromptSubmit: readiness only, next to every owner message,
#              because a single reminder at session start gets ignored.
#              Skipped once doctor passed in this session at this commit.
# Registered in ~/.claude/settings.json by install.sh.
here=$(cd "$(dirname "$0")" && pwd)
lodestar=$(cd "$here/../../../.." && { pwd -W 2>/dev/null || pwd; })
mode=${1:-session}
# Hook input arrives at once. Run by hand with stdin open but empty (a pipe
# nobody writes), the read gives up after 2 s instead of hanging.
in=; [ -t 0 ] || IFS= read -r -d '' -t 2 in
sid=; [ -n "$in" ] && sid=$(jq -r '.session_id // empty' <<<"$in" 2>/dev/null | tr -d '\r')   # none: nothing is remembered
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

git rev-parse --git-dir >/dev/null 2>&1 || exit 0   # not a project
# Where the last session stopped (global CLAUDE.md step 5). Also in lodestar-harness.
if [ "$mode" != --prompt ] && [ -f .ai/handoff.md ]; then
  echo "Lodestar: read .ai/handoff.md first; the last session wrote where it stopped."
  echo "When the owner says \"continue\", continue from its next step."
fi
# Lodestar bug inbox (rules/enforcement.md section 8), on this machine only:
# each project session adds its path to projects.txt; the lodestar-harness
# session lists `reported` lodestar- rows of their feedback logs that are not
# in seen.txt yet.
inbox=${LODESTAR_INBOX:-$HOME/.lodestar}
if [ -f enforcement/bootstrap.sh ]; then             # lodestar-harness itself
  [ "$mode" = --prompt ] && exit 0
  seen=$({ tr -d '\r' < "$inbox/seen.txt"; } 2>/dev/null)
  new=$({ tr -d '\r' < "$inbox/projects.txt"; } 2>/dev/null | sort -fu | while IFS= read -r p; do
    [ -f "$p/.ai/feedback-log.md" ] || continue
    tr -d '\r' < "$p/.ai/feedback-log.md" | awk -F'|' -v p="$p" '
      NF < 5 { next }
      { last = ($NF ~ /^ *$/) ? NF - 1 : NF; st = tolower($last); gsub(/[` ]/, "", st)
        d = $2; tag = $3; gsub(/[` ]/, "", d); gsub(/[` ]/, "", tag)
        what = $4; for (i = 5; i < last - 1; i++) what = what "|" $i }
      tag ~ /^(lodestar|orca)-/ && st ~ /^reported/ { print p "|" d "|" tag "\t" substr(what, 1, 200) }'
  done | while IFS=$'\t' read -r key what; do
    grep -qixF "$key" <<<"$seen" || printf '  %s\n    %s\n' "$key" "$what"
  done)
  if [ -n "$new" ]; then
    echo "Lodestar: projects reported Lodestar bugs not handled here yet (project|date|tag):"
    echo "$new"
    echo "Tell the owner. Fix each in lodestar-harness (or decide it is not a Lodestar bug),"
    echo "then add its project|date|tag line to $inbox/seen.txt so it stops showing."
  fi
  bash "$here/gh-sweep.sh"     # once a day: what GitHub shows since the last sweep
  exit 0
fi
if [ "$mode" != --prompt ] && [ -f .ai/feedback-log.md ]; then
  me=$(pwd -W 2>/dev/null || pwd)
  mkdir -p "$inbox" 2>/dev/null && { grep -qixF "$me" "$inbox/projects.txt" 2>/dev/null || echo "$me" >> "$inbox/projects.txt"; } 2>/dev/null
  echo "Lodestar: if a Lodestar hook, doctor check or template is wrong, add a lodestar- row to"
  echo ".ai/feedback-log.md (status reported) even if the owner said nothing; lodestar-harness sees it."
fi

gate() {
  echo "LODESTAR GATE: $1"
  echo "Do NOT start the requested code change yet. First tell the owner, in one or two"
  echo "sentences, that this project must be onboarded (workflow: $lodestar/workflows/onboarding.md)"
  echo "and offer to do it now. Answering questions is fine. Skip only if the owner explicitly"
  echo "says so, and then record the skip in .ai/tech-debt.md with a due date."
}

if [ ! -f .claude/hooks/doctor.sh ]; then
  gate "this project is not onboarded yet."
  exit 0
fi
# Doctor takes seconds on a big tree, and every owner message waited for it
# (App01: 4.5 s each, some runs hit the 30 s hook timeout). The per-prompt
# gate is for a project that is not ready, so once doctor passed in this
# session at this commit, skip it until the next commit or session.
mark="$(git rev-parse --git-dir)/lodestar-ready"
key="$sid $(git rev-parse -q --verify HEAD)"
[ "$mode" = --prompt ] && [ -n "$sid" ] && [ "$(cat "$mark" 2>/dev/null)" = "$key" ] && exit 0
if ! out=$(bash .claude/hooks/doctor.sh --quiet 2>&1); then
  rm -f "$mark" 2>/dev/null
  gate "this project is not ready. Missing items:"
  echo "$out"
  exit 0
fi
[ -n "$sid" ] && { echo "$key" > "$mark"; } 2>/dev/null
[ "$mode" = --prompt ] && exit 0
env=$(grep -E '^⚠️ +A12 ' <<<"$out")
[ -n "$env" ] && echo "Lodestar: $env. Run make setup before anything that needs make verify."
# Ready, but maintenance may be due: overdue, repeated mistakes, old template.
due=$(grep -E '^⚠️ +(D1|D2|A9b) ' <<<"$out")
if [ -n "$due" ]; then
  echo "Lodestar: maintenance is due in this project:"
  echo "$due"
  echo "Tell the owner, and offer to run: $lodestar/workflows/maintenance.md"
fi
# A merged plan must leave active/ (workflows/complex.md), but nothing
# checked it: real projects kept done plans in active/ for weeks, and every
# session reads them all. List active plans no commit has touched for
# LODESTAR_STALE_PLAN_DAYS (2) days; an uncommitted plan is new and skipped.
n=${LODESTAR_STALE_PLAN_DAYS:-2}; [[ $n =~ ^[0-9]+$ ]] || n=2
cutoff=$(date -d "$n days ago" +%F 2>/dev/null || date -v-"$n"d +%F 2>/dev/null)
stale=$(for f in .ai/plans/active/*.md; do
  [ -f "$f" ] || continue
  d=$(git log -1 --format=%cd --date=short -- "$f" 2>/dev/null)
  [ -n "$d" ] && ! [[ $d > $cutoff ]] && echo "  $f (last commit $d)"
done)
if [ -n "$stale" ]; then
  echo "Lodestar: plans in .ai/plans/active/ with no commit since $cutoff:"
  echo "$stale"
  # Global hooks run from source before a project gets the template that
  # brought completed.md; give the close step the project uses today.
  if [ -f .ai/plans/completed.md ]; then close="git rm it and add a row to .ai/plans/completed.md"
  else close="git mv it to .ai/plans/completed/"; fi
  echo "Check each against the merged PRs. Done: $close (a small PR)."
  echo "Not done: write in its progress log what it waits for. Tell the owner which is which."
fi
exit 0
