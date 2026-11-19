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

- **Q1.** (answered 2026-11-16: yes, decision log) May SIMPLE changes of one sitting share a PR (idea A), or does the
  owner want one PR per change for the record?

## 6. Not in scope

- Policy text size: 1.8% of cost, dropped as a lever on 2026-10-12.
- Retrieval layers, repo maps, a second model runtime (all dropped or closed
  with data).

## 7. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-11-13 | none | Plan written |
| 2026-11-15 | 0 | Three numbers explained, four tables below (PR #202); item 3 waits for the owner's `/context` |
| 2026-11-15 | 1 | `usage-report.py` fixed (PR #212): one task per opened PR, images by size, median per task; recount below |
| 2026-11-16 | 1 | Ideas rated, owner chose A, B, C, D (trial); E dropped, F later (PR #213) |
| 2026-11-16 | 1 | A and B in `workflows/simple.md` (PR #214) |
| 2026-11-16 | 1 | D deferred: no project is mostly SIMPLE (next PR) |
| 2026-11-16 | 0 | Item 3: owner's `/context` in all four; artifact tools 7.5k to 8.4k in C and here (this PR) |
| 2026-11-19 | 0 | `"enableArtifact": false` in C and here (2026-11-17): first turn about 38-39k to 25-27k in both, about 12k less per session start |

### Phase 0 findings (2026-11-15)

Recount of the same window on 2026-11-15: 400 sessions, 76 SIMPLE tasks,
0.43M and 4.0 owner messages each, `Read` 58%, first turn 31.4k (more
transcripts on disk than on 2026-11-13). Turns are API calls of the task's
segment; a turn with several tools counts once, in the order handoff, CI and
merge, branch and PR, change. Split at 2026-11-10: before / after.

**1. SIMPLE tasks.** 65 of 76 take their route only from a PR body, so the
report charges the whole session to them, from its first call; 49 of those
open with "continue" and 20 made two or more PRs. All 13 tasks of 50+ turns
are of this kind and hold 56% of SIMPLE cost: sessions that carried other
work (an SDK upgrade, a 19-file design doc set, an audit) and whose first PR
body said SIMPLE. They were not SIMPLE tasks; the 0.41M is mostly a counting
artifact.

| Turn kind | All 76 (turn / cost share) | 63 under 50 turns (turns per task) |
|---|---|---|
| Change and its check | 39% / 40% | 5.9 |
| Text-only reply to the owner | 21% / 19% | 4.2 |
| Branch, commit, PR text | 16% / 16% | 3.4 |
| CI wait and merge | 13% / 12% | 3.1 |
| Handoff | 9% / 11% | 2.7 |
| Cost per task, owner messages | 0.43M, 4.0 (before 0.35M, after 0.64M) | 0.23M, 2.9, median 17 turns |

In a real SIMPLE task the fixed steps (PR, CI, handoff) take 9.2 turns
against 5.9 for the change: the guess holds. Owner messages (301, by first
words, rough): approval or "go" 41%, a new request in the same session 34%,
a question 15%, a correction 7%, an interrupt 3%; "continue" opens the
session and is not counted.

**2. Reads.** Images (screenshots) are 47% of all tool-result tokens: the
report counts a base64 image as text (characters / 4), about 100 times what
the model is charged for it. Text `Read` is 11% of tool-result tokens, 22%
without images (26% on 2026-10-12): reads did not grow.

| Main-session reads | Before | After |
|---|---|---|
| Image reads, count | 88 | 35 |
| Text reads, count, mean tokens | 1,181, 1.5k | 189, 1.8k |
| Text reads whole file over 10k (count, token share) | 0.5%, 5% | 1.6%, 14% |
| Same file read again in the session (count, token share) | 47%, 44% | 26%, 24% |
| Subagents: whole over 10k; read again | 3.2%, 14%; 56%, 55% | 13%, 38%; 31%, 27% |

The 30 largest reads are all whole images in project A (34% of read
tokens). The 30 largest text reads (8k to 30k) are 19 to 20 plan files and
9 saved tool outputs in each of main and subagent runs, mostly project A.

**3. Base context** (from the session-start listings; the owner's `/context`
in each project is still to come).

| Item | Tokens each turn | Sessions that used it (400) |
|---|---|---|
| Built-in skills (13) | 1.3k | 0 |
| Agent type list | 1.2k | `Agent` in 168 |
| claude.ai design set (7) | 0.5k | 0 |
| dataviz and artifact skills (4) | 0.6k | 2 (dataviz) |
| Project A's own skills (4) | 0.4k, project A only | 0 |
| TokenEconomizer (7 commands, hooks) | 0.2k | 0 typed; runs by hook |
| MCP playwright, figma (deferred, most tools denied) | names only | 8, 1 |
| Instructions (CLAUDE.md, AGENTS.md, memory) | 1.5k to 2.5k | all |

Add-ons are about 1.5k to 2k of a 31k first turn; the rest is the runtime's
own prompt and tools.

Owner's fresh-session `/context` (2026-11-16): A 20.3k, B 20.2k, C 28.3k,
this repo 27.9k. Runtime prompt and tools are 13.1k to 13.7k in all four.
C and this repo also load seven claude-artifacts MCP tools up front (8.4k
and 7.5k); A and B set `"enableArtifact": false` in local settings and load
none. Instructions 1.3k to 3.6k (this repo adds `AGENTS.md`), skills 2.5k to
3.1k. Median first turn per project, before / after: A 26.6k /
28.9k, B 30.1k / 32.6k, C 37.9k / 37.3k, this repo 37.8k / 37.2k. The base
did not fall after 2026-11-10.

**4. Session model.**

| Setting or measure | Value |
|---|---|
| `model` in a project's `.claude/settings.local.json` | none of the four |
| Global `settings.json` | `opus`, effort medium for it |
| SIMPLE tasks on the strong tier | 74 of 76 (2 on another model) |
| All turns on the strong tier | 97% |

### Phase 1 recount with the fixed report (2026-11-15)

Same window, 400 sessions. A PR-body route now makes one task per opened PR,
from the call after the previous PR; an image counts by its size, not as
base64 text.

| Measure | Old report | Fixed report (before / after 11-10) |
|---|---|---|
| SIMPLE tasks, mean cost, median cost | 76, 0.43M, none | 90, 0.38M, 0.21M (0.22M / 0.12M) |
| SIMPLE owner messages per task | 4.0 | 3.5 |
| `Read` share of tool-result tokens; images | 58%; counted as text | 23%; 2% of all |

The first task of a session still starts at the session's first call, so
the mean keeps the carried work; rate ideas A, B, E on the median.

### Phase 1 ratings (2026-11-16)

| # | Rating | From the numbers | File, PR |
|---|---|---|---|
| A | Do | Fixed steps 9.2 turns against 5.9 for the change; 34% of owner messages are a new request in the same session | `workflows/simple.md`, next PR |
| B | Do | CI wait and merge 3.1 turns per task: push and `merge-pr.sh` in one call, no `gh pr checks` polling | `workflows/simple.md`, same PR as A |
| C | Do (owner) | claude.ai design set: 0 uses in 400 sessions, 0.5k each turn; built-in skills cannot be turned off | owner's settings, no PR |
| D | Deferred | 97% of turns on the strong tier; 7 days in one mostly-SIMPLE project, kept only if cost falls with no rise in corrections | project's local settings, no PR; result in this log |
| E | Drop | Whole-file text reads over 10k are 1.6% of reads; `Read` is 23% of tool results, not 59% | none |
| F | Later | Waits for gate S5-0 (owner's check 2026-11-24) | none |

## 8. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-11-16 | D deferred, not started: SIMPLE share of cost per project over 30 days is 4% to 18% (the most-SIMPLE consuming project has 8.5% SIMPLE, 31% COMPLEX); revisit when a project's work is mostly SIMPLE | A fast tier saves little there and may raise corrections on large tasks; owner chose to defer |
| 2026-11-16 | Q1 answered: small changes of one sitting may share one PR, one line each in the PR text | Owner chose; fixed steps cost more than the change |
| 2026-11-16 | D runs as a 7-day trial in one project, back to the strong tier if owner corrections rise | Owner chose the trial over a default change |
| 2026-11-15 | Owner: fix `usage-report.py` (session charged to a PR-body route; images counted as text) in phase 1 before rating ideas A, B, E | Ratings built on wrong counts would be wrong too |
