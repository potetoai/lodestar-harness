# Plan: English-first approval words and macOS/Linux setup

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time. Update the progress and decision logs when a phase moves.

## 1. Why this plan

The owner wants Lodestar to fit users outside Vietnam, with Vietnamese as an
option (2026-11-05). Two gaps stand in the way:

- **Approval words.** Docs and hooks are in English and `owner_language`
  defaults to English, but a few hook messages and docs tell the agent to ask
  for "duyệt" first or only ("duyệt critic", "duyệt merge PR <n>").
- **Platforms.** The setup guide is written for Windows. Linux CI runs the
  self-test only; macOS and desktop Linux have no recorded setup
  (`enforcement/setup-guide.md`, "Where this is tested"). macOS ships bash
  3.2, and the hooks use bash 4 syntax (`${var,,}`); nothing checks the bash
  version.

## 2. Limits

- Both words keep working in every project; only the word shown first
  changes. The approval hook's matching does not change.
- `agents/critic.md` and `workflows/maintenance.md` stay untouched until
  DT-1/P5 permit it (`.ai/handoff.md`); `router/ROUTER.md` changes only with
  a Router eval run, so it is left as is (it already names both words).
- No support tier or badge (strategy 01 owns tiers): the guide states what
  was tested, where, and how.
- GitHub Free only: hosted runners on this public repo, no paid runners.
- Changes under `enforcement/` pass `bash enforcement/test.sh`; a PR that
  changes `enforcement/` or `.github/` needs the owner's typed merge approval.

## 3. Phases

### Phase 1: Approval words, English first

Hook messages and docs show "approve" first and "duyệt" when
`owner_language` is `vi`. One test uses "approve critic". Done when the
self-test and link check pass.

### Phase 2: Find what breaks on macOS and Linux

On a probe branch, a CI job runs on `ubuntu-latest` and `macos-latest`:
`setup-machine.sh --yes --no-selftest` against a scratch home, then
`enforcement/test.sh`. Record each failure here. No fix in this phase.

### Phase 3: Fix and keep it tested

Fix what phase 2 found (expected: a bash 4 check with the `brew install bash`
step, and any GNU-only tool use). Keep the macOS/Linux job in CI so a later
change cannot break them silently. Done when CI passes on all runners.

### Phase 4: Setup guide

Add macOS and Linux steps to `enforcement/setup-guide.md` and update "Where
this is tested" with the CI evidence. A live first task on macOS/Linux by a
person stays "not yet shown".

## 4. Not in scope

- Translating docs; changing the approval hook's matching.
- WSL, and Claude Code's own install on macOS/Linux (its docs cover it).

## 5. Progress log

| Date | Phase | Note |
|---|---|---|
| 2026-11-05 | Start | Owner: "làm cả hai" (approval words and macOS/Linux) |
| 2026-11-05 | 1 | Approval words English first; PR #158 |
| 2026-11-05 | 2–4 | macOS/Linux: probe #157 (closed) found BSD-tool failures; fixes, CI on both, setup guide; PR #159 |
| 2026-11-05 | Close | All phases done; plan moved to completed |

## 6. Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-11-05 | Keep "duyệt" working everywhere; show "approve" first unless `owner_language` is `vi` | Owner wants Vietnamese optional, not removed; the owner's own projects use `vi` |
| 2026-11-05 | Test macOS/Linux on GitHub-hosted runners | Free on a public repo; the owner has no Mac or Linux machine |
