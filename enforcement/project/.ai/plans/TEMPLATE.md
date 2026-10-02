# Plan: <short task name>

Copy to `.ai/plans/active/<yyyy-mm-dd>-<task>.md`. Required for COMPLEX and
high-risk (tests-first) tasks. Write it in English and show the owner a
translation in chat (lodestar-harness `rules/documentation.md`, section 5). Move
it to `.ai/plans/completed/` when the task is merged.

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
when there are none. The approval hook records nothing while this is empty.

- ...

## Steps

- [ ] ...

## Progress log

| Date | Step | Done | Notes |
|---|---|---|---|

## Decision log

| Date | Decision | Why |
|---|---|---|

## Debt left on purpose

Anything left undone on purpose also goes into `.ai/tech-debt.md` with a due date.
