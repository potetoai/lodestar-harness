# Plan: harness health (release cadence, hook review, quality numbers)

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time and stop after each for the repo owner's approval. Answer
> nothing in "Open questions" yourself. Update the progress and decision logs
> when a phase moves.

## 1. Why this plan

The owner asked on 2026-10-19 for an honest review of Lodestar. Three
problems came out of it, and the owner said to act on all three:

- **Release churn.** Template 2.0.0 (2026-10-01) to 2.7.11 (2026-10-19):
  at least 20 releases in 18 days, and 31 of 100 non-merge commits are `fix:`,
  most of them in the hooks. The owner pastes an upgrade prompt into each
  project per release; on 2026-10-19 App01 was on 2.7.10 and ProjectS on
  2.7.9.
- **Hooks that read command text.** Several fixes taught a hook to read a
  shell command better: "guard sees a push only as git's subcommand"
  (2.7.10, ProjectS row `lodestar-guard-false-positive`, 2026-10-18),
  "task-done nudge ignores heredoc bodies and quoted text", "approval hook
  wrote approvals from another session and from 'để mình duyệt'" (vn30 row
  `orca-approval-false-positive`). Text matching misses some forms and
  blocks others, so it keeps needing fixes.
- **Cost is measured, quality is not.** `scripts/usage-report.py` measures
  tokens; nothing counts whether Lodestar catches bugs. The feedback logs
  hold a few rows (ProjectS: 8 `lodestar-`/`orca-` rows, App01: none), and
  most hook faults were found and fixed in this repo's sessions without a
  row.

Goal: fewer releases, fewer hook false positives, and numbers that show
which checks earn their cost. Size matters too: about 4,400 lines of shell
in `enforcement/` and 11,000 lines of docs, kept by agents for an owner who
does not read code. Prefer removing to adding.

## 2. Limits

- Do not delete existing policy (`AGENTS.md`); a hook is removed only with
  an owner decision in the decision log.
- Changes under `enforcement/` pass `bash enforcement/test.sh`; docs pass
  `bash scripts/check-links.sh`.
- Hook changes ship in a batched release (phase 1), not one release each.
- Do not mix with `agent-pitfalls.md` phase 5 measurements: phase 2 is done
  (PR #83); phase 3 starts on its data gate (gate HH-3).

## 3. Phases

### Phase 1: Release cadence (done 2026-10-19)

Rule in `enforcement/README.md` §3: raise `VERSION` at most once every 7-14
days; release at once only for a fault that blocks work or a security fix.
The tester plan-reads fix (owner yes, 2026-10-19) shipped the same day:
it lives in `agents/` and the Router, which projects read from here.

Done when: the rule is merged.

### Phase 2: Hook review (done, PR #83)

For each project hook in `enforcement/agents/claude/hooks/` and the global
ones in `enforcement/agents/claude/global/`, write one table row:

- what it protects, and what happens without it;
- how it decides: real state (git, files, GitHub API, exit codes) or command
  text (regex on the Bash command, words in a message);
- its fixes since 2026-10-01 (`git log --format=%s -- <file>`) and its
  feedback-log rows;
- proposal: keep, move to real state, move to CI, or remove.

First candidates: `guard-install.sh` (283 lines, reads command text for
push/merge/install), `approval-record.sh` (reads message words), the
task-done nudge in `global/context-nudge.sh`. A check CI already does well
(`ci-checks.sh`, branch protection) does not need a local text guard too.

Done when: the table is in this plan, the owner has chosen per row, and
each change is merged with `enforcement/test.sh` green, in the next batch.

Finding (2026-10-23): App01 and ProjectS are private repos on GitHub Free;
GitHub refuses branch protection (403). CI blocks nothing there by itself:
a red CI stops a merge only because the guard's merge gate waits for it.
So the merge gate and the push-to-main block are the only locks.

Hook review table (2026-10-23). "Text" = reads the command or message
words; "state" = git, files, GitHub API, exit codes. Fixes counted from
`git log` since 2026-10-01; rows from the projects' feedback logs.

| Hook (part) | Protects | Decides by | Fixes / rows | Proposal | Owner |
|---|---|---|---|---|---|
| `guard-install.sh` installs | pip/npm outside the project | text | 0 / `orca-install-outside-project` (fixed) | keep | keep |
| `guard-install.sh` push to main, proto push | main changes only by PR; proto stays local | text (`push` word) | 2 / `lodestar-guard-false-positive` | move to git's pre-push hook (git names the pushed refs); keep the `--no-verify` text block | yes |
| `guard-install.sh` merge gate | merge only on green CI, no unpushed commits, owner-only PRs | text + GitHub API | 6 / `lodestar-guard-merge-text-in-command` | a merge script `merge-pr.sh <n>` waits for CI and runs the checks itself (state); the guard blocks every other merge command | yes |
| `guard-install.sh` Tests-First commit | plan and approvals.log in the commit | text + index | 1 / none | remove: `ci-checks.sh` check 3 fails it, and the merge waits for CI | yes |
| `approval-record.sh` | only the owner approves | owner words (by design) | 3 / `orca-approval-false-positive`, `lodestar-approval-via-question`, `lodestar-relock-same-criteria` | keep | keep |
| `protect-tests.sh` | locked tests, approvals.log | state | 2 / `lodestar-relock-preapproved-locked-test` | keep | keep |
| `sensitive-gate.sh` | tests-first for sensitive code | state | 1 / `lodestar-sensitive-gate-bash-edit` (CI covers Bash edits) | keep | keep |
| `lint-file.sh` | lint on each edit | state | 0 / none | keep | keep |
| `verify-before-stop.sh` | no stop while `make verify` fails or commits are unpushed | state | 8 / `lodestar-verify-stop-tests-first` | keep; fixes were about when to rerun, not false reads | keep |
| `feedback-check.sh` | mistakes get a log row | owner words | 0 / none | keep; phase 3 counts its rows | keep |
| `ci-checks.sh` (CI) | tests-first order, suppressions, route line | state + PR text | 6 / `lodestar-ci-route-message-simple-review` | keep | keep |
| `context-nudge.sh` 200k nudge | session size | state (token count) | 1 / none | keep | keep |
| `context-nudge.sh` task-done nudge | `/clear` after a task | text | 4 in one day / none | the merge script marks the task done after a merge that succeeded; drop the command-text match | yes |
| `check-readiness.sh` | project readiness, bug inbox | state (doctor) | 1 / `lodestar-readiness-hook-timeout` | keep; fix: hangs when run by hand without stdin | keep |
| `gh-sweep.sh` | daily GitHub sweep | state (GitHub API) | 0 / none | keep | keep |

Not hooks (libraries or tools): `doctor.sh`, `lodestar-lib.sh`,
`reminder-lib.sh`, `codex-owner.jq`, `global/install.sh`.

### Phase 3: Quality numbers (after phase 2)

Count, per project, from what already exists (feedback logs, `gh` PR data,
`gh-sweep.sh`, transcripts read by `scripts/usage-report.py`):

- bugs caught before merge (review/critic/tester finding that changed the
  code, CI red then fixed);
- bugs found after merge (a `fix:` PR that names an earlier merged PR, an
  owner correction row);
- hook blocks, and how many were false positives (block, then the same work
  done another way or the hook fixed).

Add the count to the maintenance workflow (every 14 days) as a few lines,
not a new tool, if the numbers can be read from data that exists.

Data gate (`rules/documentation.md`, section 6; set 2026-10-28). Phase 3
only reads data, so it does not wait for other plans; it waits for enough
PRs that ran CI (both private repos had no Actions minutes from 2026-10-25 to
2026-11-01; hand-merged PRs then cannot show "CI red then fixed"):

| Gate | Measure (source) | Minimum | Check | Stop | Status |
|---|---|---|---|---|---|
| HH-3 Quality numbers | Merged PRs since 2026-10-01 whose CI ran, per project (`gh pr list --state merged --search "merged:>=2026-10-01" --json number,statusCheckRollup`); PRs merged with no CI run left out and counted apart | 20 per project (App01, vn30) | 2026-11-05 | 2026-11-26 | waiting (0) |

Done when: one report per project is in the progress log, and the owner has
decided whether it becomes a maintenance step.

### Rated idea: enforced vs written (2026-10-29)

`plans/completed/ideas/enforced-vs-written.md` lists rules a machine checks
and rules only written. Rating:

| Finding | Rating | Action |
|---|---|---|
| F1 review line accepts any text | defect; do now, smaller than written | `ci-checks.sh` and `merge-pr.sh`: verdict starts with `approve`/`pass`, and the line names a commit of this PR. Commits after the reviewed one are not failed (decision log). Ships with the batch |
| F2 hand merges skip the checks | already covered | `gh-sweep.sh` already lists merged PRs with no route or review line (it found ProjectS #157-#170); #92 ships with the batch |
| F3 security review unchecked | drop for now | No cheap way to count security tasks; reopen on a feedback-log row where one merged without it |
| F4 no `permissions.deny` | drop for now | No incident; deny rules can block the owner's work; reopen on an incident row |
| F5 learning from mistakes | covered | Gate HH-3 above |

Done when: F1 is merged with `enforcement/test.sh` green.

## 4. Open questions

- **Q1 (phase 2):** may a hook be removed when CI checks the same thing,
  accepting that the fault shows later (at PR time, not at the command)?
  Recommended: yes for faults CI blocks before merge; no for faults that
  cannot be undone (push to main, a forged approval).
- **Q2 (phase 3):** after one report, make it a maintenance step, or stop?
  Decide after seeing the numbers.

## 5. Not in scope

- New hooks or new tools.
- Changing review, critic or tester roles (`agent-pitfalls.md`,
  `subagent-cost.md` own those).
- Shortening policy docs (`docs-tidy.md` owns it).

## 6. Progress log

| Date | Phase | Note |
|---|---|---|
| 2026-10-19 | 1 | Plan written from the owner's review request; release cadence rule added to `enforcement/README.md` §3 |
| 2026-10-23 | 2 | ProjectS report `lodestar-verify-stop-tests-first`: `verify-before-stop.sh` now allows a stop at a clean HEAD that is the valid Tests-First commit (red tests by design); ships in the ~2026-10-30 batch |
| 2026-10-23 | 2 | Hook review table written (owner said start now); owner chose per row; four changes to build, shipping in the next batch |
| 2026-10-23 | 2 | Four changes built (one PR): `merge-pr.sh <n>` is the only merge (state: CI wait, unpushed commits, owner approval, pinned head), the guard blocks every other merge command; git pre-push hook `pre-push.sh` (bootstrap installs it, doctor A4d) replaces the guard's push checks; Tests-First commit check removed (CI check 3); task-done nudge reads the marker `merge-pr.sh` leaves. Also `check-readiness.sh` no longer hangs on an open empty stdin. `guard-install.sh` 358 -> 115 lines |
| 2026-10-26 | 1 | Release 2.8.0 (batch of PRs #75-#87, incl. #87 CI minute saving), released early on owner request; within cadence (7 days after 2.7.11) |
| 2026-10-27 | 2 | PR #92: `merge-pr.sh` refuses a PR without route/review lines (ProjectS merged 5 by hand while CI had no minutes); ships in the next batch |
| 2026-10-29 | idea | Idea enforced-vs-written rated; F1 built (review line: pass verdict + a commit of this PR), PR #106; ships in the next batch |
| 2026-10-31 | 1 | Release 2.9.0 (batch of PRs #89-#111), 5 days after 2.8.0: owner exception to the cadence |

## 7. Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-10-19 | Batch template releases, at most one per 7-14 days | Owner ("ok làm đi" on the review); at least 20 releases in 18 days, each an upgrade prompt per project, and projects fell behind |
| 2026-10-19 | Hook review and quality numbers wait until about 2026-10-30 | Do not mix with `agent-pitfalls.md` phase 5; ride with `docs-tidy.md` phases 2-3 |
| 2026-10-23 | Stop hook skips verify at a clean Tests-First HEAD, not on every "no file changed" turn | Narrow: a commit does not change the tree, so "nothing changed" alone would let a broken commit stop; the Tests-First commit is the one state where red is expected. Any edit verifies again; CI stays the gate |
| 2026-10-23 | Q1: a hook may go when CI fails the same fault and the merge waits for CI; faults that cannot be undone keep a local block | Owner chose "remove, CI catches it" for the Tests-First commit check; push to main and the merge gate stay local because GitHub Free cannot lock main on these private repos |
| 2026-10-23 | Merge through `merge-pr.sh <n>` (state), push checks in git's pre-push hook, Tests-First commit check removed, task-done nudge from the merge script | Owner picked all four (AskUserQuestion). Text matching caused 6+4 fixes since 2026-10-01; state checks do not need new forms taught |
| 2026-10-23 | Build notes: the guard also blocks changing `core.hooksPath` (it would turn off pre-push); pre-push blocks the owner's own pushes to main too (they can use `--no-verify`); the task-done nudge no longer fires for a plan moved to completed or the owner's merge on GitHub; a pre-push hook that is not Lodestar's is left alone with a warning | The hook must see the pushed refs from git, so it runs for every push; the nudge reads only state now, and every agent merge goes through the script |
| 2026-10-25 | This source repo records the owner's "duyệt merge PR <n>": `.claude/settings.json` runs `approval-record.sh`, whose merge part no longer needs the Lodestar library (plan approvals still do); `.ai/approvals.log` is gitignored here | Owner wants the most automation; before, `merge-pr.sh` never saw an approval here, so every safety PR needed the owner on GitHub. The template file change ships in the batch; projects behave the same |
| 2026-10-28 | Phase 3 starts on gate HH-3 (20 merged PRs with a CI run per project), not on a date or on other plans | Owner: plans start on data; phase 3 only reads data, and PRs hand-merged without CI cannot show caught faults |
| 2026-10-31 | Release 2.9.0 five days after 2.8.0, outside the 7-14 day cadence | Owner chose it when asked (AskUserQuestion), knowing no fix blocks work. Projects upgrade once GitHub billing is fixed; one batch holds #92 merge-pr route check, #95 critic limit, #106 review line, #111 cloud sessions |
| 2026-10-29 | F1: the review line counts only with a verdict starting `approve`/`pass` and a commit id of this PR; a review of an older commit of the PR still passes; `gh-sweep.sh` keeps its loose check | Owner "làm đi". Last 60 merged PRs per repo, 78 review lines: 56 start with approve/pass, 69 name a commit, 43 name the PR head. So 26 of 69 reviews had fix commits after them; "reviewed commit = head" would force a reviewer re-run on about a third of PRs (token budget). The 22 other verdicts ("no BLOCKER/MAJOR", "changes then pass") get a clear message and a one-word change. The sweep has no commit list and would flag old-format lines in projects before they upgrade |
