# LODESTAR — MASTER PLAN

> **Idea plan, rated.** Rated in `plans/active/skill-harvest.md`
> (2026-11-03, ideas 36-47): build no Core or Engineering OS as software;
> design work uses tried third-party skills plus a thin Lodestar bridge.

> Version: 1.0  
> Status: Proposed  
> Product vision: A modular AI Product Development & Software Engineering System.

## 1. Vision

Lodestar is a modular intelligence and orchestration system that helps AI agents perform professional product design and software engineering work.

Lodestar consists of three major parts:

1. **Lodestar Core:** Shared infrastructure, project intelligence, agent orchestration, memory, contracts and quality governance.
2. **Engineering OS:** Domain intelligence for software engineering.
3. **Design OS:** Domain intelligence for product design and UX/UI.

The system should make AI agents more reliable, consistent, context-aware and capable of delivering production-quality work.

Lodestar is not another coding agent. It is an operating and intelligence layer that makes existing agents better.

## 2. Core principles

### 2.1 Modular by design
- Core must remain independent from Engineering OS and Design OS.
- Each OS owns its domain knowledge, skills, workflows and quality gates.
- Domain modules communicate through versioned contracts.
- Avoid tight coupling between modules.

### 2.2 Agent-agnostic
- Do not hardcode the system around Claude Code.
- Support Claude Code as the initial primary runtime.
- Design adapters for Codex and other compatible agents.
- Separate agent capabilities from agent-specific implementations.

### 2.3 Evidence-based execution
Agents cannot claim completion without evidence.

Examples:
- Tests passed.
- Build succeeded.
- Lint passed.
- Acceptance criteria verified.
- Design validation completed.

### 2.4 Progressive context loading
- Do not load every skill and document into every task.
- Load only relevant instructions.
- Use project metadata to determine which knowledge is necessary.
- Keep core instructions concise.

### 2.5 Continuous learning
- Capture meaningful engineering and design decisions.
- Record recurring mistakes and useful solutions.
- Promote reusable lessons into project knowledge.
- Never silently modify global rules based on one isolated event.

### 2.6 Human control
- Require approval for destructive or high-impact actions.
- Never silently change architecture decisions.
- Keep important decisions auditable.
- Allow humans to override agent recommendations.

## 3. Target architecture

```text
LODESTAR
│
├── Core
│   ├── Agent Runtime Adapters
│   ├── Model/Capability Router
│   ├── Orchestration
│   ├── Project Intelligence
│   ├── Context Manager
│   ├── Memory & Learning
│   ├── Shared Contracts
│   └── Quality Governance
│
├── Engineering OS
│   ├── Engineering Knowledge
│   ├── Project Architecture Intelligence
│   ├── Specification & Planning
│   ├── Implementation Workflows
│   ├── Testing & Debugging
│   ├── Code Review
│   └── Engineering Quality Gates
│
├── Design OS
│   ├── Product & UX Knowledge
│   ├── Design System Intelligence
│   ├── UX Research
│   ├── Information Architecture
│   ├── UI Design & Interaction
│   ├── Design Execution
│   └── Design Quality Gates
│
└── Integration
    ├── Design-to-Engineering Handoff
    ├── Cross-domain Validation
    └── Joint Delivery
```

This is a logical architecture, not a mandatory directory structure. Inspect the existing repository before deciding where each module belongs.

## 4. Development roadmap

### Phase 0 — Repository Audit
- Inspect existing source code, documentation, dependencies and Git history.
- Identify existing reusable modules.
- Identify incomplete, duplicated or obsolete components.
- Inspect current agent integration and workflows.
- Review licenses of external dependencies and inspirations.
- Produce an architecture assessment.
- Create or update ADRs for major architectural decisions.

**Gate:** No implementation begins until the current architecture and migration strategy are understood.

### Phase 1 — Lodestar Core
Implement:
- Core architecture and module boundaries.
- Agent runtime abstraction.
- Capability and model routing interfaces.
- Project Intelligence.
- Context loading.
- Shared contracts.
- Workflow orchestration.
- Evidence and quality governance.
- Memory and learning foundations.

**Gate:** A basic project workflow can execute using Claude Code through Core without requiring either domain OS.

### Phase 2 — Engineering OS
Implement:
- Engineering knowledge system.
- Codebase understanding.
- Architecture analysis.
- Specification and planning.
- TDD implementation.
- Debugging.
- Code review.
- Testing and security validation.
- Documentation maintenance.

**Gate:** Lodestar can execute a real software feature from specification to verified delivery.

### Phase 3 — Design OS
Implement:
- UX and product knowledge.
- Design principles and patterns.
- Design System Adapter.
- Token and component understanding.
- UI design workflow.
- Interaction specifications.
- Accessibility.
- Visual QA.

**Gate:** Design OS can create and validate a design artifact using an existing project design system.

### Phase 4 — Cross-domain Integration
Implement:
- Versioned design handoff contracts.
- Design-to-code implementation.
- Design compliance validation.
- Technical feasibility feedback.
- Cross-domain review.
- Joint delivery reports.

**Gate:** A feature can move from product requirements through design and implementation to verified delivery.

### Phase 5 — Continuous Improvement
Implement:
- Learning capture.
- Reusable knowledge promotion.
- Failure analysis.
- Workflow evaluation.
- Quality metrics.
- Agent performance comparison.

**Gate:** Knowledge improvements are traceable, reviewable and do not silently weaken existing standards.

## 5. Implementation rules

1. Audit before modifying.
2. Implement one coherent feature at a time.
3. Define acceptance criteria before implementation.
4. Write or update tests with every relevant feature.
5. Run all relevant validation before declaring completion.
6. Update documentation after every completed feature.
7. Update architecture documentation when architectural decisions change.
8. Record significant decisions in ADRs.
9. Update the relevant plan's status and progress.
10. Commit each completed logical unit.
11. Never commit broken or unverified code.
12. Do not introduce dependencies without explaining their value.
13. Do not copy entire external repositories without license and architectural review.
14. Avoid duplicated skills and overlapping instructions.

## 6. Definition of Done

A feature is complete only when:

- [ ] Requirements are understood.
- [ ] Implementation follows architecture and conventions.
- [ ] Relevant tests pass.
- [ ] Relevant lint/type checks pass.
- [ ] Build succeeds when applicable.
- [ ] Security and regression risks are considered.
- [ ] Documentation is updated.
- [ ] ADR is updated if necessary.
- [ ] Plan status is updated.
- [ ] Changes are committed.
- [ ] Evidence of validation is recorded.

## 7. Scope management

Do not attempt to build every planned capability in the first release.

Prioritize:
1. Reliable foundation.
2. Small but complete workflows.
3. Reusable architecture.
4. Measurable quality.
5. Gradual expansion.

Avoid:
- Building a custom LLM.
- Building a custom coding agent.
- Replacing Git.
- Building an elaborate UI before the core works.
- Implementing distributed multi-agent infrastructure without a demonstrated need.
- Building an autonomous self-modifying rule system.

## 8. External references

Study, do not blindly copy:

- obra/superpowers — engineering workflows and TDD.
- garrytan/gstack — role-based product and engineering workflows.
- huanrasan/sdlc-harness — full SDLC and evidence-based governance.
- QoderAI/better-harness — harness architecture and feedback loops.
- github/spec-kit — specification-driven development.
- DESIGN:OS by jangtrinh — design knowledge and design quality gates.

Before reusing source code, inspect the exact license and compatibility.

## 9. Current project status

All phases start as `NOT_STARTED`.

Claude Code must inspect the existing repository and reconcile this plan with actual implementation before changing status.

Use:
- NOT_STARTED
- IN_PROGRESS
- BLOCKED
- COMPLETED
- DEFERRED

Do not mark a feature completed based on documentation alone.

## 10. Final objective

Lodestar should enable a team or individual to use different AI agents as a coordinated professional product development team.

The system should combine:
- Shared intelligence.
- Domain-specific expertise.
- Reliable execution.
- Verifiable quality.
- Persistent project knowledge.
- Human-governed continuous improvement.