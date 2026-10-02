# Global Rules Index

Version: 1.0
Scope: All projects using Lodestar-harness

Every agent must consult the relevant rules before significant implementation
(see `router/ORCA-INTEGRATION.md` section 3). This file is the canonical list.
Read the rules that apply to the task; do not assume a rule does not exist
because it was not linked from the task.

| File | Applies to | Summary |
|------|------------|---------|
| `coding.md` | all code work | Understand-before-change, minimal change, reuse-first, naming, error handling, type safety, scope discipline, final verification. |
| `architecture.md` | design / structure | Existing-project-first, pattern choice justification, dependency direction, separation of concerns, anti-overengineering, ADRs. |
| `testing.md` | verification | Proportional verification levels (static → E2E), bug-fix regression tests, edge/error paths, determinism, verification report. |
| `security.md` | security-sensitive tasks | Security-review gate, baseline checklist (validation, injection, authn/authz, secrets), never-simplify-away list, human approval. |
| `principles.md` | specific moments | Attack-the-premise (fix-thrash), make-operations-idempotent (retries), migrate-callers-then-delete-legacy-apis. Apply only at trigger. |
| `documentation.md` | completion | Update `.ai/project.md` and user-facing docs when structure/decisions/commands change; ADR for significant decisions; talk to the owner in `owner_language`, write files, commits and PRs in English. |
| `enforcement.md` | every project | `make` command contract (`setup`, `lint`, `test`, `verify`), hook + CI layers, Project Readiness Standard checked by `doctor.sh`, managed vs project files, risk-scaled checks, invariant → machine rule, learning from mistakes. |
| `golden-principles.md` | every project | Ten principles every project keeps, each with the check that enforces it; maintenance scans for the rest. |
| `git.md` | any git state change | Inspect-before-change, worktree isolation, commit/diff hygiene, no unauthorized destructive ops, human approval gates. |

Project-specific rules in `<project>/.ai/project.md` take precedence when they
conflict with a global rule.
