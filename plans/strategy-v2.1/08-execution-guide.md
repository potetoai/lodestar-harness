# Execution Guide

## Purpose

Translate this strategy into repository work without turning the plan itself into a large implementation project. The first change should be an evidence-led documentation and validation pass.

Revision 2.1 is delivered in `plans/strategy-v2.1/`; the nine-file ZIP is a portable reading copy. It does not start a pilot, spend evaluation quota, contact users, change runtime support or amend licensing. Existing execution plans and repository rules remain authoritative.

## First 30 days

The weeks below are a Normal-capacity sequence, not four mandatory parallel tracks. Select the [capacity level](04-roadmap-12-months.md) and record calendar dates before starting. Minimum may finish the first month with one observed task and a decision to narrow. Retention requires its full day-30–60 window; it cannot be established by this first-month schedule.

### Week 1 — Audit and clarify

- Read the current README and the specific canonical docs/active-plan sections named in the dependency table in 04; load additional files only for a concrete question.
- Map existing router, workflows, roles, capabilities, rules, enforcement, and evaluation assets.
- Identify duplicated, conflicting, stale, or aspirational documentation.
- Confirm the actual supported runtime paths and tested versions.
- Write a short list of the top five onboarding questions.
- Mark each proposed change as already done, owned by an existing plan, blocked by a gate, or a new observed gap. Record the owner, hours/week and stage check/stop dates.

**Deliverable:** repository audit with evidence and proposed doc changes.

### Week 2 — Improve the first-use path

- Rewrite the README opening and quick start only where the audit supports it.
- Make the no-orchestrator path explicit.
- Explain the boundary between Lodestar and an external runtime.
- Add one minimal end-to-end example.
- Test the instructions from a clean environment or a fresh clone.
- Record the runtime version, platform and live enforcement evidence; verify upgrade/removal and ordinary/private issue-reporting instructions. A fresh clone alone is not an isolated benchmark environment.

**Deliverable:** documentation PR and reproducible quick-start notes.

### Week 3 — Recruit and observe pilots

- Build a small batch of qualified prospects (up to 20 under Normal capacity).
- Have the owner or an explicitly authorized agent contact them individually.
- Recruit up to five pilot users.
- Observe installation and one real task per user.
- Record friction and intervention levels.
- Arrange a repeat task and later retention follow-up with consent; do not count the maintainer's own projects as external adoption.

**Deliverable:** anonymized pilot findings and prioritized problems.

### Week 4 — Establish evaluation baseline

- Select one bug-fix task for smoke; outline the three representative tasks for a later repeated cohort.
- Define A/B/C configurations.
- Fix model, runtime, repository commit, permissions, and budgets.
- Write acceptance criteria and review rubric before running.
- If the allocation and isolation checks pass, run only the three-run smoke cohort in 05 and record all outcomes. Otherwise deliver the protocol and the reason to defer; repeated comparison and ablation have separate allocations.

**Deliverable:** benchmark protocol, initial results, and a decision memo.

## Repository implementation protocol

Before editing:
1. Inspect the current repository structure and working tree.
2. Read the existing README, contribution guidance, active plans, evals, enforcement, and relevant workflows.
3. Identify canonical documents and avoid creating parallel sources of truth.
4. Map each proposed change to an existing file where possible.
5. Confirm that the proposed plan does not conflict with actual implementation.
6. Read the dependency/gate table in 04. Do not alter files being measured by another active plan without satisfying its gate. Reuse existing eval and release practices; do not create a second source of policy.

During implementation:
- Prefer small, reviewable documentation changes.
- Preserve existing conventions and terminology when they are accurate.
- Do not invent capabilities or supported integrations.
- Do not add product features as a side effect of a strategy-doc update.
- Add links between documents instead of duplicating long explanations.
- Keep examples executable and test them where feasible.

Before opening a PR:
- Check links and Markdown rendering.
- Verify all commands against the current repository.
- Confirm claims against implementation.
- Run relevant existing checks.
- Summarize changed files, rationale, checks, and unresolved questions.

## Suggested agent task prompt

Use this prompt with the agent responsible for the repository audit and documentation PR:

> Audit Lodestar against Revision 2.1. Inspect the working tree, README and the canonical sources/dependencies named in 04; read further only for a finding. Separate completed work, existing-plan ownership, gated changes and new observed onboarding gaps. Propose the smallest documentation change mapped to existing files. Follow the repository Router and its applicable approval rules. Do not implement features, contact users, launch benchmarks, change support commitments or licensing as a side effect. Preserve existing policy by moving and linking; do not remove rules under a simplification label. Verify links and claims, obtain the required review and report unverified assumptions. For actual experiments, first record the owner, capacity, isolation manifest, numeric allocation and calendar gate dates in this guide.

## Scope-control rules

- No feature without an observed problem or explicit strategic requirement.
- No abstraction for hypothetical future use.
- No new runtime adapter without a real user or evaluation need.
- No extension API until at least two concrete use cases require it.
- No additional agent role unless responsibility cannot be handled clearly by an existing role.
- No workflow proliferation: improve an existing workflow first; preserve policy through reviewed moves/links and explicit deprecation decisions under repository rules.
- Every new capability must include a use case, acceptance criteria, verification, and maintenance owner.
- Review removals and simplifications every quarter.

## Definition of done for strategy work

A strategy/documentation change is complete only when:
- It reflects the current implementation.
- It has one clear canonical home.
- It is understandable to an external developer.
- Links and commands have been checked.
- Claims and assumptions are labeled accurately.
- The PR explains what changed, why, and what was not changed.

## Unresolved strategic decisions

These are execution decisions, not blockers to writing the strategy. The owner decides before the dependent activity begins; no silent default starts spending or outreach.

| Decision | Proposed direction | Resolve before |
|---|---|---|
| Weekly capacity, accountable maintainer and start date | Select Minimum/Normal/Stretch in 04; prioritize current-project reliability if capacity conflicts | S1 start |
| First qualified cohort and contact permissions | Experienced Claude Code users with documented fragmentation; small batches | Outreach |
| Exact support matrix and integration owners | Claude reference path first; preserve verified Codex coverage; validate Orca separately under 01 | Publishing tier commitments / pilot onboarding |
| Primary benefit threshold, complexity ceilings, runner and token allocation | Use 05's defaults only after smoke/runner feasibility and user priorities are checked | Each benchmark cohort; freeze repeated-cohort criteria before its runs |
| Evidence storage and publication consent | De-identified summary indexed here; private transcripts/code stay in consented storage | Data collection |
| Commercial exploration and contribution/license policy | Keep MIT core; no commercial build without the demand gate; verify rights before any license proposal | Only if such a proposal is actually made |

## Assumptions to validate

| Assumption | Evidence / falsification | Decision location |
|---|---|---|
| Fragmentation creates enough pain for experienced Claude Code users to change setup | Recent concrete failures and independent task/repeat use; failure to recruit or repeat weakens the hypothesis | S1 |
| Lodestar adds value beyond strong lightweight guidance | Repeated A/B/C outcomes plus setup/upkeep costs; equal practical outcomes at greater cost narrow the claim | S2 |
| Selected components justify their complexity | Frozen cost ceilings, user explanations and focused ablation when needed | S2 / optional ablation |
| Guidance can adapt without bespoke maintainer work | Independent tasks in at least two differently configured projects; repeated custom interventions challenge portability | S1/S3 |
| Existing runtime coverage can be maintained within capacity | Versioned live evidence and hours log, not installed files alone | Tier ratification / S4 |
| Users return and support remains affordable | Eligible day-30–60 cohort and weekly support hours | S3/S4 |
| Teams will pay for additional help without weakening the core | Buyer, budget and a scoped paid-pilot commitment under 07; enthusiasm is insufficient | Optional commercial gate |

No assumption above is recorded as proven by this revision. Repository facts and the licensing research boundary are in 00 and 07.

## Evidence and execution register

Use this guide as an index, not a new tracking application. Before an activity starts, fill one row with the owner, selected capacity, actual dates and a stable link/path to its consented evidence. The records must let a later session reproduce the count. Missing evidence is unknown, not zero activity in the world.

| Activity | Owner / capacity | Start / check / stop | Evidence source | Status |
|---|---|---|---|---|
| S1 | Agent works, owner approves; Normal (4 h/week) | Start 2026-11-04 / check 2026-12-04 / stop 2026-12-25 | De-identified summaries indexed here; raw transcripts/code in private consented storage | Week 1 audit |
| S2–S4 | Unassigned | Not started; instantiate 04 formulas per stage | Not collected | Strategy only |
| Benchmark cohorts | Allocation not selected | Not started | Required manifest/run records below | No runs authorized by this document |
| C1 Optional commercial gate (07) | Unassigned | Not started; instantiate +30 / +51 if activated | No demand records | Deferred |

Minimum record shapes (reuse an existing issue, PR attachment or consented local log; index its exact location above):

- Pilot: pseudonymous user/project ID, qualification, runtime/environment, first accepted-task date, later task dates, criteria result, help category/minutes, consent and follow-up status. Link projects to independent operators so one person is not mistaken for several independent adopters.
- Benchmark: immutable protocol/configuration ID, code/model/runtime versions, task/condition/repeat ID, randomized order, included files/hooks, allocation, acceptance/check outcomes, intervention categories/minutes, all-agent tokens/time, evaluation cost, footprint/concept/update measures, reviewer and stopping/exclusion reason. Retain every attempted run in the denominator/accounting ledger.
- Capacity: week, selected ceiling, support/release/research/evaluation hours, open incidents and scope decision. Record gate counts with numerator, denominator, exclusions and observation window.

## Progress log

| Date | Phase | Note |
|---|---|---|
| 2026-11-04 | Revision 2.1 | Nine-file strategy and independent review completed; PR #141 |
| 2026-11-04 | S1 start | Capacity, owner, dates and evidence storage recorded; PR #144 |

## Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-11-04 | Preserve v2.0 and create a separate v2.1; no implementation changes | Owner requested the revised plan after reviewing the six improvements and additional constraints |
| 2026-11-04 | Keep existing plan ownership, gate dates and verified runtime evidence | Avoid duplicated work, interrupted measurements and unsupported support claims |
| 2026-11-04 | Use a staged, capped benchmark; commercial exploration remains optional | Owner requested a plan executable by a solo maintainer or small team; budget and demand remain unvalidated |
| 2026-11-04 | Add the C1 data-gate table and require recent use as well as historical retention for S3 | Independent review of #141 found two minor gaps in gate format and evidence freshness |
| 2026-11-04 | Delete the untracked v2.0 draft; 2.1 is the only strategy | Owner chose 2.1 and asked to remove the unused version |
| 2026-11-04 | Start S1: Normal capacity, agent works and owner approves, evidence as de-identified summary plus private raw storage | Owner choice; outreach still needs the owner's separate go. Owner does not yet know where to find pilots: the week 1 audit lists candidate channels |
