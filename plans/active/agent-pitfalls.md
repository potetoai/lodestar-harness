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
- `plans/completed/subagent-cost.md` phase 4 is measuring critic and reviewer
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
| 19 | (found in phase 0) Stop hook holds again with nothing changed | `verify-before-stop.sh` runs `make verify` on every stop | **Do** (Q4), phase 1b |

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

### Phase 1b — Stop hook repeat holds (item 19, Q4)

- Tests first in `enforcement/test.sh`: a failed verify holds once; a second
  stop with the same tree and the same failure is let through; any change to
  the tree (tracked or untracked files) or a different failure holds again;
  the locked-test check above it never relaxes.
- `verify-before-stop.sh`: after a hold, keep a fingerprint of the tree and
  the failure in `.git/lodestar-verify-held`; when a later stop matches it,
  exit 0 with a one-line note. CI stays the gate.
- Bump `enforcement/VERSION`.

Done when: `bash enforcement/test.sh` and links pass; the phase 5 rerun shows
Stop-hook forced turns back near 0.5% of turns.

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
case where the Codex builder deleted the adapter (handoff of 2026-10-13); run
since 2026-10-12, it flags the App01 session where lint blocked 52 times on
one file (phase 0); and a maintenance dry run stays within 5 excerpts.

### Phase 4 — Effort by role (item 1, only if Q2 is yes)

Starts after `plans/completed/subagent-cost.md` phase 4 has its numbers.

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

Data gates for the parts not yet decided (`rules/documentation.md`, section
6; set 2026-10-28, owner asked that waits rest on data, not a date):

| Gate | Measure (source) | Minimum | Check | Stop | Status |
|---|---|---|---|---|---|
| P5-a Phase 2 (PROTOTYPE) | Sessions routed PROTOTYPE in all projects (`usage-report.py` route lines, PR route lines) | 3 uses | 2026-11-05 | 2026-11-26 | waiting (0) |
| P5-b `--friction` | Maintenance runs that ran `usage-report.py --friction` (grep transcripts for the command), and fixes that came from its output (feedback rows, PRs, read by hand) | 3 runs, from 2 projects | 2026-11-05 | 2026-11-26 | waiting (1) |
| P5-c Critic limit (#94, #95) | Plans with critic runs since 2026-10-27: runs per plan, findings per narrowed run (`- Run <n>` lines in plan `## Criteria review`; findings counted by hand in critic reports) | 8 plans from 2 projects, 3 of them with `critic-limit.sh` installed (batch release) | 2026-11-05 | 2026-11-26, or release + 21 days if the batch ships after 2026-11-05 | waiting (2: vn30, no hook) |

Phase 5 is done when all three are met or stopped. At the stop day, P5-a and
P5-b below the minimum mean the feature is not used as built: propose to drop
or change it.

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
  English**, like other technical terms. Later the same day: the "Meaning"
  column is in the owner's language (owner, after the vn30 dry run).
- **Q4 (from phase 0):** `verify-before-stop.sh` holds the agent again when
  nothing changed since its last failed `make verify` (seen while waiting for
  a tests-first tester: "still red, I changed nothing"). Add a phase that
  lets the agent stop when the tree and the failure are the same as at the
  last hold? The first hold after any change stays, and CI stays the gate.
  Idea 10 of `plans/completed/token-efficiency.md` was dropped on 2026-10-12
  at 0.5% of turns; phase 0 measured 1.2% of cost. A yes adds this one
  exception to "Not in scope". Recommended: yes, tests first. **Answered
  2026-10-15: yes**, done as phase 1b (PR #38, template 2.3.8).

## 6. Not in scope

- Shortening policy files for tokens (dropped 2026-10-12); only a move found
  by phase 0 evidence.
- Any orchestration; the runtime dispatches.
- Changing subagent models or briefs while `subagent-cost.md` is measuring.
- Relaxing any hook, test lock or approval gate outside `proto/*` (phase 2).
  The one exception is Q4: the Stop hook lets an unchanged failure stop
  (phase 1b).

## 7. Progress log

| Date | Phase | Note |
|---|---|---|
| 2026-10-15 | — | Plan written; all 18 items rated against main 2.3.7 |
| 2026-10-15 | 0 | Baseline `python scripts/usage-report.py --since 2026-10-12`, all projects: 69 sessions, 3,183 turns, 92.0M weighted units; policy reading 1.9%, output 16.4%, subagents 27.9% (tester 54% of it, mostly Codex parity), turns above 150k 18.7%; owner questions 25 (13 in one RSI design session, each a real decision); Stop-hook turns 42; Read 53% of tool-result tokens |
| 2026-10-15 | 0 | Item 2: feedback logs of this repo, vn30 and App01 (27 rows). Misses of an existing rule were of short project rules (AGENTS.md rules 1 and 2, owner language), a plan, memory, and once the `.ai/project.md` merge policy (App01); none traced to `router/`, `ORCA-INTEGRATION.md` or `rules/testing.md` |
| 2026-10-15 | 0 | Item 6: hook text reaching the model (throwaway scripts in the session scratchpad): about 22k tokens in all sessions (lint blocks 53, 52 of them on one App01 file; context nudge 27; SessionStart 77; approval 12); carried cost under 0.1%. Stop-hook forced turns: 47 counted, 1.08M weighted (1.2% of cost); the held turns read "`make verify` still red for the same reason, I changed nothing" while a tests-first tester was running |
| 2026-10-15 | 0 | Seen, left to the projects: vn30 tag `unstated-assumption` twice (open), plus `unchecked-example` and `incomplete-rule-scan`, all "a claim shown before it was checked"; its next maintenance handles D2 |
| 2026-10-15 | 1 | "Domain Terms" table added to the `project.md` template; onboarding fills it, maintenance adds it, the intake gate asks about unknown words, builder names after it, reviewer flags new names. Dry run on vn30 (read only, not written): 8 rows from AGENTS.md and `.claude/docs`, 2 need the owner; vn30's code names and the owner's words are Vietnamese (`hoi_tu`, `doan_quan_tinh`), so the English term is a third name |
| 2026-10-15 | 1b | `verify-before-stop.sh` holds once per state: fingerprint of HEAD, each changed or untracked file's content (from the repo root) and the failure without digits, in `.git/lodestar-verify-held`; a pass clears it; no git keeps the old behavior. Tests first (4 red, then green). Sonnet review: 1 major (subfolder project missed tracked edits: git prints root paths), 3 minor (empty hash compare, one process per file, digit test not portable), all fixed with tests. Known limits, accepted: submodule contents and gitignored files are not in the fingerprint. Template 2.3.8 |
| 2026-10-16 | 2 | Route PROTOTYPE (`router/ROUTER.md` section 5, rule 17) and `workflows/prototype.md`: `proto/<name>` branch in its own worktree (Q1 a), time box, demo and findings, then worktree and branch deleted. `guard-install.sh` blocks pushing a `proto/*` branch and any push while on one; `verify-before-stop.sh` skips verify on `proto/*`. Tests first (13 red, then green), Claude and Codex. Sonnet review: worktree push missed (branch read from the project folder), quoted refs, `--all`/`--mirror`, rename dodge, Router "every workflow ends with verification"; all fixed with tests (push judged from `cwd`, `cd X`, `git -C X`; rename to or from `proto/` blocked). Known limit: starting `proto/*` on top of real work skips the stop hook; CI is the gate. Smoke in a throwaway bootstrapped project (deleted): push blocked, stop on `proto/*` clean, the same failure held off it. Template 2.5.0 |
| 2026-10-16 | 3 | `usage-report.py --friction`: per transcript (subagents too) counts tool errors, hook and permission blocks (context nudge excluded), repeats (same command or file failing again with no success of it between) and owner interrupts (count 3); top 5 with one `--excerpt` range each (30 lead lines); `--excerpt` prints one short line per entry. Maintenance step 2 runs it. Checks: 2026-10-13..14 in this repo flags 764938f6, the owner interrupt after the Codex builder stopped mid-replacement of the adapter (excerpt shows it). Sonnet review: one failed call counted twice (hook and result), one rejection counted as two interrupts, non-object lines, `--excerpt A` without `-B`, folder rule; all fixed. Same file with a different edit still counts as a repeat (the lint case needs it). Since 2026-10-12 the top session is vn30 6c52f53b (lint blocked 14 times on `rsi_patterns.py`, 13 repeats); no App01 transcript has more than 10 lint blocks, so the phase 0 "52 on one App01 file" does not reproduce (most likely the throwaway count double-counted and misread the project). Dry run: 5 excerpts, 14.6k characters (about 4k tokens). No installed file changed, so no template bump |
| 2026-10-19 | 4 | Transcripts record `effort`: every subagent ran medium. Tester cost since 2026-10-13 (26 runs, App01 and ProjectS): 46.7% of subagent cost, about 11.5% of all cost. Split: start context re-sent 15.5%, plan-file reads 7.9% (whole plan read 2-8 times per run), cache rewrites after long waits about 8% (mostly 2-hour waits), writing tests about 5%; cache read 56%, cache write 31%, output 13% |
| 2026-10-27 | 5 prep | `usage-report.py` takes the route line from a PR body when the session wrote none (sessions continued after `/clear`); Router: a continued session writes the line again. Routed cost 8.7% -> 42.8% (2026-10-17..27); PR #93 |
| 2026-10-27 | 5 prep | Critic run limit hook `critic-limit.sh` (PR #95) |
| 2026-10-27 | 5 | Rerun since 2026-10-17: 235 sessions, 12,456 turns, 244.7M units; policy reading 1.2% (was 1.9%), subagents 24.5% (27.9%), owner questions 0.40 per session (0.36), Read 55%; PR #99 |
| 2026-10-27 | 5 | 1b: 176 Stop-hook holds = 125 `make verify` (1.0% of turns; first answers 0.84% of cost, was 1.2%) + 51 unpushed commits (0.27%). Of 54 holds equal to the one before, 48 followed an edit or shell command, 6 nothing (a background builder was editing); PR #99 |
| 2026-10-27 | 5 | 1: App01 has the Domain Terms table, vn30 does not (missed at its 2026-10-19 maintenance). 2: no real PROTOTYPE route yet. 3: `--friction` ran in one maintenance (vn30); PR #99 |
| 2026-10-28 | 5 data | Critic limit, for the 11-05 recount: vn30 `rsi-force-filter` 6 runs (3 full, then 3 narrowed, each after an owner fix and "duyệt critic", as the rule allows); narrowed runs 16% of its critic cache reads; run 4 found a live-DB write, run 5 three minors, run 6 none. vn30 `intraday-write-changed-only` 4 runs. vn30 has no `critic-limit.sh` yet (batch); PR #103 |

## 8. Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-10-15 | Shortening Router and rules not redone | Owner dropped it on 2026-10-12 (policy reading 1.1% of cost); phase 0 checks the quality side only |
| 2026-10-15 | Item 2 (long files): drop | 0 rule misses traced to the long Lodestar files; 1 to `.ai/project.md`, under the 2-miss bar |
| 2026-10-15 | Item 4 (aligning too often): drop | 25 owner questions in 69 sessions, about half in one design session where each was a real decision |
| 2026-10-15 | Item 6 (hook text): drop; Stop-hook repeat holds raised as Q4 | Hook text under 0.1% of cost; repeat holds 1.2%, above the 1% bar |
| 2026-10-15 | Phase 3 check case added: lint blocked 52 times on one App01 file | A known friction case the `--friction` table should flag |
| 2026-10-16 | Phase 3 check case moved to vn30 6c52f53b (14 lint blocks on one file) | The App01 "52" case is not in any transcript; the worst real lint case is in vn30 |
| 2026-10-16 | Codex transcripts left out of `--friction` | Owner uses Codex only through Orca, rarely; add when a Codex mistake slips by |
| 2026-10-16 | Item 19 and the phase 1b section restored | Commit 36ebe8d was pushed after PR #36 merged and never reached main; the phase 5 rerun needs its done-when bar |
| 2026-10-15 | "Meaning" column in the owner's language; `rules/documentation.md` section 5 names it as the one exception | Owner, after the vn30 dry run showed the English term is a third name the owner does not use |
| 2026-10-15 | Q4 yes: the Stop hook holds once per unchanged state (phase 1b, PR #38) | Repeat holds were 1.2% of cost, above the 1% bar; the first hold after any change stays, CI is the gate |
| 2026-10-17 | Stop hook also holds once per HEAD while the branch has commits on no remote (template 2.7.0) | Owner wants commit, push, PR and merge automated; App01 had 2 unpushed commits and a branch never pushed (2026-10-17). Phase 5 counts these holds apart from `make verify` holds (message "exist only on this machine") |
| 2026-10-17 | Test lock stays in force while any active plan has a valid Tests-First round; CI also checks a round merged before the branch (template 2.7.1) | vn30 report: two plans shared `.ai/test-lock`; closing the plan with the newest round unlocked the other active plan's tests, and CI only saw rounds on the branch. Tests from a closed plan stay locked until the last plan closes (safe side) |
| 2026-10-17 | Lock baseline is the newest valid round overall, while any active plan has a round (template 2.7.2) | vn30 report on 2.7.1: the baseline was the active plan's older round, so tests a later approved round of the closed pilot rewrote were flagged as edits (false hold, clean tree) |
| 2026-10-17 | Guard blocks running a script file that holds a PR merge (template 2.7.3); `rules/git.md` says merge directly | App01 merged PR 45 from a script by mistake, so the CI-wait and approval checks saw nothing (CI was green, owner had approved). Catches the mistake, not a merge hidden on purpose; Lodestar-managed files are skipped |
| 2026-10-17 | D2 skips repeated tags whose rows are `accepted` (owner agreed no machine rule fits); a new row warns again (template 2.7.4) | ProjectS: D2 warned every session about `unstated-assumption`, a conversation mistake no lint or test can catch, after the owner accepted it twice (2026-10-13, 2026-10-15). The only way to silence it was marking it `enforced`, which would be false |
| 2026-10-17 | Bug inbox: the global hook keeps projects in `~/.lodestar/projects.txt` and shows their `reported` `lodestar-` rows when a lodestar-harness session starts; agents also log Lodestar faults they find themselves (template 2.7.5) | Owner wants project sessions to report Lodestar bugs back here. Before, the rows were read only when the owner asked, and only owner corrections were logged. Not a GitHub issue: lodestar-harness is public and vn30 is private. Not a message to this session: it is lost when the session is closed. Costs two lines of hook text per project session |
| 2026-10-17 | Stop hook skips `make verify` when the files did not change since it last passed (template 2.7.6) | Owner: the Stop hook ran over 5 minutes after a turn that only answered a question. A failed run was already remembered per state; a pass now is too. Any file change runs it again; CI stays the gate |
| 2026-10-17 | `make verify` records its own pass, so the Stop hook does not rerun it right after the agent did (template 2.7.7, doctor A10b) | Owner: the Stop hook still took over 3 minutes at the end of every task. The agent runs `make verify` before finishing, then the hook ran it again on the same files. The stamp comes from the top-level make only (a part's pass is not the whole repo's). Existing projects add the line at upgrade (A10b warns); CI stays the gate |
| 2026-10-17 | Verify state is the working files as a tree, not HEAD plus changed files (template 2.7.8) | Found in review of 2.7.7: the usual flow is verify, commit, stop; the commit changed HEAD, so the Stop hook ran verify again on the same files. A temp index copy builds the tree; the real index is untouched. If the tree cannot be built, nothing is skipped |
| 2026-10-17 | The context nudge also fires when a task ends: a PR merged by the agent or seen merged (gh pr view), or a plan moved to completed; once per PR or plan, not for subagents | Owner: wants a /clear reminder after every task, like the 200k one. The rule was text only (global CLAUDE.md step 5) and agents skipped it. Only a real command counts: the first draft fired on quoted text in this very session. Global hook, so every project gets it without an upgrade |
| 2026-10-18 | Task-done nudge: `gh pr view` counts only for a PR this session opened (`gh pr create` records owner/repo/pull/N per session) | Audit 2026-10-18: reading an old merged PR of another project fired the nudge. A subagent's `gh pr create` is not recorded (false negative only) |
| 2026-10-18 | CI checks the route line in the PR text: SIMPLE fails with high risk or 3+ files outside `.ai/`; BUILD_REVIEW and up need a `Lodestar review:` line (template 2.7.9) | Audit of vn30 and App01 (2026-10-18): vn30 PR #113 was routed as "bugfix" (no Lodestar workflow), touched 3 files after an investigation and merged with no independent review. The route line was text only. MAINTENANCE and ONBOARDING skip Lodestar's own files in the count (template upgrades; the owner approves safety files at merge), PROTOTYPE gets the high-risk rule, owner-opened PRs need the line too (agents use the owner's gh account, so the author cannot tell them apart). The review line is the agent's own word: it makes a skipped review visible, not impossible |
| 2026-10-18 | Daily GitHub sweep (`gh-sweep.sh`) in the lodestar-harness session start, once a day: merged PRs with no route or review line, PRs closed unmerged, open PRs failing, main CI failing | Owner wants a daily check of the projects and opens a lodestar-harness session every day. A `/schedule` cloud agent spends tokens each run and cannot see this machine; a script spends none. The bug inbox misses slips no session logs (vn30 #113). Shows only what is new since the last sweep; findings grouped per kind so a project before 2.7.9 gives one line, not one per PR |
| 2026-10-18 | Session start lists active plans no commit touched for 2 days (`check-readiness.sh`); the task-done nudge says to move a finished plan | Audit 2026-10-18: App01 kept the week 1-3 plans in `active/` after their PRs merged; "move to completed" was text only. Global hook, no upgrade. A nudge, not a block: the machine cannot tell a done plan from one waiting for the owner, so the agent checks merged PRs or notes what the plan waits for |
| 2026-10-18 | Guard sees a push only as git's subcommand (template 2.7.10) | ProjectS reported `git stash push -q <file> && git switch -c <b>` blocked on main as a push: the guard matched the word `push` anywhere in a git command. Now `push` must follow `git` and its own options (`-C dir`, `-c k=v`, `--no-pager`); the merge check uses the same pattern |
| 2026-10-19 | Stop hook sees a same-size edit in the index's clock tick (template 2.7.11) | CI failed three stop-hook tests at random (the flake in the handoff). The hook copied the index with `cp`, which gives the copy a new time; git then trusted file times that matched and missed a same-size edit, so the hook could skip `make verify` after a real change. `cp -p` keeps the time, so git re-reads such files. New test makes the case every time |
| 2026-10-19 | Phase 4: keep medium effort for all roles; no per-role effort in the brief | Owner decision on the numbers above: every role already runs medium and no single cost cause points at effort |
| 2026-10-19 | `tester-cost` idea rated: fix the tester's plan reads (brief carries the criteria, tester reads only its plan section and writes the progress log once at the end); ship in the next batched upgrade. The rest dropped | Owner said yes. Plan reads are 7.9% of tester cost (about 1% of all); the other shares have no single fix: start context is the runtime's, long waits are the owner's pace, writing tests is the work |
| 2026-10-19 | Tester plan-reads fix shipped now, not in the batch: `agents/tester.md` "Reading the plan"; Router step 16 brief carries criteria and plan section | Owner asked not to wait. Roles and the Router are read from this repo, not copied into projects, so no `VERSION` change and the cadence rule does not apply |
| 2026-10-25 | Keep the tester plan-reads fix | Measured on tester runs since 2026-10-13 (same method both sides: plan-file read results, cache write once plus re-read by each later call): 24 runs before the fix, 9.8% of tester cost, median 4 plan reads per run; 28 runs after (2026-10-19..25, App01 and ProjectS), 3.3%, median 3. The bar was "revert if no drop" |
| 2026-10-27 | Critic re-runs: a narrowed run raises nothing new on unchanged criteria (except data loss or security); stop after the third run, open findings go to the owner | Owner chose B. Since 2026-10-17: 220 critic runs, 85 were a third or later run, up to 16 on one App01 plan (each narrowed run found new nits on old text). Takes effect on merge (role files are read from this repo) |
| 2026-10-27 | Hook `critic-limit.sh` blocks a critic run past the limit; "duyệt critic <plan>" allows one more (approves no criteria); each criteria approval allows one more. Claude Code only | Owner asked (App01 plan search-perf-p3 had 8 runs the same day the rule went live; runs 5-8 found only benchmark wording). A brief that names no `.ai/plans/active/` path passes (fail open) |
| 2026-10-27 | Phase 1b: keep; the "near 0.5% of turns" bar is not chased (1.0%) | Repeat holds with nothing changed fell to 6 in 11 days; the rest follow a change, mostly tests-first red rounds; cost 1.2% -> 0.84%. Lower means skipping verify after a change |
| 2026-10-27 | Unpushed-commit holds: keep | 0.27% of cost; owner wants commit, push, PR and merge automated |
| 2026-10-27 | Phase 1: keep; vn30 adds the table at its next maintenance (owner tells its session) | Maintenance rule missed once; no naming mix-up rows either way, so no quality number yet |
| 2026-10-27 | Item 4 drop stands | Owner questions 0.40 per session, was 0.36 |
| 2026-10-27 | Phase 2, `--friction` use and the critic limit (PR #94, #95): wait, recount about 2026-11-05; plan stays active | Owner: decide where data is enough, wait elsewhere. No PROTOTYPE use yet, one `--friction` run, critic limit live since 2026-10-27 |
| 2026-10-28 | The phase 5 waits become data gates P5-a..c (minimum, check 2026-11-05, stop 2026-11-26) | Owner: plans fix their start on data, not only a date; a recount on a fixed day could decide on a thin count |
