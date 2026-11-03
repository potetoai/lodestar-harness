# LODESTAR ENGINEERING OS — IMPLEMENTATION PLAN

> **Idea plan, rated.** Rated in `plans/active/skill-harvest.md`
> (2026-11-03, ideas 36-47): build no Core or Engineering OS as software;
> design work uses tried third-party skills plus a thin Lodestar bridge.

> Parent: plan.md  
> Dependency: Lodestar Core  
> Priority: P1  
> Initial agent: Claude Code

## 1. Objective

Build an Engineering Intelligence Engine that helps AI agents perform software engineering tasks using professional engineering principles.

The system must improve:
- Code correctness.
- Architecture quality.
- Maintainability.
- Testability.
- Security.
- Performance.
- Delivery reliability.

It must work with existing repositories and adapt to their actual architecture rather than forcing every project into one preferred stack.

## 2. Engineering Knowledge System

Create a structured engineering knowledge base.

### Architecture
- MVC.
- MVVM.
- Clean Architecture.
- Hexagonal Architecture.
- Layered Architecture.
- Modular Monolith.
- Microservices.
- Event-driven Architecture.

### Software design
- SOLID.
- DRY.
- KISS.
- YAGNI.
- Separation of Concerns.
- Dependency Injection.
- Design Patterns.
- Domain-Driven Design.

### Engineering practices
- Git workflows.
- Code review.
- TDD.
- BDD.
- Debugging.
- Refactoring.
- Testing strategies.
- CI/CD.

### Technical quality
- Security.
- Performance.
- Reliability.
- Observability.
- Accessibility.
- Scalability.

Requirements:
- Explain when a principle should be used.
- Explain when it should not be used.
- Include trade-offs and practical examples.
- Avoid treating every engineering principle as an absolute rule.
- Prefer project-specific conventions when they are deliberate and safe.

## 3. Codebase Intelligence

Objective: Understand the existing codebase before modifying it.

Capabilities:
- Detect languages and frameworks.
- Analyze repository structure.
- Identify entry points.
- Identify major modules.
- Map dependencies.
- Understand data flow.
- Identify API boundaries.
- Inspect database schemas.
- Discover existing tests.
- Detect coding conventions.
- Identify duplicated or obsolete code.
- Identify architectural risks.

Produce:
- Project technical profile.
- Architecture overview.
- Dependency map.
- Important module descriptions.
- Known technical debt.
- Testing coverage overview where measurable.

Rules:
- Do not claim complete understanding after scanning only a few files.
- Record confidence and evidence.
- Revisit the analysis when important architecture changes occur.
- Prefer incremental updates over rebuilding all project knowledge every task.

Acceptance:
An agent can identify where a feature belongs, which modules it affects and which conventions it must follow before implementation.

## 4. Specification & Planning Engine

Every non-trivial implementation must start with a specification.

Specification includes:
- Problem statement.
- Expected behavior.
- Functional requirements.
- Non-functional requirements.
- Constraints.
- Edge cases.
- Acceptance criteria.
- Dependencies.
- Risks.

Planning includes:
- Architecture impact.
- Files/modules affected.
- Implementation sequence.
- Testing strategy.
- Migration requirements.
- Rollback considerations.

Requirements:
- Ask for clarification when requirements materially affect implementation.
- Separate assumptions from confirmed requirements.
- Avoid excessive planning for trivial changes.
- Require human review for high-impact architecture decisions.

## 5. Architecture Intelligence

Objective: Help AI make technically sound architectural decisions.

Capabilities:
- Evaluate existing architecture.
- Recommend architectural patterns based on actual project needs.
- Detect inappropriate dependencies.
- Identify circular dependencies.
- Evaluate module boundaries.
- Review data ownership.
- Review API contracts.
- Evaluate scalability and maintainability trade-offs.

Architecture Decision Records must contain:
- Context.
- Problem.
- Options.
- Decision.
- Rationale.
- Consequences.
- Status.

Do not introduce Clean Architecture, DDD or microservices merely because they are popular.

Preserve existing architecture when it is adequate.

## 6. Implementation Engine

Objective: Execute features in controlled, maintainable increments.

Workflow:

Investigate → Specify → Plan → Implement → Test → Verify → Review → Deliver.

Requirements:
- Follow existing coding conventions.
- Reuse existing abstractions.
- Avoid unnecessary dependencies.
- Avoid unrelated refactoring.
- Keep changes focused.
- Handle error states.
- Consider edge cases.
- Maintain backward compatibility where required.
- Update relevant documentation.

Support:
- Frontend development.
- Backend development.
- API integration.
- Database changes.
- Infrastructure changes.
- Refactoring.
- Bug fixing.

## 7. TDD & Testing Engine

Implement testing strategies based on project needs.

Test levels:
- Unit tests.
- Integration tests.
- API tests.
- Component tests.
- End-to-end tests.
- Regression tests.
- Contract tests.

TDD workflow:

1. Write a failing test.
2. Run the test and verify failure.
3. Implement the smallest correct solution.
4. Run the test and verify success.
5. Refactor.
6. Run relevant regression tests.

Requirements:
- Do not create meaningless tests solely to satisfy coverage metrics.
- Test business behavior and edge cases.
- Reuse the project's existing test framework.
- Avoid testing implementation details unnecessarily.
- Record test evidence.

## 8. Systematic Debugging

Objective: Prevent AI from randomly changing code until an error disappears.

Workflow:
1. Reproduce the issue.
2. Collect evidence.
3. Identify possible causes.
4. Form a hypothesis.
5. Test the hypothesis.
6. Identify root cause.
7. Implement the fix.
8. Add regression coverage.
9. Verify the fix.

Rules:
- Do not conceal errors.
- Do not suppress failing tests without justification.
- Do not remove validation to make builds pass.
- Distinguish root-cause fixes from temporary workarounds.

## 9. Code Review Engine

Review dimensions:

### Correctness
- Does the implementation meet requirements?
- Are edge cases handled?
- Are error states handled?

### Architecture
- Are boundaries respected?
- Are dependencies appropriate?
- Is the solution unnecessarily complex?

### Maintainability
- Is the code understandable?
- Is duplication introduced?
- Are abstractions justified?

### Security
- Authentication.
- Authorization.
- Input validation.
- Secrets handling.
- Injection risks.
- Dependency vulnerabilities.

### Performance
- Unnecessary rendering.
- Expensive operations.
- Database query efficiency.
- Memory/resource usage.

### Testing
- Missing test scenarios.
- Regression risk.
- Weak assertions.

Review findings must include:
- Severity.
- Evidence.
- Location.
- Explanation.
- Recommended action.

## 10. Quality Gates

Define project-configurable quality gates.

### Required checks
- Relevant tests.
- Lint.
- Type checking where applicable.
- Build where applicable.
- Acceptance criteria verification.

### Conditional checks
- Security scans.
- Performance tests.
- Dependency audits.
- API contract checks.
- Database migration checks.

Rules:
- A skipped check must be reported.
- Existing unrelated failures must be distinguished from newly introduced failures.
- Critical failures block delivery.
- Exceptions require documented rationale.

## 11. Documentation Intelligence

After every completed feature, update relevant documentation.

Required documentation when applicable:
- README.
- architecture.md.
- API documentation.
- Database documentation.
- Configuration documentation.
- Developer setup.
- Changelog.
- ADRs.

Do not generate redundant documents for every small code change.

Documentation must reflect the actual implementation, not the original plan if implementation differs.

## 12. Engineering Workflows

Create modular workflows:

### Feature Development
Investigate → Specify → Plan → Implement → Test → Review → Deliver.

### Bug Fix
Reproduce → Diagnose → Root Cause → Fix → Regression Test → Verify.

### Refactoring
Baseline → Scope → Refactor → Regression Test → Compare.

### Architecture Change
Assess → Propose → ADR → Approval → Implement → Validate → Document.

### Security Review
Threat Identification → Inspection → Findings → Remediation → Verification.

### Release
Pre-release Checks → Build → Test → Review → Release Notes → Approval.

Use only relevant workflows for each task.

## 13. Skills Architecture

Organize skills by domain and purpose.

Suggested categories:

- engineering/architecture/
- engineering/planning/
- engineering/implementation/
- engineering/testing/
- engineering/debugging/
- engineering/review/
- engineering/security/
- engineering/documentation/

Each skill should contain:
- Purpose.
- When to use.
- When not to use.
- Required inputs.
- Execution steps.
- Validation criteria.
- Expected outputs.
- References.

Keep skills small and composable.

## 14. Implementation sequence

CODE-01: Engineering knowledge architecture.

CODE-02: Codebase discovery and project profiling.

CODE-03: Architecture intelligence.

CODE-04: Specification and planning.

CODE-05: Implementation workflow.

CODE-06: TDD and testing.

CODE-07: Systematic debugging.

CODE-08: Code review.

CODE-09: Quality gates.

CODE-10: Documentation intelligence.

CODE-11: Learning and workflow evaluation.

CODE-12: End-to-end validation.

## 15. Engineering MVP acceptance

Given an existing repository and a feature request, Engineering OS must:

1. Understand relevant project context.
2. Identify affected modules.
3. Produce an implementation plan.
4. Implement the feature.
5. Add relevant tests.
6. Run validation.
7. Review the changes.
8. Update documentation.
9. Record meaningful decisions.
10. Provide evidence-based delivery results.

The system must not claim success when required checks fail.