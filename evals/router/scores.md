# Router suite: main scores

Run on branch `feat/router-prototype-step` (PROTOTYPE folded into the routes
as a step, "data integrity" defined, rule 15 upgrade wording), 2026-11-24,
Claude Code 2.1.331, model opus (claude-opus-5-5), 1 run per case, both
arms, `-j 3`. After the review fixes, `prototype-try` and
`data-integrity-report` were run again (with 1.00 both; tokens below are
from those reruns). A PR that changes `router/ROUTER.md` compares its
branch run with this table; a merged change replaces it.

| Case | With | Without | Tokens with | Tokens without |
|---|---|---|---|---|
| approval-wait-migration | 1.00 | 1.00 | 61k | 12k |
| br-api-rename | 1.00 | 1.00 | 61k | 12k |
| br-investigation | 1.00 | 1.00 | 61k | 12k |
| br-sort-dropdown | 1.00 | 0.00 | 61k | 12k |
| compare-live-updates | 1.00 | 1.00 | 61k | 12k |
| complex-multitenant | 1.00 | 1.00 | 61k | 12k |
| data-integrity-report | 1.00 | 1.00 | 61k | 12k |
| prototype-trap-fix | 1.00 | 1.00 | 61k | 12k |
| prototype-try | 1.00 | 0.00 | 74k | 12k |
| question-explain | 1.00 | 1.00 | 12k | 12k |
| question-is-there-a-way | 1.00 | 0.00 | 55k | 12k |
| sensitive-billing | 1.00 | 0.50 | 61k | 12k |
| sensitive-invariant | 1.00 | 0.50 | 61k | 12k |
| simple-label | 1.00 | 1.00 | 60k | 12k |

Overall: with 1.00, 979k tokens for the full run (14 cases; 860k for 13 on
2026-11-02, so about 3k more per case for the longer Router)

The baseline (no Lodestar) fails or half-fails five cases: it writes a
route line for a question (`question-is-there-a-way`), names no tests-first
mode on the two sensitive-path cases, did not route `br-sort-dropdown` as
expected in this run (one run, so a flip), and without the PROTOTYPE name
in the prompt does not say it starts with a prototype step
(`prototype-try`).

Limits: one run per case, so a single flip moves a score; 14 cases, written
by the same author as the policy; graders are regex on the route line (one
case adds a haiku judge), so the suite measures the routing decision, not the quality of the
work that follows. Lodestar costs about 49k more tokens per routed task (61k vs 12k).
Reproduce with the command in `evals/README.md`; the run's JSON stays on the
owner's machine (the evals results folder is gitignored), and `--runs 3` on a case
shows whether a result holds.
