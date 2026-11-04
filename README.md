# Lodestar-harness

Entry point for Lodestar-harness, a policy harness for AI coding agents
(Claude Code first). Start here.

This repo defines the **intelligence and engineering policy**: which workflow,
which roles, which checks, and to what standard. It does not run orchestration
itself.

Claude Code alone is enough; an orchestrator such as Orca is optional.

> The agent runtime executes the work: Claude Code alone (subagents, git
> worktrees), or an orchestrator such as Orca ADE when installed.
> Lodestar-harness decides what should happen and to what standard.

---

## Quick Start

For a person setting it up:

1. **Set up the machine once** with the
   [setup guide](enforcement/setup-guide.md): install Git, Claude Code and
   the GitHub CLI, clone this repo, run `enforcement/setup-machine.sh`. The
   guide is written for Windows (Git Bash).
2. **Open Claude Code in your project** and ask for a task. In a project that
   is not ready yet, the agent first runs
   [onboarding](workflows/onboarding.md); after that, each task goes through
   the Router. The setup guide's step 5 walks through a first task.
3. **Approve when asked.** Some steps wait for you, such as merging a pull
   request that changes safety files. Start your own message with `approve`
   or `duyệt`, for example `approve merge PR 12`.

The setup guide is the single start. `enforcement/README.md` (manual install,
upgrade) and `workflows/onboarding.md` are reference.

Claude remains the default agent in Orca. When the owner selects Codex, it
follows the same Lodestar rules and checks; hook installation does not change
the default agent. Runtime coverage and activation are described in
[Runtime parity](enforcement/runtime-parity.md).

---

## Start Here

An agent operating this system reads, in order:

1. **`router/ROUTER.md`** — the Master Router. Analyzes the task, runs the intake
   gate, and selects the smallest reliable workflow, agent roles, capabilities,
   and verification level. The Router decides; it does not implement.
2. **`router/ORCA-INTEGRATION.md`** — how Router decisions are executed (task
   specs, dispatch, parallel waves, settlement, verification, failure
   handling). Written for Orca; the same contract applies to Claude Code
   subagents (see the note at its top).
3. **`<project>/.ai/project.md`** — the specific project's context. Read before
   significant implementation. Create it from the template for a new project.
4. The **rules**, **agent role**, **workflow**, and **capabilities** selected for
   the task (see the map below).

A worker dispatched for a task reads only its brief, the files the brief names
(its **agent role** in `agents/`, the **rules** that apply, the files to change),
and the files a finding needs. The Router reads the workflow and the project
context and puts what the worker needs into the brief.

---

## Directory Map

| Path | Purpose |
|------|---------|
| `router/ROUTER.md` | Master Router: task → workflow, roles, capabilities, verification. |
| `router/ORCA-INTEGRATION.md` | How Router decisions are executed: Orca Tasks/Dispatches/Workers, or Claude Code subagents. |
| `workflows/` | Execution strategies: `simple`, `build-review`, `independent-compare`, `complex`, `prototype` (a throwaway sketch); plus `onboarding`, the mandatory first task of every project, and `maintenance`, run every 14 days. |
| `enforcement/` | Machine checks every project must pass: hooks, CI, `bootstrap.sh`, `doctor.sh`. Rules: `rules/enforcement.md`. |
| `agents/` | Logical role definitions: architect, builder, frontend, backend, database, critic, tester, reviewer, qa. |
| `rules/` | Global engineering policy. Index: `rules/README.md`. |
| `skills/` | Specialized capabilities (`capabilities.md`) and the methods that deliver them. |
| `project/.ai/project.md` | Per-project context template. Lives at `<project>/.ai/project.md`. |

---

## Layer Responsibilities

```text
USER → RUNTIME → ROUTER → WORKFLOW → AGENT ROLE → CAPABILITY → WORKER → VERIFICATION
```

- **Runtime** — runs the agents and their lifecycle: Claude Code alone, or an
  orchestrator such as Orca ADE (third party, by Stably; Lodestar-harness is
  not affiliated with it). Not rebuilt here.
- **Router** — decides the approach.
- **Workflow** — defines the execution strategy.
- **Agent role** — defines who is responsible.
- **Capability** — optional specialized methodology (`skills/`) or a tool the
  agent runtime provides (see `skills/capabilities.md`).
- **Rules** — constraints and principles every agent follows (`rules/README.md`).
- **Project context** — project-specific knowledge (`.ai/project.md`).

Global policy in `rules/` is overridden by project-specific rules in
`.ai/project.md` when they conflict.

---

## Running Without an Orchestrator

Claude Code alone is enough:

- One worker (SIMPLE, the BUILD_REVIEW builder): the main session.
- Reviewer, critic, tester: a subagent given its role brief.
- Independent workers (INDEPENDENT_COMPARE, parallel waves in COMPLEX):
  subagents, each in its own git worktree.
- Settlement and verification: the same rules; the Router reads each result
  and runs the checks before reporting.

With Orca, `router/ORCA-INTEGRATION.md` maps the same decisions to Orca Tasks,
Dispatches and Workers.

---

## Core Principle

Use the smallest workflow, the fewest roles, and the minimum capabilities that
can reliably complete the task. Never report completion without verification.
Never build an orchestration system; use the runtime's.

---

## Reporting Problems

- Bugs, questions, ideas: open a
  [GitHub issue](https://github.com/potetoai/lodestar-harness/issues).
- Security problems (for example, a way to bypass an approval check): do not
  open a public issue; follow [SECURITY.md](SECURITY.md).

---

## License

MIT (`LICENSE`). Tools it calls but does not include are listed in
`THIRD_PARTY.md`.
