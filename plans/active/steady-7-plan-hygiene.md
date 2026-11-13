# Plan: steady 7, plan hygiene (project names, closed phases)

> **For Claude Code:** This is an execution plan, child of
> `plans/active/steady-state.md` (read its section 2 first). Read all of this
> file. Do one phase at a time and stop after each for the repo owner's
> approval. Answer nothing in "Open questions" yourself. Update the progress
> and decision logs here, and add one row to the parent's progress log, when
> a phase moves.

## 1. Why this plan

- `AGENTS.md`: "Public repo: never name the owner's consuming projects in
  files, commits or PR text." On 2026-11-13 a case-sensitive `git grep -c`
  for the three project names (and one repo name) finds 170 lines in 15
  tracked files: three active plans (72), eleven completed plans and ideas
  (96), one strategy file (2). An earlier PR removed names from
  repo files; the plans kept theirs and gained more since.
- Two active plans are 36 KB each (`agent-pitfalls.md`, `skill-harvest.md`).
  An agent told to read the decision log before changing the system reads
  phases that closed weeks ago.

Goal: no project name in a tracked file, and active plans that hold only
what is still open.

## 2. Limits

- Replace a name with a fixed letter (project A, B, C; the same letter in
  every file). The key lives only in the gitignored `.ai/handoff.md`.
- Do not change a number, a date or a decision. Folder patterns in logged
  commands (`--match` regexes) become `<project folders>`.
- Git history keeps the old text. Rewriting history is not part of this
  plan (Q2).
- `agent-pitfalls.md` and `skill-harvest.md` are measuring until gate P5
  closes (2026-11-26); `plans/active/docs-tidy.md` forbids text changes to
  them before that. Phase 1 leaves both alone.
- Do not delete policy or history: closed phases move to
  `plans/completed/`, with a pointer left behind.
- Each PR passes `bash scripts/check-links.sh`. Review checks that only
  names and paths changed (`git diff --word-diff`).

## 3. Phases

### Phase 1: Names out of files that are not measuring

The eleven files under `plans/completed/` and the one under
`plans/strategy-v2.1/`, plus `plans/active/docs-tidy.md` (1 mention). One
PR. Check after: the `git grep` of section 1 finds only the two measuring
plans.

Done when: merged.

### Phase 2: A check that keeps them out (if Q1 is yes)

The names cannot sit in CI or in a tracked file. A local check reads
`.ai/private-names.txt` (gitignored, one name per line) and refuses a commit
or a `gh pr create` whose text or staged diff holds one; with no such file
it does nothing. It belongs in this repo's own `.claude/` hooks (a safety
file: owner's typed merge approval), not in the project template, unless
the owner wants projects to have it too.

Done when: merged, with a test that uses a fake name.

### Phase 3: The two measuring plans (at gate S7-0)

Names out of `agent-pitfalls.md` and `skill-harvest.md`. In the same PR,
move their closed phases and the matching log rows to
`plans/completed/<name>-closed.md`, leaving one line per moved phase that
points there. A plan that is wholly closed moves whole.

Done when: `git grep` finds no name in tracked files; each active plan holds
only open phases, their gates and the full decision log.

### Phase 4: Keep active plans short

Propose to the owner (do not write the rule yourself): when a phase closes,
its text moves to `plans/completed/` in the PR that closes it. If the owner
agrees it goes in `rules/documentation.md`, reviewed as a rule change.

Done when: the owner has decided.

## 4. Data gates

| Gate | Measure (source) | Minimum | Check | Stop | Status |
|---|---|---|---|---|---|
| S7-0 Start phase 3 | `agent-pitfalls.md` gates P5-a..c and `skill-harvest.md` gate SH-0 met or stopped | All recorded | 2026-11-26 | 2026-12-17 | waiting (P5-b, P5-c met; P5-a stops 2026-11-26) |

## 5. Open questions

- **Q1.** A local name check (parent Q3): yes or no, and only here or in
  every project?
- **Q2.** The names stay in git history. Leave it (default), or does the
  owner want history rewritten? That is a forced push on a public repo and
  breaks every PR link; this plan advises against it.

## 6. Not in scope

- Project names in the owner's private files (`.ai/handoff.md`, memory).
- Rewording any plan.

## 7. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-11-13 | none | Plan written |

## 8. Decision log

| Date | Decision | Reason |
|---|---|---|
