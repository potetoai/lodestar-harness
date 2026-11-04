# 12-Month Roadmap

## Roadmap approach

Use four evidence-gated stages, not a feature-driven sequence. Months are planning windows, not deadlines that override evidence. The sequence is **Prove the methodology → Prove the value → Earn adoption → Build the ecosystem → Explore monetization**; the last step is optional and is not promised within twelve months.

The immediate objective is to learn whether reduced supervision and better verification justify setup and upkeep. Internal use can remain successful even if external expansion is stopped. Do not treat the maintainer's own projects as independent external adoption.

## Capacity contract

Before starting, the owner records a weekly ceiling, a pilot start date and one accountable maintainer in [08](08-execution-guide.md). Proposed levels are Minimum: 2 hours/week, Normal: 4 hours/week, Stretch: up to 6 hours/week. These include support, research, evaluation preparation/review, releases and reporting, not just new work. They are options, not assumed availability.

Reserve about half of that time for reliability, support and recovery; spend the remainder on one validation question at a time. No stage requires simultaneous research, community, benchmark and feature work. Unused time need not be filled. If essential support consumes the ceiling, pause recruitment and experiments first. Two consecutive weeks above the ceiling trigger a smaller scope or a pause, not an expectation of overtime. Reserve breaks and do not promise an on-call service or response-time SLA.

Minimum produces a useful decision even when there is too little evidence to advance. Normal is a planning expectation conditional on capacity. Stretch is optional and never a prerequisite of a later stage. A failed gate leads to narrowing, stopping or an explicitly logged extension; it does not create an indefinite backlog.

## Existing work and dependencies

Snapshot: 2026-11-04 at `ebf2587`. Recheck statuses before execution. These plans retain ownership; this strategy does not reopen their completed phases or bypass their gates.

| Area | Already present | Remaining work for this strategy | Owner / dependency |
|---|---|---|---|
| Documentation consistency | [docs-tidy](https://github.com/potetoai/lodestar-harness/blob/ebf2587ca3b716ee6cbab2414f6436abe9052ea0/plans/active/docs-tidy.md) phases 2–3 recorded in #135/#139 | Observe external first-use friction; improve only proven gaps | Existing plan owns cleanup. Its phase 4 check is 2026-11-18; DT-1 protects files still under P5 measurement. |
| Policy regression evals | [behavior-evals](https://github.com/potetoai/lodestar-harness/blob/ebf2587ca3b716ee6cbab2414f6436abe9052ea0/plans/active/behavior-evals.md): Router suite and run policy exist | End-to-end product comparison, which answers a different question | Preserve EV-3 for additional behavior suites (check 2026-12-01, stop 2026-12-22); product pilots do not authorize expanding those suites. |
| Release and operational health | [harness-health](https://github.com/potetoai/lodestar-harness/blob/ebf2587ca3b716ee6cbab2414f6436abe9052ea0/plans/active/harness-health.md), batched release policy | Measure external upgrade burden and document the existing practice | Existing plan owns hook health; retain current release cadence and exceptions. |
| Skills and role changes | [skill-harvest](https://github.com/potetoai/lodestar-harness/blob/ebf2587ca3b716ee6cbab2414f6436abe9052ea0/plans/active/skill-harvest.md), [agent-pitfalls](https://github.com/potetoai/lodestar-harness/blob/ebf2587ca3b716ee6cbab2414f6436abe9052ea0/plans/active/agent-pitfalls.md) | Route pilot findings to the relevant existing plan | SH-0 and P5-a..c still govern affected work. Observe without changing measured policy; pin experiment versions. |
| Runtime coverage | [runtime parity](https://github.com/potetoai/lodestar-harness/blob/ebf2587ca3b716ee6cbab2414f6436abe9052ea0/enforcement/runtime-parity.md), Claude/Codex adapters, Orca contract | Reconcile evidence with the tier checklist in [01](01-vision-and-positioning.md) | Preserve existing verified coverage; no new adapter required. |

## Stage 1 — Prove the methodology is usable (Months 1–2)

**Goal:** external Claude Code users with fragmented project guidance can understand and repeat one bounded workflow.

- **Minimum:** reconcile the table above, verify one first-use path, interview/observe one qualified external user and record whether the next bottleneck is recruitment, setup or usefulness. One observation is not adoption proof.
- **Normal:** recruit up to five pilots, observe a real task on each project and request an independent repeat. Fix the highest-impact documentation or setup issue. Explain supported environments, upgrade/removal, and where to report ordinary or sensitive issues before inviting pilots.
- **Stretch:** additional interviews up to 8–12 total, or a second task walkthrough if the first one works. Neither is needed for Stage 2.

**Exit:** gate S1: at least three external users finish a real task, at least two repeat independently, and the main value/friction is recorded in their words. Otherwise improve the first-use path or narrow the cohort. Commercial and new-integration work do not address this gate.

## Stage 2 — Prove value over a simpler setup (Months 3–5)

**Goal:** identify a bounded use case where benefit justifies complexity.

- **Minimum:** execute the three-run A/B/C protocol smoke test in [05](05-product-validation-and-benchmark.md); decide whether isolation, scoring and budget permit a meaningful comparison. Publish no superiority claim from this smoke test.
- **Normal:** run the bounded repeated cohort, report quality, supervision, cost and complexity separately, and record a continue/narrow/stop decision. Prefer a smaller configuration if it delivers comparable outcomes with less upkeep.
- **Stretch:** run the four-configuration ablation ladder for one unresolved component decision. Reuse comparable Full Lodestar results; a ladder is not required to advance to Stage 3.

**Exit:** gate S2 and the pre-registered decision rule in [05](05-product-validation-and-benchmark.md). A weak or inconclusive result narrows claims; it does not justify trying more features until something wins. Changes to shared policy follow existing review and data gates.

## Stage 3 — Earn repeat adoption (Months 6–9)

**Goal:** repeated independent use of the validated use case within a sustainable support budget.

- **Minimum:** follow the existing cohort through the retention window, fix one recurring support problem, and decide whether continued external support is affordable.
- **Normal:** at least three independently operated external projects show day-30–60 retention and each completes an accepted task in the 30 days ending at the S3 check, with at least two of those recent tasks completed without live help. Publish the proven walkthrough and common troubleshooting; accept small docs or example contributions.
- **Stretch:** one outside contributor can maintain an example or a user-requested integration. Contributor recruitment is not a retention gate and no later stage depends on this stretch work.

**Exit:** S3. Collect day-30–60 follow-ups when due during S1/S2, even if Stage 3 has not started. S3 checks current use as well as historical retention; recruit a later cohort only within capacity. Show the denominator, nonresponse and support burden. Attention or enthusiasm without a later real task does not pass.

## Stage 4 — Sustain the core and build an ecosystem (Months 10–12)

**Goal:** a useful open-source core with maintenance responsibilities that fit available capacity.

- **Minimum:** document a release/upgrade/recovery checklist, state support limits and audit actual maintenance hours. Choose sustainable maintenance mode if expansion is unaffordable.
- **Normal:** exercise the checklist for a release or rehearsal, publish a consented evidence summary including failures, and make contribution review and ownership understandable. Seek backup help without assuming volunteers will appear.
- **Stretch:** an external maintainer rehearses a release or owns an area. Explore a commercial service only if the separate demand conditions in [07](07-metrics-and-sustainability.md) are met; do not build enterprise features to complete this stage.

**Exit:** S4. A sustainable maintainer-only project is a valid outcome; missing outside contributors or revenue does not invalidate proven user value.

## Data gates

The owner records calendar dates at the start of each stage: `S1 start`, `S2 start`, etc. `+30` means calendar days after that recorded date. Until dates, capacity and evidence sources are entered in [08](08-execution-guide.md), the stage is not started. Every gate uses the [repository data-gate rule](https://github.com/potetoai/lodestar-harness/blob/ebf2587ca3b716ee6cbab2414f6436abe9052ea0/rules/documentation.md); dates below are formulas to instantiate, not deadlines silently activated by this document.

| Gate | Measure (source) | Minimum to decide / pass | Check | Stop | Status |
|---|---|---|---|---|---|
| S1 Usability | Consented pilot task and repeat records indexed in 08; distinct external users, help received and task acceptance | 3 users complete; 2 repeat without live help; value and friction recorded | S1 start +30 | S1 start +51 | waiting (0 recorded; not started) |
| S2 Value | Frozen benchmark manifest and all-run summary indexed in 08 | 3 tasks × A/B/C × 3 runs; apply 05's quality/supervision and complexity rule; all stopped/invalid runs disclosed | S2 start +30 | S2 start +51 | waiting (0 recorded; not started) |
| S3 Retention | Eligible pilot cohort, day-30–60 follow-ups and accepted tasks in the 30 days ending at the check in 08, using 07's definitions | At least 3 eligible independent external projects retained and each active in that recent window; 2 recent tasks without live help; 4 weeks of support within recorded ceiling | S3 start +60 | S3 start +81 | waiting (0 recorded; not started) |
| S4 Sustainability | Four-week hours log, release/recovery rehearsal and unresolved support list indexed in 08 | 4 weeks within capacity; one documented release or rehearsal; critical support issues resolved or affected scope explicitly withdrawn; continued external use documented in that window | S4 start +30 | S4 start +51 | waiting (0 recorded; not started) |

At each check, log counts, exclusions and the next check date. At stop with insufficient use, treat the absence of use as evidence; narrow or stop. For other insufficient data, the owner explicitly chooses an extension, dropping the step or proceeding with thin evidence; record that limitation. Passing a gate does not automatically allocate the next stage's budget. A stage may start only after the previous gate passes or an explicit thin-data/narrowed-scope decision is logged. No new validation claim follows merely from stopping a gate.

## Scope rule

Keep reliability and support active throughout; select other work serially. Do not advance because the calendar says so. Preserve existing policy: simplify through reviewed moves, links and explicit deprecation decisions under repository rules, never by deleting safeguards to reduce a metric. Stretch goals never become dependencies.
