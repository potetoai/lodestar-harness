# Project Context

## 1. Project Overview

### Project Name

[Project name]

### Purpose

[What this project does]

### Current Status

[New project / Active development / Maintenance / Refactoring]

### Main Goals

* [Goal 1]
* [Goal 2]
* [Goal 3]

### Owner Language

The language the agent uses to talk to the owner (ISO 639-1 code: `en`,
`vi`, `ja`...). Missing means English. Everything written to files, commits
and PRs stays in English (lodestar-harness `rules/documentation.md`, section 5).

```yaml
owner_language: en
```

---

## 2. Technology Stack

### Frontend

* Framework:
* Language:
* Build tool:
* UI library:
* State management:
* Styling:
* Testing:

### Backend

* Framework:
* Language:
* Database:
* ORM:
* API:
* Authentication:
* Testing:

### Infrastructure

* Hosting:
* Deployment:
* CI/CD:
* Storage:
* External services:

---

## 3. Repository Structure

```text

project/

├── front-end/

├── back-end/

├── .ai/

└── ...

```

### Frontend Structure

[Describe important folders and responsibilities]

### Backend Structure

[Describe important folders and responsibilities]

### Shared / Other

[Describe shared modules, packages, assets, etc.]

---

## 4. Current Architecture

### Overall Architecture

[Describe the current architecture]

### Frontend Architecture

[Describe current frontend architecture]

### Backend Architecture

[Describe current backend architecture]

### Data Flow

[Describe important data flows]

### Important Boundaries

[Describe boundaries between modules/layers]

### Architecture Decisions

[List important existing architecture decisions]

---

## 5. Coding Conventions

### Naming

[Project-specific naming conventions]

### Components

[Component conventions]

### Functions

[Function/method conventions]

### State Management

[State management conventions]

### API

[API conventions]

### Error Handling

[Error handling conventions]

### Other

[Other project-specific conventions]

Global coding rules are defined in:

`<lodestar-home>\rules\coding.md`

---

## 6. Testing

### Unit Tests

[Test framework and command]

### Integration Tests

[Test framework and command]

### E2E Tests

[Test framework and command]

### Full Test

[Full test command]

### Lint

[Lint command]

### Type Check

[Type-check command]

### Build

[Build command]

### Test Requirements

[Project-specific testing requirements]

Global testing rules are defined in:

`<lodestar-home>\rules\testing.md`

---

## 7. Development Commands

### Install

```text

[command]

```

### Development

```text

[command]

```

### Build

```text

[command]

```

### Test

```text

[command]

```

### Lint

```text

[command]

```

### Type Check

```text

[command]

```

### Deploy / Release

```text

[command]

```

### Rollback

```text

[command]

```

### Other

```text

[command]

```

---

## 8. Design System

### UI Framework

[Framework/library]

### Design System

[Existing design system]

### Component Library

[Component library]

### Design Tokens

[Location or description]

### UX Conventions

[Important UX conventions]

### Accessibility

[Accessibility requirements]

### Responsive Behavior

[Responsive requirements]

---

## 9. Security & Constraints

### Security Requirements

[Security requirements]

### Authentication

[Authentication requirements]

### Authorization

[Authorization requirements]

### Sensitive Data

[Types of sensitive data]

### Sensitive Paths

Files where a mistake touches money, access, personal data, or deletes data.
Changes here need tests and a higher verification level. The list may be
empty only with a reason. `doctor.sh` looks for the `sensitive_paths:` line.

```yaml
sensitive_paths:
  - [path/or/glob]
```

### External Services

[External services and constraints]

### Environment Restrictions

[Environment-specific restrictions]

### Compliance

[Relevant compliance requirements]

---

## 10. Git & Collaboration

### Main Branch

[main/master/etc.]

### Branch Convention

[Branch naming]

### Commit Convention

[Commit convention]

### Pull Request Requirements

[PR requirements]

### Worktree Usage

[Worktree conventions]

Global Git rules are defined in:

`<lodestar-home>\rules\git.md`

---

## 11. Agent Constraints

Agents working on this project must:

* Read this file before making significant changes.
* Inspect existing code before introducing new architecture.
* Follow global rules in `Lodestar-harness/rules/` (index: `rules/README.md`).
* Follow the selected workflow from `Lodestar-harness/workflows/`.
* Respect existing project conventions.
* Reuse existing components, utilities, and services where appropriate.
* Avoid unnecessary refactoring.
* Avoid introducing dependencies without justification.
* Run appropriate verification before reporting completion.
* Never assume a particular architecture pattern without inspecting the project.

---

## 12. Important Project Knowledge

### Known Technical Decisions

[List important decisions]

### Known Limitations

[List known limitations]

### Known Technical Debt

[List important technical debt]

### Known Bugs

[List known bugs that agents should be aware of]

### Important Dependencies

[List important dependencies]

---

## 13. Agent Guidance

### When Working on Frontend

[Project-specific frontend instructions]

### When Working on Backend

[Project-specific backend instructions]

### When Working on Database

[Database-specific instructions]

### When Working on UI/UX

[UI/UX-specific instructions]

### When Debugging

[Debugging-specific instructions]

### When Refactoring

[Refactoring-specific instructions]

---

## 14. Verification Requirements

Before considering a task complete:

1. Run the smallest appropriate verification.
2. Run broader verification when the change has a wider impact.
3. Review the final diff.
4. Confirm no unrelated files were changed.
5. Confirm existing behavior has not been unintentionally broken.
6. Report any remaining risks or failed checks.

---

## 15. Project-Specific Rules

[Add rules that apply only to this project.]

---

## 16. Project Context Maintenance

This file should be updated when:

* Architecture changes.
* Technology stack changes.
* Development commands change.
* Testing strategy changes.
* Important project conventions change.
* Security or deployment constraints change.
* Major technical decisions are made.

Do not update this file for temporary task-specific information.

---

## Source of Truth

### Global Workflow

`<lodestar-home>\`

### Global Rules

`<lodestar-home>\rules\`

### Global Agents

`<lodestar-home>\agents\`

### Global Workflows

`<lodestar-home>\workflows\`

### Global Skills

`<lodestar-home>\skills\`

### Project Context

`.ai/project.md`
