# Global Testing Rules

Version: 1.0
Scope: All projects using Lodestar-harness

---

## Purpose

Define global testing and verification principles for all projects.

These rules apply to:

* Builder
* Frontend
* Backend
* Tester
* Reviewer
* QA
* Architect when defining verification strategy

The goal is to ensure that completed work is verified rather than assumed to be correct.

---

# 1. Core Principle

Never report a task as complete without appropriate verification.

Verification should be proportional to:

* Change size
* Risk
* Architecture impact
* User impact
* Regression risk
* Complexity

Small changes require focused verification.

Large or high-risk changes require broader verification.

---

# 2. Test Before Claiming Completion

An agent must not claim:

* "Tests pass"
* "Build passes"
* "Feature works"
* "No regression"

unless the relevant verification was actually performed.

If verification cannot be performed, explicitly report:

* What was not tested
* Why it could not be tested
* What remains uncertain

---

# 3. Test Strategy

Select the smallest effective verification strategy.

Possible levels:

### Level 1 — Static Verification

Use for very small or low-risk changes.

Examples:

* Type checking
* Linting
* Formatting
* Static analysis

### Level 2 — Focused Tests

Use when a specific function, component, module, or feature changes.

Examples:

* Unit test
* Component test
* API test

### Level 3 — Integration Verification

Use when multiple modules interact.

Examples:

* API + database
* Frontend + backend
* Service + external dependency

### Level 4 — End-to-End Verification

Use when user flows or critical system behavior are affected.

Examples:

* Login
* Checkout
* Payment
* Important business workflows

### Level 5 — Full Verification

Use for high-risk or major changes.

May include:

* Unit tests
* Integration tests
* End-to-end tests
* Type checking
* Linting
* Build
* QA

### Levels as commands

Every onboarded project exposes the same `make` targets
(`rules/enforcement.md`), so each level maps to a command:

| Level | Command | Also |
|---|---|---|
| 1 | `make lint` + `make typecheck` (if the project has it) | The edit hook runs `make lint-file` on every change |
| 2 | `make test` | The Stop hook runs `make verify` (1 + 2) before the agent may finish |
| 3–5 | `make verify-full`, plus targets the project declares in `.ai/project.md` | CI runs `make verify-full` on every PR |

State the chosen level and the reason in the routing decision.

### Tests-first mode (high risk)

A task is **high risk** when it touches a path in `sensitive_paths` or a
high-risk invariant in `.ai/invariants.md`. The Router selects this mode
automatically; when unsure, select it.

1. **Criteria.** The agent writes the acceptance criteria in plain language,
   one line per behavior (for example "Selling more than the holding → error,
   nothing written"), under `## Acceptance criteria` in the task's plan file
   (`.ai/plans/active/`, from `.ai/plans/TEMPLATE.md`). Write the file
   **before** asking for approval: the approval hook records only criteria
   that already exist in a plan file.
   Then a fresh subagent with the **critic** role (`agents/critic.md`)
   attacks the criteria: missing behaviors, numbers with no data behind them,
   scope limited to named examples, tolerance, open choices. Fix the criteria
   or write why not; the findings go under `## Criteria review` in the plan.
   The approval hook records nothing while that section is empty.
2. **Owner approval.** Show the criteria to the owner (in their language,
   English lines next to it: `rules/documentation.md`, section 5) and ask
   them to reply with the approval word: **"duyệt"** when `owner_language` is
   `vi`, else **"approve"**. Both work in every project. The owner reviews
   criteria, not test code. A hook (`approval-record.sh`) records that
   approval with a hash of the criteria in `.ai/approvals.log`; the agent
   never writes that file. Only a message that starts with the approval word
   counts ("để mình duyệt" does not). With several plans waiting, the owner
   names each one ("approve fix-login", the file name without its date); the
   hook lists the names.
   Editing the criteria afterwards needs a new approval. Until the criteria are
   approved and tests are locked, a hook (`sensitive-gate.sh`) blocks edits to
   non-test files in `sensitive_paths`; CI fails a PR whose sensitive changes
   have no approved plan.
3. **Tests first (tester role).** One test per criterion. Run them and
   confirm they **fail** before any implementation; a test that passes on the
   old code proves nothing. The tests must fail **only** because the behavior
   is missing: run `make lint` on them first. List the test files in
   `.ai/test-lock` (one path per line) and commit the tests, the lock, the plan
   and `.ai/approvals.log` together, with the trailer
   `Tests-First: <short task name>`. A Tests-First commit without an approved
   plan in it is rejected by CI and ignored by the hooks. The lock must list
   at least one test changed on the branch: a lock left from an earlier task
   does not open the gate, and an earlier task's round is no baseline.
4. **Implementation (builder role).** Make the tests pass. Anything beyond
   the approved criteria (a new criterion, a behavior change elsewhere) needs
   the owner's approval first: stop, ask, and update the plan. The builder never
   edits locked tests: hooks block it while the task is active, and CI fails a
   later commit that changes them.
5. **Review.** The reviewer checks that every criterion has a test and the
   tests match the criteria.
6. **Close.** Move the plan to `.ai/plans/completed/` and delete
   `.ai/test-lock` in the final commit. The lock expires on its own once its
   plan leaves `active/`, even if the file is forgotten; the owner never has
   to unlock anything.

**When a test or criterion turns out wrong mid-task** (a misread criterion,
the owner changes their mind, a test that cannot work):

1. The builder stops and tells the owner in plain words what is wrong.
2. If the owner agrees, update the criteria in the plan and ask for the
   approval word again. This opens a relock window: the tester may rewrite the
   locked tests.
3. The tester changes only the affected tests (they must fail on the current
   code, or the report says why not), updates `.ai/test-lock`, and commits a
   new `Tests-First:` round that includes the updated plan and approvals log.
4. The builder continues from step 4. Every change of criteria stays visible
   in the plan, in `.ai/approvals.log`, and in the PR summary.

### Sensitive changes need tests

CI fails a pull request that changes a file in `sensitive_paths` without
changing any test file. When a change truly needs no new test (a comment, a
rename), add a trailer to the commit with the reason:

```
No-Test-Reason: only fixes a typo in a comment
```

The reason is visible in the PR, where the reviewer can challenge it.

### Mutation testing (report only, on request)

The tool breaks the code on purpose (`>` becomes `>=`, `1` becomes `0`) and
reruns the tests. A **surviving mutant** is a change no test noticed: a gap
in the tests. It is off by default: it costs CI time, and acting on its
report costs agent tokens. Turn it on only for changes where a missed bug is
expensive (money, source data). The agent suggests it to the owner in one
line, always under the one name `test-mutation` (for example "This PR
changes the fee calculation: run test-mutation?"); only after the owner
agrees does it add the label:
`gh label create test-mutation --force && gh pr edit <n> --add-label test-mutation`.
CI then runs `make test-mutation` on the PR's changed files in `sensitive_paths`.
The PR summary lists the score and each survivor with its line. It never
fails the PR. For each survivor, add a test that fails on it, or write in
the PR why not.
Tools: cosmic-ray (Python), Stryker (`@stryker-mutator/core`, node-ts). Run
it locally on a clean tree: `make test-mutation FILES="app/money.py"`.

---

# 4. Test Existing Behavior First

Before changing complex functionality, identify existing tests.

Determine:

* What behavior is already covered
* What behavior is not covered
* Which tests are relevant to the change

Do not delete existing tests simply because they are inconvenient.

If existing tests are incorrect, document why they need to change.

---

# 5. New Functionality

New functionality should normally include appropriate tests.

Tests should cover:

* Expected behavior
* Important edge cases
* Failure cases
* Validation
* Relevant boundary conditions

The exact test type depends on the project's architecture.

---

# 6. Bug Fixes

When fixing a reproducible bug:

1. Understand the failure.
2. Reproduce it when possible.
3. Identify the root cause.
4. Implement the fix.
5. Add or update a regression test when practical.
6. Verify the original failure no longer occurs.
7. Run relevant regression tests.

A bug fix without regression protection should be treated as higher risk.

---

# 7. Edge Cases

Tests should consider relevant edge cases such as:

* Empty input
* Null/undefined values
* Invalid input
* Boundary values
* Duplicate data
* Missing data
* Unexpected API responses
* Network failures
* Permission failures
* Timeout
* Concurrent operations

Do not test hypothetical edge cases that have no meaningful relationship to the system.

---

# 8. Error Paths

Do not test only the happy path.

When failure handling is part of the feature, verify:

* Error detection
* Error propagation
* User-facing behavior
* Recovery behavior
* Logging when appropriate

---

# 9. Frontend Testing

For frontend changes, consider:

* Rendering
* User interaction
* State transitions
* Loading state
* Error state
* Empty state
* Form validation
* Accessibility
* Responsive behavior when relevant

For important user flows, use integration or end-to-end verification when appropriate.

Do not rely exclusively on snapshots for behavior-heavy components.

---

# 10. Backend Testing

For backend changes, consider:

* Request validation
* Business logic
* API responses
* Error handling
* Authorization
* Database behavior
* Transactions
* External service failures

Critical business logic should have direct automated coverage where practical.

---

# 11. Database Changes

For database-related changes, verify:

* Migration succeeds
* Existing data remains valid
* Constraints behave correctly
* Rollback strategy when applicable
* Application compatibility
* Queries behave as expected

Never run destructive database operations against real environments without explicit authorization.

---

# 12. Integration Testing

Use integration tests when correctness depends on multiple components working together.

Examples:

```text
Frontend
    ↓
API
    ↓
Business Logic
    ↓
Database
```

or:

```text
Application
    ↓
External Service
```

Unit tests alone may not detect integration failures.

---

# 13. End-to-End Testing

Use E2E testing for important user-facing flows when appropriate.

Typical examples:

* Authentication
* Registration
* Checkout
* Payment
* Important CRUD workflows
* Critical navigation flows

E2E tests should focus on meaningful user behavior rather than implementation details.

---

# 14. Test Independence

Tests should be as independent as practical.

Avoid:

* Hidden dependency between tests
* Shared mutable state
* Test-order dependence
* Persistent test data leaking between tests

If shared setup is necessary, keep it explicit.

---

# 15. Test Determinism

Tests should produce predictable results.

Avoid unnecessary dependence on:

* Current time
* Randomness
* External services
* Network availability
* Machine-specific state

When such dependencies are required, isolate or control them where practical.

---

# 16. External Services

Do not make normal unit tests depend on unreliable external services.

Prefer:

* Mocks
* Stubs
* Fakes
* Test environments

Use real integrations for integration/E2E testing when appropriate.

---

# 17. Test Data

Test data should be:

* Minimal
* Understandable
* Relevant
* Reproducible

Avoid unnecessarily large fixtures.

Do not include real secrets or sensitive production data in tests.

---

# 18. Test Failures

When a test fails:

1. Determine whether the failure is caused by the change.
2. Identify the root cause.
3. Fix the implementation if necessary.
4. Fix the test only when the test itself is incorrect.
5. Re-run the relevant test.
6. Run regression tests when appropriate.

Never modify a test merely to make a failing implementation pass.

---

# 19. Flaky Tests

If a test is flaky:

* Identify the source of nondeterminism.
* Do not simply retry indefinitely.
* Do not disable the test without documenting why.
* Fix the underlying cause when practical.

A known flaky test should be reported as a verification risk.

---

# 20. Test Coverage

Coverage percentage is a signal, not the objective.

Do not optimize for coverage numbers alone.

Prioritize coverage of:

* Business-critical logic
* High-risk paths
* Complex logic
* Important user flows
* Regression-prone functionality

A high coverage percentage does not guarantee correct behavior.

---

# 21. Performance Testing

Do not perform performance optimization or benchmarking without a relevant reason.

When performance matters:

* Define the metric.
* Establish a baseline.
* Make the change.
* Measure again.
* Verify the result.

Do not claim performance improvement without measurement.

---

# 22. Architecture Changes

For significant architecture changes, testing should verify:

* Existing behavior
* New behavior
* Module boundaries
* Integration points
* Dependency changes
* Regression risks

Architectural changes should generally receive broader verification than ordinary feature changes.

---

# 23. Reviewer Testing Responsibility

The Reviewer should verify that:

* Appropriate tests exist
* Tests cover important behavior
* Tests are meaningful
* Tests are not merely written to satisfy coverage
* Relevant verification was actually executed

The Reviewer should distinguish between:

* Missing tests
* Incorrect tests
* Failing tests
* Untested behavior

---

# 24. QA Responsibility

QA should focus on behavior from the user's perspective.

QA should verify where applicable:

* Main user flow
* Edge cases
* Error states
* Loading states
* Empty states
* UI behavior
* Accessibility
* Responsive behavior
* Acceptance criteria

QA should not duplicate every unit test.

---

# 25. Verification Report

When completing a task, report verification in a concise format:

```text
Verification

Tests:
- <command>
- PASS / FAIL

Type Check:
- PASS / FAIL / N/A

Lint:
- PASS / FAIL / N/A

Build:
- PASS / FAIL / N/A

E2E / QA:
- PASS / FAIL / N/A

Remaining Risks:
- <risk or None>
```

Only report checks that were actually performed.

---

# 26. Failed Verification

If verification fails:

Do not report the task as complete.

Instead:

1. Investigate.
2. Fix if within scope.
3. Re-run verification.
4. Escalate when necessary.

For a workflow containing multiple agents, return the task to the appropriate implementation agent when possible.

---

# 27. Verification Loop

For tasks requiring iterative debugging:

```text
Implement
    ↓
Test
    ↓
Failure?
 ┌──┴──┐
Yes    No
 ↓      ↓
Fix   Verify
 ↓
Test again
```

Repeat until:

* Verification passes
* The issue is proven unrelated
* The issue requires human decision
* The available environment prevents further verification

---

# 28. Final Rule

Testing is not a separate step added at the end.

Testing is part of implementation.

Every workflow must end with verification appropriate to the task's risk.

> Implement → Test → Fix → Verify → Report
