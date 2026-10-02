#!/usr/bin/env bash
# Global hook: tell the agent when a project is not ready. It never blocks
# (always exit 0); stdout goes into the agent's context.
#   (no args)  SessionStart: readiness, plus maintenance due (overdue, repeats).
#   --prompt   UserPromptSubmit: readiness only, next to every owner message,
#              because a single reminder at session start gets ignored.
# Registered in ~/.claude/settings.json by install.sh.
here=$(cd "$(dirname "$0")" && pwd)
lodestar=$(cd "$here/../../../.." && { pwd -W 2>/dev/null || pwd; })
mode=${1:-session}
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

git rev-parse --git-dir >/dev/null 2>&1 || exit 0   # not a project
# Where the last session stopped (global CLAUDE.md step 5). Also in lodestar-harness.
if [ "$mode" != --prompt ] && [ -f .ai/handoff.md ]; then
  echo "Lodestar: read .ai/handoff.md first; the last session wrote where it stopped."
  echo "When the owner says \"continue\", continue from its next step."
fi
[ -f enforcement/bootstrap.sh ] && exit 0            # lodestar-harness itself

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
if ! out=$(bash .claude/hooks/doctor.sh --quiet 2>&1); then
  gate "this project is not ready. Missing items:"
  echo "$out"
  exit 0
fi
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
exit 0
