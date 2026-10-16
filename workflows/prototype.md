# Prototype Workflow

## Purpose

Answer "what do I want?" fast, before deciding. A prototype is a sketch: it
is thrown away, never shipped. What survives is what was learned.

## When

- The owner wants to see or try an idea before choosing.
- Requirements are still unclear after one intake question.

Never for a fix, a data change, or anything that must ship. Those take a
normal route; when unsure, do not prototype.

## Where it lives

A `proto/<name>` branch in its own git worktree of the project, made from
main: real project code to start from, hooks stay on. Never in the owner's
main checkout, and never on a branch that already holds real work.

    git worktree add ../<project>-proto-<name> -b proto/<name> origin/main

Machine guarantees (`enforcement/`, tested in `enforcement/test.sh`):

- `guard-install.sh` blocks pushing or renaming a `proto/*` branch, and any
  push run in its worktree, so it cannot reach a PR or main.
- `verify-before-stop.sh` does not run `make verify` on `proto/*`: tests and
  lint are not required in a sketch.

A renamed branch or a script can get around both: the rules below still
hold, and CI stays the gate.

## Process

1. Set a time box with the owner (default: one session) and write down the
   question the prototype must answer.
2. Create the worktree and branch above.
3. Build the least that answers the question. No review, no tests required.
4. Show a demo: a screenshot, or the exact command the owner runs to try it.
5. Stop every server, browser and watcher you started (G10,
   `rules/golden-principles.md`).
6. Write the findings: what the owner liked, rejected and decided, in plain
   words. Each becomes an acceptance criterion of the real task.
7. Delete the worktree and the branch:
   `git worktree remove ../<project>-proto-<name>` then
   `git branch -D proto/<name>`.

## Agent Model

One agent. No reviewer, tester or critic: nothing here ships.

## Rules

- Prototype code is never merged, pushed, or copied into the real change.
  The real change is a new task (BUILD_REVIEW or higher) that starts from
  the findings and is built and tested from scratch.
- Renaming a `proto/*` branch to ship it is the same as copying it: not allowed.
- Do not change the owner's main checkout, shared data, or anything outside
  the worktree. A prototype that needs real data only reads it.
- When the time box ends, stop and show what you have; do not extend it
  without the owner.

## Completion Criteria

The task is complete only when:

- the owner has seen the demo
- the findings are written down where the real task will read them (its plan,
  or the reply that starts it)
- background processes are stopped
- the worktree and the `proto/*` branch are deleted
