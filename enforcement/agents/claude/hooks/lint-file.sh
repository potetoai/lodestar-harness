#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# PostToolUse (Edit|Write): lint the file the agent just changed.
# Exit 2 sends stderr back to the agent so it fixes the problem itself.
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
export NO_COLOR=1 FORCE_COLOR=0  # plain text for the agent

# -j: no trailing newline, so Windows jq.exe cannot add a CR.
file=$(jq -j '.tool_input.file_path // empty')
[ -z "$file" ] && exit 0

# Print at most 30 lines, so a large lint dump does not flood the agent.
cap() { awk 'NR<=30; END { if (NR>30) printf "... %d more lines\n", NR-30 }'; }

# Only lint files inside this project. Compare with forward slashes and
# lowercase, because Windows paths vary in both.
proj=$(pwd -W 2>/dev/null || pwd)
f=${file//\\//} p=${proj//\\//}
case "${f,,}" in
  "${p,,}"/*) ;;
  *) exit 0 ;;
esac

# A new lint suppression needs a reason on the same line (" -- <reason>").
# New lines = diff against HEAD, or the whole file if git does not track it.
# Keep this pattern in sync with ci-checks.sh.
SUPPRESS='(#[[:space:]]*noqa|#[[:space:]]*type:[[:space:]]*ignore|#[[:space:]]*pylint:[[:space:]]*disable|eslint-disable|oxlint-disable|@ts-ignore|@ts-expect-error|//[[:space:]]*nolint)'
case "$f" in *.md|*/.claude/hooks/*|*/.github/workflows/*) ;; *)
  if git ls-files --error-unmatch -- "$file" >/dev/null 2>&1; then
    added=$(git diff -U0 HEAD -- "$file" | sed -n 's/^+\([^+]\)/\1/p')
  else
    added=$(cat -- "$file" 2>/dev/null)
  fi
  bad=$(grep -E "$SUPPRESS" <<<"$added" | grep -vE -- '--[[:space:]]*[^[:space:]]')
  if [ -n "$bad" ]; then
    echo "Lint suppression without a reason in $file:" >&2
    echo "$bad" | cap >&2
    echo "Fix the code instead. If the linter is really wrong, keep the suppression and add ' -- <reason>' on the same line." >&2
    exit 2
  fi
esac

[ -f Makefile ] || exit 0
if ! make -n lint-file FILE="$file" >/dev/null 2>&1; then
  # lint-file is optional; if even the required 'verify' fails, make itself is
  # broken here (for example a folder name with accents on Windows): say so.
  make -n verify >/dev/null 2>&1 && exit 0
  echo "make cannot run in this project, so $file was not linted." >&2
  echo "Run 'bash .claude/hooks/doctor.sh' to see why." >&2
  exit 2
fi
if ! out=$(make --no-print-directory lint-file FILE="$file" 2>&1); then
  echo "Linter found problems in $file. Fix them as the messages below say:" >&2
  echo "$out" | cap >&2
  exit 2
fi
exit 0
