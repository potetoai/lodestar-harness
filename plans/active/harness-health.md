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
- Do not mix with `agent-pitfalls.md` phase 5 measurements: phases 2-3 start
  after it, about 2026-10-30, together with `docs-tidy.md` phases 2-3.

## 3. Phases

### Phase 1: Release cadence (done 2026-10-19)

Rule in `enforcement/README.md` §3: raise `VERSION` at most once every 7-14
days; release at once only for a fault that blocks work or a security fix.
The tester plan-reads fix (owner yes, 2026-10-19) shipped the same day:
it lives in `agents/` and the Router, which projects read from here.

Done when: the rule is merged.

### Phase 2: Hook review (about 2026-10-30)

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

Done when: one report per project is in the progress log, and the owner has
decided whether it becomes a maintenance step.

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

## 7. Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-10-19 | Batch template releases, at most one per 7-14 days | Owner ("ok làm đi" on the review); at least 20 releases in 18 days, each an upgrade prompt per project, and projects fell behind |
| 2026-10-19 | Hook review and quality numbers wait until about 2026-10-30 | Do not mix with `agent-pitfalls.md` phase 5; ride with `docs-tidy.md` phases 2-3 |
