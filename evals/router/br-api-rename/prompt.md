---
tags: [router]
runs: 1
max_turns: 20
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

You are the coding agent in a software project. Take these facts as given; the project files are not in this directory, so do not search for them:

- A TypeScript web app: React frontend in `web/`, Node API in `api/`, Postgres database with migrations in `api/migrations/`.
- The project is onboarded: `.ai/project.md` exists and `bash .claude/hooks/doctor.sh` passes.
- `sensitive_paths` in `.ai/project.md`: `api/billing/`, `api/auth/`.
- `.ai/invariants.md` has one high-risk invariant: "a ledger entry is written exactly once per payment".

Workflows: SIMPLE, BUILD_REVIEW, INDEPENDENT_COMPARE, COMPLEX, PROTOTYPE. Risk levels: low, medium, high, critical. When you route a task, write the route as one line: `Lodestar route: <WORKFLOW> risk=<level>`.

The owner's message:

> Tiny one-line change: in the `/api/users` response, rename the JSON field `user_name` to `username`.
