# LODESTAR CORE — IMPLEMENTATION PLAN

> **Idea plan, rated.** Rated in `plans/active/skill-harvest.md`
> (2026-11-03, ideas 36-47): build no Core or Engineering OS as software;
> design work uses tried third-party skills plus a thin Lodestar bridge.

> Parent: plan.md  
> Priority: P0  
> Initial runtime: Claude Code  
> Architecture: Modular, agent-agnostic

## 1. Objective

Build a shared foundation that enables Engineering OS and Design OS to operate independently while sharing project context, agent execution infrastructure, contracts and governance.

Core must not contain domain-specific engineering or design instructions.

## 2. Module 1 — Core Architecture

Requirements:
- Establish clear module boundaries.
- Define public interfaces for Core and domain OS modules.
- Establish dependency direction.
- Define configuration conventions.
- Define error handling and logging conventions.
- Define versioning strategy for shared contracts.

Rules:
- Domain OS modules must not import internal implementation details from each other.
- Core must not depend on either domain OS.
- Shared interfaces must be documented.
- Prefer simple local execution over distributed infrastructure.

Deliverables:
- architecture.md
- module-boundaries.md
- ADR-001-core-architecture.md

Acceptance:
- Architecture boundaries are documented.
- Dependencies follow the intended direction.
- A new domain module can be added without modifying unrelated Core internals.

## 3. Module 2 — Agent Runtime Adapter

Objective:
Provide a consistent interface for invoking supported AI agents.

Initial target:
- Claude Code.

Future targets:
- Codex.
- Gemini CLI.
- Other compatible coding/design agents.

Requirements:
- Define agent capability metadata.
- Define input/output conventions.
- Support task execution and result collection.
- Support execution status and error reporting.
- Support cancellation when the underlying runtime permits it.
- Capture execution metadata.
- Avoid assuming all agents support the same tools.

Important:
Do not rebuild Claude Code's native functionality.
Do not create a custom terminal or agent runtime unless necessary.

Deliverables:
- Agent adapter interface.
- Claude Code adapter.
- Capability registry.
- Runtime integration tests.

Acceptance:
- Core can invoke Claude Code through the defined adapter.
- Runtime errors are reported consistently.
- Unsupported capabilities are explicitly identified.

## 4. Module 3 — Capability & Model Routing

Objective:
Select an appropriate agent/model for each task based on capabilities, complexity and constraints.

Routing inputs:
- Task category.
- Task complexity.
- Required capabilities.
- Context requirements.
- Available providers.
- Cost/latency constraints.
- User preferences.

Initial categories:
- Research.
- Planning.
- Architecture.
- Design.
- Implementation.
- Testing.
- Review.
- Documentation.

Rules:
- Do not hardcode Claude for design and Codex for coding.
- Routing must be based on task requirements and available capabilities.
- Support explicit user overrides.
- Record routing decisions.
- Provide deterministic fallback behavior.

Acceptance:
- Routing decisions are explainable.
- Missing capabilities are detected before execution.
- Provider failures do not silently produce false success.

## 5. Module 4 — Project Intelligence

Objective:
Give agents a persistent and structured understanding of each project.

Project knowledge should include:

### Project identity
- Project purpose.
- Business domain.
- Target users.
- Technology stack.
- Repository structure.

### Architecture
- Architectural style.
- Major modules.
- Dependency relationships.
- Data flow.
- External integrations.
- Important technical constraints.

### Conventions
- Coding standards.
- Naming conventions.
- File organization.
- Testing conventions.
- Documentation conventions.

### Decisions
- Architecture Decision Records.
- Product decisions.
- Technology choices.
- Rejected alternatives.
- Known trade-offs.

### Design context
- Design system.
- Design tokens.
- Component library.
- UX guidelines.
- Design references.

Requirements:
- Distinguish verified facts from agent assumptions.
- Record source and last verification date.
- Track stale or conflicting information.
- Support project-level overrides.
- Avoid duplicating information already present in source files.

Acceptance:
- Agents can retrieve relevant project context before task execution.
- Knowledge is traceable to its source.
- Conflicting information is surfaced instead of silently resolved.

## 6. Module 5 — Context Manager

Objective:
Load the right information at the right time.

Context layers:
1. Core instructions.
2. Project context.
3. Task-specific context.
4. Domain-specific skills.
5. Relevant historical decisions.

Requirements:
- Progressive disclosure.
- Relevance-based retrieval.
- Context size awareness.
- Avoid loading all domain skills by default.
- Prefer authoritative project files over unverified memory.
- Resolve conflicts using explicit precedence rules.

Acceptance:
- A design task does not automatically load the entire engineering knowledge base.
- A coding task does not automatically load all UX research materials.
- Relevant shared project context remains accessible.

## 7. Module 6 — Shared Contracts

Define versioned contracts between Core and OS modules.

Initial contracts:

### Task Contract
- task_id
- project_id
- domain
- objective
- inputs
- constraints
- acceptance_criteria
- required_capabilities
- approval_requirements

### Execution Contract
- execution_id
- task_id
- agent
- status
- artifacts
- logs
- validation_results

### Artifact Contract
- artifact_id
- type
- location
- version
- source_task
- validation_status

### Decision Contract
- decision_id
- domain
- context
- decision
- alternatives
- rationale
- consequences
- approval_status

### Handoff Contract
- handoff_id
- source_domain
- target_domain
- specification_version
- artifacts
- acceptance_criteria
- known_constraints

Use schemas with validation. Avoid unstructured free-form data when a stable structure is possible.

Acceptance:
- Contracts are versioned.
- Invalid data is rejected.
- Breaking changes are documented and migrated deliberately.

## 8. Module 7 — Workflow Orchestration

Objective:
Coordinate tasks without forcing every task through a complicated multi-agent workflow.

Support:
- Sequential execution.
- Parallel execution.
- Review loops.
- Approval checkpoints.
- Retry policies.
- Task dependencies.
- Failure handling.

Workflow principles:
- Use a single agent for simple independent tasks.
- Use planning and review for complex tasks.
- Use parallel agents only when work can be isolated safely.
- Do not run tests against incomplete parallel implementation unless the test scope is independent.
- Use isolated Git worktrees when concurrent changes could conflict.
- Define merge and conflict-resolution policies.

Initial workflow:

Investigate → Plan → Implement → Test → Verify → Review → Deliver.

Acceptance:
- Task state is traceable.
- Dependencies are respected.
- Failed tasks do not appear successful.
- Human approval is enforced at configured checkpoints.

## 9. Module 8 — Quality Governance

Objective:
Ensure completion claims are backed by evidence.

Core responsibilities:
- Collect validation results.
- Associate evidence with tasks and artifacts.
- Track required versus optional checks.
- Support approval policies.
- Prevent false completion states.

Evidence examples:
- Test output.
- Build output.
- Lint output.
- Security scan.
- Review report.
- Visual QA report.

Do not implement every domain-specific check inside Core. Domain OS modules define their own checks and register them through shared interfaces.

## 10. Module 9 — Memory & Learning

Three memory scopes:

### Core memory
Reusable execution and orchestration knowledge.

### Project memory
Project-specific architecture, conventions and decisions.

### Domain memory
Engineering or Design knowledge.

Learning lifecycle:
1. Capture a lesson.
2. Identify its scope.
3. Verify evidence.
4. Review its usefulness.
5. Approve promotion.
6. Update the relevant knowledge source.
7. Record the change.

Never automatically turn every agent observation into a permanent rule.

Acceptance:
- Lessons have provenance.
- Changes are auditable.
- Incorrect lessons can be reverted.
- Project knowledge is not polluted by unrelated projects.

## 11. Module 10 — Configuration & Governance

Requirements:
- Global configuration.
- Project configuration.
- Domain-specific configuration.
- Agent capability configuration.
- Approval policies.
- Routing policies.

Precedence:
Project-specific configuration overrides global defaults, unless a mandatory security or governance policy prohibits it.

Provide safe defaults.

## 12. Implementation sequence

Core-01: Repository audit and architecture baseline.

Core-02: Module boundaries and shared contracts.

Core-03: Configuration and project discovery.

Core-04: Claude Code runtime adapter.

Core-05: Project Intelligence.

Core-06: Context Manager.

Core-07: Basic sequential workflow orchestration.

Core-08: Evidence collection and quality governance.

Core-09: Capability routing.

Core-10: Memory and learning foundation.

Core-11: Integration and end-to-end tests.

Do not start the next major module until the current module passes its acceptance criteria.

## 13. Core MVP

The first usable release must support:

- Discover an existing project.
- Read and understand project context.
- Execute a task through Claude Code.
- Load relevant skills and instructions.
- Follow a defined workflow.
- Collect validation evidence.
- Update project documentation.
- Record decisions.
- Report completion honestly.

Advanced multi-agent execution, remote workers and distributed infrastructure are not MVP requirements.

## 14. Required documentation

- architecture.md
- module-boundaries.md
- contracts.md
- configuration.md
- agent-adapters.md
- project-intelligence.md
- workflow-engine.md
- quality-governance.md
- memory-and-learning.md
- ADRs

Update relevant documents after each feature.