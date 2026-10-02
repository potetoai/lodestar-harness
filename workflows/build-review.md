# Build Review Workflow

## Purpose

Implement a normal development task and independently review the implementation before completion.

## Process

1. Understand the task.
2. Inspect the relevant code.
3. Define the implementation approach.
4. Builder implements the task.
5. Builder runs relevant tests.
6. Reviewer independently inspects the implementation.
7. Reviewer identifies:
   - correctness issues
   - bugs
   - architecture problems
   - missing tests
   - unnecessary changes
   - regressions
8. Builder fixes valid findings.
9. Run verification again.
10. Inspect the final diff.

## Review cost

A reviewer in a fresh subagent starts with no context and re-reads what the
builder already read. Its fixed start cost (system prompt, tools, skill list)
was measured at about 30k tokens (2026-10-02), even for a 2k-token diff.
Match the cost to the change:

- Small change (under about 100 changed lines, low or medium risk, no
  `sensitive_paths`, not tests-first): no subagent. The session that holds
  the change reviews it as a separate step: read the full diff
  (`git diff`) fresh, check it against the reviewer checklist
  (`agents/reviewer.md`), and list findings before fixing any. It opens other
  files only when a finding needs them and does not rerun the test suite
  (the builder ran it and says so). The owner can still ask for a subagent
  reviewer.
- Larger, high-risk, tests-first or sensitive change: a subagent reviewer,
  reading the code around the diff.

A subagent reviewer skips the Lodestar startup steps (global `CLAUDE.md`,
"For subagents"); the dispatch prompt holds the task goal and the diff.

## Agents

### Builder

Responsible for:

- investigation
- implementation
- initial testing

### Reviewer

Responsible for:

- independent review
- identifying problems
- checking requirements
- checking tests
- checking unintended changes

The reviewer must not simply approve the implementation without examining it.

## Rules

- Keep builder and reviewer responsibilities separate. For a small change the
  review is a separate step in the same session (Review cost), not a skipped one.
- Reviewer should challenge the implementation when appropriate.
- Do not rewrite working code without a concrete reason.
- All valid review findings must be resolved or explicitly documented.
- Disputed findings: when builder and reviewer disagree whether a finding is valid, do not let either side unilaterally close it. Escalate to the Architect role, or to the user, for a decision. Record the outcome. A finding is never dropped just because the builder disagrees.

## Completion Criteria

The task is complete only when:

- implementation satisfies the requirements
- reviewer has completed the review
- valid findings are resolved
- relevant tests pass
- final diff is clean
