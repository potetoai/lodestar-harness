# Plan: <short task name>

Copy to `.ai/plans/active/<yyyy-mm-dd>-<task>.md`. Required for COMPLEX and
high-risk (tests-first) tasks. Write it in English and show the owner a
translation in chat (lodestar-harness `rules/documentation.md`, section 5). When
the task is merged, delete it (`git rm`) and add one row to
`.ai/plans/completed.md`.

## Goal

What changes for the user, in one or two sentences.

## Acceptance criteria

One line per behavior, in plain language. The owner approves this list before
any test or code is written (high-risk tasks).

- [ ] ...

The owner approves this list by replying with the approval word ("duyệt" or
"approve"). A hook records the approval in `.ai/approvals.log` (never edit
that file). Changing the criteria later needs a new approval.

## Criteria review

Written before the owner is asked to approve (high-risk tasks): the critic
(lodestar-harness `agents/critic.md`) runs in a fresh subagent. One line per
finding and what was done ("fixed", or "kept, because ..."); `- No findings.`
when there are none. The last line is `- Reviewed criteria: <hash>`, the
criteria this review covers (`agents/critic.md`, Output). The approval hook
records nothing while this is empty or that line is missing or stale.

- ...

## Steps

- [ ] ...

## Progress log

One short line per step: done or what it waits for, and the PR number. What
changed stays in the PR and git.

| Date | Step | Done | Notes |
|---|---|---|---|

## Decision log

| Date | Decision | Why |
|---|---|---|

## Debt left on purpose

Anything left undone on purpose also goes into `.ai/tech-debt.md` with a due date.
