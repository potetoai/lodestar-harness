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
- Mid-execution escalation: if, once implementation starts, the task reveals hidden complexity — more files than expected, a cross-layer dependency, an architecture/data/security impact, or real regression risk — STOP. Do not finish under the SIMPLE workflow. Re-route: present the corrected routing decision (now BUILD_REVIEW or higher, its route line ending in `escalated-from=SIMPLE`) and wait for approval before continuing.

## Completion Criteria

The task is complete only when:

- the requested change is implemented
- relevant checks pass
- no unrelated changes were introduced
- no hidden complexity surfaced that should have escalated to a higher workflow
