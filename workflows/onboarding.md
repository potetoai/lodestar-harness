# Onboarding Workflow

## Purpose

Make a project ready before any feature work: install the machine checks
(tier A), then set up the project-specific parts (tier B) with the owner.
"Ready" means `bash .claude/hooks/doctor.sh` passes. Rules and the full
readiness list: `rules/enforcement.md`.

Onboarding has two paths: **A** for a new project, **B** for an existing
one. Both end in the same project layout, and after onboarding every project
follows the same process.

## When it runs

- The Router's intake gate finds no `.claude/hooks/doctor.sh`, or doctor fails.
- The owner asks to onboard a project.

It is the first task of every project, and it runs once. Feature work waits
until it is done, unless the owner explicitly says to skip. Then record the
skip in `.ai/tech-debt.md` with a due date.

## Agent Model

One agent does the onboarding. It talks to the owner directly. Do not
dispatch parallel workers: the interview and the setup depend on each other.

## Step 0: Choose the path

| Path | When | Main risk |
|---|---|---|
| **A: new project** | No source code yet (only README, LICENSE, `.gitignore`, docs) | Choosing the wrong foundation |
| **B: existing project** | Any source code exists | Breaking what already works |

If unsure, take **path B**: it reads first and protects what exists.

For both paths: work on a branch, never on `main`. Follow the project's own
branch and commit conventions if it has them (for example
`chore/lodestar-onboarding`). The project's own rules win over this workflow.

---

## Path A: new project

1. **Interview.** Ask the owner the interview questions below, one short
   question at a time. "I don't know yet" is a valid answer; record it as an
   open item.
2. **Choose the stack.** Propose a default from the table and let the owner
   confirm or change it. Only stacks in `enforcement/stacks/` are ready to
   use; another language first needs a new stack folder there.

   | Kind of project | Default |
   |---|---|
   | Command-line tool, script, data processing | `python` (SQLite if it stores data) |
   | Web app with a UI | `node-ts` for the UI; add `python` as a second part (`backend/`) only if it needs its own API |
   | Unsure | `python`, the simplest to start |

3. **Shared steps S1–S3** below. The owner must approve the draft of
   invariants and sensitive paths before you write them (S2).
4. **Confirm (S4).** Then start the first feature on its own branch.

## Path B: existing project

1. **Read first.** Derive everything you can from the code and docs:
   languages, frameworks, folder layout, lint/test tools, git hooks, CI,
   existing `CLAUDE.md` and `.ai/project.md`, branch and commit conventions.
2. **Snapshot "before".** Run the project's own checks (tests, check
   scripts, build, lint) and record the exact result, for example
   "185/185 checks pass". If there are no checks, record that the app builds
   and starts.
3. **List the conflicts** between the project's rules and the Lodestar standard
   (for example "no test framework", "no CI"). The owner decides each one.
   If they choose the standard, update the project's docs in the same PR so
   the old rule is gone.
4. **Interview** the owner, but **only** for what steps 1–3 did not answer.
5. **Present the change plan**: every file you will add or change, and why.
   Wait for the owner's approval before editing anything. After S1 installs
   the hooks, save the change list as the acceptance criteria of
   `.ai/plans/active/<date>-onboarding.md` with
   `No-Test-Reason: onboarding, behavior unchanged`, and ask the owner to
   reply with the approval word ("duyệt" or "approve") once more so the hook
   records it. Only then may the baseline
   fixes touch sensitive files.
6. **Shared steps S1–S3** below. Keep the tools the project already uses and
   wire them into the `make` targets. Then set the **baseline**:
   - Run the linter's auto-fix (`--fix`) and commit that separately.
   - Few problems left: fix them. Many left: suppress them with the linter's
     own mechanism (a baseline or suppressions file, or per-rule or per-file
     ignores; check what the current version supports). Add one
     `tech-debt.md` entry per suppressed group, with a due date.
   - **No-growth rule:** new code and edited files must be clean; the
     baseline only shrinks. Never mass-edit old code beyond `--fix`.
   - Keep the project's git hooks, CI and docs. Add to them; do not replace
     them.
7. **Snapshot "after".** Run the same checks as in step 2. The result must
   be **identical**. If anything differs, stop and find the cause before going
   on.
8. **Confirm (S4).** Put both snapshots in the report.

---

## Interview questions

First, in both paths, ask which language the owner wants to talk in, and use
it from then on. Record it as `owner_language:` in `.ai/project.md` (ISO
639-1 code; missing means English). Files, commits and PRs stay in English
(`rules/documentation.md`, section 5).

Then ask only what you cannot derive yourself.

1. What does the project do, and for whom? What kind is it (management,
   finance, content, internal tool…)?
2. Language, framework, where it runs or deploys?
3. What must **never** go wrong? (This becomes the invariants.)
4. Which parts touch money, access rights, personal data, or deleting data?
   (This becomes `sensitive_paths`.)
5. The intended architecture: main layers or modules, and which may depend
   on which?
6. External systems: payments, email, partner APIs, data sources?
7. How much testing is needed: unit only, integration, E2E, UI?
8. Who reviews pull requests: the owner, a reviewer agent, or both?

## Shared steps

### S1: Tier A: install the checks

Run from the project root:

```bash
# One language at the root:
bash <lodestar-harness>/enforcement/bootstrap.sh . --stack <node-ts|python>
# Several parts, one language each:
bash <lodestar-harness>/enforcement/bootstrap.sh . --stack python=backend --stack node-ts=frontend
```

`bootstrap.sh` never overwrites existing project files (`CLAUDE.md`,
`.ai/project.md`, `Makefile`, `.gitignore`). If the project already has them,
**merge** the missing parts by hand; do not replace the owner's content.

### S2: Tier B: project-specific setup

- **B1 Linter.** Keep an existing linter and wire it into `make lint` and
  `make lint-file`. Otherwise pick the common one for the language (check the
  current choice before installing; for example ESLint for JS/TS, Ruff for
  Python) and add its formatter. Turn on the rules that catch golden
  principles where the linter has them, for example ruff `S113` (HTTP call
  without a timeout, G11).
- **Canary.** Create a temporary file with an obvious violation, run
  `make lint`, and **confirm it fails**. Delete the file. If lint passes, the
  linter is not working; fix that before going on. Record the result in the
  report.
- **Installs stay in the project.** Never install into the system Python or
  global npm (`pip install` on the system interpreter, `npm install -g`).
  Tools go into `.venv/` or `node_modules/` through `make setup`. If the
  project relies on packages that exist only in the system Python (not on the
  public index), create the venv with them visible:
  `make setup VENV_ARGS=--system-site-packages` (or set it in the Makefile).
  A hook (`guard-install.sh`) blocks system-wide installs once S1 is done.
- **Clean-machine check.** CI starts from nothing, so before the first push
  check that every dependency installs from the public index: Python
  `python -m pip download --no-deps -d <temp dir> -r requirements.txt`,
  Node `npm ci` in a fresh clone. For a package that is not available,
  skip it when `CI` is set (tests must not need it) and record it in
  `tech-debt.md`. A red CI on the onboarding PR usually means this step was
  skipped.
- **B2 Tests.** Use the standard test framework for the language, with at
  least one real smoke test (the main module imports; the app starts).
  `make test` must run it. Existing test scripts are wrapped by the framework
  and moved over gradually (`tech-debt.md`).
- **B3/B4 Architecture.** Write the layers and allowed dependency directions
  in "Important Boundaries" of `.ai/project.md`. Add a structural test when
  the project is high-risk (for example dependency-cruiser for JS/TS,
  import-linter for Python; check current tools first).
- **Owner language.** Fill `owner_language:` in `.ai/project.md` from the
  first interview answer.
- **B5 Sensitive paths.** Fill `sensitive_paths:` in `.ai/project.md` from
  the answer to question 4 (path B: also from the code that writes or deletes
  data). An empty list needs a written reason.
- **B6/B7 Invariants.** Draft `.ai/invariants.md` rows from questions 3–4
  and **get the owner's approval**. Each high-risk invariant is enforced by a
  lint rule or a test, or gets a `tech-debt.md` entry with a due date.
- **Commands.** Make the `Makefile` recipes real. "Development Commands" in
  `.ai/project.md` **points to the make targets** instead of copying commands.
- **CLAUDE.md.** At most ~100 lines: what the project is, that it follows
  lodestar-harness, what to read (`.ai/project.md`, `.ai/invariants.md`), the
  absolute rules, and `make verify`.

### S3: Commit

Commit on the onboarding branch, in the project's commit style. Path B: the
auto-fix is its own commit.

### S4: Confirm and report

- `make verify` passes locally, and CI is green on the onboarding PR.
- `bash .claude/hooks/doctor.sh` prints "Ready".
- Ask the owner to do tier C by hand: protect `main` on GitHub (require a PR
  and the `CI` check), and add any secrets CI needs.
- Report briefly: the path taken, what was installed, which invariants are
  machine-enforced and which are still text, which debt was recorded, the
  canary result, open questions from the interview, and (path B) the
  before/after snapshots.
- Open a PR from the onboarding branch. The owner merges it.
- Ask the owner where maintenance runs every 14 days: on this machine (default)
  or in the cloud (`workflows/maintenance.md`, "When it runs", says when each
  fits). `bootstrap.sh` already started the clock in `.ai/last-maintenance`.

## Pitfalls seen in real onboardings

- **`.gitignore` hides the hooks.** A rule like `.claude/*` keeps
  `settings.json` and `hooks/` out of git. `bootstrap.sh` warns; add
  `!.claude/settings.json` and `!.claude/hooks/`.
- **Generated code** (database migrations, build output): exclude it from the
  linter; never auto-fix it.
- **Dependencies that cannot be installed** from the public index (found by
  the clean-machine check in S2): skip them when `CI` is set, record them in
  `tech-debt.md`, and keep the tests independent of them.
- **Tools installed into the system Python** "because python is not on
  PATH": use the full interpreter path to create `.venv` instead, then only
  the venv's python.
- **Secret-scan false positives:** fix the file, then add the finding's
  fingerprint to `.gitleaksignore` with the reason. Never ignore a real
  secret; rotate it.
- **Env files in subfolders** (`backend/.env`) need a `.env.example` next to
  them, with names only, no values.

## Rules

- Never overwrite the owner's existing docs or configs; merge.
- Never guess an invariant. If the owner does not know yet, record it as open.
- Never set `LODESTAR_SKIP_HOOKS`; only a human may.
- A linter that has not failed a canary does not count as installed.
- Path B: never finish while the "after" snapshot differs from "before".
