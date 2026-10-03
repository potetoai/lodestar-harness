# Enforcement Rules

Version: 1.0
Scope: All projects using Lodestar-harness

Text rules can be forgotten. Machine checks cannot. Every project therefore
exposes the same `make` commands, and hooks and CI call only those commands.
Tooling lives in `enforcement/` (start with `enforcement/README.md`).

## 1. Command contract

Every project has a `Makefile` with these targets. Names are fixed; recipes
belong to the project.

| Target | Meaning | Called by | Level |
|---|---|---|---|
| `make setup` | Install dependencies and tools | CI, new developers | Required |
| `make lint` | Linter and custom rules, whole project | `verify` | Required |
| `make test` | Unit and smoke tests | `verify` | Required |
| `make verify` | **Fast** checks (target under ~3 minutes) | Stop hook | Required |
| `make lint-file FILE=...` | Format, then lint, one file, for the edit hook | PostToolUse hook | Recommended |
| `make format-check` | Check formatting, change nothing | `verify` | Recommended |
| `make typecheck` | Type check, where the language has one | `verify` | Recommended |
| `make verify-full` | `verify` plus integration/E2E | CI | Recommended |
| `make test-mutation FILES=...` | Mutation testing on the given files; prints the score and surviving mutants | CI (`ci-checks.sh`) | Recommended |

`make setup` installs into the project only (`.venv/`, `node_modules/`),
never into the system Python or global npm, and must work on a clean machine
such as CI.

`verify` stays fast so the Stop hook never stalls a session. Slow tests go in
`verify-full`, which CI enforces.

## 2. Three layers

1. `CLAUDE.md` explains the rules.
2. Hooks make the agent fix problems at once: lint after each edit, and
   `make verify` before the agent may finish.
3. CI is the final gate: `make verify-full`, secret scan, readiness check.

Hooks and CI verify. They never dispatch work; orchestration stays in the agent runtime
(Claude Code, or Orca when present).

## 3. Project Readiness Standard

A project is ready when `bash .claude/hooks/doctor.sh` passes. Required
items fail the check; recommended items only warn. `workflows/onboarding.md`
gets a project there. Tier B items that a script cannot judge (linter proven
by a canary, a real smoke test, architecture, enforced invariants) are
checked by the onboarding report and review.

| # | Item | Level |
|---|---|---|
| T1–T3 | `make`, `jq` installed; project is a git repository | Required |
| A1 | `CLAUDE.md`: short map, no `[placeholder]` lines | Required |
| A2 | `.ai/project.md` filled in, no `[placeholder]` lines | Required |
| A3 | `Makefile` has `setup`, `lint`, `test`, `verify` | Required |
| A4 | `.claude/settings.json` registers the lint, verify and test-lock hooks; all hook scripts present | Required |
| A5 | `.github/workflows/ci.yml` | Required |
| A6 | `.gitignore`; no committed `.env`; `.env.example` when `.env` is used | Required |
| A7 | CI runs a secret scan (gitleaks) | Required |
| A7b | CI runs the PR checks (`ci-checks.sh`, section 6) | Required |
| A8 | `.ai/invariants.md`, `feedback-log.md`, `tech-debt.md`, `plans/{active,completed}/` | Required |
| A9 | `.ai/enforcement.json` records the template version | Required |
| B5 | `sensitive_paths:` declared in `.ai/project.md` (may be empty, with a reason) | Required |
| B6 | `.ai/invariants.md` lists at least one invariant | Required |
| A10 | `format-check`, `lint-file`, `verify-full` targets | Recommended |
| A11 | `CLAUDE.md` under 200 lines; detail moves to `.claude/rules/` (scoped with `paths:`) or docs | Recommended |
| A12 | Stack tools installed (`.venv` / `node_modules`); else run `make setup` | Recommended |
| C1 | `main` requires a PR and passing checks (set by hand on GitHub) | Recommended |
| D1 | Maintenance done in the last 14 days (`.ai/last-maintenance`) | Recommended |
| D2 | No repeated mistake in `.ai/feedback-log.md` without a machine rule | Recommended |

## 4. File ownership

- **[managed]** files start with *"Managed by lodestar-harness"*. Change them in
  lodestar-harness, then run `bootstrap.sh <dir> --stack <s> --upgrade`. Never
  edit them in a project.
- **[project]** files belong to the project. Upgrades never overwrite them.

## 5. Emergency exit

A human may start Claude Code with `LODESTAR_SKIP_HOOKS=1` to switch the hooks off
for one session. An agent must never set it. CI still enforces everything.

## 6. Checks that scale with risk

| Check | Where | Rule |
|---|---|---|
| Sensitive paths need tests | CI (`ci-checks.sh`) | A PR that changes a file in `sensitive_paths` must change a test, or carry a commit trailer `No-Test-Reason: <reason>` |
| Lint suppressions need a reason | Edit hook + CI | A new `# noqa`, `eslint-disable`, `@ts-ignore`, `type: ignore`… needs ` -- <reason>` on the same line. CI lists every new suppression for the reviewer |
| Installs stay in the project | PreToolUse hook (`guard-install.sh`) | `pip install` outside `.venv` and `npm install -g` are blocked; `make setup` and the venv's python are the way to install |
| Main changes only through a PR | PreToolUse hook (`guard-install.sh`) | The agent cannot `git push` to `main`, `master` or the remote's default branch, or skip git hooks (`--no-verify`, `commit -n`). Covers repos where GitHub cannot lock `main` (private repo on GitHub Free: doctor C1 says so) |
| Merge only on green CI | PreToolUse hook (`guard-install.sh`) | Every `gh pr merge` must run behind the CI wait's own exit code: `if gh pr checks <n> --watch; then gh pr merge <n>; fi` (PowerShell: `gh pr checks <n> --watch; if ($LASTEXITCODE -eq 0) { ... }`). `gh pr view && gh pr merge` and `gh pr checks \| tail && gh pr merge` are blocked: both exit 0 on a red CI |
| Owner approval | UserPromptSubmit hook | The owner replying with a message that starts with the approval word, "duyệt" or "approve" (plus the plan's name when several plans wait) records the plan's criteria hash in `.ai/approvals.log`; the agent cannot edit that file; changed criteria need a new approval; a plan with an empty `## Criteria review` (critic, `agents/critic.md`) is not recorded |
| Tests-first gate | PreToolUse hook + CI | Editing a non-test file in `sensitive_paths` needs owner-approved criteria and locked tests (or `No-Test-Reason:` in the plan); CI needs the approved plan in the PR and prints an English summary of the criteria for the owner |
| Mutation testing | CI (`ci-checks.sh`), report only, on request | Only with the PR label `test-mutation`: `make test-mutation` runs on the PR's changed files in `sensitive_paths`; the score and surviving mutants go to the PR summary; never fails the PR (`rules/testing.md`) |
| Locked tests | PreToolUse + Stop hooks + CI | Files in `.ai/test-lock` (tests-first mode) cannot be edited by the agent; CI fails if a later commit changes them |

Tests-first mode and the levels-to-commands map: `rules/testing.md`.

## 7. Turning an invariant into a machine rule

An invariant in `.ai/invariants.md` is only a wish until a machine checks it.
Try these in order:

1. **A built-in linter rule** (for example ruff `TID251` banned imports,
   ESLint `no-restricted-imports`). Configure it; do not write code.
2. **A custom check script** in `<project>/scripts/checks/`, called by `make lint`.
3. **A test**, when the rule is about behavior, not code shape (for example
   "every payment writes an audit log").

Every rule:

- **Says how to fix it.** Error format:
  `[INV-01] Float used for money at src/pay/x.ts:12. Fix: use Decimal. See .ai/invariants.md#inv-01`
- **Is proven to catch the violation**: a fixture in `tests/lint-fixtures/`
  (or a canary run recorded in the onboarding report) that the rule rejects.
- **Is recorded**: update the "Enforced by" and "Status" columns of
  `.ai/invariants.md`.

## 8. Learning from mistakes

- When the owner corrects an agent mistake, the agent adds a row to
  `.ai/feedback-log.md` right away: date, a short tag for the kind of mistake
  (reuse existing tags), what went wrong in its own words, the related rule
  or invariant. The owner never has to write it.
- **Hook:** `feedback-check.sh` (Stop) reads the owner's last message. If it
  looks like a correction ("sai", "nhầm", "làm lại", "wrong"…), it holds the
  agent once and asks it to judge and log. The hook stores nothing; the log
  holds only the agent's one-line summary, never the owner's words.
- **`lodestar-` tag:** a mistake caused by Lodestar-harness itself (missing
  workflow step, wrong template or hook) gets a tag starting with `lodestar-`
  (`orca-` before 2.0.0), status `reported`. It is fixed in lodestar-harness,
  so `doctor.sh` (D2) ignores it. When the owner asks to review the mistake
  logs of the projects, run
  `grep -HE '\| (lodestar|orca)-' <project>/.ai/feedback-log.md` for each
  project and fix the causes here.
- **Sweep:** maintenance looks through git and PR history for mistakes the hook
  missed (fix commits on fresh code, reverts, PRs with requested changes).
- **Second time = machine rule.** When a tag appears a second time, the
  mistake becomes a lint rule or a test (section 7), and its rows become
  `enforced`. `doctor.sh` warns (D2) while a repeated tag is not enforced.
- Maintenance (`workflows/maintenance.md`) runs every 14 days and picks these up;
  `doctor.sh` warns (D1) when it is overdue.
- Principles every project keeps: `rules/golden-principles.md`.

## 9. Session length

- Every turn re-reads the whole context, so long sessions cost most of the
  tokens (measured over real sessions with a usage report).
- **Hook:** `context-nudge.sh` (global, PostToolUse) reads the session's last
  context size. Past 200k tokens (`LODESTAR_NUDGE_AT` changes it) it tells the
  agent once: finish the current step, overwrite `.ai/handoff.md`, ask the owner
  for `/clear`. It repeats at every further 100k. It never blocks a tool.
