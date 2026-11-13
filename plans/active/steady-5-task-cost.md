# Plan: steady 5, small tasks, reads, base context and plugins

> **For Claude Code:** This is an execution plan, child of
> `plans/active/steady-state.md` (read its section 2 first). Read all of this
> file. Do one phase at a time and stop after each for the repo owner's
> approval. Answer nothing in "Open questions" yourself. Update the progress
> and decision logs here, and add one row to the parent's progress log, when
> a phase moves.

## 1. Why this plan

Three numbers from 2026-10-28 to 2026-11-13 have no explanation yet, and the
owner asked whether outside plugins or skills could lower cost.

- A SIMPLE task costs 0.41M weighted units and 4.0 owner messages on
  average (72 tasks). SIMPLE means one or two files and an obvious change.
  The guess to test: the fixed steps around the change (branch, PR, CI wait,
  merge, handoff) cost more than the change.
- `Read` is 59% of tool-result tokens; it was 26% on 2026-10-12.
  `rules/coding.md` section 1 already says: grep, then read a large file by
  range.
- Base context is 18.9% of cost (median first turn 31.6k). Every installed
  plugin and skill adds its list to every turn of every session.

What is already known about add-ons: parking 141 skills cut the base from
63k to 34k (2026-10-02); a second model runtime showed no saving on small
tasks (plan closed); TokenEconomizer has been on trial since 2026-11-10,
owner's check on 2026-11-24.

Goal: explain the three numbers, then change only what the numbers support.

## 2. Limits

- Phase 0 only reads transcripts and settings. No model runs.
- No plugin or skill is added to save cost without the trial of phase 2.
- Owner's plugins are the owner's choice: this plan lists cost and use, the
  owner turns things off.
- TokenEconomizer went live inside the measured window: split every count
  at 2026-11-10 before reading it.

## 3. Phases

### Phase 0: Explain the three numbers (read only)

1. SIMPLE tasks: for the 72, turns per task and where they go (the change
   and its check; branch, commit, PR text; waiting for CI and merge;
   handoff; answering the owner). What the 4.0 owner messages are (approval,
   "continue", a correction, a new request in the same task). Tasks whose
   route line says SIMPLE but which ran 50 turns or more: were they SIMPLE?
2. Reads: the 30 largest `Read` results by tokens (file kind, whole file or
   range, project); share of reads that are whole files over 10k tokens;
   reads of the same file twice in one session; before and after 2026-11-10.
3. Base context: a fresh-session `/context` in each project and here (the
   owner runs it; one screenshot or paste each). List every plugin, skill
   set and MCP server with its tokens, and how many sessions in the window
   called it at least once (tool and skill names in the transcripts).
4. Session model: which projects set a model in
   `.claude/settings.local.json`, and the share of SIMPLE tasks that ran on
   the strong tier (Router, "Session Model and Effort").

Done when: four short tables are in the progress log.

### Phase 1: Rate and choose

Rate each idea Do, Later or Drop from phase 0, then the owner chooses:

| # | Idea | Depends on |
|---|---|---|
| A | Several small changes of one sitting go in one PR | Item 1 shows the fixed steps dominate |
| B | A SIMPLE task that waits for CI ends its turn and is picked up by `merge-pr.sh` in one call, not polled | Item 1 shows turns spent waiting |
| C | Turn off add-ons with no call in the window (owner does it, per item 3) | Item 3 |
| D | Projects whose work is mostly SIMPLE start on the fast tier (the setting exists) | Item 4 |
| E | A note at the read that crosses 10k tokens (a hook) | Item 2; a hook costs every project, so only if whole-file reads are a large, repeated share |
| F | Keep, tune or remove TokenEconomizer | Owner's 2026-11-24 check and the split in items 1 to 3 |

Done when: the owner has chosen; each Do names its file and PR.

### Phase 2: Trial rule for an outside plugin or skill

Write the rule once, in `skills/capabilities.md` beside "Sources": an add-on
that claims to save tokens is tried in one project for 7 days and kept only
if `scripts/usage-report.py` shows cost per turn down by more than its own
base-context cost, with no rise in owner corrections; the trial has a data
gate like any other. Candidates the owner names are tried one at a time.

Done when: the rule is merged (docs only).

### Phase 3: Recount

Done when: gate S5-1 is met or stopped.

## 4. Data gates

| Gate | Measure (source) | Minimum | Check | Stop | Status |
|---|---|---|---|---|---|
| S5-0 Plugin step | Owner's TokenEconomizer check (`/tokeneconomizer:status`) and the before/after split from phase 0 | 14 days of sessions after 2026-11-10, from 2 projects | 2026-11-24 | 2026-12-15 | waiting |
| S5-1 Effect | Cost per SIMPLE task, `Read` share, median first-turn context (`scripts/usage-report.py`), 14 days after the chosen changes | 30 SIMPLE tasks from 2 projects | 14 days after phase 1 | 3 weeks later | waiting (0.41M, 59%, 31.6k on 2026-11-13) |

## 5. Open questions

- **Q1.** May SIMPLE changes of one sitting share a PR (idea A), or does the
  owner want one PR per change for the record?

## 6. Not in scope

- Policy text size: 1.8% of cost, dropped as a lever on 2026-10-12.
- Retrieval layers, repo maps, a second model runtime (all dropped or closed
  with data).

## 7. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-11-13 | none | Plan written |

## 8. Decision log

| Date | Decision | Reason |
|---|---|---|
