# Product Validation and Benchmark

## Purpose

Determine whether Lodestar helps developers complete engineering tasks more reliably or with less supervision—and whether that benefit justifies its setup and maintenance cost.

A benchmark is not a marketing demonstration. Publish the protocol, task set, outcome summaries, limitations, and unsuccessful runs when sharing is permitted. Private project code and transcripts remain private; publish de-identified summaries with consent and disclose any reproducibility limits.

## Part 1 — User validation

### Pilot cohort

Under Normal capacity, recruit up to five developers from the [primary ICP](02-users-and-product-strategy.md); Minimum starts with one observation. Participants:
- Are not the project author.
- Use Claude Code on established code with existing instructions, skills/workflows and hooks.
- Have a codebase with established conventions.
- Can describe a recent failure or supervision burden.

Do not recruit only close friends or people already enthusiastic about the project.

### Observe, do not just ask

For each pilot:
1. Ask them to install Lodestar using the documentation.
2. Observe where they hesitate or fail.
3. Have them complete a bounded task on their own project.
4. Record interventions, corrections, checks run, and time spent.
5. Ask them to repeat a task later without live help; distinguish early repeat from day-30–60 retention using [07](07-metrics-and-sustainability.md).
6. Ask what they would remove, not only what they want added.

Collect only information participants knowingly provide. Do not introduce hidden telemetry.

### Validation questions

- Did the user understand what Lodestar does?
- Could they get started without the maintainer?
- Did it reduce repeated prompting or manual steering?
- Did it improve task selection or verification?
- Was the result worth the extra structure?
- Would they use it again on another task? Why or why not?

## Part 2 — A/B/C benchmark

Use three conditions:

**A — Project baseline:** the agent receives the project's normal documentation and instructions. This must be a competent, realistic baseline—not an intentionally bare agent.

**B — Lightweight guidance:** the same agent receives a concise, well-written instruction setup with the minimum relevant rules and task guidance.

A and B retain the project's legitimate existing safeguards. Freeze and publish B's actual text/configuration before runs; have someone familiar with the project check it is competent. Do not tune B after seeing C's results. Document whether B supplements or consolidates A's instructions and why; the task facts and required outcomes remain the same.

**C — Lodestar:** the agent uses the relevant Lodestar router, workflow, roles, capabilities, and enforcement.

The B condition matters: it tests whether Lodestar provides value beyond a small amount of thoughtful prompt/instruction engineering.

## Controls

Keep constant wherever possible:
- Model and exact model version.
- Runtime and runtime version.
- Repository commit and working-tree state.
- Task specification and acceptance criteria.
- Tool permissions and available tools.
- Environment, dependencies, and test data.
- Time or token budget.
- Human intervention policy.

Randomize condition order. Run each task-condition combination multiple times when budget allows. Record every run, including failures. Avoid selecting only the best output.

If the model or runtime changes, treat it as a new benchmark cohort rather than silently combining results.

Use separate disposable runtime homes and fresh repository copies for each condition/run. Record global/project instructions, plugins, skills, hooks, trust state and available tools in a configuration manifest. Verify A/B do not inherit Lodestar through a global bootstrap, ancestor instructions, shared sessions or hooks. Keep credentials private; do not reuse conversation memory. Reset the repository, dependencies and task data identically. A fresh clone alone is not isolation.

Tool capabilities, sandbox and approval policy stay constant; the treatment's Lodestar enforcement is the declared difference. Do not disable ordinary project/CI safeguards in A/B. Use throwaway data for risky tasks. The same external acceptance checks evaluate every output; C's extra internal verification is part of its cost, not a more lenient grading standard. For multiple agents, pin the model/version for every role or disclose any deviation as a confound.

## Staged runs and resource budget

These are proposed ceilings to ratify before running, not an instruction to spend quota now. Count input, output and cache-read/write tokens once under a declared accounting method across all builders, reviewers, critics, retries and evaluation judges. Report subscription quota consumption separately from estimated API prices or actual cash spend.

| Cohort | Scope | Proposed ceiling | Decision |
|---|---|---|---|
| Protocol smoke | 1 task × A/B/C × 1 run = 3 runs | 150k tokens and 30 minutes per condition-run; 600k total including up to 150k for evaluation; 4 maintainer hours spread within weekly capacity | Check isolation, scoring and whether caps permit meaningful work. No superiority claim. |
| Repeated comparison | 3 tasks × A/B/C × 3 runs = 27 runs | Same per-run caps unless smoke justifies a newly frozen cohort; 4.5M total including up to 450k evaluation; 12 maintainer hours spread over the stage | Apply S2; report every outcome and stopping reason. Needs a separately recorded allocation after smoke. |
| Focused ablation | 1 selected task × 4 configurations × 3 runs = 12 outcomes | Reuse 3 comparable Full Lodestar outcomes; at most 9 new runs at the same caps, 1.5M total new tokens including evaluation, 6 maintainer hours | Explain one unresolved component decision; optional and separately allocated. If reuse is invalid, re-budget before running. |

Stop at the first elapsed-time, token or cohort ceiling reached; cap failures remain outcomes. If the runner cannot meter or enforce the chosen budget, prove a bounded run/accounting path first and do not launch the batch. Do not build an orchestration system or custom runner to fulfill this strategy. Record overruns and unavailable token categories; never label partial counts as total cost.

A smoke task may show that the proposed cap is unrealistic. Adjust scope or record a new allocation before a fresh cohort; do not selectively extend only C or silently exclude its timeouts. Protocol smoke results are not pooled into the repeated cohort. Three runs per task show variation but cannot support broad statistical claims. Scheduling a full repeated cohort in Week 4 is not required.

## Task set

Use one bug-fix task for protocol smoke, then three frozen tasks for the repeated cohort:
1. Bounded bug fix requiring a regression test.
2. Small feature spanning more than one layer.
3. Refactor with behavior-preservation constraints.

Documentation/configuration or security/data-handling tasks are optional later cohorts only when a decision needs them, not additions to the initial run matrix.

Tasks should be realistic, bounded, reproducible, and independently reviewable.

## Measures

| Measure | What it tells you |
|---|---|
| Acceptance criteria passed | Whether the task was completed correctly |
| Existing and new tests passed | Verification outcome |
| Defects introduced | Quality and regression risk |
| Human interventions | Supervision burden |
| Unsupported completion claims | Verification discipline |
| Elapsed time | Speed, interpreted with quality |
| Token / API cost | Resource cost |
| Setup and configuration time | Adoption friction |
| Workflow/routing appropriateness | Whether the system selected a suitable path |
| User preference and repeat intent | Perceived practical value |
| Configuration footprint | Files, nonblank lines, settings and installed hooks added/changed per condition, including global state; distinguish generated from user-maintained configuration |
| Concepts users must understand | Pre-list distinct concepts needed for the task and ask pilots to explain them; count misunderstood concepts and time to learn, not just document headings |
| Maintenance burden | Maintainer and user minutes spent diagnosing, repairing and updating the setup per task/week; include support and manual workarounds |
| System update time | Time from a frozen previous setup to a verified update, plus changed files, failed attempts and rollback effort on the same update scenario |

Define acceptance as all mandatory criteria passing with no unresolved blocking defect. Report verification pass rate against a frozen list of required checks with a denominator; a skipped or unavailable required check is not a pass. Count human interventions by category (clarification, correction, expected approval, environment repair) and minutes. Required approvals must not be removed to improve the score. Record learning/setup once and per-task cost separately; amortize only over an explicitly stated number of tasks.

Do not collapse everything into one opaque score. Report quality, effort, cost, and reliability separately.

## Review protocol

- Use a written scoring rubric before running tasks.
- Have reviewers assess outputs without knowing the condition where practical.
- Use at least two reviewers for subjective quality where feasible.
- Resolve disagreements and report reviewer limitations.
- Track task-level results, not only averages.
- Include confidence intervals or ranges when sample size permits; do not imply statistical certainty from a tiny sample.
- Assess anonymized patches and test results for task quality; assess process traces separately for workflow compliance, where blinding may be impossible. Record reviewer identities/roles, condition leakage and disagreements. A single reviewer is acceptable when disclosed; the producing agent cannot be the sole judge of its own success.
- Use frozen independent acceptance tests and rubric, not merely tests created by the agent. Test-passing with wrong behavior remains a failure. Record all attempts, timeouts and infrastructure errors; list invalid-run exclusions and replacement decisions without erasing the original attempt or cost.

## Component attribution

Use this cumulative ladder only when the A/B/C results leave a decision that could change the product:

| Configuration | Treatment added to the same project foundation |
|---|---|
| R1 — Router only | Routing guidance and minimal definitions needed to interpret route labels; no Lodestar workflow bodies, role briefs or enforcement installation |
| R2 — Router + workflows | R1 plus selected workflow instructions; generic runtime agents may perform the specified steps, without Lodestar role briefs |
| R3 — Router + workflows + agent roles | R2 plus the relevant role definitions and responsibility boundaries |
| R4 — Full Lodestar | R3 plus applicable rules/capabilities and active Lodestar enforcement and verification mechanisms; identical to C when reused |

Inventory every included file and global/project setting. Router references must not accidentally load omitted components; prevent and inspect out-of-condition reads in disposable fixtures. If a component cannot be isolated without changing its meaning, mark that comparison infeasible rather than mislabel it. Every condition retains the project's normal safeguards and the same external grading.

The ladder estimates incremental effects in this order, not independent causal effects. R4 adds a bundle, so an R3→R4 gain cannot be attributed to enforcement alone. Run a targeted leave-one-out comparison only if that specific attribution affects a decision and receives its own budget. A beneficial simpler configuration may become the recommendation; do not optimize the experiment to make Full Lodestar win.

Do not infer that every component helps because the full system performs well.

## Reporting template

- Evaluation date:
- Repository commit:
- Model/runtime/version:
- Task descriptions:
- Conditions and configuration:
- Number of runs:
- Isolation/configuration manifest and omissions:
- Frozen rubric, benefit threshold, complexity ceilings and allocation:
- Acceptance rate:
- Test outcomes:
- Defects:
- Human interventions:
- Time and cost:
- Setup, configuration footprint, concepts, support and update time:
- Reviewer method:
- Failures and anomalies:
- Limitations:
- What changed as a result:

## Decision standard

Before the repeated cohort, choose one primary benefit and freeze its threshold plus acceptable token/time/setup/update ceilings with the pilot's priorities. Proposed S2 default: versus B, C has at least one additional accepted run among three repeats on at least two of the three tasks, OR at least one fewer median corrective intervention per task on at least two tasks with no lower acceptance count on any task. No new blocking safety defect is acceptable; costs must remain within the pre-agreed ceilings. Compare against A as well and disclose any deterioration. These small-sample decision thresholds are operational judgments, not statistical significance.

S2 passes only with the complete repeated-cohort accounting, the chosen benefit, acceptable complexity, and a documented bounded use case. If the result is inconclusive, prefer a smaller recommendation or gather specifically justified evidence; do not claim equivalence or superiority. Safety-relevant rare failures may need separate focused tests; a small benchmark cannot establish that a safeguard is unnecessary.

Keep a component when it provides a repeatable benefit, is necessary for a valued workflow, or materially improves safety/verification. When benefit is unproven and maintenance cost is real, propose simplification through the repository's review and preservation rules. This experiment does not authorize deleting policies or bypassing existing gates.
