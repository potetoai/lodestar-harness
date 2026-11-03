# Router suite: main scores

Run on main at commit ca9ff5c (`router/ROUTER.md` unchanged since), 2026-11-02,
Claude Code 2.1.316, model opus (claude-opus-5-5), 1 run per case, both
arms. 160 s wall time with `-j 3`. A PR that changes `router/ROUTER.md`
compares its branch run with this table; a merged change replaces it.

| Case | With | Without | Tokens with | Tokens without |
|---|---|---|---|---|
| approval-wait-migration | 1.00 | 1.00 | 58k | 12k |
| br-api-rename | 1.00 | 1.00 | 58k | 11k |
| br-investigation | 1.00 | 1.00 | 58k | 12k |
| br-sort-dropdown | 1.00 | 1.00 | 58k | 12k |
| compare-live-updates | 1.00 | 1.00 | 58k | 12k |
| complex-multitenant | 1.00 | 1.00 | 58k | 12k |
| prototype-trap-fix | 1.00 | 1.00 | 58k | 12k |
| prototype-try | 1.00 | 1.00 | 59k | 12k |
| question-explain | 1.00 | 1.00 | 11k | 11k |
| question-is-there-a-way | 1.00 | 0.00 | 58k | 12k |
| sensitive-billing | 1.00 | 0.50 | 58k | 12k |
| sensitive-invariant | 1.00 | 0.50 | 58k | 12k |
| simple-label | 1.00 | 1.00 | 57k | 11k |

Overall: with 1.00, mean delta +0.15, 860k tokens

The baseline (no Lodestar) fails three cases: it writes a route line for a
question (`question-is-there-a-way`), and on both sensitive-path cases it
picks high risk but does not name tests-first mode. On the other ten it
routes the same as Lodestar once the prompt lists the workflow names.

Limits: one run per case, so a single flip moves a score; 13 cases, written
by the same author as the policy; graders read the route line (one haiku
judge), so the suite measures the routing decision, not the quality of the
work that follows. Without Lodestar, 10 of 13 cases pass fully (mean 0.85).
Lodestar costs about 46k more tokens per routed task (58k vs 12k).
Reproduce with the command in `evals/README.md`; the run's JSON stays on the
owner's machine (`evals/results/` is gitignored), and `--runs 3` on a case
shows whether a result holds.
