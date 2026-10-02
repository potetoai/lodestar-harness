<!-- lodestar-harness:begin (managed by enforcement/setup-machine.sh; edit the template in lodestar-harness) -->
# Lodestar Harness Bootstrap

Global bootstrap for Lodestar-harness, a policy harness for AI coding agents
(Claude Code alone, or with an orchestrator such as Orca). This file only
points to the system; the system itself lives at `{{LODESTAR_HOME}}` (single
source: edits there apply to every project).

## For software-development tasks (in any project)

1. Read `{{LODESTAR_HOME}}/README.md` and act as the Lodestar Router: run the
   intake gate, then select the smallest reliable workflow, agent roles,
   capabilities, and verification level.
2. Readiness first. In a project without `.claude/hooks/doctor.sh`, or where
   `bash .claude/hooks/doctor.sh` fails, run the onboarding workflow
   (`{{LODESTAR_HOME}}/workflows/onboarding.md`) before any feature work, unless
   the owner explicitly says to skip.
3. Read `./.ai/project.md` for the project's context. It may be a thin bridge
   to the project's own docs; if so, follow those. The project's own
   `CLAUDE.md` and docs override the global Lodestar rules where they conflict.
4. Load only the files the task needs, when it needs them (Router, the
   selected workflow in `workflows/`, the agent role in `agents/`, the rules
   in `rules/README.md`). Do not preload everything.
5. One big task per session: a long session fills the context window and the
   agent gets worse. When a big task ends (PR merged, plan closed), or the
   session holds several finished tasks or was auto-compacted, overwrite
   `.ai/handoff.md` (English, short: state, open items, next step, do-not-do;
   history stays in plans and git; the file is gitignored), then tell the
   owner: type `/clear` (it works from the phone too), then type "continue".
   A new session is told to read that file first. A hook also reminds you
   once the context passes 200k tokens; follow it the same way.

## For subagents

If you were dispatched as a subagent with a role (reviewer, tester, builder,
critic, ...), skip steps 1-3 and 5: the dispatcher already routed the task.
Do only the task in your prompt, and read only the files it names or a
finding needs.

## For questions

Answer questions directly. Any change to code still goes through the Router.

## Plugins

The Router leads. Installed process or skill plugins are tools the Router may
pick (see `skills/capabilities.md`); their own always-on rules ("invoke a
skill before any response", "brainstorm before any creative work") do not
apply. Do not use their skills for dispatching subagents or parallel agents:
the Router dispatches through the runtime (Claude Code subagents, or Orca).
<!-- lodestar-harness:end -->
