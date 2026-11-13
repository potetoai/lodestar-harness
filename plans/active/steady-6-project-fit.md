# Plan: steady 6, does it pay, by kind of project

> **For Claude Code:** This is an execution plan, child of
> `plans/active/steady-state.md` (read its section 2 first). Read all of this
> file. Do one phase at a time and stop after each for the repo owner's
> approval. Answer nothing in "Open questions" yourself. Update the progress
> and decision logs here, and add one row to the parent's progress log, when
> a phase moves.

## 1. Why this plan

The owner asked whether Lodestar is worth using. The honest state on
2026-11-13:

- Where faults are in the code, the checks catch them. Project A: 42 PRs
  changed after review, 154 correct holds on a failing `make verify`, 13
  bugs caught before merge against 3 after.
- Where faults come from events after the merge, they do not. Project B:
  about 12 real bugs after merge against 3 caught. Its faults were late
  source data, quota limits and interrupted runs. It already runs a
  real-data check in 76 of 83 code PRs, so "check harder before merge" was
  proposed and dropped.
- No project runs without Lodestar, so the gain has no control to compare
  with. The cost is known: subagents 30% of cost, upkeep of the harness
  about 13%.

Goal: one page each month that lets the owner judge cost against catch per
project, and a method for the faults reviews cannot see.

## 2. Limits

- Lodestar stays general: nothing here is written for one project. A method
  is described by the kind of fault ("a job that reads outside data on a
  schedule"), and a project opts in.
- App observability was deferred by the owner earlier. This plan rates it
  again with the new count; it builds nothing before the owner says so.
- No new always-on step. A method lives in `skills/` and is chosen by the
  Router when the task fits.

## 3. Rating of every idea (first pass)

| # | Idea | Expected effect | Rating |
|---|---|---|---|
| A | Monthly scorecard, one table per project: cost per task by workflow, subagent share, bugs caught before merge, bugs found after, wrong hook blocks, releases taken. All from `scripts/usage-report.py`, `gh` and the feedback logs | Makes "does it pay" a number the owner reads each month | **Do** |
| B | A before/after count from each project's own history: share of fix PRs and owner corrections per month before its onboarding date and after | The nearest thing to a control that costs nothing. Weak: the project and the model changed too; say so beside the number | **Do** once |
| C | Run-health method (`skills/run-health.md`): for a scheduled job or outside data source, the job records what it expected and got (rows, freshness, finished or not) and one check tells the owner when a run is short, late or missing | Aims at the after-merge faults of project B's kind, which no review reads | **Do** if the 2026-12-09 count repeats the pattern (gate S6-1) |
| D | A fault note in `.ai/project.md`: where this project's last faults came from (code, data, environment), kept by the 14-day maintenance from the feedback log | Lets the Router and reviewer aim checks; small | **Later**, after A shows the split per project |
| E | Lighter review by default where the scorecard shows review catches little | Saves subagent runs; risk of missing the rare code fault; a per-project rule set drifts from "one standard" | **Later**, owner decides after two scorecards |
| F | A control: the same small task set run with and without Lodestar | A true comparison; costs tokens every run and `plans/active/behavior-evals.md` already covers routing | **Drop** unless gate EV-3 there says evals earn their cost |

## 4. Phases

### Phase 0: Scorecard and the before/after count (ideas A, B)

Build the table for 2026-11-09 to 2026-12-09 with the method the owner set
on 2026-11-09 (escaped: fix PRs for bugs found after merge, read from the PR
text; caught: PR text with a blocker, major or should-fix finding, plus a
failed CI step). Add the cost columns from the usage report. Run idea B once
per project from `gh pr list --state merged` and `git log`.

Done when: the scorecard is in the progress log (projects as A, B, C) and
the owner has read it.

### Phase 1: Run-health method (idea C, at gate S6-1)

Write `skills/run-health.md` (what to record, what to compare, how the owner
is told, what not to alert on) and one row in `skills/capabilities.md`. Try
it in one project that opts in, from its own session; this repo's agent
never edits a project.

Done when: the method is merged and one project has used it for 14 days.

### Phase 2: Decide ideas D and E

After two scorecards (2026-12-09 and the one after).

Done when: the owner has decided; the decision log says so.

## 5. Data gates

| Gate | Measure (source) | Minimum | Check | Stop | Status |
|---|---|---|---|---|---|
| S6-0 Scorecard | Merged PRs per project since 2026-11-09 (`gh pr list --state merged --search "merged:>=2026-11-09"`) | 20 per project in 2 projects | 2026-12-09 | 2026-12-30 | waiting |
| S6-1 Run-health | Bugs found after merge whose cause is a later event (late data, quota, interrupted run), read from fix PR text, per project | 5 in one project within the month | 2026-12-09 | 2026-12-30 | waiting (about 12 in project B, 2026-10-10 to 11-09) |
| S6-2 Method used | Runs in the opted-in project where the health check spoke, and how many were real | 14 days of scheduled runs | 14 days after phase 1 | 3 weeks later | waiting |

## 6. Open questions

- **Q1.** Is the scorecard a standing step of the monthly count (about the
  cost of one usage report and a `gh` query per project), or a one-off?
- **Q2.** If gate S6-1 is met: which project tries the run-health method
  first?

## 7. Not in scope

- A monitoring product, dashboards, paid services (GitHub Free only).
- Changing what counts as "escaped" or "caught": the owner set it.

## 8. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-11-13 | none | Plan written |

## 9. Decision log

| Date | Decision | Reason |
|---|---|---|
