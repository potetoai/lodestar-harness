# Plan: steady state (parent of seven child plans)

> **For Claude Code:** This is the parent plan. It holds the evidence, the
> order and the targets; the work is in the child plans. An agent given one
> child reads that child in full and section 2 here, nothing else. Answer
> nothing in "Open questions" yourself. When a child's phase moves, add one
> row to the progress log here (date, child, PR number).

## 1. Why this plan

The owner asked on 2026-11-13 for a review of the whole harness: what is
wrong, what costs too much, and whether it pays. The review found that the
policy works where it was measured, and that three costs grew since the last
count (2026-10-12): the harness's own upkeep, subagent runs, and stops sent
back by a hook. It also found repo rules that are not kept (release cadence,
handoff length, project names in a public repo) and one unsafe tool (the
self-test file).

Goal: hold the harness still while its running cost comes down. Fewer
releases, fewer wasted turns, a count each month that shows whether the
process still earns its cost in each project.

## 2. Evidence (measured 2026-11-13)

Source: `python scripts/usage-report.py --since 2026-10-28 --until 2026-11-13`
(add `--match <folder regex>` for one project, `--friction` for the hot
sessions). 385 sessions, 18,050 turns, 380.2M weighted units (input 1, cache
write 1.25, cache read 0.1, output 5). Shares overlap. Projects are named A
(an app, the largest), B (a data project) and C (the newest, sessions from
2026-11-08 only); the key is in the owner's local handoff, never in this repo.

| Measure | 2026-10-12 count | Now | Child |
|---|---|---|---|
| This repo's share of all cost | not counted | 11.2% (42.5M, 104 sessions) | 1 |
| MAINTENANCE tasks (mostly template upgrades) | 1 task, 0.1% | 26 tasks, 2.3%, about 0.33M each | 1 |
| Template releases | rule of 2026-10-19: at most one per 7-14 days | 11 (2.9.7 to 2.9.17) from 2026-11-07 to 11-12 | 1 |
| Turns sent back by a Stop hook | 42 of 5,217 (0.8%) | 309 of 18,050 (1.7%); project C 4.4% | 2 |
| Subagents | 15.2% of cost, 57 runs | 30.2% of cost, 411 runs | 4 |
| Turns above 150k context | 23.1% | 11.2% (the 200k nudge holds) | none |
| Base context on every turn | 26.8% | 18.9% (median first turn 31.6k) | 5 |
| `Read` share of tool-result tokens | 26% | 59% | 5 |
| Policy reading | 1.1% | 1.8% | none: not a lever |
| SIMPLE task | 5 tasks | 72 tasks, 0.41M and 4.0 owner messages each | 5 |
| Owner questions (`AskUserQuestion`) | 16 in 97 sessions | 91 in 385 sessions | none |

Cost by project: A 195.0M (51%), B 88.0M (23%), C 47.8M (13%), this repo
42.5M (11%).

Not from the usage report:

- `enforcement/test.sh` is one file of 2,270 lines (190 KB). The full run is
  too slow to use on Windows, and on 2026-11-11 a fixture snippet run outside
  a fixture folder made a commit and changed git config in this repo (undone).
- `.ai/handoff.md` here held 68 lines with history back to 2026-11-09; the
  global bootstrap asks for a short file, overwritten.
- `git grep -c -E '<the three project names>'` finds 170 lines in 15 tracked
  plan files. `AGENTS.md` forbids naming consuming projects.
- Escaped against caught, owner's baseline 2026-10-10 to 11-09: project B
  about 12 real bugs found after merge and 3 caught before; project A 3 after
  (plus 2 red main CI runs) and 13 caught, 13 more by planned checks; project
  C 0 and 2. Project B's escapes came from later events (late source data,
  quota, interrupted runs), not from code a review could read.

Limits of this evidence: no project runs without Lodestar, so there is no
control; the route table cannot tie 42% of cost to a workflow (sessions that
open with "continue"); TokenEconomizer was installed on 2026-11-10, inside
the window.

## 3. Child plans

| # | File | What | Changes safety files | Starts |
|---|---|---|---|---|
| 1 | `plans/active/steady-1-own-cost.md` | Release rhythm, handoff, the harness's share of cost | only if Q1 is yes | now |
| 2 | `plans/active/steady-2-stop-hook.md` | Stop-hook repeats; a handoff-length note | yes | now (phase 0 reads only) |
| 3 | `plans/active/steady-3-test-suite.md` | Split `enforcement/test.sh`, run one part, fixture guard | yes | after child 2's fix merges |
| 4 | `plans/active/steady-4-subagent-cost.md` | Subagent cost, round 2: run counts and output | no | 2026-11-27 (gate S4-0) |
| 5 | `plans/active/steady-5-task-cost.md` | Small-task cost, reads, base context, plugins | no | phase 0 now; plugin step after 2026-11-24 |
| 6 | `plans/active/steady-6-project-fit.md` | Does it pay, per kind of project; run-time checks | no | 2026-12-09 (monthly count) |
| 7 | `plans/active/steady-7-plan-hygiene.md` | Project names out of tracked files; closed phases out of active plans | only if Q3 is yes | now for completed plans; active ones after 2026-11-26 |

Order and what may run side by side:

- Now, side by side: child 1, child 2 phase 0, child 5 phase 0, child 7
  phase 1. They touch different files.
- Child 2's fix and child 3 both edit `enforcement/test.sh`: child 2 first.
  Both ship in one weekly release (child 1's rhythm), not one each.
- Child 4 waits for the 2026-11-19 recount and two weeks of data after the
  critic change of 2026-11-13 (PR #195).
- Child 6 decides on the 2026-12-09 count and reads what children 4 and 5
  measured.

One agent per child, one session per phase (`.ai/handoff.md` after each). No
child spawns a subagent for measuring: every count comes from
`scripts/usage-report.py` or `gh`, offline.

## 4. Targets

Counted with the section 2 command over the 14 days before each check.

| Measure | Now | Target | First check |
|---|---|---|---|
| Template releases | 11 in 6 days | at most 1 per 7 days, urgent ones counted apart | 2026-11-27 |
| This repo's share of cost | 11.2% | owner sets it (Q2); proposed 5% | 2026-12-09 |
| Turns sent back by a Stop hook | 1.7% | 0.8% or less | 14 days after child 2 reaches the projects |
| Subagent share of cost | 30.2% | set after child 4 phase 0 | 2026-12-11 |
| Handoff here | 68 lines | 30 lines or fewer | each session |
| Lines with a project name in tracked files | 170 | 0 | when child 7 closes |

## 5. Limits

- Repo rules hold (`AGENTS.md`): no orchestration system, no deleted policy,
  safety-file PRs wait for the owner's typed merge approval, the Router eval
  suite runs only for a `router/ROUTER.md` change.
- No new line in an always-loaded file (`AGENTS.md`, global `CLAUDE.md`,
  README opening, hook output) unless most sessions need it.
- Never fit Lodestar to one project: a fix names the general cause.
- No external plugin or skill is added to save cost without the trial in
  child 5; each one adds text to every turn of every session.
- Decisions already made stay made unless new data is named: cheaper model
  for critic and reviewer (dropped 2026-10-12), call budget in briefs
  (dropped 2026-10-12), Router card and brief rewrite (dropped 2026-10-12).

## 6. Open questions

- **Q1 (child 1).** Should CI in this repo refuse a second `VERSION` raise
  within 7 days unless the PR text carries an urgent reason? The text rule of
  2026-10-19 was not kept.
- **Q2 (child 1).** Target for this repo's share of cost: 5%, or another
  number?
- **Q3 (child 7).** A local check for project names before a commit, read
  from a gitignored list? The names cannot be listed in CI without
  publishing them.
- **Q4 (child 2).** How many times may the same failure send the agent back
  in one session before the stop is let go: 2 or 3?

## 7. How to start a child

In a new session in this repo: "Read `plans/active/steady-state.md` section 2
and `plans/active/steady-<n>-<name>.md`. Do phase <p> only, then stop and
report." The agent routes the phase through the Router as usual.

## 8. Progress log

| Date | Child | Work |
|---|---|---|
| 2026-11-13 | all | Parent and seven child plans written from the review; no work started |

## 9. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-11-13 | One parent with seven children instead of one long plan | Owner hands each child to a different agent; an agent reads one child and section 2 here |
| 2026-11-13 | Children 4 and 6 wait for data gates | The critic rule changed on 2026-11-13; counting now would mix old and new behaviour |
