# Plan: steady 1, the harness's own cost

> **For Claude Code:** This is an execution plan, child of
> `plans/active/steady-state.md` (read its section 2 first). Read all of this
> file. Do one phase at a time and stop after each for the repo owner's
> approval. Answer nothing in "Open questions" yourself. Update the progress
> and decision logs here, and add one row to the parent's progress log, when
> a phase moves.

## 1. Why this plan

From 2026-10-28 to 2026-11-13 this repo took 11.2% of all token cost (104
sessions), and template upgrades in the projects took most of another 2.3%
(26 MAINTENANCE tasks, about 0.33M weighted units each). Eleven template
versions shipped in six days (2.9.7 on 2026-11-07 to 2.9.17 on 2026-11-12).
`enforcement/README.md` section 3 has said since 2026-10-19: raise `VERSION`
at most once every 7-14 days, at once only for a fault that blocks work or a
security fix. Each release asks three projects to upgrade: about 1M weighted
units, three PRs and three CI runs, before any feature work.

Goal: one release a week at most, a short handoff, and a number that shows
what the harness costs to keep.

## 2. Limits

- No rule is reworded. Phase 1 adds a way to keep the existing rule.
- Fixes still merge to main when ready; only the `VERSION` raise waits.
- An urgent release stays allowed, by the rule's own list (a hook blocking
  correct work, a false approval, a broken install, a security fix, a rule
  text that needs new hooks).
- A check in `.github/` is a safety-file change: the owner types the merge
  approval.

## 3. Phases

### Phase 0: Why eleven releases (read only)

For each version 2.9.7 to 2.9.17, from `git log -- enforcement/VERSION` and
the PRs it carried: was it urgent by the rule's list, asked early by the
owner, or neither? Write the table in the progress log. This shows whether
the cause is urgent faults, owner requests, or habit, and phase 1 fits that.

Done when: the table is logged.

### Phase 1: Keep the rhythm

- A release day: one fixed weekday (owner picks, Q3). Merged changes wait on
  main; the handoff keeps a line "Unreleased: PR numbers".
- The release PR text says `Lodestar release: batch` or
  `Lodestar release: urgent, <reason from the rule's list>`.
- When the owner asks for an early release, the agent says once what it
  costs (three upgrade sessions, about 1M weighted units) and the next
  release day, then follows the owner's choice.
- Q1 is yes (owner, 2026-11-13): a step in `.github/workflows/test.yml` (or a small script it
  calls) fails a PR that raises `enforcement/VERSION` when the last raise on
  main is under 7 days old and the PR text has no urgent line. Test it in
  `enforcement/test.sh` style with a fake history.
- Projects: an upgrade that is not urgent rides the 14-day maintenance run
  (`workflows/maintenance.md`), not its own session. Check that the doctor's
  "template outdated" warning does not make every session propose an upgrade
  (Router rule 15); if it does, propose wording to the owner, do not edit the
  Router in this plan.

Done when: the release-day line is in `enforcement/README.md` section 3, the
check is merged, and gate S1-1 is set.

### Phase 2: Handoff

- Overwrite, do not prepend: the file holds state, next step, scheduled
  checks, do-not-do and the route line in progress. History is in git and
  plans. Limit: 30 lines.
- The length note itself is a hook change and lives in child 2 (one
  enforcement batch).

Done when: this repo's handoff is 30 lines or fewer for two weeks (gate S1-2).

### Phase 3: The harness's share, each month

Add one line to the owner's monthly count (next 2026-12-09): this repo's
share of cost over the last 14 days, from
`python scripts/usage-report.py --match 'Lodestar-harness'` against the run
without `--match`, and the number of releases, urgent ones apart.

Done when: the 2026-12-09 count carries the line and the owner has seen it.

## 4. Data gates

| Gate | Measure (source) | Minimum | Check | Stop | Status |
|---|---|---|---|---|---|
| S1-1 Rhythm kept | `VERSION` raises on main, urgent ones apart (`git log -- enforcement/VERSION`, PR text) | 14 days after phase 1 merges | 2026-11-27 | 2026-12-18 | waiting |
| S1-2 Handoff short | Lines in `.ai/handoff.md` at each session end (read by hand, 5 sessions) | 5 sessions | 2026-11-27 | 2026-12-18 | waiting |
| S1-3 Share | This repo's share of cost, 14 days (`scripts/usage-report.py`); target 5%, 10% if 5% proves too hard | 14 days after phase 1 merges | 2026-12-09 | 2026-12-30 | waiting (11.2% on 2026-11-13) |

## 5. Open questions

- **Q1.** CI check on the release rhythm (parent Q1): yes or no? **Yes**
  (answered 2026-11-13).
- **Q2.** The share target (parent Q2)? **5%; 10% if 5% proves too hard**
  (answered 2026-11-13).
- **Q3.** Which weekday is release day? Still open.

## 6. Not in scope

- Fewer fixes. The bug inbox from projects still gets read; only the release
  waits.
- Any change to `router/ROUTER.md`.

## 7. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-11-13 | none | Plan written |

## 8. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-11-13 | Owner: CI check on the release rhythm, yes; share target 5%, 10% if 5% proves too hard | The text rule of 2026-10-19 was not kept. The target is a signal at the monthly count, not a block |
