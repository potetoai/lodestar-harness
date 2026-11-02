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
  out=${out//$'\r'/}
  # Some linters colour their output even here (ruff reads any FORCE_COLOR
  # value as "force colour"), so drop colour codes before matching.
  esc=$'\e'; out=$(sed "s/${esc}\[[0-9;]*[A-Za-z]//g" <<<"$out")
  # A name added before its first use (an import now, the code that uses it
  # in the next edit) is not a mistake yet. When every problem found is an
  # unused name (ESLint no-unused-vars, oxlint eslint(no-unused-vars),
  # ruff F401/F841), let the edit pass:
  # `make lint` in verify and CI still catch a name that stays unused.
  # Fail closed: any other line that looks like a problem (error, warning,
  # a rule code such as E501, a syntax error) blocks as before. Summary
  # lines and the file-name header line are not problems. oxlint's default
  # format has no error/warning word, so its rule names (eslint(...)) count.
  unused='no-unused-(vars|imports)[[:space:]]*$|[a-z-]*eslint\(no-unused-(vars|imports)\):|(^|[^[:alnum:]])F(401|841)([^[:alnum:]]|$)'
  if grep -qE "$unused" <<<"$out" && ! grep -vE "$unused" <<<"$out" |
      grep -vE '^Found [0-9]+ errors?\.|problems? \(|potentially fixable|^make(\[[0-9]+\])?: \*\*\* .*Error [0-9]+$' |
      tr '\\\\' / | awk -v b="/${f##*/}" 'substr($0, length($0) - length(b) + 1) != b' |
      grep -qE '[Ee]rror|ERROR|[Ww]arn|WARN|[A-Z]+[0-9]{3}|(^|[^[:alnum:]_])([a-z-]*eslint|oxc|unicorn|react[a-z-]*|import|jsx-a11y|nextjs|jest|vitest|promise|node|jsdoc|regex|vue)\([a-z0-9/_-]+\)'; then
    exit 0
  fi
  echo "Linter found problems in $file. Fix them as the messages below say:" >&2
  echo "$out" | cap >&2
  exit 2
fi
exit 0
