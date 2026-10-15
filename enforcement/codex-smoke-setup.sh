#!/usr/bin/env bash
# Build a throwaway project for the live Codex smoke
# (enforcement/codex-live-smoke.md). Not for real projects.
#
# Usage: codex-smoke-setup.sh <new-dir>
# The folder must not exist. Delete it when the smoke is done.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
dir=${1:-}
[ -n "$dir" ] || { echo "Usage: codex-smoke-setup.sh <new-dir>" >&2; exit 1; }
[ ! -e "$dir" ] || { echo "$dir already exists; pick a new folder." >&2; exit 1; }
mkdir -p "$dir"
cd "$dir"
git init -q
git config user.name 'Lodestar smoke'
git config user.email 'smoke@example.invalid'
git config core.autocrlf false
bash "$here/bootstrap.sh" . --stack python >/dev/null

# Placeholders filled so doctor reports Ready.
sed -i -E 's/^([[:space:]]*([*-][[:space:]]*)?)\[([^]]+)\][[:space:]]*$/\1Smoke fixture: \3/' AGENTS.md
cat > .ai/project.md <<'EOF'
# Project: Lodestar Codex smoke

Throwaway project for the live Codex smoke. Delete after use.

sensitive_paths:
  - app/money.py
EOF
printf '| INV-1 | app/money.py changes only with locked tests | high | sensitive-gate | open |\n' >> .ai/invariants.md
# Known make targets: verify fails while ./fail exists; lint flags BAD.
printf 'setup:\n\t@:\nlint:\n\t@:\ntest:\n\t@:\nformat-check:\n\t@:\nverify-full: verify\nverify:\n\t@test ! -f fail\nlint-file:\n\t@! grep -q BAD "$(FILE)"\n' > Makefile
mkdir -p app .ai/plans/active
printf 'def balance():\n    return 0\n' > app/money.py
# An active plan without owner approval: the sensitive gate blocks, and
# "duyệt" from the owner records the first approval.
printf '# Plan: smoke\n\n## Acceptance criteria\n\n- [ ] C1: balance() returns 0.\n' > .ai/plans/active/smoke.md
rm -f .ai/last-maintenance   # maintenance due, so SessionStart shows it
git add -A
git commit -q -m 'smoke fixture'
bash .claude/hooks/doctor.sh --quiet >/dev/null && echo "Ready: $(pwd -W 2>/dev/null || pwd)" ||
  { bash .claude/hooks/doctor.sh; exit 1; }
