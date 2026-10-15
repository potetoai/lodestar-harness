# Plan: agent pitfalls (Matt Pocock's list)

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time and stop after each for the repo owner's approval. Answer
> nothing in "Open questions" yourself. Update the progress and decision logs
> when a phase moves.

## 1. Why this plan

Matt Pocock (on X) listed 18 common mistakes people make when working with
coding agents. The owner asked how to avoid them and what Lodestar already
does. This plan rates all 18 against Lodestar as it is on main (2.3.7), keeps
the ones that are already covered, and does only the gaps that evidence
supports. It keeps every check: hooks, CI, tests-first, review and approvals
stay.

## 2. Evidence (read 2026-10-15)

- Cost split, 2026-10-03..2026-10-11, all projects
  (`plans/completed/token-efficiency.md`, phase 4): policy reading **1.1%**
  of cost, base context 26.8%, output 17.2%, subagents 15.2%; owner questions
  fell from 125 to 16 over a comparable period; hook-forced turns 0.25%.
- On 2026-10-12 the owner dropped the "router card" and the CI context
  budget (ideas 8 and 9 there) because policy reading is 1.1% of cost. So
  shortening `router/ROUTER.md` (627 lines), `router/ORCA-INTEGRATION.md`
  (900) or `rules/testing.md` (687) does not pay off in tokens. Long files
  could still cost quality (rules missed), but no evidence of that exists yet.
- `plans/active/subagent-cost.md` phase 4 is measuring critic and reviewer
  runs until 10 critic runs since 2026-10-13. Changing subagent settings
  before then mixes up its numbers.
- No glossary exists: `project/.ai/project.md` (508 lines) has no section for
  domain terms. The owner talks in Vietnamese; code names are English.
- No route for throwaway prototypes: every route ends in a reviewed PR.
- Maintenance step 2 sweeps git and PR history for missed mistakes, and the
  feedback hook records owner corrections. Nothing reads past session
  transcripts for wasted work the owner never corrected (repeated failing
  commands, blocked hooks, long detours). `scripts/usage-report.py` already
  parses those transcripts.
- Lodestar sets no effort level. The Agent tool takes one per subagent only
  when instructions ask for it; the main session's level is the owner's
  setting.

## 3. Rating of every item

Rating: **Do** · **Check** (measure in phase 0, act only if the number says
so) · **Optional** (owner's choice) · **Covered** (Lodestar has it; no work).

| # | Mistake | What Lodestar has today | Rating |
|---|---|---|---|
| 1 | Effort level too high | Nothing | **Optional** (Q2), phase 4 |
| 2 | Skills too long | Read only what the task needs; long files dropped for tokens on 2026-10-12 | **Check**: rules missed because of length, phase 0 |
| 3 | Not aligning before work | Router intake gate: clarify, acceptance criteria | **Covered** |
| 4 | Aligning too often, too hard | Owner questions 125 -> 16; low/medium risk proceeds | **Check**: question count, phase 0 |
| 5 | Automated checks too lax | Hooks, CI, gitleaks, mutation testing, doctor, maintenance D2 | **Covered** |
| 6 | Custom tooling token-inefficient | Lint output capped at 30 lines; hook turns 0.25% | **Check**: hook text per session, phase 0 |
| 7 | Not enough automated review | BUILD_REVIEW, reviewer and critic roles | **Covered** |
| 8 | Not reviewing past sessions | Maintenance sweep of git/PR history, feedback hook | **Do**, phase 3 |
| 9 | Too much human review | Machine checks; owner only approves merge and DB writes | **Covered** |
| 10 | Not vibe coding prototypes | No route for it | **Do**, phase 2 |
| 11 | Agent cannot verify its work | `verify-before-stop`, `make verify`, browser capability (`skills/capabilities.md`) | **Covered** |
| 12 | Babysitting the agent | Hooks block risky actions; gates only where they matter | **Covered** |
| 13 | Overloaded global steering files | Global `CLAUDE.md` is a 2.7 KB pointer; base context audited | **Covered** |
| 14 | Codebase hard to navigate | G8 (split past ~500 lines), AGENTS.md map, maintenance scan | **Covered** |
| 15 | No shared language | Nothing | **Do**, phase 1 |
| 16 | Architecture allows bad tests | Tests-first, `protect-tests.sh`, mutation testing, `rules/testing.md` | **Covered** |
| 17 | Not thinking strategically | Architect role, `skills/explore-options.md`, plans | **Covered** |
| 18 | Not thinking enough | Critic, `skills/investigate.md` two-failure stop | **Covered**; the effort side is item 1 |

## 4. Phases

Phases 2 and 3 may change installed files: bump `enforcement/VERSION` as
earlier template PRs did. PR #33 (Codex parity) takes 2.4.0; whichever
merges second takes the next number.

### Phase 0 — Baseline and checks (items 2, 4, 6)

- Run `python scripts/usage-report.py --since 2026-10-12` (all projects) and
  record owner questions, output share and policy reading in the progress
  log; this is the baseline for phase 5.
- Item 2: read `.ai/feedback-log.md` in this repo, vn30 and App01 (read
  only). Count rows where the rule already existed and the agent missed it;
  note the file and its length. Two or more misses on the same long file:
  propose moving that part to its own file (move and link, never reword).
  Fewer: drop.
- Item 4: owner questions per routed session. Drop unless it went back up.
- Item 6: size of hook-injected text per session (reminders, lint, block
  messages). Act only above 1% of cost.

Done when: the numbers and a keep/drop decision per item are in the logs.

### Phase 1 — Shared language (item 15)

- `project/.ai/project.md`: a short "Domain terms" section, one table:
  term (English, Q3) | name in code | meaning | not to confuse with. About 5 to 15 rows; it is a dictionary, not documentation.
- `workflows/onboarding.md`: fill the table from the code and docs, then let
  the owner correct it.
- `router/ROUTER.md` intake gate, one line: when the owner uses a word that
  is not in the table or maps to two things, ask once and add the row.
- `agents/builder.md`, `agents/reviewer.md`, one line each: use the table's
  code names for new names; the reviewer flags a new name for a listed
  concept.
- `workflows/maintenance.md` step 1: add the section to a project that
  lacks it (`--upgrade` never touches `.ai/project.md`).

Done when: links pass; one dry run on a throwaway copy of a real project's
`project.md` fills a table the owner finds right. vn30 and App01 get it at
their next maintenance, not from this repo.

### Phase 2 — Prototype route (item 10)

A prototype answers "what do I want?" fast, then is thrown away. It never
becomes production code; what survives is what was learned.

- `router/ROUTER.md`: route PROTOTYPE, picked when the owner wants to see or
  try an idea before deciding, or requirements are unclear after one
  question. Never for a fix, a data change or anything that must ship.
- New `workflows/prototype.md`: where it lives (Q1), no review, no tests
  required, a time box, stop background processes (G10). Output: a demo
  (screenshot or run command) and a list of findings. The findings become
  acceptance criteria of a normal BUILD_REVIEW task; the prototype code is
  deleted, never merged or copied over.
- Machine guarantee, if Q1 picks the branch option: `guard-install.sh` blocks
  `git push` of a `proto/*` branch, and `verify-before-stop.sh` skips the
  verify on `proto/*`. Tests first in `enforcement/test.sh`.

Done when: `bash enforcement/test.sh` and links pass; one prototype run in a
throwaway project (deleted after) shows the push block and a clean stop.

### Phase 3 — Session review (item 8)

- `scripts/usage-report.py --friction`: per session, count tool errors, hook
  blocks, the same command failing two or more times in a row, and owner
  interrupts. Print the top 5 sessions with the transcript path and the turn
  ranges that scored. The script does the reading; no agent reads whole
  transcripts.
- `workflows/maintenance.md` step 2: run it since `.ai/last-maintenance`,
  read only the flagged ranges (grep, then read the range), and add a
  feedback-log row with a tag for each real mistake. At most 5 excerpts per
  run.
- Claude transcripts only; Codex after parity (PR #33) merges.

Done when: run over 2026-10-13..2026-10-14 in this repo, it flags the known
case where the Codex builder deleted the adapter (handoff of 2026-10-13), and
a maintenance dry run stays within 5 excerpts.

### Phase 4 — Effort by role (item 1, only if Q2 is yes)

Starts after `plans/active/subagent-cost.md` phase 4 has its numbers.

- Check whether transcripts record the effort level. If yes, add it as a
  column to `usage-report.py` and compare cost and findings per role.
- If the numbers support it: the role brief names an effort per role
  (`router/ORCA-INTEGRATION.md`, brief template), and
  `enforcement/setup-guide.md` suggests a default for the owner's main
  session, raised for COMPLEX or high-risk work. No change without numbers.

Done when: a keep/change decision with its number is in the decision log.

### Phase 5 — Measure and close

About two weeks after phase 3 merges, rerun the phase 0 commands. Record
per phase: keep, change or revert, with the number. Then move this plan to
`plans/completed/`.

## 5. Open questions

- **Q1 (phase 2):** where a prototype lives. (a) A `proto/<name>` branch in
  its own worktree of the project: real code to start from, hooks stay on,
  push is blocked by machine. (b) A scratch folder outside the project: no
  hooks at all, but no project code. **Answered 2026-10-15: (a).**
- **Q2 (phase 4):** do phase 4 at all, or drop item 1. **Answered
  2026-10-15: keep it** and decide on the subagent-cost numbers.
- **Q3 (phase 1):** the first column holds the owner's own words (Vietnamese
  for this owner), so the table bridges how the owner talks and how the code
  names things. Recommended: yes. **Answered 2026-10-15: no, terms are in
  English**, like other technical terms.

## 6. Not in scope

- Shortening policy files for tokens (dropped 2026-10-12); only a move found
  by phase 0 evidence.
- Any orchestration; the runtime dispatches.
- Changing subagent models or briefs while `subagent-cost.md` is measuring.
- Relaxing any hook, test lock or approval gate outside `proto/*` (phase 2).

## 7. Progress log

| Date | Phase | Note |
|---|---|---|
| 2026-10-15 | — | Plan written; all 18 items rated against main 2.3.7 |

## 8. Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-10-15 | Shortening Router and rules not redone | Owner dropped it on 2026-10-12 (policy reading 1.1% of cost); phase 0 checks the quality side only |
