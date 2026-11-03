# Specialized Capabilities

Version: 2.0
Scope: Global Lodestar-harness

---

## Purpose

The Router may activate a specialized capability when a task needs methodology
or tooling beyond normal agent execution.

A capability is either a method written in this folder, or a tool the
project's agent runtime provides (an MCP server, for example). No third-party
plugin is required. The engineering rules in `rules/` still apply on top.

A capability is different from an agent role:

- Agent role (`agents/*.md`) = WHO is responsible.
- Capability = WHAT extra methodology or tooling is applied.

Do not permanently map a capability to a specific agent or model.

---

## Deep-Investigation

**Source:** the methods in this folder:

- `skills/investigate.md`: find the root cause before changing code.
- `skills/explore-options.md`: settle the goal and the approach before
  building.

**Use when** engineering reasoning is the hard part:

- Unfamiliar or poorly understood codebase
- Difficult debugging / unclear root cause
- Root-cause and dependency analysis
- Architecture investigation or decision
- Large or risky refactoring / blast-radius analysis
- Complex implementation needing deeper planning
- High-risk verification

**Do not use** for simple tasks where normal agent reasoning is enough.

---

## Product / QA / Release

**Source:** a browser automation tool, when the runtime has one (for example a
Playwright MCP server: navigate, click, fill forms, read the page, take
screenshots). Without one, use the project's end-to-end test command.

**Use when** product, UI, browser, or delivery validation is the hard part:

- Significant UI/UX changes
- Browser interaction / end-to-end user flows
- Product behavior and visual validation
- Browser QA and accessibility validation
- Release / ship validation

**Do not use** for backend-only or trivial changes where browser/product
validation adds nothing.

---

## Selection Principle

The Router chooses, in order of preference:

1. The smallest reliable workflow.
2. The minimum required agent roles.
3. The minimum capabilities necessary — prefer none when normal agent
   capability suffices.
4. The appropriate verification level.

Use both capabilities only when a task has significant engineering AND
product/UI dimensions. Do not activate either automatically.

---

## Other installed plugins

If the machine has other process or skill plugins, they are optional tools
the Router may pick. The Router and `rules/` lead: a plugin's own "always do X
first" rules do not apply. Before using a tool, check that it exists in the
installed version; do not hard-code tool names or flags.

### Adopting a third-party skill or plugin

A project adopts one only for a gap its rules and checks leave, and keeps
few: many skills slow agents and make them erratic.

1. **Read it first.** What it installs, which files it writes, whether it
   starts hooks or subagents, what it sends out (telemetry off), and its
   license. Pin the commit or version.
2. **Turn off what competes with Lodestar.** Commands that write their own
   source of truth next to the project's docs (a second design or product
   file), its own hooks, and any skill instruction that dispatches
   subagents: the project's docs stay the one source, and the Router
   dispatches.
3. **Per project.** Turn it on in the project that needs it, not for the
   whole machine.
4. **Trial before keeping.** Run it read only on real work and compare its
   findings with known bugs or the reviewer's findings. Keep it if it finds
   real issues the project's checks missed, at a token cost the owner
   accepts (the owner decides); drop it otherwise.
5. **Record it** in the project's `.ai/project.md`, table "Agent Skills and
   Plugins": source and commit, why it was chosen, trial result, status.

A skill's findings are review input, not proof: tests, lint and the other
machine checks still decide whether work is done.
