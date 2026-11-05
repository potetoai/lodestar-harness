# Idea: behavior evals for the Router, reviewer and text-only rules

> **Idea plan, rated.** Rated in `plans/completed/harness-health.md`
> (2026-11-02, section "Rated idea: behavior evals"); built in
> `plans/active/behavior-evals.md`, Router suite first.

## 1. Why

The owner asked on 2026-11-02 why large vendors run evals when they create or
change a skill, then asked for a small, cheap eval set for Lodestar.
Lodestar's policy files are instructions to a model, like skills. Today a
change to them is checked by review, `enforcement/test.sh` and
`scripts/check-links.sh`. These prove hooks work and links resolve; none of
them shows that an agent behaves better after the text changes. Models are
non-deterministic, so one manual try proves little.

## 2. Evidence (read 2026-11-02, main at 1b79adb)

- `claude plugin eval` exists in the installed Claude Code: cases as
  `case.yaml` or `prompt.md` plus `graders/*.md`, 3 runs per case by default,
  a no-plugin baseline arm (`--ablation with-without`), `--max-cost-usd`,
  `--model`, `--judge-model` (default haiku), `--threshold`, `--no-publish`.
  Using it keeps the rule "never build an orchestration system".
- Lodestar is not a plugin; it loads through the global `~/.claude/CLAUDE.md`.
  Unknown: whether the runner can target it, and whether its baseline arm also
  loads that global file (which would make the baseline not a baseline).
- `plans/completed/ideas/enforced-vs-written.md` lists rules with no machine
  check: security review for security tasks (F3), human approval for
  destructive operations (F4), honest risk level, acceptance criteria. Evals
  are the only way to measure these.
- `router/ROUTER.md` is about 2,500 words; `agents/reviewer.md` about 300.
- Owner constraints: token budget is watched (`feedback_token_budget`),
  GitHub Free only, test artifacts are throwaway.

## 3. Proposal

Three small suites, about 22 cases, under `evals/` in this repo.

| Suite | Cases | What a case checks | Grader |
|---|---|---|---|
| E1 Router | ~12 | Task text in, expected `Lodestar route: <WORKFLOW> risk=<level>` out. Covers the SIMPLE/BUILD_REVIEW boundary, sensitive paths (tests-first), a question that is not a request, a high-risk task that must wait for approval | String match (free) |
| E2 Reviewer | ~6 | Small diff with a planted bug: the bug is reported with location. Clean diff: no blocking finding. Format: the four fields per finding | String match first, haiku judge only where needed |
| E3 Text-only rules | ~4 | Destructive command request: the agent asks before running (F4). Auth change: a security review is named (F3) | haiku judge |

How it is used:

- Run by hand, only when a PR changes a file a suite covers
  (`router/ROUTER.md`, `agents/reviewer.md`, the rules under E3). Run on main
  and on the branch; the PR text carries one line with both scores.
- The baseline arm shows whether the text earns its tokens: a rule that scores
  the same with and without Lodestar is a candidate to cut.
- Not in CI: CI has no model credential and runs cost the owner's quota.
- Results stay local (`evals/results/` gitignored, `--no-publish`).

## 4. Phases

0. Spike (gate EV-0). One E1 case through `claude plugin eval`. Answer: can
   it load Lodestar, is the baseline arm clean, what does one run cost. If the
   runner cannot load Lodestar cleanly, stop and report; do not write a custom
   runner without a new rating.
1. E1 Router suite, run once on main, record scores and cost.
2. E2 and E3, same.
3. One line in `rules/documentation.md` or `AGENTS.md`: a PR that changes a
   covered file runs its suite and reports both scores.

## 5. Not doing

- No eval for every file; only where wrong behavior is costly and no hook
  checks it.
- No LLM judge where a string match works.
- No eval gate in `merge-pr.sh` or CI.

## 6. Open questions (owner)

1. Cost ceiling per suite run (`--max-cost-usd`), after phase 0 measures it.
2. Which model runs the cases: the model used day to day, or a cheaper one
   (cheaper may score differently from real use).
