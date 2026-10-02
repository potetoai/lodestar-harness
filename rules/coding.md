# Global Coding Rules

Version: 1.0
Scope: All projects using Lodestar-harness

---

## Purpose

Define global coding principles for all agents that create, modify, or review code.

These rules apply to:

* Architect
* Builder
* Frontend
* Backend
* Reviewer
* Tester
* QA

Project-specific coding conventions take precedence when explicitly defined in the project context.

---

# 1. Understand Before Changing

Before modifying code, the agent MUST:

1. Understand the task.
2. Inspect relevant files.
3. Identify existing patterns.
4. Search for reusable implementations.
5. Understand dependencies and side effects.
6. Determine the smallest safe change.

Do not modify code based only on filenames or assumptions.

For a large file, grep (or Glob) first, then read only the range you need, not
the whole file.

---

# 2. Minimal Change

Prefer the smallest change that correctly solves the task.

Do not:

* Refactor unrelated code
* Rename unrelated files
* Reformat unrelated files
* Change architecture without justification
* Upgrade dependencies without reason
* Modify unrelated behavior

A larger change is acceptable when the task or architecture requires it.

---

# 3. Existing Code First

Before creating new:

* Components
* Functions
* Utilities
* Services
* Hooks
* APIs
* Types
* Classes

search the existing codebase.

Prefer:

1. Reuse
2. Extend
3. Refactor existing implementation
4. Create new implementation

Avoid unnecessary duplication.

---

# 4. Naming

Names must clearly communicate intent.

Prefer descriptive names over short names.

Avoid meaningless names such as:

* `data`
* `temp`
* `thing`
* `foo`
* `manager`
* `helper`

unless their meaning is genuinely clear from context.

Use the project's existing naming conventions.

Do not introduce a new naming convention when an established convention already exists.

---

# 5. Functions and Methods

Functions should have a clear responsibility.

Prefer:

* Small focused functions
* Explicit inputs
* Predictable outputs
* Minimal side effects

Avoid functions that simultaneously handle unrelated responsibilities such as:

* Validation
* Database access
* Business logic
* Formatting
* UI rendering

unless the project's architecture intentionally combines them.

---

# 6. Duplication

Avoid duplicated business logic.

If the same logic appears repeatedly:

1. Determine whether duplication is intentional.
2. Check whether an existing abstraction already exists.
3. Extract a shared abstraction only when it improves maintainability.

Do not create abstractions solely to eliminate a few lines of duplication.

---

# 7. Abstraction

Introduce abstraction when it provides meaningful value.

Good reasons include:

* Multiple implementations
* Complex business logic
* Clear dependency boundary
* Testability
* Reuse across meaningful modules
* Separation from infrastructure

Avoid abstractions created only because:

* "Clean Code" recommends them
* A pattern usually uses them
* Future requirements might need them

---

# 8. Error Handling

Errors must be handled intentionally.

Do not:

* Silently swallow errors
* Ignore rejected promises
* Catch exceptions without handling them
* Return misleading success states

Errors should:

* Preserve useful diagnostic information
* Be handled at the appropriate layer
* Provide meaningful user-facing behavior where applicable
* Avoid exposing sensitive internal information

Follow the project's existing error-handling strategy.

---

# 9. Validation

Validate data at appropriate boundaries.

Examples:

* User input
* API requests
* External service responses
* Configuration
* Database boundaries

Do not rely solely on frontend validation for security-sensitive operations.

Backend or server-side validation remains authoritative when applicable.

---

# 10. Security

Never introduce obvious security vulnerabilities.

Pay particular attention to:

* Authentication
* Authorization
* Input validation
* Injection
* Secrets
* Sensitive data
* File access
* External URLs
* Authentication tokens
* Database queries

Never hard-code:

* API keys
* Passwords
* Access tokens
* Private credentials

Use the project's approved configuration or secret-management mechanism.

---

# 11. Dependencies

Before adding a dependency:

1. Check whether the functionality already exists.
2. Check whether the project's existing dependencies can solve the problem.
3. Evaluate maintenance and security implications.
4. Confirm compatibility with the project.
5. Add the dependency only when justified.

Do not add libraries for trivial functionality.

Do not upgrade unrelated dependencies during feature work.

---

# 12. Comments

Comments should explain **why**, not simply **what**.

Good:

```text
// Retry once because the payment provider may temporarily return 503.
```

Bad:

```text
// Increment counter
counter++;
```

Avoid comments that merely repeat the code.

Document non-obvious:

* Business rules
* Workarounds
* External limitations
* Important architectural constraints
* Complex algorithms

---

# 13. Type Safety

Use the strongest practical type safety supported by the project.

Avoid unnecessary:

* `any`
* Unsafe casts
* Suppression directives
* Weakly typed APIs

When an unsafe escape is necessary, document why when appropriate.

Follow the project's existing type system and conventions.

---

# 14. State and Side Effects

Keep state changes predictable.

Clearly separate, where appropriate:

* Pure logic
* State management
* External side effects
* Network operations
* Persistence

Avoid hidden global state unless the project intentionally uses it.

---

# 15. Performance

Do not prematurely optimize.

First prioritize:

1. Correctness
2. Maintainability
3. Clear architecture

Optimize when there is evidence of a performance problem or when requirements explicitly demand it.

When optimizing, verify that the optimization actually improves the relevant metric.

---

# 16. Backward Compatibility

Before changing existing behavior, identify:

* Existing callers
* Existing APIs
* Data formats
* Database dependencies
* External integrations
* Tests

Avoid breaking existing consumers unless the task explicitly requires a breaking change.

For breaking changes, identify affected areas and update them consistently.

---

# 17. Configuration

Keep environment-specific configuration outside source code where appropriate.

Do not hard-code:

* URLs
* Credentials
* Environment-specific values
* Deployment-specific settings

Follow the project's configuration strategy.

---

# 18. Generated Code

Do not manually modify generated files unless the project explicitly requires it.

First identify:

* Source of generation
* Generation command
* Generated output

When generated code must change, modify the source and regenerate when possible.

---

# 19. Formatting and Linting

Follow the project's existing:

* Formatter
* Linter
* Import ordering
* Code style
* Naming conventions

Do not introduce a new formatter or linting system unless explicitly required.

Run the project's standard formatting/linting checks when relevant.

---

# 20. Testing During Implementation

Code changes should be verified at the appropriate level.

At minimum:

* Run relevant tests
* Run relevant type checks
* Run relevant lint/build checks when applicable

The exact testing strategy is defined by `rules/testing.md`.

Do not claim that code works without performing the relevant verification.

---

# 21. Scope Discipline

Agents must stay within the assigned scope.

If unrelated issues are discovered:

* Do not silently fix them.
* Report them.
* Fix them only if they block the current task or the task explicitly includes them.

This is especially important when multiple agents are working in parallel.

---

# 22. Preserve Existing Behavior

Unless explicitly required, existing behavior should remain unchanged.

Before changing behavior, determine:

* Why the behavior exists
* Who depends on it
* Whether tests cover it
* Whether the change is intentional

Avoid accidental behavior changes caused by cleanup or refactoring.

---

# 23. Code Review Expectations

Reviewers should evaluate:

* Correctness
* Maintainability
* Readability
* Security
* Error handling
* Duplication
* Unnecessary complexity
* Scope discipline
* Consistency with project architecture

Reviewers should evaluate code against:

1. Project requirements
2. Project-specific rules
3. Global rules
4. Existing project conventions

Personal coding preferences should not be treated as requirements.

---

# 24. Agent Uncertainty

When an agent is uncertain about an important implementation decision:

1. Inspect more context.
2. Search the codebase.
3. Check project documentation.
4. Check existing patterns.
5. Ask the appropriate specialist agent when necessary.
6. Escalate to Architect for architectural decisions.

Do not invent project conventions.

---

# 25. Final Verification

Before reporting completion, the implementing agent should verify:

* Requested functionality works
* Relevant tests pass
* Type checks pass when applicable
* Lint/build checks pass when applicable
* No unintended files changed
* No unrelated behavior changed
* Final diff matches the requested scope

---

# 26. Engineering Principles

Additional design reflexes for specific moments (fix-thrash, idempotent
operations, legacy-API deletion) are defined in `rules/principles.md`. Apply
each only at its trigger.

---

# Global Rule

Write code that is:

> Correct before clever.
> Simple before abstract.
> Reused before duplicated.
> Explicit before implicit.
> Minimal before expansive.
> Verified before reported as complete.
