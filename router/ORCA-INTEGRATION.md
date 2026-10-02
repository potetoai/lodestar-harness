# Orca Integration Contract

> **Optional adapter.** Orca ADE is a third-party orchestrator (by Stably);
> Lodestar-harness is not affiliated with it and does not require it. Without
> Orca, read "Orca Task / Dispatch / Worker" as "subagent brief / subagent run /
> subagent", and "Orca" as the agent runtime (Claude Code). Sections 8 and
> 11–17 (task spec, verification, completion, escalation, failure handling,
> worktrees, output contract) apply to any runtime.

## 1. Purpose

This document defines how the Global Master Router integrates with Orca orchestration.

The Router decides:

* Which workflow to use.
* Which agent roles are required.
* Which specialized skills are useful.
* What verification is required.
* Whether work can run in parallel.

Orca is responsible for:

* Creating and managing Tasks.
* Creating and managing Dispatches.
* Starting workers.
* Managing worker lifecycle.
* Coordinating messages and completion.
* Managing workspaces/worktrees.
* Waiting for worker results.
* Reusing, retaining, or releasing settled workers.

The Router must not recreate Orca's orchestration lifecycle.

---

# 2. Responsibility Boundary

## Router

The Router answers:

> What should happen?

The Router determines:

```text
Task
  ↓
Complexity
  ↓
Workflow
  ↓
Agent Roles
  ↓
Skills
  ↓
Verification
```

## Orca

Orca answers:

> How is that work coordinated and executed?

Orca manages:

```text
Run
  ↓
Task
  ↓
Dispatch
  ↓
Worker
  ↓
Messages / Questions
  ↓
worker_done
  ↓
Settlement
  ↓
Reuse / Retain / Release
```

Orca's orchestration layer explicitly defines Run, Task and Dispatch responsibilities and worker lifecycle.

---

# 3. Source of Truth

The system has two levels of configuration.

## Global

```text
<lodestar-home>/
```

Contains:

```text
router/
workflows/
agents/
rules/
skills/
```

These define how agents should work.

## Project

```text
<project>\.ai\project.md
```

Defines how the specific project works.

Before significant implementation, the system should consider:

1. Global Router.
2. Selected Workflow.
3. Relevant Agent Role.
4. Relevant Rules — see the index in `rules/README.md`; read every rule that applies to the task.
5. Relevant Capabilities — see `skills/capabilities.md`.
6. Project Context.

---

# 4. Routing Process

For every new user task:

```text
User Task
    ↓
Intake gate
  - Clarify ambiguous requirements with the user (only when a wrong
    reading would change the work; otherwise state an assumption).
  - Capture explicit acceptance criteria (what proves this task done).
  - If no <project>/.ai/project.md exists, create it from the template
    before implementation begins.
    ↓
Read Project Context
    ↓
Router analyzes task
    ↓
Determine complexity
    ↓
Select workflow
    ↓
Select agent roles
    ↓
Select optional capabilities
    ↓
Define verification
    ↓
Routing approval gate
  - SIMPLE, low/medium-risk BUILD_REVIEW: announce in one line, proceed.
  - High-risk or tests-first BUILD_REVIEW, INDEPENDENT_COMPARE, COMPLEX:
    present the decision and wait for the user's approval before dispatching.
    ↓
Create Orca Task specifications
    ↓
Dispatch workers
```

The Router should select the smallest workflow that can reliably complete the task.

Do not create multiple workers merely because Orca supports multiple workers.

The acceptance criteria captured at intake become the `Observable Acceptance`
of the Orca Task specifications (see section 8), so completion is judged against
what the user agreed to, not what the Router assumed.

---

# 5. Workflow Mapping

## SIMPLE

Use when:

* Scope is small.
* Risk is low.
* Dependencies are limited.
* One worker can safely complete the task.

Execution:

```text
Router
  ↓
Simple Workflow
  ↓
One Worker
  ↓
Implement
  ↓
Test
  ↓
Verify
  ↓
worker_done
```

Normally use one Orca worker.

---

## BUILD_REVIEW

Use when:

* Implementation is meaningful.
* Independent review provides useful confidence.
* Architecture or regression risk is moderate.

Execution:

```text
Router
  ↓
Build Review Workflow
  ↓
Builder
  ↓
Implementation
  ↓
Testing
  ↓
Reviewer
  ↓
Findings
  ↓
Builder Fix
  ↓
Verification
  ↓
worker_done
```

Builder and Reviewer must have clearly defined ownership.

---

## INDEPENDENT_COMPARE

Use when:

* Multiple technically valid approaches are possible.
* Comparing independent solutions provides meaningful value.
* The task is important enough to justify additional work.

Execution:

```text
Router
        ↓
Independent Compare
        ↓
   ┌────┴────┐
   ▼         ▼
Worker A   Worker B
   │         │
   └────┬────┘
        ▼
     Compare
        ↓
Select / Merge / Reimplement
        ↓
Final Verification
```

Independent workers should not see each other's solution before independent work is complete.

---

## COMPLEX

Use when:

* Architecture is affected.
* Multiple modules are involved.
* Investigation is required.
* Multiple specialists are useful.
* Verification requirements are significant.

Execution:

```text
Router
   ↓
Complex Workflow
   ↓
Investigation
   ↓
Planning / Architecture
   ↓
Decomposition
   ↓
Parallel Implementation
   ↓
Integration
   ↓
Verification
   ↓
QA / Review
   ↓
Final Verification
```

Only parallelize genuinely independent work.

Orca's orchestration guide recommends parallel waves for independent work and dependencies only where real ordering exists.

---

# 6. Agent Role Mapping

Agent roles are logical responsibilities.

Available roles:

```text
architect
builder
reviewer
frontend
backend
tester
qa
```

The Router selects roles.

The Router must NOT permanently define:

```text
Claude = Frontend
Codex = Backend
```

Instead:

```text
Role
  ↓
Available Agent
  ↓
Orca worker
```

The actual model/agent selection may change according to:

* Task requirements.
* Availability.
* Project constraints.
* User configuration.
* Workflow requirements.

Orca's own orchestration example demonstrates workers being started with different agents such as `--agent codex` and `--agent claude`.

---

# 7. Capability Selection

Specialized capabilities are optional: methods in `skills/` or tools the agent runtime provides. See `skills/capabilities.md`.

Available capabilities:

```text
Deep-Investigation   (skills/investigate.md, skills/explore-options.md)
Product/QA/Release   (browser automation tool, e.g. Playwright MCP)
```

Capabilities do not replace agent roles.

Examples:

```text
Architect + Deep-Investigation
Builder + Deep-Investigation
Frontend + Product/QA/Release
QA + Product/QA/Release
```

Do not automatically use a capability for every task.

The Router should choose a capability only when it materially improves reliability.

---

# 8. Task Specification

Every Orca Task created from the Router must be self-contained.

Each Task must define:

### Target

What files, components, modules, or environment are in scope.

### Change

The concrete result expected from the worker.

### Constraints

Important invariants, compatibility requirements, rules, and boundaries.

### Ownership

What the worker is allowed to modify.

### Observable Acceptance

What evidence proves the Task is complete.

This follows Orca's Task-spec contract.

Example:

```text
Target:
front-end/src/features/auth/

Change:
Implement password reset flow.

Constraints:
- Preserve existing authentication API.
- Reuse existing form components.
- Do not modify unrelated features.

Ownership:
Authentication feature files and associated tests.

Observable Acceptance:
- Password reset flow works.
- Relevant tests pass.
- Type check passes.
```

---

# 9. Dispatch Rules

The Router should translate workflow steps into Orca Dispatches.

Conceptually:

```text
Workflow Step
     ↓
Task Specification
     ↓
Orca Task
     ↓
Orca Dispatch
     ↓
Worker
```

Use `worker-start --spec` when a new worker Task can be fully specified.

For planned dependency graphs or known existing Tasks, use the appropriate Task creation and worker-start flow.

Do not manually recreate lifecycle state that Orca already manages.

---

# 10. Parallel Execution

Parallel execution is allowed only when tasks are sufficiently independent.

Good:

```text
Frontend implementation
        +
Backend implementation
```

when the interfaces are already defined.

Good:

```text
Independent implementation A
        +
Independent implementation B
```

Bad:

```text
Architect
   ↓
Builder
   ↓
Builder
```

if the second Builder cannot start until the first has completed.

Use dependencies for actual ordering requirements.

Prefer parallel waves over unnecessarily deep chains.

---

# 11. Verification

Every workflow must end with verification.

Verification may include:

```text
Static checks
Focused tests
Integration tests
E2E tests
Build
Lint
Type check
Review
Browser QA
```

The Router determines the required level.

Relevant agents may perform verification:

```text
Tester
Reviewer
QA
Builder
```

Specialized capabilities may be added when useful:

```text
Deep-Investigation → engineering verification
Product/QA/Release → UI/browser/product verification
```

Never report completion solely because a worker stopped.

Completion requires evidence.

---

# 12. Worker Completion

A worker must report explicit success or failure.

Expected lifecycle:

```text
Worker
  ↓
Implement
  ↓
Test
  ↓
Verify
  ↓
worker_done
  ↓
Accepted Settlement
```

The worker should not be considered complete based only on:

* Terminal disappearance.
* Timeout.
* Lost connection.
* Missing response.
* Visible process state.

Orca explicitly treats uncertain state as `unverifiable` and requires positive evidence before stop, abandon, retry, or release.

---

# 13. Completion Accounting

After a worker has successfully settled, exactly one lifecycle decision should follow:

```text
Reuse
OR
Retain
OR
Release
```

Do not release a worker merely because it appears idle.

Settlement must be established first.

Orca's orchestration contract explicitly defines reuse, retention, and release after accepted settlement.

---

# 14. Questions and Escalation

Workers may encounter uncertainty.

Examples:

* Requirement ambiguity.
* Missing information.
* Architecture conflict.
* Destructive change.
* Unexpected dependency.
* Security concern.
* Test failure that cannot be safely resolved.

The worker should escalate through the Orca orchestration mechanism rather than inventing an assumption when the decision materially affects the task.

The Coordinator/Router should resolve the question and allow the worker to continue.

---

# 15. Failure Handling

Failure must preserve:

* Existing work.
* Worker authority.
* Evidence.
* Current state.

Do not automatically:

* Retry.
* Stop.
* Abandon.
* Release.
* Launch a duplicate worker.

A timeout or missing response is not automatically proof of failure.

Orca explicitly defines timeout/empty results as checkpoints rather than automatic failure.

---

# 16. Worktree and Workspace

Workspace decisions belong to Orca's orchestration layer.

The Router should describe the required ownership/isolation.

Example:

```text
Ownership:
Modify only the authentication feature.

Isolation:
Independent implementation requires isolated workspace.
```

Do not assume every task requires Git worktrees.

Orca supports folder workspaces and does not require Git/worktrees for every task.

---

# 17. Router Output Contract

Before execution, the Router should produce:

```text
Workflow:
[Simple / Build Review / Independent Compare / Complex]

Complexity:
[Low / Medium / High]

Scope:
[Description]

Risk:
[Low / Medium / High]

Architecture Impact:
[None / Low / Medium / High]

Uncertainty:
[Low / Medium / High]

Agents:
[Selected roles]

Skills:
[Selected skills or None]

Verification:
[Required verification]

Reason:
[Why this workflow was selected]
```

The Router then converts this decision into Orca Task specifications.

---

# 18. Example

User:

> Add a new password reset feature.

Router:

```text
Workflow:
BUILD_REVIEW

Complexity:
Medium

Scope:
Authentication feature

Risk:
Medium

Architecture Impact:
Medium

Uncertainty:
Low

Agents:
Builder
Reviewer
Tester

Skills:
None

Verification:
Focused tests + integration tests + type check

Reason:
Meaningful authentication change with moderate regression risk.
Independent review improves reliability.
```

Orca then manages:

```text
Task
  ↓
Builder Dispatch
  ↓
Implementation
  ↓
Tests
  ↓
Reviewer Dispatch
  ↓
Review
  ↓
Fix Dispatch
  ↓
Final Verification
  ↓
worker_done
```

---

# 19. Core Principle

The system has a strict separation of concerns:

```text
USER
  ↓
ORCA
  ↓
ROUTER
  ↓
WORKFLOW
  ↓
AGENT ROLE
  ↓
SKILL
  ↓
WORKER
  ↓
VERIFICATION
```

Each layer has one primary responsibility.

Do not duplicate functionality between layers.

### Router

Decides.

### Workflow

Defines execution strategy.

### Agent

Defines responsibility.

### Skill

Provides specialized capability.

### Rule

Defines constraints and principles.

### Project Context

Defines project-specific knowledge.

### Orca

Coordinates execution and lifecycle.

### Worker

Performs the actual work.

---

# 20. Global Rule

Never build a second orchestration system beside Orca.

Use the existing Orca orchestration primitives for:

* Tasks
* Dispatches
* Workers
* Coordination
* Messaging
* Waiting
* DAGs
* Settlement
* Cleanup

Use `Lodestar-harness` for:

* Routing decisions
* Workflow definitions
* Agent role definitions
* Global engineering rules
* Optional skills
* Project context conventions

The goal is:

> **Orca executes the orchestration. Lodestar-harness defines the intelligence and engineering policy behind that orchestration.**
