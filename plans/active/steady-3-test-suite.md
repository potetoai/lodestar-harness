# Plan: steady 3, the self-test in parts

> **For Claude Code:** This is an execution plan, child of
> `plans/active/steady-state.md` (read its section 2 first). Read all of this
> file. Do one phase at a time and stop after each for the repo owner's
> approval. Answer nothing in "Open questions" yourself. Update the progress
> and decision logs here, and add one row to the parent's progress log, when
> a phase moves.

## 1. Why this plan

`enforcement/test.sh` is one file: 2,270 lines, 190 KB, 35 numbered blocks
(1 to 25 with 6b, 6c, 6d, 7b, 10b, 16b, 19b, 21b, 21c; the number 7 is used
twice and block 12 sits near the end). Every hook change adds to it. Three
effects:

- The full run is too slow to use on Windows, so agents run "only the needed
  block" by copying it out. On 2026-11-11 one such copy ran outside a
  fixture folder: it made a commit (`git add -A; commit`) and set
  `core.autocrlf` in this repo. It was undone by hand.
- An agent that edits a hook reads a large part of the file to find its
  block.
- Blocks share state (`$p`, `$tmp`, stub files from earlier blocks), so a
  block cannot be trusted alone.

Goal: `bash enforcement/test.sh <block>` runs one block safely in seconds;
the full run and CI stay as they are; no check is lost.

## 2. Limits

- `bash enforcement/test.sh` with no argument still runs everything
  (`AGENTS.md`, CI `.github/workflows/test.yml`).
- No check changes meaning. Proof: the sorted list of `PASS` names before
  and after is the same on Linux, macOS and Windows CI.
- Start only after child 2's hook fix is merged (both edit this file).
- Shell files keep LF. The PR changes `enforcement/`: owner's typed merge
  approval. The self-test is not installed into projects; confirm that from
  `enforcement/bootstrap.sh` before saying "no template release needed".
- Move code, do not rewrite it. A block that needs a rewrite to stand alone
  is listed for the owner, not fixed silently.

## 3. Phases

### Phase 0: Map (read only)

- Time per block on CI (from job logs with timestamps) and on this Windows
  machine for the five slowest.
- For each block: which variables, folders and stubs from earlier blocks it
  uses. Mark it "stands alone", "needs setup X" or "tangled".
- The count of `PASS` lines per OS, as the baseline.

Done when: the map is in the progress log.

### Phase 1: Parts and a runner

- `enforcement/tests/lib.sh`: the shared head of today's file (temp folder,
  scratch registry key, inbox, `pass`, `bad`, `t`, `sedi`, `snapshot`,
  `fill`) and named setup functions for the shared fixtures found in phase 0.
- `enforcement/tests/<nn>-<name>.sh`: one file per block, calling the setup
  it needs.
- `enforcement/test.sh`: sources `lib.sh`, then all parts in order, or only
  the parts named as arguments (`bash enforcement/test.sh 6b 21c`). Prints
  the same `PASS`/`FAIL` lines and the same exit code.

Done when: the `PASS` name lists match the baseline on all three OS, and one
block runs alone on Windows.

### Phase 2: Fixture guard

- A part file refuses to run when it was not started by the runner (a
  variable `lib.sh` sets), with a message naming the one-block command.
- `lib.sh` gives one helper that changes into a fixture folder and fails the
  block when the folder is not under the run's temp folder; blocks use it
  before any `git add`, `git commit` or `git config`.
- A test for the guard itself: a part started alone exits non-zero and
  leaves the current repo untouched.

Done when: merged; the handoff's do-not-do line about fixture snippets is
replaced by the one-block command.

### Phase 3: Say it once

`enforcement/README.md` gets the one-block command where it names the
self-test. No line in `AGENTS.md` unless the owner asks: the existing line
(`bash enforcement/test.sh`) stays true.

Done when: `bash scripts/check-links.sh` passes.

## 4. Data gates

None: this plan waits for no data. It waits for child 2 phase 1 to merge.

## 5. Open questions

- **Q1.** If phase 0 finds tangled blocks that cannot move without a
  rewrite: leave them in one "legacy" part, or rewrite them in a later PR?

## 6. Not in scope

- `enforcement/test-parity.sh` (31 KB): look at it only if phase 0 shows the
  same problem there.
- Faster CI. The gain here is safety and local speed.

## 7. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-11-13 | none | Plan written |

## 8. Decision log

| Date | Decision | Reason |
|---|---|---|
