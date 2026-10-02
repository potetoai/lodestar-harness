# Global Architecture Rules

Version: 1.0

Scope: All projects using Lodestar-harness

---

## Purpose

This document defines the global architecture principles shared by every project.

These rules guide:

- Architect
- Builder
- Frontend
- Backend
- Reviewer
- Tester
- QA

The objective is to produce software that is consistent, maintainable and appropriate for the project's real requirements.

---

# 1. Core Principles

Always prefer:

- Simplicity over unnecessary complexity
- Consistency over theoretical purity
- Reuse over duplication
- Explicit boundaries over implicit behavior
- Incremental improvement over large rewrites

Architecture exists to solve problems, not to satisfy design patterns.

---

# 2. Existing Project First

Before proposing any architectural change, the Architect MUST identify:

- Current project structure
- Existing architectural pattern
- Module boundaries
- Dependency direction
- Data flow
- Existing conventions

If the current architecture is adequate, preserve it.

Never refactor an entire project simply to convert MVC into Clean Architecture or MVVM.

---

# 3. New Project Rule

For a new project, choose architecture according to:

- Project size
- Feature complexity
- Expected growth
- Team size
- Testing requirements
- Deployment model
- Maintainability

Do NOT automatically choose:

- Clean Architecture
- MVVM
- MVC
- Hexagonal
- DDD

Every architecture must be justified.

---

# 4. Supported Architecture Patterns

The Architect may choose one or combine compatible concepts.

Supported patterns include:

- MVC
- MVVM
- Clean Architecture
- Layered Architecture
- Feature-based Architecture
- Modular Architecture
- Hexagonal Architecture
- Domain-Driven Design

The chosen pattern must include:

- Responsibility boundaries
- Dependency direction
- Data flow
- Justification
- Trade-offs

---

# 5. Frontend Principles

Frontend should separate:

- UI
- State
- Business logic
- API access
- Shared components

Always consider:

- Loading state
- Error state
- Empty state
- Accessibility
- Responsive behavior

Avoid creating unnecessary ViewModels or abstraction layers for small features.

---

# 6. Backend Principles

Backend should clearly separate:

- Presentation/API
- Business logic
- Data access
- Infrastructure

Always include:

- Validation
- Error handling
- Authentication when required
- Transaction safety

Business logic should not depend directly on framework-specific infrastructure.

---

# 7. Dependency Rules

Allowed direction:

Presentation

→ Application

→ Domain

→ Infrastructure

Avoid:

- Circular dependency
- UI calling database directly
- Domain depending on HTTP objects
- Business logic inside controllers/components

Only introduce interfaces when they provide real value.

---

# 8. Separation of Concerns

Each module should have one clear responsibility.

Avoid mixing:

- Rendering
- Business rules
- Database access
- Network calls
- Authentication
- Formatting
- Validation

Keep separation proportional to project complexity.

---

# 9. Reuse Policy

Before creating new code:

1. Search existing implementation.
2. Reuse if appropriate.
3. Extend if necessary.
4. Create new only when justified.

Never duplicate business logic.

---

# 10. Anti-Overengineering Rules

Never introduce:

- Unnecessary layers
- Unnecessary interfaces
- Generic abstractions for one use case
- Premature microservices
- Large refactors unrelated to the task

Solve today's problem while leaving reasonable room for tomorrow.

---

# 11. Architecture Decision Record (ADR)

For significant architectural decisions, document:

## Problem

What needs to be solved?

## Context

Existing constraints.

## Options

Possible solutions.

## Decision

Chosen solution.

## Why

Reason for choosing it.

## Trade-offs

Benefits and costs.

## Impact

Affected modules.

Small implementation tasks do not require ADR.

---

# 12. Reviewer Checklist

The Reviewer must verify:

- Dependency direction
- Module boundaries
- Business logic placement
- Duplicate logic
- Unnecessary abstraction
- Architecture consistency
- Unrelated refactoring

Do not reject code because it doesn't match personal preference.

Review against the documented project architecture.

---

# 13. Verification

After architecture changes verify:

- Build success
- Existing functionality
- New functionality
- Integration points
- Tests
- Dependency integrity
- No unintended side effects

High-risk architecture changes require explicit human approval before merge.

---

# Global Rule

Choose the architecture that best fits the project.

Never force the project to fit the architecture.
