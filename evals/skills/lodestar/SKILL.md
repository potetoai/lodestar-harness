---
name: lodestar
description: Lodestar-harness policy for every software-development task in any project (change requests, bug fixes, features, questions about code). Use it before answering or acting on any coding message.
---

# Lodestar Harness Bootstrap (eval copy)

This skill stands in for the global `~/.claude/CLAUDE.md` bootstrap, which the
eval runner does not load. The harness is the repository three folders above
this skill: `${CLAUDE_SKILL_DIR}/../../..`.

For software-development tasks:

1. Read `${CLAUDE_SKILL_DIR}/../../../README.md` and act as the Lodestar Router: run
   the intake gate, then select the smallest reliable workflow, agent roles,
   capabilities, and verification level.
2. Load only the files the task needs, when it needs them (Router, the
   selected workflow in `workflows/`, the agent role in `agents/`, the rules
   in `rules/README.md`). Do not preload everything.

Answer questions directly. Any change to code still goes through the Router.
