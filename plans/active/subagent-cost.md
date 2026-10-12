# Plan: subagent cost (idea 12)

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time and stop after each for the repo owner's approval. Answer
> nothing in "Open questions" yourself. Update the progress and decision logs
> when a phase moves.

## 1. Why this plan

Subagents went from 1.4% to 15.2% of all cost between the two measured periods
(`plans/completed/token-efficiency.md`, phase 4, decision of 2026-10-12: start
idea 12 with its own plan). This plan finds where that cost sits, changes only
what the numbers point at, and measures again. It keeps every check: the critic,
the tester, the reviewer and the approval stay.

## 2. Evidence (measured 2026-10-12)

Source: `python scripts/usage-report.py --since 2026-10-03 --until 2026-10-11`
(phase 0 added the table), all projects: 107 sessions, 122.5M weighted units,
subagents 15.4% of it. Weights: input 1, cache write 1.25, cache read 0.1,
output 5. 60 subagent runs, 18.9M. The role is the first role word in the
first 600 characters of the brief. The call-count buckets, the model counts
and the re-run reading below come from a throwaway script over the same
transcripts.

| Role | Runs | Cost | Share of subagent cost | Cost per run (median) | Calls per run (median) | Context at first call | Peak context (median) |
|---|---|---|---|---|---|---|---|
| critic | 24 | 6.33M | 33.5% | 243k | 16 | 40k | 95k |
| tester | 6 | 5.24M | 27.7% | 982k | 46 | 41k | 190k |
| reviewer | 27 | 5.18M | 27.4% | 160k | 11 | 37k | 76k |
| builder | 2 | 2.10M | 11.1% | 1,426k | 43 | 41k | 210k |

| Where a run's cost goes | critic | reviewer | tester | builder |
|---|---|---|---|---|
| First call (the start cost) | 17% | 21% | 5% | 4% |
| New input on later calls | 30% | 38% | 20% | 38% |
| Context re-sent on later calls (cache read) | 47% | 41% | 62% | 51% |
| Output | 6% | 1% | 13% | 7% |

What the numbers say:

- The start cost is about 13% of subagent cost. `workflows/build-review.md`
  ("Review cost") aims at it; the other 80% is input after the first call.
- A run pays for its whole context again on every call, and it makes about
  one tool call per call: 1.13 (critic), 1.23 (reviewer), 1.3 (tester), 1.24
  (builder). 67% to 80% of tool calls are `Bash`, nearly all of the form
  `cd <project> && <one command>`. Calls are the lever: the 10 runs with more
  than 30 calls hold 46% of the cost, the 11 runs with 5 or fewer hold 5%.
- Briefs are short (median 500 to 600 tokens for critic and reviewer), so the
  run spends calls finding the plan, the diff and the files. In the
  cross-model plan (phase 0, item 5) a reviewer whose brief held the diff
  finished in 2 tool calls and 37.6k tokens and found both planted bugs.
- The critic runs again on every change of the criteria. Read on 2026-10-12:
  6 critic re-runs in 5 sessions (2 more counted as critic were reviewers;
  the role match is that rough). All 6 briefs already narrowed the run
  ("review ONLY the effect of that change", "MUST only, fixes for critic run
  10"), with no rule asking for it. A narrowed run on plan text took 3 to 4
  calls against 20 for the first run; one that measured the data again took
  14 to 21. Each of the 6 found at least one real problem, a contradiction
  with an untouched criterion among them. What a full run would have found
  on top is not known.
- Tester and builder (8 runs, 39%) do work the main session would do
  otherwise, at a context no smaller. Nothing here shows waste in them.
- Model: 47 runs on Opus, 11 on Sonnet. No rule sets it.

Ceiling: critic and reviewer are 61% of subagent cost, about 9% of all cost.
Cutting their runs by 30% to 40% saves about 3% of all cost. The plan is
worth doing for that; it is not a large lever.

## 3. Rating of every idea

Rating: **Do** · **Drop**.

| # | Idea | Expected effect, from section 2 | Rating |
|---|---|---|---|
| A | Per-role subagent table in `scripts/usage-report.py` (runs, calls, cost split) | No saving itself; makes before and after checkable with one command | **Do** |
| B | The brief carries the material: the criteria or the diff in full, the paths and line ranges to read, the commands already run with their result, the project root | Fewer calls spent finding things; the 2-call reviewer is the model case | **Do** |
| C | Batch rule in the brief: independent reads and commands go in one turn | Calls per run fall with no loss of reading | **Do** |
| D | Call budget in the brief (a number per role): past it, report what was checked and what was not, instead of going on | Cuts the 31+ call tail (46% of cost). Soft limit, in the brief only; no hook, no orchestration. It can cut a run short, so it needs a replay of about 10 runs first | **Drop** (owner, 2026-10-12) |
| E | A rule for the critic re-run after a criteria change: what a narrowed run must still check, and when a full run is required | Saving: about none, dispatchers narrow the run already. It puts limits on a habit that has none today | **Do** as a safety rule |
| F | Reviewer on a cheaper model (idea 16, dropped at 1.3%) | About 40% of reviewer cost if quality holds; the one earlier trial (Haiku, 2026-10-02) gave a wrong finding | **Drop** (owner, 2026-10-12) |
| G | Critic on a cheaper model, or in the author's session for small criteria (`plans/ideas/token-diet.md`, phase 4.1) | Largest single saving, and the largest risk: the critic guards what a non-coder owner signs (decision of 2026-10-12, cross-model plan) | **Drop** |
| H | Tester or builder back in the main session | No measured saving | **Drop** |

## 4. Phases

Each phase is one PR. Repo rules apply: `bash scripts/check-links.sh` for docs,
`bash enforcement/test.sh` for `enforcement/` changes, LF line endings, move
and link instead of deleting policy. Rule text is added, not reworded; the
owner reviews the wording of each new rule line.

### Phase 0 — Measure (idea A)

- `scripts/usage-report.py`: add a subagent table per role (runs, cost,
  calls per run, context at first call, peak context, the four-way cost
  split) and the tool calls per call.
- Record the section 2 numbers as the baseline in the progress log.

Done when: the script reproduces section 2 for 2026-10-03..2026-10-11.

### Phase 1 — Brief and batching (ideas B, C)

- Generalise "Review cost" in `workflows/build-review.md` into a **Subagent
  cost** rule where dispatch is described (`router/ORCA-INTEGRATION.md`,
  section 8, Task Specification), linked from `build-review.md`,
  `agents/critic.md` and `agents/reviewer.md`. It holds what a brief must
  carry per role, and the batch line.
- Critic brief: the plan file path, the criteria text, the paths the plan
  touches, the data source it changes. Reviewer brief: the task goal, the
  diff (or the command that prints it, when it is above about 100 lines), the
  approved criteria and the locked test list for a tests-first task, and the
  verify result the builder got.
- No replay before the merge: the run reads the same material in fewer
  trips, and nothing tells it to read less. The check is on real runs: the
  phase 0 table after the next 10 critic and reviewer runs.

Done when: the rule is merged and the 10-run table is in the progress log. If
calls per run did not fall, the rule is reverted or changed.

### Phase 2 — Critic re-run rule (idea E)

- `agents/critic.md`, "Again whenever the criteria change": the brief of a
  re-run carries the `git diff` of the criteria and the lines already under
  `## Criteria review`. A narrowed run still checks three things: the
  changed criteria, every other criterion they could contradict, and that
  each earlier finding is still answered.
- A full run is required when no earlier review exists, when the change
  touches other stored data than before, when more than half of the criteria
  changed, or when the owner asks.
- The report says which kind of run it was and what it did not read, and the
  line goes under `## Criteria review`, so the owner sees it before approving.

Done when: the rule is merged. No replay: it limits what dispatchers do
already and adds no shortcut.

### Phase 4 — Measure and close

After 20 new critic and reviewer runs, or two weeks, rerun the phase 0 table.
Record keep, change or revert for each rule in the decision log, then move
this plan to `plans/completed/`.

Target: median calls per run 16 to 10 or fewer (critic) and 11 to 6 or fewer
(reviewer); cost per run 30% lower; subagent share of all cost back under
12%. A reviewer or critic miss that reaches CI or the owner counts against
the rule that shortened the run.

## 5. Open questions

- **Q1:** test a cheaper model for the reviewer? **No** (owner, 2026-10-12;
  first yes as a test, then dropped with the replay checks).
- **Q2:** a rule for the narrowed critic re-run (phase 2)? **Yes** (owner,
  2026-10-12), after the risk rating in the decision log.
- **Q3:** run the replay checks? **No** (owner, 2026-10-12; first yes,
  later): dropped, not deferred. See the decision log.
- **Q4:** how is phase 1 checked? **On the next 10 real runs, with the
  phase 0 table in `scripts/usage-report.py`** (owner, 2026-10-12, choice A
  over reusing the throwaway script).

## 6. Not in scope

- The approval hook accepting a stale criteria review (deferred by the owner;
  it is a gate fix, not a cost fix, and it adds critic runs).
- Tester and builder dispatch (idea H), and main-session cost.
- Orchestration: no hook counts or stops a subagent's calls.
- Weaker checks: no role is removed and no approval is skipped.

## 7. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-10-12 | — | Plan written. Section 2 measured with a throwaway script over 58 subagent transcripts of 2026-10-03..2026-10-11; nothing merged, no rule changed |
| 2026-10-12 | — | Owner's answers: Q1 yes as a test, Q3 yes but later. The briefs and reports of the critic re-runs were read for Q2 (section 2). Phases reordered: the replay checks, the call budget and the model test are phase 3 and wait for the owner |
| 2026-10-12 | 0 | Owner: Q2 yes, Q4 choice A. `scripts/usage-report.py` prints a table per subagent role: runs, share, median cost, calls, first and peak context, the four-way cost split, tool calls per call. Baseline, `--since 2026-10-03 --until 2026-10-11`: the section 2 tables (critic 24 runs, 16 calls, 243k per run; reviewer 27 runs, 11 calls, 160k). Section 2 now holds the script's numbers; the first draft, from a throwaway script, had 58 runs and 18.5M. Also run on 2026-09-23..2026-10-02 (14 runs) and on an empty period |
| 2026-10-12 | 1 | Rule written: "Subagent cost" in `router/ORCA-INTEGRATION.md`, section 8 (what every brief holds, the batch line, the critic and reviewer lists), linked from `workflows/build-review.md`, `agents/critic.md` and `agents/reviewer.md`. Text added only; no existing line changed. Open: the table after the next 10 critic and reviewer runs |
| 2026-10-12 | 1 | Diff limit in the reviewer's brief lowered from about 400 to about 100 lines. Phase 3 (replay checks, call budget, reviewer model test) removed from the plan on the owner's word; there is no phase 3 |
| 2026-10-12 | 1 | PR #23 merged (9bc8a18). Open: the table after the next 10 critic and reviewer runs |
| 2026-10-12 | 2 | Rule written: "Re-run after a criteria change" in `agents/critic.md` (what a narrowed run still checks, when a full run is required, the line under `## Criteria review`). Text added only |

## 8. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-10-12 | Aim at calls per run, not at the start cost | The first call is 13% of subagent cost; input on later calls is 80% |
| 2026-10-12 | Critic and reviewer only; tester and builder left as they are | 61% of subagent cost against 39%, and no sign of waste in the 8 tester and builder runs |
| 2026-10-12 | The critic keeps its own fresh subagent and its model | It guards what a non-coder owner signs |
| 2026-10-12 | Risk rating of the narrowed critic re-run (Q2). Chance of a miss: low to medium; impact: high, the owner signs the criteria. Against today: lower, not higher | All 6 re-runs in the data were narrowed already, by the dispatcher's own choice and with no limit. The rule adds the contradiction check, the full-run cases and a line the owner sees. Not known: what a full run would have added |
| 2026-10-12 | The call budget moves from Do to Test | It is the one phase 1 idea that can make a run read less; it merges only after the replay |
| 2026-10-12 | The critic's brief holds material only, not the author's reasons (one line beyond the phase 1 list) | A fuller brief must not carry the author's view into a run that is fresh on purpose (`agents/critic.md`, Role) |
| 2026-10-12 | The diff goes in the reviewer's brief only up to about 100 lines, not 400 | The dispatcher writes the brief as output (weight 5) and keeps it in its own context. Estimate, not measured: a 400-line diff costs the main session 25k to 50k, about the 48k the reviewer run is meant to save; a 100-line diff costs 6k to 12k |
| 2026-10-12 | Phase 3 dropped and its text removed: no call budget, no reviewer model test, no replays (owner) | The whole plan is worth at most 3% of all cost, likely 1% to 2%. The replays cost about 2M at once, and the call budget is the one idea that can make a check weaker. Unused plan text is clutter; git keeps it (PR #22) |
| 2026-10-12 | A narrowed critic run that meets a full-run case reports it, and a full run follows (one line beyond the phase 2 list) | The dispatcher picks the kind of run before the critic has read the change; the critic is the one that can see the choice was wrong |
