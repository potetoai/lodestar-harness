# Lodestar Strategy Plan

**Revision:** 2.1 (2026-11-04)

**Purpose:** A practical, evidence-led plan for making Lodestar useful, adoptable, differentiated, and sustainable.

**Status:** strategy revision; pilot, benchmark, compatibility-tier activation and commercial work are not yet executed. Revision 2.0 remains unchanged in `plans/active/lodestar-strategy-plans-v2/`. This directory is the canonical home for the revised strategy; existing execution plans retain their authority.

## Strategic thesis

Lodestar should become a reusable engineering harness for AI coding agents: a system that helps teams route engineering tasks, coordinate agent roles, apply project standards, and verify completion.

Lodestar should not become another orchestration runtime. It defines the engineering method and constraints; the runtime executes the work. It should remain useful with Claude Code alone and interoperable with external orchestration systems such as Orca.

The sequence is **Prove the methodology → Prove the value → Earn adoption → Build the ecosystem → Explore monetization**. Commercialization is optional, not the definition of success. Initially validate with experienced Claude Code users whose established codebases have fragmented instructions, workflows and hooks. Orca is an external orchestration integration, not a prerequisite or a competing runtime to build.

## The outcomes that matter

1. A developer who did not create Lodestar can understand, install, and use it on a real project.
2. Lodestar solves a meaningful problem that is not adequately solved by a few project instructions, skills, or hooks.
3. Its value can be demonstrated with fair, repeatable evaluations.
4. External users return, adapt it, and eventually contribute without depending on the maintainer.

## Strategic principles

- **Validate before expanding:** user evidence precedes feature investment.
- **Smallest effective system:** prefer the smallest workflow, fewest roles, and minimum capabilities that solve the task.
- **Runtime-neutral, not runtime-owning:** integrate with runtimes; do not recreate them.
- **Verification over claims:** never report completion without appropriate verification.
- **Evidence over vanity metrics:** stars and impressions are signals, not product outcomes.
- **Explicit complexity budget:** every abstraction, adapter, and rule must justify its maintenance cost.
- **Privacy by default:** do not assume telemetry; use voluntary, transparent reporting.

## Plan structure

| File | Purpose |
|---|---|
| [01](01-vision-and-positioning.md) | Vision, positioning, boundaries and compatibility tiers |
| [02](02-users-and-product-strategy.md) | Initial users, jobs-to-be-done, product hypotheses |
| [03](03-competitive-analysis.md) | Alternatives and differentiation |
| [04](04-roadmap-12-months.md) | Capacity levels, dependencies and data gates |
| [05](05-product-validation-and-benchmark.md) | Pilot design, A/B/C, staged ablation and budgets |
| [06](06-adoption-and-community.md) | First users and sustainable adoption |
| [07](07-metrics-and-sustainability.md) | Metrics, business principles, licensing and risk register |
| [08](08-execution-guide.md) | First 30 days, unresolved decisions, assumptions and logs |

## Decision rule

When a proposed feature or initiative does not improve usability, differentiation, verifiability, adoption, or maintainability—and cannot be validated—defer or reject it.

## Evidence boundary

Repository facts were inspected at `ebf2587ca3b716ee6cbab2414f6436abe9052ea0` on 2026-11-04: README, Router, role/workflow/rule structure, enforcement and runtime-parity docs, active plans, eval documentation, LICENSE and local Git history. References in this set point to that snapshot where possible. A documented capability is not a newly verified live runtime result.

No external adoption, willingness-to-pay or end-to-end performance result is established by this revision. Targets, budgets and thresholds below are proposed operating defaults, not measurements or claims of statistical power. The owner selects capacity and records a pilot start date before execution; writing this strategy does not start its clocks. Existing repository policies and gates take precedence over strategy suggestions.

## Changelog: 2.0 → 2.1

- Narrowed the first cohort to experienced Claude Code users maintaining fragmented engineering guidance; kept technical leads and tool builders secondary.
- Added version-scoped support tiers and promotion/demotion criteria, preserving existing Codex evidence and treating Orca as an integration.
- Added complexity measurements, clean A/B/C environments, total-agent budget accounting and a staged four-configuration ablation ladder.
- Made every roadmap stage Minimum/Normal/Stretch, mapped existing plans, and added check/stop gates and maintainer capacity limits.
- Added an open-source sustainability model, conditional commercial exploration, verified MIT/history notes and licensing questions requiring further review.
- Added eight practical risks, consistent retention windows, unresolved decisions and validation assumptions. Preserved runtime independence, fair baselines and scope control.

## Five next actions

1. Record the strategy owner, weekly capacity and start date; reconcile the existing-plan dependencies in [04](04-roadmap-12-months.md).
2. Verify one Claude Code setup-to-task-to-upgrade/removal path and record its exact environment and support limits.
3. Recruit a small qualified cohort, observe a real task and arrange an independent repeat; record help and refusals as well as successes.
4. Freeze the A/B/C protocol and run the budgeted smoke cohort before deciding whether repeated runs or ablation are worth the cost.
5. At the first check, decide continue, narrow or stop from task outcomes, supervision effort and maintenance cost; log the evidence in [08](08-execution-guide.md).
