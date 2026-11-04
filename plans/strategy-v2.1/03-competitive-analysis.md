# Competitive Analysis

## Purpose

Understand the alternatives users already have. Lodestar does not need to win every category; it needs a clear reason to exist for a specific user and use case.

## Alternative categories

| Category | Examples / forms | What users get | Potential gap Lodestar may address |
|---|---|---|---|
| Native project instructions | `CLAUDE.md`, `AGENTS.md`, repository docs | Simple, familiar project guidance | May lack explicit routing, workflow composition, role boundaries, and systematic verification |
| Skills and prompt collections | Reusable skills, command packs, templates | Task-specific expertise and repeatable prompts | Often leave task selection, cross-skill coordination, and completion evidence to the user |
| Agent workflow frameworks | Multi-step agent workflows and role systems | Structured execution patterns | May be tied to a runtime or add complexity beyond the task |
| Orchestration platforms | Worker/session/agent coordinators such as Orca | Execution management and parallelism | Not necessarily a portable engineering policy and verification model |
| Custom team harnesses | Internal scripts, hooks, prompts, CI rules | Exact fit for one team | Expensive to maintain and difficult to reuse across projects |

Examples are categories to investigate, not claims that every tool in a category has the same capabilities.

## Required comparison dimensions

For each relevant alternative, record:
- Task routing and workflow selection.
- Workflow composition and conditional paths.
- Role separation and coordination.
- Project-specific standards/context.
- Machine-checkable enforcement.
- Verification and evidence of completion.
- Runtime portability.
- Setup time and learning curve.
- Configuration footprint and number of concepts the user must understand.
- Maintenance burden and extensibility.
- Time to update the system and recover from runtime or policy changes.
- License, activity, documentation, and contributor health.

## The critical differentiation question

Why should a developer use Lodestar instead of writing a good `CLAUDE.md` or `AGENTS.md`, adding a few skills, and using existing hooks?

A defensible answer may be:

> Lodestar packages routing, workflow structure, role responsibilities, project standards, and verifiable completion into a coherent, reusable system. It is useful when scattered instructions have become difficult to maintain—but it deliberately stays smaller than an orchestration runtime.

This answer must be validated with users and benchmark results. If users cannot identify meaningful value beyond a well-written instruction file, simplify the product or narrow its claim.

Differentiation should rest on a coherent reusable methodology, verifiable execution/enforcement and adaptation across engineering environments. Feature count, agent count and adapter count are not evidence. A lighter configuration winning a use case is a useful product result, not a failed marketing exercise.

The categories above are research hypotheses; this revision does not establish competitor capabilities or a market ranking. Repo inspection verifies what Lodestar contains, not that it outperforms those alternatives. Use the [A/B/C and ablation protocol](05-product-validation-and-benchmark.md) for outcome comparisons.

## Research protocol

1. Start with the pilot's existing setup and one strong lightweight alternative. Limit the first desk-research pass to two maintainer hours inside the roadmap budget; expand to 3–5 named alternatives only if a product decision needs it.
2. Inspect official documentation and repositories; record the date and version.
3. Evaluate each against the same dimensions.
4. Install and test a small subset rather than relying only on README claims.
5. Publish a concise comparison that states limitations and avoids strawman descriptions.
6. Revisit the alternatives actually used by pilots at a stage decision or when a relevant upstream change affects a claim. Do not maintain an exhaustive market catalog.

## Comparison template

For each alternative:

- Name and URL:
- Category:
- Version / date reviewed:
- Intended user:
- Routing:
- Workflows:
- Roles:
- Project context:
- Enforcement:
- Verification:
- Runtime portability:
- Setup effort:
- Configuration footprint / concepts to learn:
- Maintenance burden:
- Update time / support scope:
- Strengths:
- Weaknesses / trade-offs:
- What Lodestar can learn:
- Evidence / test notes:

## Competitive integrity

Do not claim “first,” “best,” “universal,” or “more reliable” without evidence. Compare actual workflows and outcomes, not feature-count checklists alone.
