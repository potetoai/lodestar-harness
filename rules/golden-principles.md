# Golden Principles

Version: 1.0
Scope: All projects using Lodestar-harness

A short list that every project keeps. Each principle names the machine check
that enforces it; "maintenance scan" means `workflows/maintenance.md` looks for it
until a stronger check exists.

| # | Principle | Checked by |
|---|---|---|
| G1 | Never break an invariant in `.ai/invariants.md` | Its lint rule or test; CI |
| G2 | A change to sensitive code comes with a test | `ci-checks.sh` (CI) |
| G3 | Fix the code, do not silence the linter; a suppression states its reason. Never rewrite code only to slip past a check: if a check flags correct code, fix the check and say so in the PR | Edit hook + `ci-checks.sh`; review |
| G4 | No secrets in the repo; config comes from the environment | gitleaks (CI); doctor A6 |
| G5 | Validate data where it enters the system (API input, files, external data) | Tests for sensitive paths; review |
| G6 | Reuse what exists before writing a new helper; no copied code blocks | Review; maintenance scan |
| G7 | No dead code: unused imports, variables, functions | Linter (ruff `F401`/`F841`, ESLint `no-unused-vars`) |
| G8 | Keep files small enough to read: split a file past ~500 lines | Maintenance scan |
| G9 | Debt left on purpose is written down with a due date | Reviewer; CI lists new TODO/FIXME |
| G10 | Leave nothing running: stop dev servers, test browsers and watchers you started | Review; agent roles (builder, tester, qa) |
| G11 | Every network call has a timeout; in a job over many items, one failing or hanging item is skipped and never stops the rest, and is recorded as failed in the job's report the owner reads (a printed line alone does not count) | Linter where a rule exists (ruff `S113`); review |

When review or maintenance keeps finding the same violation of a principle marked
"review" or "maintenance scan", make it a machine check (`rules/enforcement.md`,
section 7).
