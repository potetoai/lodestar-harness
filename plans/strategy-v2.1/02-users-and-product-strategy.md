# Users and Product Strategy

## Initial ideal user profile

Start narrow. The first target is not every developer using AI.

**Primary ICP:** experienced Claude Code users working on established codebases who already maintain multiple project instructions, skills, workflows, hooks and engineering conventions. Their problem is fragmented guidance, inconsistent agent behavior, unclear responsibility between agents, weak workflow consistency, unreliable verification, or increasing maintenance complexity.

Likely characteristics:
- They use Claude Code frequently and can explain their current guidance and verification setup.
- They work across features, bug fixes, refactors, and tests.
- They have project conventions that agents often miss.
- They have experienced inconsistent agent behavior, weak verification, or context-heavy repeated instructions.
- They are willing to try a repository-level workflow if setup is clear and reversible.

**Secondary ICP:** AI developer-tool builders and technical leads responsible for AI-assisted engineering practices across projects. Their integration or governance requests must not displace the first cohort's demonstrated needs.

Qualify the first cohort by a recent concrete failure, an existing instruction/hook setup, and willingness to compare against a lighter configuration. Team size alone is not a qualification. New agent users with a simple repository and no recurring coordination problem are not the first target; their existing instructions may be sufficient.

Claude Code is the reference runtime. Orca remains an important optional orchestration integration. Existing Codex work is assessed through the [compatibility tiers](01-vision-and-positioning.md), not discarded to narrow the audience.

Do not target large enterprises first; security, procurement, governance, and integration requirements may overwhelm an early-stage maintainer.

## Jobs to be done

When I delegate engineering work to an AI coding agent, I want it to:
1. Choose an appropriate workflow instead of improvising every task.
2. Respect project architecture and conventions.
3. Split responsibilities only when doing so adds value.
4. Run relevant checks and report evidence.
5. Avoid claiming completion when verification is missing.

The user is not buying “more agents.” They are trying to reduce rework, inconsistency, and the cognitive overhead of supervising AI-generated changes.

## Core product hypotheses

| Hypothesis | Evidence required |
|---|---|
| Routing improves task-to-workflow consistency | Fewer inappropriate workflows and less manual steering |
| Project context reduces repeated prompting | Lower user correction/re-prompt burden |
| Role separation helps on suitable tasks | Better outcomes on tasks where independent responsibilities matter |
| Enforcement improves completion reliability | More required checks actually run; fewer unsupported completion claims |
| Minimal setup enables adoption | A new user completes a real task without maintainer intervention |
| Coherence pays for its complexity | Better outcomes or less supervision than lightweight guidance, within a user-accepted setup and maintenance cost |
| Adaptation works across established projects | A second project can fit its conventions without forking shared policy or needing bespoke maintainer work |

Treat each as a hypothesis, not a marketing claim.

## First use cases

Start the first-use walkthrough with a bounded bug fix. Expand evaluation to three representative tasks under the [benchmark budget](05-product-validation-and-benchmark.md):
- A bounded bug fix with a regression test.
- A small feature that touches multiple layers.
- A refactor that must preserve behavior and pass existing checks.

Avoid starting with giant greenfield builds; they are difficult to reproduce and make attribution hard.

## Product priorities

**P0 — adoption blockers**
- Clear quick start and prerequisites.
- A minimal working path with Claude Code alone.
- Explicit explanation of runtime boundary and Orca integration.
- One end-to-end bug-fix example; expand to the other representative tasks only when the first-use path works.
- Clear failure modes and troubleshooting.
- A tested upgrade/removal path and a version-scoped support statement before external pilots.

**P1 — prove value**
- Evaluation tasks and scoring rubric.
- Verification evidence in workflow outputs.
- Guidance on when not to use multi-agent or complex workflows.
- Small, tested integration examples.

**P2 — only after user demand**
- Additional runtime adapters.
- Extension interfaces.
- More role/workflow templates.
- Team-level governance features.
- Commercial services or team offerings only after the demand gate in [07](07-metrics-and-sustainability.md); no artificial restrictions on the open-source core.

## Feature admission checklist

Before accepting a feature, answer:
1. Which observed user problem does it solve?
2. Which user or workflow is affected?
3. What is the smallest solution?
4. How will success be verified?
5. What new setup and maintenance burden does it add?
6. Can an existing rule, example, or document solve the problem instead?
7. Which maintainer owns it, what recurring work does it add, and what would make us retire it through the existing review process?

If the problem is hypothetical or the benefit cannot be evaluated, defer the feature.
