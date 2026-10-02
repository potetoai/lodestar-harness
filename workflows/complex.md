# Complex Workflow

## Purpose

Handle large, cross-layer, architectural, or high-risk development tasks using specialized agents and structured verification.

## Process

### Phase 1 — Investigation

Understand:

- existing architecture
- affected modules
- dependencies
- data flow
- API contracts
- current tests
- technical constraints

Do not modify code unnecessarily during investigation.

### Phase 2 — Planning

Create an implementation plan containing:

- requirements
- affected systems
- implementation steps
- dependencies
- risks
- testing strategy

Write the plan to a file: copy `.ai/plans/TEMPLATE.md` to
`.ai/plans/active/<yyyy-mm-dd>-<task>.md` in the project. The chat is not the
record; the file is, so later sessions and other workers can pick the task up.
Update its progress log after each phase and its decision log whenever a
choice is made. When the task is merged, move the file to
`.ai/plans/completed/`. High-risk tasks (tests-first mode) need this file too,
even outside COMPLEX; CI checks it.

### Phase 3 — Architecture Review

Determine:

- whether the existing architecture supports the change
- whether new abstractions are necessary
- whether existing abstractions should be reused
- API/data-model impact
- frontend/backend boundaries

Use the Deep-Investigation capability (`skills/investigate.md`, `skills/explore-options.md`) when engineering investigation or architecture is a significant part of the task.

### Phase 4 — Decomposition

Split the implementation into tasks with clear ownership.

Possible roles:

- architect
- frontend
- backend
- database
- infrastructure
- tester
- reviewer
- QA

Only create roles that provide meaningful value.

### Plan Approval Gate

Before the plan goes to the user, a critic (`agents/critic.md`, fresh
subagent) attacks its acceptance criteria; findings go under
`## Criteria review` in the plan.

Before spawning parallel implementation workers, present the plan, architecture
decision and decomposition to the user and get approval.

Parallel workers are the most expensive and hardest-to-reverse step. A wrong
plan multiplies across every worker. Require approval when the task is high
risk, changes architecture, or spawns three or more parallel workers. For lower
stakes, state the plan and proceed unless the user objects.

### Phase 5 — Parallel Implementation

Run independent tasks in parallel when dependencies allow.

Examples:

- frontend implementation
- backend implementation
- tests
- documentation

Do not parallelize tightly dependent tasks.

### Phase 6 — Integration

Integrate the implementations.

Check:

- API compatibility
- data contracts
- state management
- error handling
- type consistency
- configuration

### Phase 7 — Verification

Run:

- unit tests
- integration tests
- end-to-end tests when applicable
- build/type checks
- lint/static analysis when applicable

### Phase 8 — Product/UI QA

Use the Product/QA/Release capability (browser automation tool, `skills/capabilities.md`) when the task has significant:

- UI/UX changes
- browser behavior
- user flows
- visual validation
- product-level QA
- release validation

### Phase 9 — Final Review

Review:

- requirements
- architecture
- implementation
- tests
- security
- performance
- unintended changes
- the plan file: progress and decision logs are current; debt left on purpose
  is in `.ai/tech-debt.md`

### Phase 10 — Final Verification

Run the required verification again after all fixes.

### Phase 11 — Release / Delivery (optional)

Run only when the task's scope includes shipping, not just producing verified
code. Skip when delivery is handled outside this workflow (by a person or CI).

This workflow does not invent a deployment pipeline. It uses what the project
already defines:

- Use the deploy/release command from `.ai/project.md`.
- Apply the Product/QA/Release capability (browser automation tool) for
  release checks when available.
- Run a post-deploy smoke check of the critical path (the acceptance criteria
  from intake).
- Confirm a rollback path exists before deploying; if the smoke check fails,
  roll back rather than leave a broken release.
- Update docs / changelog per `rules/documentation.md`.

High-risk or production deploys require explicit human approval
(see `rules/git.md`).

## Rules

- Do not spawn agents without defined responsibilities.
- Do not parallelize dependent work.
- Keep architecture decisions explicit.
- Minimize unrelated changes.
- Verify the integrated system, not only individual worktrees.
- Use specialized capabilities (Deep-Investigation, Product/QA/Release) only when they are relevant.
- High-risk operations require explicit human approval.
- Integration failure: if integration or final verification fails and cannot be safely resolved, roll back to the last verified good state instead of forcing a broken merge. Preserve each worker's branch/worktree and evidence (see `rules/git.md`). Do not discard work to unblock; report the failure and the recovery point.
- When the change alters architecture, technical decisions, commands, or conventions, update `.ai/project.md` and any user-facing docs/changelog as part of completion (see `rules/documentation.md`).

## Completion Criteria

The task is complete only when:

- requirements are satisfied
- architecture is coherent
- implementation is integrated
- relevant tests pass
- required QA is complete
- final review is complete
- final verification passes
