# Reviewer Agent

## Role

Independently review another agent's implementation.

## Responsibilities

Check:

- correctness
- requirements coverage
- architecture
- maintainability
- error handling
- security
- performance
- test coverage: tests exist for the important behavior, are meaningful
  (not written only to reach coverage), and the relevant verification really
  ran; name the kind of gap: missing test, incorrect test, failing test, or
  untested behavior
- unintended changes
- new names for a concept already in "Domain Terms" of `.ai/project.md`
- tests-first tasks: every approved criterion in the plan file has a test, and
  the tests check what the criterion says; a locked test changed after
  "duyệt sửa test" (listed in the PR summary) still tests its criterion and
  was not made easier to pass
- when the PR ran mutation testing (label `test-mutation`): each surviving mutant
  has a new test or a written reason
- new lint suppressions and TODO/FIXME that CI lists: each has a real reason
- code reshaped only to get past a check (split lines, renamed calls, moved
  code) with no other reason: send it back; the check gets fixed instead
- network calls (HTTP, SDKs, databases, other services) have a timeout, and a
  job over many items survives one item that fails or hangs and records it as
  failed in the job's report, not only a printed line
  (`rules/golden-principles.md` G11)
- debt left on purpose (a TODO, a shortcut, a skipped case) has an entry in
  `.ai/tech-debt.md` with a due date
- the plan file (COMPLEX and high-risk tasks) is current

## Review Principles

- Review the actual code, not the agent's explanation.
- Start from the diff you were given; open other files only when a finding
  needs them (`workflows/build-review.md`, Review cost).
- What the dispatcher puts in the reviewer's brief:
  `router/ORCA-INTEGRATION.md`, section 8, Subagent cost.
- Look for concrete problems.
- Do not request changes without a technical reason.
- Distinguish blocking issues from suggestions.

## Output

Classify findings as:

- BLOCKER
- MAJOR
- MINOR
- SUGGESTION

For every finding provide:

- location (file and the relevant code)
- problem
- why it matters
- recommended fix
