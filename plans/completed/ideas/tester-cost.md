# Idea: tester cost

> **Rated 2026-10-19** in `plans/active/agent-pitfalls.md` (phase 4,
> decision log): one fix kept (tester plan reads), the rest dropped.

From `plans/completed/subagent-cost.md`, phase 4 (2026-10-19). Not yet rated.

The tester holds 46.8% of subagent cost (`python scripts/usage-report.py
--since 2026-10-13`: 24 runs, median 606k, 29 calls, peak 154k); subagents
are 24.7% of all cost. The editing line and the subagent nudge already cut a
run by about 38%. Open: where the rest goes (context re-sent is 56% of a
tester run), and whether runs can start with less to find. Rate it in an
active plan, with fresh numbers, before any work.
