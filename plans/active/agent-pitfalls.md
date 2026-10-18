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
