# Idea: criteria-to-evidence table and fact/assumption marking

> **Idea plan, not rated.** Rate it in an active plan before any work
> (`plans/ideas/README.md`).

## 1. Why

On 2026-11-12 the owner asked for a review of an outside plan that proposed
adopting GitHub Spec Kit's spec-driven development (specify, clarify, plan,
tasks, analyze, converge) into Lodestar. Most of it already exists: the
workflows and risk levels cover its NONE/LEAN/FULL modes, the intake gate
covers specify and clarify, the critic and tests-first mode cover analyze,
and `rules/` plus `.ai/project.md` cover its constitution. The owner decided
not to adopt Spec Kit. Two small ideas were kept for rating.

## 2. Idea A: criteria-to-evidence table at the final review

The reviewer (or QA) writes one row per acceptance criterion: PASS, FAIL,
NOT VERIFIED or NOT APPLICABLE, with the evidence (test name, command
output, file and line). Code that exists is not evidence that it works.

- Gap today: `agents/reviewer.md` checks criteria against tests only in
  tests-first mode; BUILD_REVIEW work has no per-criterion check.
- Catches: a criterion with no test, reported as done.
- Limit: the agent writes the table; no hook checks it. A checklist, not a
  lock. Adds some tokens per review.
- Rate against: has an agent reported done while a criterion was unmet?
  If no case is found, the value is small.

## 3. Idea B: mark facts, assumptions and open questions in plans

In a plan's criteria, mark what the owner said versus what the agent
assumed, and mark open questions that change behavior, security or data.
A low-risk assumption may proceed if written down and reversible; a
material one (for example an authorization rule) is asked, not assumed.

- Gap today: the intake gate asks on ambiguity but has no marker for
  assumptions that went unasked.
- Limit: text-only rule, no machine check.

## 4. Not adopted (owner decision, 2026-11-12)

- A separate NONE/LEAN/FULL mode selector: it would be a second router.
- Framework-specific checks (mobile, OAuth, web) in the harness: they
  belong in a consuming project's own skill.
- Installing or copying Spec Kit, and a multi-run benchmark phase.
