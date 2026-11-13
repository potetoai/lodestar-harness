# Plan: steady 2, Stop-hook repeats

> **For Claude Code:** This is an execution plan, child of
> `plans/active/steady-state.md` (read its section 2 first). Read all of this
> file. Do one phase at a time and stop after each for the repo owner's
> approval. Answer nothing in "Open questions" yourself. Update the progress
> and decision logs here, and add one row to the parent's progress log, when
> a phase moves.

## 1. Why this plan

A Stop hook sent the agent back on 309 of 18,050 turns (1.7%) from
2026-10-28 to 2026-11-13; on 2026-10-12 it was 42 of 5,217 (0.8%). By
project: A 165 of 8,217, B 72 of 4,861, C 72 of 1,620 (4.4%), this repo 0.
Each such turn sends the whole context again and prints up to 60 lines of
failure.

One session in project C (template 2.9.15) was held 26 times. In the range
read by hand (`--excerpt` lines 512-696) seven holds in a row carried the
same `make verify-quick` failure: two tests that were red before the task.
The agent was guiding the owner through a hand edit of a data file, one step
per message. Each owner edit changed a file that is not a note, so
`verify-before-stop.sh` saw new work and held again; the agent could fix
nothing and said so each time.

The hook already lets a stop go when the same failure repeats on the same
files, notes aside (`same_files`, extended in PR #192). It has no limit when
other files change and the failure stays the same.

Goal: a failure the agent cannot or does not fix stops costing a turn per
stop, without letting a real, fixable failure slip (CI and `pre-push.sh`
remain the gate).

## 2. Limits

- Changes under `enforcement/` pass `bash enforcement/test.sh`; on Windows
  run only the needed blocks (6b, 6c, 6d, 17), CI runs all.
- The PR changes safety files: the owner types the merge approval.
- No release of its own: ships in the next weekly batch (child 1).
- Messages the hook prints stay short; no new always-printed line.

## 3. Phases

### Phase 0: What the 309 holds were (read only)

Add a `--holds` table to `scripts/usage-report.py`, so the count can be
repeated without a model: per project and per hook message kind (verify
fails, unpushed commits, criteria not reviewed, locked tests, feedback
check), the number of holds, and how many repeat the previous hold's failure
in the same session (same text with digits removed, as the hook's own
failure id). For the repeats, say what changed between the two holds: an
agent edit, no edit, or only an owner message. Source: `Stop hook feedback`
entries in the transcripts (the method of `plans/completed/harness-health.md`
phase 3).

Report: the table, the five sessions with the most repeats, and how many of
the 309 a limit of 2 and of 3 would have let go.

Done when: the table is in the progress log, and the report says whether
the count supports the limit of 3 (Q1) or asks the owner to change it.

### Phase 1: Limit the repeats

In `enforcement/agents/claude/hooks/verify-before-stop.sh`: keep a count
beside the held state. When the failure id equals the last hold's and the
count has reached the limit (3, Q1), let the stop go with one line that names
the target and says the agent must tell the owner the failure is still
there. Any different failure id, or a pass, resets the count. The locked
Tests-First path and the unpushed-commits path keep their own once-per-state
rules.

Tests (block 6b style): same failure with a code file changed each time is
held up to the limit, then let go; a different failure after that holds
again; a pass resets; without git every failed stop still holds.

Rate in the PR text, from phase 0 data, what the limit can miss: a failure
the agent keeps trying and failing to fix is released after the limit; the
push is still refused by CI.

Done when: the PR is merged with the owner's typed approval.

### Phase 2: Handoff-length note

In `enforcement/agents/claude/global/check-readiness.sh` (session start
only): when `.ai/handoff.md` is longer than 30 lines, print one line asking
the session to overwrite it short at its next handoff. Never blocks. One
test in block 7. Installed copies update through `global/install.sh`; say so
in the handoff.

Done when: merged in the same weekly batch as phase 1.

### Phase 3: Recount

Fourteen days after the release reaches the projects, run `--holds` again.

Done when: gate S2-1 is met or stopped and the owner has seen the count.

## 4. Data gates

| Gate | Measure (source) | Minimum | Check | Stop | Status |
|---|---|---|---|---|---|
| S2-1 Fewer repeats | Stop-hook holds as a share of turns, and repeats of the same failure (`scripts/usage-report.py --holds`), in projects on the new template only | 14 days and 3,000 turns after the upgrade | 14 days after the release | 3 weeks later | waiting (1.7%, 309 of 18,050, on 2026-11-13) |

## 5. Open questions

- **Q1.** Limit of 2 or 3 holds on the same failure (parent Q4)? **3**
  (answered 2026-11-13), unless phase 0 shows otherwise: then ask again.

## 6. Not in scope

- A record of tests that were already red on main ("known red"): needs a
  baseline run per branch; rate it only if phase 3 shows the limit is not
  enough.
- The feedback-check hook's word list (dropped 2026-10-12; recount it in
  phase 0, propose nothing unless its holds grew).

## 7. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-11-13 | none | Plan written |

## 8. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-11-13 | Owner: limit 3 holds on the same failure, open to change after phase 0 | In the worst session 3 saves 23 of 26 turns and 2 saves 24; 3 leaves one more try at a real fix |
