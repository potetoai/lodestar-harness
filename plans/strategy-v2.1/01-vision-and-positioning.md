# Vision and Positioning

## Vision

Make disciplined software engineering practices usable by AI coding agents, without forcing developers into a single runtime or heavyweight orchestration system.

Earn influence through a coherent, reusable engineering methodology, verifiable execution and enforcement, and adaptation to different projects and engineering environments. The number of workflows, skills, roles or integrations is not the moat. Each component must earn its setup, learning and maintenance cost.

The strategic sequence is: **Prove the methodology → Prove the value → Earn adoption → Build the ecosystem → Explore monetization**. Ecosystem work follows repeat use; monetization may never be necessary. The useful, locally runnable open-source core is the foundation throughout; see [sustainability](07-metrics-and-sustainability.md).

## Recommended positioning

**Category:** Engineering harness for AI coding agents.

**One-line description:**

A reusable system for routing engineering tasks, coordinating agent roles, applying project standards, and enforcing verifiable completion.

**Short pitch:**

Lodestar gives AI coding agents a consistent engineering operating model: what workflow to follow, which responsibilities to separate, which project standards apply, and what evidence is required before work is considered complete. It can run with Claude Code alone and can be used alongside an external orchestrator such as Orca.

For the first cohort, make the problem concrete: established Claude Code projects accumulate instructions, skills, hooks and conventions that become hard to reconcile. Lodestar aims to reduce that supervision and maintenance burden; the benefit remains a hypothesis until measured against a strong lightweight setup.

## Why “engineering harness”

“Policy layer” communicates rules but undersells routing, workflows, roles, capabilities, and verification. “Orchestration framework” overstates the runtime responsibility and risks confusing Lodestar with tools that manage execution, sessions, or workers.

“Harness” best communicates the reusable structure around an agent while leaving execution to the runtime.

## Product boundary

Lodestar owns:
- Engineering task routing and workflow selection.
- Definitions of agent roles and their responsibilities.
- Project standards and reusable capabilities.
- Verification requirements and machine-checkable enforcement.
- Integration guidance and portable conventions.

The runtime owns:
- Model invocation and provider connectivity.
- Tool execution, terminal, filesystem, and browser access.
- Session lifecycle, worker scheduling, and execution infrastructure.
- Runtime-specific permissions and safety controls.

External orchestrators may coordinate execution, but Lodestar should not require one.

## Non-goals

- Building a competing agent runtime or orchestration platform.
- Replacing IDEs, coding agents, CI systems, or project-specific engineering judgment.
- Adding generic abstractions for hypothetical future integrations.
- Maximizing the number of agents, skills, workflows, or configuration files.
- Claiming better outcomes without a fair evaluation.

## Positioning tests

A new user should be able to answer these questions from the README:
1. What problem does Lodestar solve?
2. What does it do that a `CLAUDE.md`, `AGENTS.md`, skills folder, or hooks alone may not?
3. What does it not do?
4. Can I try it without Orca or another orchestrator?
5. What evidence should I expect before trusting its completion claims?

## Messaging guardrails

Prefer:
- “Reusable engineering harness”
- “Task routing and workflow selection”
- “Verifiable completion”
- “Works with Claude Code alone; can integrate with external runtimes”

Avoid:
- “Autonomous engineering platform”
- “Universal orchestration”
- “Guaranteed higher-quality code”
- “Works with every agent” unless each integration has been tested.

## Runtime and integration compatibility tiers

Tiers describe a named runtime/version/platform/entry-point combination, not every release of a product. Record the maintainer, test date, install/upgrade/removal result, real-task result, hook activation and known gaps. Configuration present on disk is not proof of active enforcement.

| Tier | Commitment and required evidence |
|---|---|
| Tier 1 — Officially supported and tested | A named Lodestar maintainer owns a bounded matrix; documented setup, upgrade and removal; live task and applicable lifecycle checks pass; failures and migration limits are documented; checks run before claiming a new version supported. No implied response-time SLA. |
| Tier 2 — Community-supported | A named external maintainer supplies a reproducible example and compatibility evidence, keeps instructions current and handles integration issues. Core maintainers review shared-policy changes but do not promise coverage of this matrix. |
| Tier 3 — Experimental | A limited investigation with explicit gaps, a time budget and an owner. No production-support promise; no label of enforcement parity without evidence. |

Initial direction and verified repository context:

| Path | Strategy | Evidence and remaining work |
|---|---|---|
| Claude Code alone | Reference runtime and first Tier 1 validation target | Core workflow/enforcement and Router eval assets exist. Record the current version/platform and live first-use lifecycle before publishing a Tier 1 matrix; this revision ran no runtime smoke tests. |
| Orca with a specified agent | Important external orchestration integration; validate a bounded Tier 1 integration target when capacity permits | The [integration contract](https://github.com/potetoai/lodestar-harness/blob/ebf2587ca3b716ee6cbab2414f6436abe9052ea0/router/ORCA-INTEGRATION.md) exists. Validate agent choice, dispatch and evidence return in that environment. Agent-level test evidence alone does not certify Orca. Standalone use never waits for this. |
| Codex adapter already in this repo | Preserve existing coverage; assess its tier from evidence and maintenance ownership | [Runtime parity](https://github.com/potetoai/lodestar-harness/blob/ebf2587ca3b716ee6cbab2414f6436abe9052ea0/enforcement/runtime-parity.md) documents a Codex 0.162.1 Windows target and coverage limits. This is not evidence for every Codex version/platform. No automatic demotion, removal or change of default agent is authorized here. |
| Other runtimes | Consider Tier 3 only after a real user need and a feasible owner/time budget exist | No new adapter is committed by this roadmap. Community ownership is needed before calling a path Tier 2. |

The initial table sets targets and evidence gaps, not newly awarded support badges. When ratifying the matrix, retain existing verified support and name any unverified claims instead of inventing a tier.

Promotion requires passing the destination tier's evidence checklist, a real consuming use case, an owner and budget, and a reviewed matrix change. Tier 2 is not a mandatory waypoint when a core maintainer owns an experimental path. Recheck on a runtime change affecting tools, hooks or instructions and before a compatibility release. If a required guard breaks, immediately mark the affected combination unsupported for that operation and offer a last verified version or safe alternative. If reproducibility or ownership cannot be restored within a recorded 21-day repair window, demote that combination with migration notes; do not silently weaken a shared rule or promise support for untested versions.
