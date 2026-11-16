# Simple Workflow

## Purpose

Complete small, low-risk tasks with the minimum necessary process.

## Process

1. Read the task carefully.
2. Inspect the relevant files.
3. Identify the smallest required change.
4. Implement the change.
5. Run the relevant checks or tests.
6. Inspect the final diff.
7. Report the result.

## Agent Model

Use one agent only.

The agent is responsible for:

- investigation
- implementation
- verification

## Rules

- Do not spawn additional agents.
- Do not perform unnecessary refactoring.
- Do not change unrelated files.
- Do not introduce architecture changes.
- Always perform basic verification.
- One PR per sitting: small changes the owner asks for in one sitting share
  one branch and one PR, one line each in the PR text, while the PR stays
  within SIMPLE (risk low or medium, under 3 changed files outside `.ai/`).
  A change that would break that, or that the owner wants on its own record,
  gets its own PR.
- Push and merge in one call: after the last commit, push and run
  `merge-pr.sh <n>` in the same command, in the background or with a long
  timeout. Do not poll `gh pr checks`; end the turn and report when the
  command finishes. A PR that needs the owner's "duyệt merge PR <n>" stops
  after the push.
- Mid-execution escalation: if, once implementation starts, the task reveals hidden complexity — more files than expected, a cross-layer dependency, an architecture/data/security impact, or real regression risk — STOP. Do not finish under the SIMPLE workflow. Re-route: present the corrected routing decision (now BUILD_REVIEW or higher, its route line ending in `escalated-from=SIMPLE`), then follow the Routing Approval Gate (`router/ROUTER.md`) for the new route: BUILD_REVIEW with low or medium risk continues; high or critical risk, tests-first, INDEPENDENT_COMPARE and COMPLEX wait for approval.

## Completion Criteria

The task is complete only when:

- the requested change is implemented
- relevant checks pass
- no unrelated changes were introduced
- no hidden complexity surfaced that should have escalated to a higher workflow
