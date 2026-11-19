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
| S4-0 Start | Critic and reviewer runs made after 2026-11-13 (`scripts/usage-report.py --since 2026-11-14`); `agent-pitfalls.md` phase 5 closed | 40 critic runs and 40 reviewer runs from 2 projects | 2026-11-27 | 2026-12-18 | met 2026-11-19: critic 54, reviewer 61, 4 projects; started early (decision log) |
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
| 2026-11-19 | 0 | Measured A, B and a risk split; H not measured; second rating in section 11 (PR #222) |

## 10. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-11-19 | Phase 0 started before 2026-11-27, owner agreed | Gate counts were met. P5-c (critic limit) was decided on 2026-11-13, and data from 2026-11-14 is all under the new critic rule. P5-a (PROTOTYPE) has nothing to do with subagents |

## 11. Phase 0 results (2026-11-14 to 2026-11-19)

Source: `scripts/usage-report.py --since 2026-11-14`. Runs per route line
and the output split are now in the report. The risk split came from a
one-off read. 117 sessions, 229 subagent runs, 88.8M weighted units, 51% of
all cost.

| Role | Runs | Share | Cost per run | Calls | Split | Output: report / tool input / thinking |
|---|---|---|---|---|---|---|
| builder | 37 | 34.0% | 672k | 44 | 2/23/54/22 | 3/30/66 |
| tester | 33 | 27.5% | 769k | 38 | 2/21/47/30 | 3/28/69 |
| reviewer | 61 | 19.2% | 221k | 16 | 7/28/41/24 | 8/17/74 |
| critic | 54 | 10.8% | 134k | 10 | 11/26/32/31 | 9/19/72 |
| other | 44 | 8.5% | 93k | 5 | 8/37/27/28 | 14/27/59 |

The rest of output is estimated as output tokens minus visible characters / 4.
The transcripts do not keep thinking text.

Runs by project, workflow and risk (one-off read):

| Project | Route | Tasks | critic / reviewer / tester / builder / other |
|---|---|---|---|
| C | BUILD_REVIEW high | 23 | 27 / 23 / 13 / 20 / 35 |
| C | BUILD_REVIEW, no risk on the line | 4 | 15 / 2 / 9 / 5 / 1 |
| C | SIMPLE low | 8 | 2 / 4 / 1 / 2 / 1 |
| A | COMPLEX high | 8 | 0 / 9 / 3 / 6 / 0 |
| A | BUILD_REVIEW high | 2 | 3 / 2 / 3 / 2 / 0 |
| A | BUILD_REVIEW low and medium | 18 | 1 / 8 / 0 / 0 / 0 |
| A | SIMPLE low | 13 | 0 / 1 / 0 / 0 / 0 |
| B, this repo | all | 17 | 0 / 9 / 0 / 0 / 4 |

What the numbers say:

- Project C made 150 of the 229 runs (65%). Its tasks are high risk or have no
  risk on the line: 27 of 29 BUILD_REVIEW tasks. Its `sensitive_paths` is empty
  and it has no high-risk invariant. The route reasons it states call the
  correctness of research data "data integrity", and Router rule 16 then turns
  every such task into tests-first (critic, tester, builder, reviewer). A
  BUILD_REVIEW task costs 3.0M in C and 1.2M in A.
- About 70% of output is thinking, and only 3-9% is report text.
- Builder and tester runs are long (44 and 38 calls), and half their cost is
  context sent again.
- Reviewer runs on low and medium BUILD_REVIEW are rare: 9 runs in 25 tasks
  outside C. Diff sizes were not read.
- Idea H (cost per changed line) was not measured. It needs the PR diff sizes,
  and the risk split above already explains where the runs come from.

Second rating:

| # | Idea | Rating with numbers |
|---|---|---|
| C | Report shape | **Drop**: report text is 3-9% of output, under 3% of a run |
| D | Lower effort on small, low-risk reviews | **Small**: thinking is about 18% of a reviewer run, but low-risk reviewer runs are 9 in 5 days. The replay costs more than it saves |
| E | Second review reads the fix diff only | **Drop**: about 1 reviewer run per task, so there are few repeats |
| F | Raise the 100-line line | **Drop**: about 13 runs, about 3% of subagent cost |
| G | Rerun cost note before a critic rerun | **Wait** (after P5): critic is 1.2 runs per high-risk task in C, so reruns are not the driver now |
| I | New: say what "data integrity" means in the Router (stored real data lost or corrupted, not whether computed output is correct; correctness gets normal tests) | **Do, owner decides**: it is a Router change, so it goes into the 2026-11-26 `ROUTER.md` eval run already planned. It targets the 65% of runs |

