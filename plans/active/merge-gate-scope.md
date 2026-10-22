# Plan: merge gate scope (fewer false "duyệt merge")

> **For Claude Code:** This is an execution plan. Read all of it first.
> Update the progress and decision logs when a step moves.

## 1. Why this plan

On 2026-10-22 the owner asked for fewer "duyệt merge PR <n>" messages. From
2026-10-16 to 2026-10-22 they typed 51 (App01 21, ProjectS 30). Why each PR
was owner-only (`guard-install.sh`, rules/enforcement.md "Owner-only merge"):

| PRs | Reason | Verdict |
|---|---|---|
| 16 | Lodestar template upgrade | Release cadence (harness-health phase 1) already cuts these |
| 16 | Edits an already-locked test | Real risk: keep the owner |
| 7 | ProjectS: only project docs in `.claude/docs/` | False positive |
| 1 | ProjectS: `.claude/agents/` | Keep: agent files can carry hooks and permissions |
| 3 | App01: only adds new tests to `.ai/test-lock` | False positive: tightens, criteria already approved |
| 6 | Sensitive code plus new locked tests | Owner keeps (see Out of scope) |
| 2 | `.ai/project.md`, or no clear reason | Keep |

The earlier idea (an AI reviewer instead of the owner for sensitive code,
locked-test changes kept) would have removed 0 of 51: every sensitive PR also
grew the lock. The owner chose (2026-10-22): remove the false positives
first, keep locked-test edits owner-only, and decide AI review later with
data. Expected: about 10 of 35 feature-PR approvals fewer.

## Acceptance criteria

The owner-only merge check in `enforcement/agents/claude/hooks/guard-install.sh`:

- C1. Under `.claude/`, only `.claude/docs/` stops being owner-only: a PR
  whose `.claude/` files are all in `.claude/docs/`, with nothing else
  owner-only in it, merges without the owner's "duyệt merge PR <n>". Every
  other path under `.claude/` stays owner-only, including folders Claude Code
  adds later.
- C2. Unchanged: `.codex/`, `.github/`, `enforcement/`, `.ai/project.md` and
  `.ai/enforcement.json` stay owner-only.
- C3. A PR whose change to `.ai/test-lock` only adds lines is not owner-only
  for that file. Only adds: gh reports the file as added, or as modified with
  a diff where every non-comment, non-blank line it removes is added back
  unchanged (so appending to a lock with no final newline still counts).
- C4. A PR that removes or changes a non-comment line of `.ai/test-lock`,
  deletes it, or renames it away stays owner-only; so does one where gh gives
  no diff for the lock.
- C5. A PR that modifies, removes or renames away a locked test stays
  owner-only. Locked: matched by a line of `.ai/test-lock` on the PR's target
  branch, read from GitHub at merge time, both at the branch's current tip
  and at the PR's base commit. Matching is the gate's rule: any letter case; a
  line with no `*`, `?` or `[` covers that file and the folder of that name;
  a line with one is a shell pattern. A file the PR adds is not owner-only
  for being locked. The lock in the local working tree is not used.
- C6. Fail closed: a file whose change type gh does not give counts as
  changed; a lock read that fails for any reason other than "no such file"
  (HTTP 404) blocks the merge as "cannot be checked".
- C7. Unchanged: `sensitive_paths`, approval by head commit,
  `--match-head-commit`, no `--auto`, push before merge, `-R`/`GH_REPO`,
  merges through `gh api` (all existing tests still pass).
- C8. Docs say the same: rules/enforcement.md ("Owner-only merge"), with a
  known limit: a PR that is not owner-only can still change test setup
  (`conftest.py`, test config, a Makefile test target) that weakens locked
  tests without editing them; rules/git.md section 12. rules/testing.md gets
  the App01 line (`lodestar-relock-preapproved-locked-test`): approved
  criteria cannot schedule an edit of an already-locked test for a later
  step; plan that step as its own criteria change with a new approval, or
  write the early test so the later step only adds a new test.
- C9. `bash enforcement/test.sh` passes with tests for C1-C6, including lock
  lines `tests/core/`, `tests/test_*.py` and `Tests/X.py`, a test locked only
  at the target branch's tip, and a 404 versus another read error;
  `bash scripts/check-links.sh` passes. Template change only: no `VERSION`
  bump; it ships in the next batched release (about 2026-10-30).

Out of scope: an AI reviewer instead of the owner for sensitive code
(re-decide about 2026-11-05 with data: count self-merged PRs later reverted
or fixed); template upgrade PRs; edits of locked tests (owner keeps them).

## Criteria review

- Full run (critic subagent, 2026-10-22). Not read: `enforcement/test.sh`,
  `sensitive-gate.sh`, `approval-record.sh` beyond grep, the Codex adapter,
  App01 PR data; the frontmatter findings come from knowledge of Claude Code,
  not checked against its current docs.
- Freeing all of `.claude/` except hooks and settings frees agents, skills
  and commands, whose frontmatter can add hooks, change permission mode or
  run commands outside the guard; a future config folder would start free.
  Fix: free only `.claude/docs/`. Fixed (C1).
- Settings can name scripts outside `.claude/hooks/`. Covered by the C1 fix.
  Fixed.
- The PR's base commit can be older than the target branch's tip: a test
  locked by a PR merged in between would be missed. Fix: read the lock at
  the tip too. Fixed (C5).
- The working-tree lock depends on the checkout and already holds the PR's
  own lines. Fix: do not use it. Fixed (C5).
- Falling back to the local lock fails open when it is stale. Fix: 404 means
  no lock, any other error blocks. Fixed (C6).
- Renames and "only adds" were not defined. Fixed (C3, C4); "removed lines
  added back" instead of "no removed line", so a lock without a final newline
  can still grow.
- The matching rule was not stated. Fixed (C5, tests in C9).
- A self-merging PR can weaken locked tests through test setup without
  touching them. Kept, listed as a known limit (C8): any PR outside the
  owner-only list can already do this, and the owner's merge word does not
  read code.
- Reviewed criteria: ff927ee095f5c4da17f2669abc59a09524ff6ae7

## 3. Progress log

- 2026-10-22: plan written; route BUILD_REVIEW risk=high (tests-first),
  owner "làm đi". Critic run; 8 findings, 7 fixed, 1 kept as a known limit.
  Owner "duyệt" on criteria ff927ee0 (2026-10-22). Tests written first.
- 2026-10-22: guard written (`guard-install.sh`): safety list and
  sensitive_paths kept apart so only the built-in `.claude/` frees
  `.claude/docs/`; file change types and lock growth from the PR's files;
  lock read from GitHub at the target tip and the PR base; gh timeout 15 s
  to 7 s (four calls in the 30 s hook). Checked against real gh output on
  this repo (PR #78, a 404 lock, a raw read at a branch and a commit).

## 4. Decision log

- 2026-10-22: owner chose "remove false positives first" over AI review of
  sensitive code; locked-test edits stay owner-only; App01 relock report:
  option A (doc line, no new unlock path).
