# Tech debt

Known shortcuts and gaps, kept on purpose. Each entry has a due date.

| Date | Debt | Why | Due |
|---|---|---|---|
| 2026-10-13 | Closed: the source-repository onboarding waiver was unnecessary. | Investigation confirmed `check-readiness.sh` exempts the Lodestar source repository since commit 4c23d3a, also documented in `plans/completed/round-2.md`. Use the source repository's self-tests and link checks; do not request another waiver. Clarifying the shared written rules is tracked in `plans/completed/codex-lodestar-parity.md`. | Resolved 2026-10-13 |
