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

The Stop hook holds a failed `verify` once per state: when neither the files
nor the failure changed since the last hold, the stop ends (for example while
the agent waits for a tests-first tester). Any change holds again. CI stays
the gate.

A pass is remembered the same way: when the files did not change since
`verify` last passed (the agent only answered a question), the Stop hook does
not run it again.

After `verify` passes, the Stop hook also holds once per HEAD while the
current branch has commits on no remote branch: push the own branch (always
allowed, no need to ask), or on the default branch move the commits to a
feature branch. Local refs only, no network; skipped with no remote, a
detached HEAD or a `proto/*` branch.

## 2. Three layers

1. `AGENTS.md` explains the rules (Claude and Codex both read it).
2. Hooks make the agent fix problems at once: lint after each edit, and
   `make verify` before the agent may finish. Claude and Codex run the same
   hook scripts (Codex through `.codex/hooks.json` and an adapter).
3. CI is the final gate: `make verify-full`, secret scan, readiness check.

Hooks and CI verify. They never dispatch work; orchestration stays in the agent runtime
(Claude Code, or Orca when present).

## 3. Project Readiness Standard

This standard applies to consuming projects. The Lodestar source repository
is already exempt from their onboarding and installed doctor: its own
`AGENTS.md`/`README.md` provide context, and its self-tests and link checks
verify changes. The global readiness hook preserves its handoff reminder
before applying this source exemption. Review and approval still apply.

A project is ready when `bash .claude/hooks/doctor.sh` passes. Required
items fail the check; recommended items only warn. `workflows/onboarding.md`
gets a project there. Tier B items that a script cannot judge (linter proven
by a canary, a real smoke test, architecture, enforced invariants) are
checked by the onboarding report and review.

| # | Item | Level |
|---|---|---|
| T1–T3 | `make`, `jq` installed; project is a git repository | Required |
| A1 | `AGENTS.md`: short map, no `[placeholder]` lines | Required |
| A1b | No `CLAUDE.md` with its own text (Claude then skips `AGENTS.md`); only the line `@AGENTS.md` is allowed | Required |
| A2 | `.ai/project.md` filled in, no `[placeholder]` lines | Required |
| A3 | `Makefile` has `setup`, `lint`, `test`, `verify` | Required |
| A4 | `.claude/settings.json` registers every Lodestar hook on its event and tool matcher; all hook scripts present | Required |
| A4b | `.codex/hooks.json` registers the same hooks for Codex on their event and matcher, through `.claude/hooks/codex-hook.sh` | Required |
| A4c | Codex trusts the project and its current hooks (`/hooks` in Codex; it skips untrusted hooks); asked from Codex, not read from `config.toml`; not run with `--quiet` | Recommended |
| A5 | `.github/workflows/ci.yml` | Required |
| A6 | `.gitignore`; no committed `.env`; `.env.example` when `.env` is used | Required |
| A7 | CI runs a secret scan (gitleaks) | Required |
| A7b | CI runs the PR checks (`ci-checks.sh`, section 6) | Required |
| A8 | `.ai/invariants.md`, `feedback-log.md`, `tech-debt.md`, `plans/{active,completed}/` | Required |
| A9 | `.ai/enforcement.json` records the template version | Required |
| B5 | `sensitive_paths:` declared in `.ai/project.md` (may be empty, with a reason) | Required |
| B6 | `.ai/invariants.md` lists at least one invariant | Required |
| A10 | `format-check`, `lint-file`, `verify-full` targets | Recommended |
| A11 | `AGENTS.md` under 200 lines; detail moves to `.claude/rules/` (scoped with `paths:`) or docs | Recommended |
| A12 | Stack tools installed (`.venv` / `node_modules`); else run `make setup` | Recommended |
| C1 | `main` requires a PR and passing checks (set by hand on GitHub) | Recommended |
| D1 | Maintenance done in the last 14 days (`.ai/last-maintenance`) | Recommended |
| D2 | No repeated mistake in `.ai/feedback-log.md` without a machine rule | Recommended |

Installed configuration and runtime activation are separate checks. A4b
checks required events and matchers; a historical trust entry is not proof
that all current Codex hooks are enabled and trusted. A4c asks Codex
(`hooks/list`) and names each required hook that is missing, disabled,
untrusted or modified; it reports unverified when Codex gives no answer. Review `/hooks` in the
actual Codex home and verify lifecycle execution before claiming activation.
See [runtime parity](../enforcement/runtime-parity.md) for the contract.

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
| Merge only on green CI | PreToolUse hook (`guard-install.sh`) | Every `gh pr merge` must run behind the CI wait's own exit code: `if gh pr checks <n> --watch; then gh pr merge <n>; fi` (PowerShell: `gh pr checks <n> --watch; if ($LASTEXITCODE -eq 0) { ... }`). `gh pr view && gh pr merge` and `gh pr checks \| tail && gh pr merge` are blocked: both exit 0 on a red CI. A merge is also blocked while the PR's branch has local commits never pushed (they would be left out) |
| Owner-only merge | PreToolUse hook (`guard-install.sh`) + UserPromptSubmit hook (`approval-record.sh`) | The agent may merge its own PR (`rules/git.md`, merge policy), but a PR that changes a file in `sensitive_paths`, a test in `.ai/test-lock`, or a safety file (`.claude/`, `.codex/`, `.github/`, `enforcement/`, `.ai/project.md`, `.ai/enforcement.json`, `.ai/test-lock`) is blocked until the owner types "duyệt merge PR <n>" (or "approve merge PR <n>"); that records the PR's head commit in `.ai/approvals.log`, and the merge must then pin it with `--match-head-commit <head>` (no `--auto`), so a later push needs a new approval. Renamed files count by their old path too. Also blocked: a PR gh cannot read, another repo (`-R`, `GH_REPO`), a `git push` in the same command as the merge, and merges through `gh api` (REST PUT or GraphQL). Known limits: security code outside `sensitive_paths` is not caught (maintenance reviews the list), and a merge hidden on purpose (a script without a known extension, or written and run in one command) is not seen; running a `.sh`, `.ps1`, `.py` (and similar) script that holds a merge is blocked |
| Prototype stays local | PreToolUse + Stop hooks (`guard-install.sh`, `verify-before-stop.sh`) | A `proto/*` branch cannot be pushed or renamed to or from; nothing can be pushed from its checkout or worktree, nor `--all`/`--mirror` while one exists; `make verify` is not required there. The code is thrown away (`workflows/prototype.md`). Starting a `proto/*` branch on top of real work cannot be told apart from a new prototype: CI stays the gate |
| Tests-First commit carries the approval | PreToolUse hook (`guard-install.sh`) | A `git commit` whose message starts with `Tests-First:` is blocked when no changed plan has owner-approved criteria, when `.ai/approvals.log` is gitignored, or when the plan or the log would be left out of the commit. CI checks the same later; this catches it before the push |
| Owner approval | UserPromptSubmit hook | The owner replying with a message that starts with the approval word, "duyệt" or "approve" (plus the plan's name when several plans wait) records the plan's criteria hash in `.ai/approvals.log`; the agent cannot edit that file; changed criteria need a new approval; a plan with an empty `## Criteria review` (critic, `agents/critic.md`), or whose review has no `- Reviewed criteria:` line with the hash of the current criteria, is not recorded |
| Tests-first gate | PreToolUse hook + CI | Editing a non-test file in `sensitive_paths` needs owner-approved criteria and locked tests (or `No-Test-Reason:` in the plan); CI needs the approved plan in the PR and prints an English summary of the criteria for the owner |
| Mutation testing | CI (`ci-checks.sh`), report only, on request | Only with the PR label `test-mutation`: `make test-mutation` runs on the PR's changed files in `sensitive_paths`; the score and surviving mutants go to the PR summary; never fails the PR (`rules/testing.md`) |
| Push before stopping | Stop hook (`verify-before-stop.sh`) | Once per HEAD, the agent cannot end its turn while the current branch has commits that exist on no remote branch; it pushes its own branch (or, on the default branch, moves the commits to a feature branch). Uncommitted edits are not checked: the agent may stop to wait for the owner |
| Locked tests | PreToolUse + Stop hooks + CI | Files in `.ai/test-lock` (tests-first mode) cannot be edited by the agent; CI fails if a later commit changes them. The lock itself may only gain lines, while the plan is approved |

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
  so `doctor.sh` (D2) ignores it. The agent also logs one when it finds the
  fault itself (a hook blocks wrongly, doctor reports wrongly, a template
  contradicts itself), even if the owner said nothing. When the owner asks to
  review the mistake logs of the projects, run
  `grep -HE '\| (lodestar|orca)-' <project>/.ai/feedback-log.md` for each
  project and fix the causes here.
- **Bug inbox (this machine):** the global hook `check-readiness.sh` adds each
  project that has a feedback log to `~/.lodestar/projects.txt` and reminds
  its session to log Lodestar faults. In lodestar-harness, at session start,
  it lists `reported` `lodestar-`/`orca-` rows of those projects that are not
  in `~/.lodestar/seen.txt`. After fixing one (or deciding it is not a
  Lodestar bug), add its `project|date|tag` line to `seen.txt`.
- **Sweep:** maintenance looks through git and PR history for mistakes the hook
  missed (fix commits on fresh code, reverts, PRs with requested changes).
- **Second time = machine rule.** When a tag appears a second time, the
  mistake becomes a lint rule or a test (section 7), and its rows become
  `enforced`. `doctor.sh` warns (D2) while a repeated tag is not enforced.
  If no machine rule can catch it and the owner agrees, its rows become
  `accepted`; a new row of that tag warns again.
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
