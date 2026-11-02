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
