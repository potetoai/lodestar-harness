# CLAUDE.md

Short map for agents. Details live in the files it points to.

## What this project is

[One or two sentences: what the project does and for whom]

## How to work here

- Follow lodestar-harness: start with its `router/ROUTER.md`.
- Read `.ai/project.md` (context, architecture, sensitive paths) before
  significant changes.
- Read `.ai/invariants.md`. Never break an invariant.
- Talk to the owner in `owner_language` from `.ai/project.md` (missing means
  English). Write code, notes, plans, commits and PRs in English
  (lodestar-harness `rules/documentation.md`, section 5).

## Absolute rules

[Rules that must never be broken in this project, one per line]

## Checks

- `make verify` must pass before you say a task is done. A hook enforces it.
- `make lint-file FILE=<path>` formats and lints the file after every edit.
  Fix what it reports.
- Never rewrite code only to get past a lint rule or test. If a check flags
  correct code, fix the check and tell the owner in the PR.
- CI runs `make verify-full`, a secret scan, and the readiness check.

## Before you say done

Stop every background process you started (dev server, test browser, watcher) before you report the task done, and say in the report that you did.

## When the owner corrects you

Add a row to `.ai/feedback-log.md` right away (reuse the tag if the same kind
of mistake happened before). A tag seen twice becomes a lint rule or a test.
If the Lodestar system caused it (missing workflow step, wrong template or hook),
start the tag with `lodestar-` and tell the owner it needs a fix in lodestar-harness.
