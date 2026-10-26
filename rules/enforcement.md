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
not run it again. `make verify` records its own pass (its last line runs
`verify-before-stop.sh --record-pass`, top-level make only), so when the agent
just ran it, the Stop hook does not run it a second time (doctor A10b). The
state is the working files only, so a commit after the run does not count as
a change.

After `verify` passes, the Stop hook also holds once per HEAD while the
current branch has commits on no remote branch: push the own branch (always
allowed, no need to ask), or on the default branch move the commits to a
feature branch. Local refs only, no network; skipped with no remote, a
detached HEAD or a `proto/*` branch.

It also holds once per plan and criteria while an active plan has a filled
`## Criteria review`, is not approved, and has no `- Reviewed criteria:` line
with the hash of its criteria as they are now: the agent adds the line (or
re-runs the critic) before it asks the owner for the approval word, so the
owner types it once.

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
| A10b | `verify` ends with `verify-before-stop.sh --record-pass` (top-level make only), so a passing run by the agent is not repeated by the Stop hook | Recommended |
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
| Sensitive paths need tests | CI (`ci-checks.sh`) | A PR that changes a file in `sensitive_paths` must change a test, or carry a commit trailer `No-Test-Reason: <reason>`. The list is the merge base's `sensitive_paths` plus the PR's, so dropping a pattern does not skip its check |
| Lint suppressions need a reason | Edit hook + CI | A new `# noqa`, `eslint-disable`, `@ts-ignore`, `type: ignore`… needs ` -- <reason>` on the same line. CI lists every new suppression for the reviewer |
| Installs stay in the project | PreToolUse hook (`guard-install.sh`) | `pip install` outside `.venv` and `npm install -g` are blocked; `make setup` and the venv's python are the way to install |
| Main changes only through a PR | git pre-push hook (`pre-push.sh`, installed by `bootstrap.sh`; doctor A4d) + PreToolUse hook (`guard-install.sh`) | No push creates, updates or deletes `main`, `master` or the remote's default branch: git names the refs it pushes, so no command text is read. It applies to every push from the checkout; the owner can push by hand with `--no-verify`. The agent cannot skip git hooks (`--no-verify`, `commit -n`) or change `core.hooksPath` (the guard). Git does not clone hooks: a fresh clone fails doctor A4d until `bootstrap.sh` runs again. Covers repos where GitHub cannot lock `main` (private repo on GitHub Free: doctor C1 says so). Known limits: the remote's default branch is known only when `origin/HEAD` exists (a clone); the hook runs the branch's own `pre-push.sh`; turning hooks off on purpose (`--config-env`, `GIT_CONFIG_*` variables, deleting the hook) is not caught; with `core.hooksPath` set, bootstrap only says which line to add |
| Merge only on green CI | Merge script (`merge-pr.sh`) + PreToolUse hook (`guard-install.sh`) | The agent merges only with `bash .claude/hooks/merge-pr.sh <n>` (options `--squash`, `--rebase`, `--delete-branch`); the guard blocks every other merge command (`gh pr merge` in any spelling, `gh api` REST PUT or GraphQL). The script decides from state: the PR is open and in this repo (no `GH_REPO`), its branch has no local commit never pushed (it would be left out), the owner approved it when owner-only (below), CI is green (`gh pr checks --watch` exits 0), and the head is still the one checked; it merges with `--match-head-commit <that head>`, so a later push is refused. It takes as long as CI: run it with a long timeout or in the background |
| Owner-only merge | Merge script (`merge-pr.sh`) + UserPromptSubmit hook (`approval-record.sh`) | The agent may merge its own PR (`rules/git.md`, merge policy), but a PR that changes a file in `sensitive_paths`, a locked test, or a safety file (`.claude/` except `.claude/docs/`, `.codex/`, `.github/`, `enforcement/`, `.ai/project.md`, `.ai/enforcement.json`, `.ai/test-lock`) is refused until the owner types "duyệt merge PR <n>" (or "approve merge PR <n>"); that records the PR's head commit in `.ai/approvals.log`, and the script merges only that head (`--match-head-commit`), so a later push needs a new approval. A locked test is a file covered by a line of `.ai/test-lock` on the PR's target branch, read from GitHub at merge time at the branch's tip and at the PR's base (any case; a line without `*`, `?` or `[` covers that file and the folder of that name); a file the PR adds is not locked. A change to `.ai/test-lock` that only adds lines is not owner-only (the edit hooks allow one only while an active plan is approved); removing or changing a line, deleting or renaming the lock, or a lock change gh shows no diff for, is. Agents, skills, commands and settings under `.claude/` can run commands or change permissions, so only `.claude/docs/` is free. Renamed files count by their old path too; a file gh gives no change type for counts as changed. Also refused: a PR gh cannot read, and a lock gh cannot read (other than HTTP 404, no lock). Known limits: security code outside `sensitive_paths` is not caught (maintenance reviews the list); a merge hidden on purpose (a `gh pr merge` inside a script file the agent wrote, a gh alias, `curl` to the API) is not seen by the guard; a PR that is not owner-only can still change test setup (`conftest.py`, test config, a Makefile test target) that weakens locked tests without editing them, so CI and the review stay the backstop |
| Prototype stays local | git pre-push hook (`pre-push.sh`) + PreToolUse + Stop hooks (`guard-install.sh`, `verify-before-stop.sh`) | No push of a `proto/*` branch under any name, to a `proto/*` name (so `--all`/`--mirror` while one exists too), or while one is checked out, also from its worktree (pre-push, from the refs git names); the guard blocks renaming a branch to or from `proto/*`; `make verify` is not required there. The code is thrown away (`workflows/prototype.md`). Starting a `proto/*` branch on top of real work cannot be told apart from a new prototype: CI stays the gate |
| Tests-First commit carries the approval | CI (`ci-checks.sh`) | A `Tests-First:` commit without a changed plan with owner-approved criteria, with `.ai/approvals.log` gitignored, or with the plan or the log left out, fails the PR, and `merge-pr.sh` merges only on green CI. (Until 2026-10 the guard also blocked such a commit locally; removed by owner decision, `plans/active/harness-health.md`.) |
| Owner approval | UserPromptSubmit hook | The owner replying with a message that starts with the approval word, "duyệt" or "approve" (plus the plan's name when several plans wait) records the plan's criteria hash in `.ai/approvals.log`; the agent cannot edit that file; changed criteria need a new approval; a plan with an empty `## Criteria review` (critic, `agents/critic.md`), or whose review has no `- Reviewed criteria:` line with the hash of the current criteria, is not recorded |
| Tests-first gate | PreToolUse hook + CI | Editing a non-test file in `sensitive_paths` needs owner-approved criteria and locked tests (or `No-Test-Reason:` in the plan); CI needs the approved plan in the PR, fails a commit that changes sensitive code before the approved plan and locked tests are committed (this also catches edits the hook cannot see, such as a Bash script; a `No-Test-Reason:` trailer on that commit, or in a plan changed on the branch, excuses it), and prints an English summary of the criteria for the owner |
| Route line in the PR | CI (`ci-checks.sh`) | The PR text has the line `Lodestar route: <WORKFLOW> risk=<level>` (`router/ROUTER.md`; the last one counts). SIMPLE and PROTOTYPE fail with risk high or critical; SIMPLE also fails with 3 or more changed files outside `.ai/`. BUILD_REVIEW, INDEPENDENT_COMPARE and COMPLEX need a line `Lodestar review: <verdict>, <who>, <commit>`. Read live from GitHub, so after `gh pr edit` a rerun of the job sees the fix. MAINTENANCE and ONBOARDING may change Lodestar's own files (`.claude/`, `.codex/`, `.github/`) without the review line, since those are safety files the owner approves with "duyệt merge PR <n>" (owner-only merge, above); 3 or more other files need the review line, as do 3 or more files for PROTOTYPE. PRs opened by bots are skipped; a PR the owner opens by hand needs the line too. The line is the agent's own word: it makes a skipped review visible, it does not prove one |
| Mutation testing | CI (`ci-checks.sh`), report only, on request | Only with the PR label `test-mutation`: `make test-mutation` runs on the PR's changed files in `sensitive_paths`; the score and surviving mutants go to the PR summary; never fails the PR (`rules/testing.md`) |
| Push before stopping | Stop hook (`verify-before-stop.sh`) | Once per HEAD, the agent cannot end its turn while the current branch has commits that exist on no remote branch; it pushes its own branch (or, on the default branch, moves the commits to a feature branch). Uncommitted edits are not checked: the agent may stop to wait for the owner |
| Review line before asking | Stop hook (`verify-before-stop.sh`) | Once per plan and criteria, the agent cannot end its turn while an active, unapproved plan has a filled `## Criteria review` without a `- Reviewed criteria:` line for its current criteria; the approval hook would refuse the owner's approval word |
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
- **Daily GitHub sweep:** in lodestar-harness, the first session of the day
  also runs `gh-sweep.sh` (global hook folder). It reads each listed project's
  GitHub and shows what is new since the last sweep: PRs merged with no route
  line or (BUILD_REVIEW and up) no review line, PRs closed unmerged, open PRs
  with failing checks, a failed CI run on main. Read only; no tokens spent.
  Each project's last good sweep is kept in `~/.lodestar/gh-sweep.txt`; a
  project whose sweep fails (offline) keeps its old time, and the next
  session retries it. Find the cause: a Lodestar fault is fixed here, a project
  slip goes to that project's session as a prompt for the owner.
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
- The same hook marks the end of a task: when the agent merges a PR (`gh pr
  merge`), sees the owner's merge (`gh pr view` printing MERGED), or moves a
  plan to `completed`, it tells the agent once per PR or plan to write the
  handoff and offer the owner `/clear`. Only a command counts, not quoted text;
  subagents are left out.
