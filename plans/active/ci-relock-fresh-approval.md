# Plan: CI relock requires fresh approval

## Goal

Keep a later Tests-First round from weakening previously locked tests without
a new owner approval, while preserving additional test rounds under unchanged
approved criteria.

## Scope

- `enforcement/agents/claude/hooks/ci-checks.sh`, check 3.
- `enforcement/agents/claude/hooks/lodestar-lib.sh` only if a shared helper is needed.
- `enforcement/test.sh`, the disposable Git histories in section 9.
- `enforcement/VERSION` and a clarification in `rules/testing.md` if needed.
- No Codex patch adapter changes and no project upgrades.

## Acceptance criteria

- [x] C1: CI rejects a later Tests-First round that modifies, deletes or renames a previously locked test when the round only updates progress under already approved criteria.
- [x] C2: CI accepts a later round that adds and locks new tests under unchanged approved criteria, provided previously locked tests remain unchanged.
- [x] C3: CI permits a valid Tests-First round to revise locked tests when a plan changed by that commit has a criteria hash different from that plan at the immediately preceding valid round, approved in the current commit's approval log, and absent from the preceding round's approval log. The approval and criteria revision may be committed between rounds or in the revising round.
- [x] C4: Copying or restoring criteria whose hash was already approved at the preceding valid round, or reusing an approval present in an intervening valid round, does not authorize another revision of locked tests.
- [x] C5: An ordinary commit, a Tests-First trailer without an approved plan change, or changed criteria without owner approval cannot revise locked tests, even if a later valid round follows.
- [x] C6: Within the existing CI review range, a valid approved revision does not release older locked tests for subsequent unapproved revisions, and every old locked path remains protected by CI even if a later lock omits it or is missing.

## Criteria review

- Full independent Codex review: read this plan, critic role, CI check 3 and setup, criteria/approval/relock helpers, test section 9, tests-first rules and the approval hook. Did not read other test sections, adapters, CI configuration, VERSION or consuming repositories.
- MEDIUM: C3 did not define fresh evidence or bind it to the plan carried by the revising commit; fixed by requiring an approved criteria hash absent from the preceding round's log, different from that plan at that round, on a plan changed by the revising commit.
- MEDIUM: C4 banned every copied plan, including genuinely fresh criteria; fixed by limiting the ban to criteria already approved at the preceding round, consistent with the existing hash-based approval model.
- Scope clarification: C6 covers the existing CI review range and explicitly includes a missing later lock. Merge-history traversal and locks originating before the review range remain outside this fix.
- Narrowed independent Codex re-review: checked C3/C4/C6 corrections, interactions with C1/C2/C5, and both earlier findings; no remaining findings. Read the revised plan; relied on the prior full source review without rereading implementation files or running tests.
- Reviewed criteria: 8c3b61894286574d12b3f703c2f748e095d38bcc

## Verification cases

- Modification, deletion and rename of an old locked test without fresh approval.
- New tests appended to the lock with unchanged old tests and criteria.
- Changed criteria and approval committed between rounds, followed by a round that updates the relevant plan's progress.
- Fresh approval for a plan not changed by the revising commit, while an old approved plan only changes progress: reject.
- A fresh approval consumed by an intervening add-only round cannot authorize a later rewrite.
- Unauthorized edits followed by restoration or a valid round still fail CI.
- Two successive revisions, each independently freshly approved, pass.
- A later lock omitting an old path or disappearing does not erase old protection.

## Steps

- [x] Reproduce the existing CI bypass in a disposable repository.
- [x] Complete independent criteria review; confirm the source repository's existing readiness exemption.
- [x] Obtain owner approval of the reviewed criteria.
- [x] Write regression tests first and demonstrate the relevant failures on the old implementation.
- [x] Implement the CI check and increment the managed template version.
- [x] Run self-tests and documentation link checks; obtain independent security review.
- [ ] Open a PR with evidence and await the owner's merge instruction.

## Progress log

| Date | Step | Done | Notes |
|---|---|---|---|
| 2026-10-13 | Investigation | Reproduced | A disposable history changed a locked balance assertion to `assert True`, changed only plan progress, and kept criteria and approvals identical. Existing CI exited 0 and reported locked tests unchanged. No real project data was used. |
| 2026-10-13 | Readiness | Pending owner choice | This source repository has no `.claude/hooks/doctor.sh` or `.ai/project.md`. Asked whether to skip onboarding for this fix and use the repository self-tests. No production code changed. |
| 2026-10-13 | Criteria review | Waiting | Claude quota exhausted before any review; asked the owner whether Codex may substitute for critic and reviewer. No claim of reviewed criteria or owner approval. |
| 2026-10-13 | Baseline verification | Passed | `bash enforcement/test.sh` outside the sandbox exited 0: all tests passed. `bash scripts/check-links.sh` and `git diff --check` passed. The first sandbox self-test run was invalid because jq and make were blocked; no failures from that run are attributed to the implementation. |
| 2026-10-13 | Criteria review | In progress | Owner authorized Codex temporarily replacing Claude for critic/review; dispatched a fresh read-only Codex critic. Onboarding skip is still unanswered. |
| 2026-10-13 | Criteria review | Corrections written | Full critic found two medium ambiguities in C3/C4, both addressed. Clarified C6's existing review range and missing-lock case. Narrowed re-review requested. |
| 2026-10-13 | Criteria review | Passed | Narrowed independent Codex re-review found no remaining findings. Current criteria hash recorded. Documentation link check and diff whitespace check pass. Owner criteria approval and onboarding decision remain pending. |
| 2026-10-13 | Readiness | Resolved; earlier blocker was incorrect | `enforcement/agents/claude/global/check-readiness.sh:19` explicitly exempts lodestar-harness when `enforcement/bootstrap.sh` exists. Git blame traces the exemption to the initial commit 4c23d3a; `plans/completed/round-2.md` also documents it. Claude's installed global hooks invoke this script. No onboarding or new owner waiver is needed. Repository self-tests and link checks are the existing verification contract. |
| 2026-10-13 | Session closure | Saved for continuation | At the owner's request, hook/rule parity findings were sent to the existing Codex parity session via Orca (input accepted; no new turn observed). That session owns parity and the shared checkout is now on its `feat/codex-lodestar-parity` branch. This CI task remains separate and incomplete: reviewed plan only, no implementation or regression tests, criteria approval pending. Do not commit this plan into parity or change its branch while that session works. |
| 2026-10-13 | Owner approval | Approved | Owner explicitly replied "duyệt" for the unchanged reviewed C1-C6 criteria in this session. Source-repository evidence is this conversation and plan; no installed consuming-project approvals log was created. Work continues only in the isolated `potetoai/ci-relock-fresh-approval` worktree. |
| 2026-10-13 | Tests first | Regressions demonstrated | Added 28 CI assertions in section 9 (119 lines). Old CI incorrectly accepts 14 prohibited histories; 14 positive or existing-protection assertions pass. Failures cover stale progress-only modification/deletion/rename, unrelated fresh approval, copied/restored/consumed approval, intermediate unauthorized edits, and omitted/missing later locks. Shell syntax and whitespace checks pass. Full self-tests exited 1 as expected: 367 assertions, 353 passed and only the 14 new regressions failed; all 339 pre-existing assertions passed. The suite exited and its scratch registry key was removed. No started process remains. Red-run log: system temporary directory, `lodestar-ci-relock-red.log`. |
| 2026-10-13 | Implementation | Complete; verification running | CI now compares each valid later round with its immediately preceding valid round and requires fresh approval on a plan changed by the revising commit. Every earlier lock is still checked. Only ci-checks.sh and VERSION (2.3.7) changed; test checkpoint 7be822d is unchanged. Syntax, internal links and whitespace checks pass; full self-test is running. |
| 2026-10-13 | Independent review | Security review passed | Fresh Codex reviewer inspected the complete diff, CI and approval helpers, tests and approved criteria. No code or security findings. Two minor table-formatting errors in this plan were fixed; reviewer did not rerun the suite. Full self-test remains in progress. |
| 2026-10-13 | Final verification | Passed | Full Windows self-test exited 0: all 367 assertions passed, including all 28 new regressions. Old implementation had 14 expected failures; all 339 original assertions passed before and after. Independent security review passed. Tests are unchanged from checkpoint 7be822d; shell syntax, documentation links and diff whitespace pass. |

## Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-10-13 | BUILD_REVIEW, high risk, tests first | The CI check protects locked tests in every consuming project. |
| 2026-10-13 | Compare against the immediately preceding valid round | Comparing only with the original lock would let one approval authorize repeated later rewrites. |
| 2026-10-13 | Temporarily use independent Codex critic and reviewer | Explicit owner instruction after Claude exhausted its session quota. |
| 2026-10-13 | Apply the existing source-repository readiness exemption | Missing installed project hooks alone did not establish an onboarding requirement here. The earlier request for an owner waiver was mistaken; no tech-debt skip is needed. |
| 2026-10-13 | Freeze regression tests by the normal source test checkpoint | This source repository is exempt from consuming-project onboarding. Owner approval is in the conversation and plan; no source `approvals.log`, synthetic owner prompt, or managed `test-lock` is created. Builder must preserve the checkpoint tests. |
| 2026-10-13 | Keep the fresh-approval check local to CI | Reuse existing criteria and approval helpers without changing runtime hooks or policy files owned by the parallel parity task. Preserve the existing review range and cumulative protection from older lock snapshots. |

## Debt left on purpose

- The Codex adapter's inability to append test-lock paths is a separate follow-up.
- Approval authenticity remains the existing approval-hook trust model; this task does not introduce signatures or bind individual tests to individual criteria.
- Existing check 3 examines rounds in `merge-base..HEAD`; protection originating before that range and ambiguous predecessor ordering across merge histories are not redesigned by this fix.
