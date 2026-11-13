# Plan: steady 4, subagent cost, round 2

> **For Claude Code:** This is an execution plan, child of
> `plans/active/steady-state.md` (read its section 2 first). Read all of this
> file. Do one phase at a time and stop after each for the repo owner's
> approval. Answer nothing in "Open questions" yourself. Update the progress
> and decision logs here, and add one row to the parent's progress log, when
> a phase moves.

## 1. Why this plan

Subagents went from 15.2% of cost (2026-10-12) to 30.2% (2026-10-28 to
2026-11-13): 411 runs, 114.9M weighted units. Round 1
(`plans/completed/subagent-cost.md`) cut the cost of a run. The count of
runs is what grew.

## 2. Evidence (measured 2026-11-13)

Medians per run; split is first call / new input later / context sent again
/ output.

| Role | Runs | Share of subagent cost | Cost per run | Calls | Start context | Split | 2026-10-12: runs, cost per run, output share |
|---|---|---|---|---|---|---|---|
| tester | 64 | 34.5% | 533k | 25 | 17k | 3/23/41/33 | 6, 982k, 13% |
| builder | 46 | 24.7% | 480k | 30 | 17k | 2/24/51/23 | 2, 1,426k, 7% |
| critic | 165 | 21.0% | 105k | 7 | 17k | 12/31/26/31 | 24, 243k, 6% |
| reviewer | 123 | 17.6% | 109k | 7 | 20k | 15/34/26/25 | 27, 160k, 1% |

What the numbers say:

- A run got cheaper: critic 243k to 105k, reviewer 160k to 109k, start
  context 40k to 17k, calls 16 to 7 and 11 to 7. The briefs of round 1 work.
- Runs multiplied: 288 critic and reviewer runs against 233 routed tasks
  (BUILD_REVIEW 102, SIMPLE 72, COMPLEX 29). Critic and reviewer are about
  12% of all cost, tester and builder about 18%.
- Output is now a quarter to a third of a run, and output is priced five
  times input. Whether it is report text or thinking is not known.
- By project: A 235 runs (37.9% of its cost), B 68 (19.0%), C 59 (40.2%),
  this repo 49 (11.9%).
- Critic runs per plan, counted by hand on 2026-11-13
  (`plans/active/agent-pitfalls.md`, gate P5-c): 43, 17, 8, 7, 5 and 4; every
  run past the limit came from an owner approval. PR #195 changed the rule
  the same day (from run 4 only BLOCKER and MAJOR findings drive a run).

## 3. Limits

- Decisions of 2026-10-12 stand unless phase 0 gives new data: no cheaper
  model for critic or reviewer, no call budget in briefs, tester and builder
  stay subagents.
- Do not edit `agents/critic.md` before gate P5 closes (2026-11-26).
- Measuring uses `scripts/usage-report.py` and transcript reads, no model
  runs. A trial that runs models states its token ceiling first and waits
  for the owner.
- Quality first: a change that lowers what review catches is not a saving.
  Project A's reviews changed code in 42 PRs in five weeks
  (`plans/completed/harness-health.md`, phase 3).

## 4. Rating of every idea (first pass; phase 0 confirms or changes it)

| # | Idea | Expected effect | Rating |
|---|---|---|---|
| A | Count runs per task and per plan, by role and project; size of the diff each reviewer run read; reviewer runs on changes under 100 lines, where `workflows/build-review.md` asks for a same-session review | No saving itself; shows where the 288 runs come from | **Do** (phase 0) |
| B | Split output into thinking and report text (block lengths in the transcripts), per role | Shows whether idea C or D can touch the output third | **Do** (phase 0) |
| C | Report shape for critic and reviewer: findings only, each with severity, file and line; no retelling of the diff or the criteria | Cuts report text, if B shows it is a large part | After B |
| D | Lower effort for a reviewer run on a small, low-risk diff (the runtime's effort setting, not a cheaper model) | Cuts thinking, if B shows it is a large part. Risk: missed findings; needs a replay of about 10 past reviews with known findings | After B, owner decides (Q1) |
| E | A second review after fixes reads only the fix diff, with the first findings in the brief | Cuts repeat runs, if A shows many | After A |
| F | Raise the same-session review line above 100 changed lines for low and medium risk | Cuts reviewer runs; the cost of a miss grows with the diff | After A, owner decides |
| G | Before a critic rerun the owner asks for, the agent says the usual cost of a run (about 100k) and what the last run left open | Fewer reruns by choice, none by rule | After P5 closes |
| H | Tester and builder: cost per changed line as a subagent against the same work in the main session at its context size | Tells whether the 18% is waste or just where the work happens | **Do** (phase 0), measure only |

## 5. Phases

### Phase 0: Measure (starts at gate S4-0)

Ideas A, B, H. Add to `scripts/usage-report.py` only what will be counted
again (runs per route line, output split); one-off reads stay throwaway.
Report the tables and a second rating of C to G with numbers.

Done when: the tables are in the progress log and the owner has chosen which
of C to G to do.

### Phase 1: The chosen changes

One PR per idea, each naming its file (`agents/reviewer.md`,
`agents/critic.md`, `workflows/build-review.md`,
`router/ORCA-INTEGRATION.md` section 8). Idea D only after its replay.

Done when: merged, and gate S4-1 is set.

### Phase 2: Recount and close

Done when: gate S4-1 is met or stopped and the owner has seen the count.

## 6. Data gates

| Gate | Measure (source) | Minimum | Check | Stop | Status |
|---|---|---|---|---|---|
| S4-0 Start | Critic and reviewer runs made after 2026-11-13 (`scripts/usage-report.py --since 2026-11-14`); `agent-pitfalls.md` phase 5 closed | 40 critic runs and 40 reviewer runs from 2 projects | 2026-11-27 | 2026-12-18 | waiting |
| S4-1 Effect | Subagent share of cost and runs per task, 14 days after phase 1 | 100 runs from 2 projects | 14 days after phase 1 | 3 weeks later | waiting (30.2%, 411 runs on 2026-11-13) |

## 7. Open questions

- **Q1.** May idea D be tried (a replay of about 10 reviews, token ceiling
  named first)? The owner dropped a cheaper reviewer model on 2026-10-12;
  effort is a different setting with a like risk.

## 8. Not in scope

- Any orchestration, queue or budget enforced by code.
- Router changes; a finding that needs one goes to the owner as a proposal.

## 9. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-11-13 | none | Plan written; section 2 measured |

## 10. Decision log

| Date | Decision | Reason |
|---|---|---|
