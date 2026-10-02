# Plan: Retrieval, Advisory Triggers & Model Tiering

> **Idea plan, not executed as written.** Rated and merged into
> `plans/active/token-efficiency.md` (2026-10-02); see its section 3.

Status: proposed
Owner: Lodestar-harness
Scope: policy only (router, rules, agents, enforcement). Execution stays in Orca.

## Goal

Cut cost/usage per task and reduce human interventions without lowering the
verification bar.

Two levers:

1. Move retrieval work off the expensive model: deterministic tools first,
   RAG for prose, a cheap LLM explorer only as a last resort.
2. Call expensive judgment (critic) only at high-risk moments, and stop
   retry loops with fixed rules.

## Non-goals

- No orchestration logic (spawning, threads, scheduling, auto-review
  mechanics). Orca owns these. Lodestar only declares *what* and *when*.
- No large-scale sampling or voting layer for micro-decisions. Fixed rules
  are cheaper.
- No vector RAG over source code as the primary code-search method.

---

## Phase 0: Baseline (do first)

Without a baseline, no later phase can be judged.

- Pick a fixed benchmark set of 5–10 representative tasks, mixing simple,
  build-review and complex.
- For each run, record:
  - tokens per role, and cost per role (price-weighted)
  - human interventions (count + reason)
  - first-pass verification rate
  - number of retries and repeated-error loops
- Add the metric template to `workflows/maintenance` so it is re-measured
  every 14 days.

Exit: baseline numbers committed under `plans/metrics/`.

## Phase 1: Deterministic retrieval layer

Code search with zero LLM judgment.

- Register in `skills/capabilities.md`:
  - `ripgrep`: exact symbol/string search
  - LSP: go-to-definition, find-references
  - repo map (tree-sitter): files, classes, functions, signatures
- `enforcement/`:
  - hook regenerates the repo map after each commit
  - `doctor.sh` fails if the repo map is older than HEAD
- `rules/retrieval.md` (new): workers must try deterministic tools before
  reading whole files or calling an explorer.

Exit: the repo map is generated and kept fresh on 1 real project.

## Phase 2: RAG for prose and selective rule loading

- Index `rules/`, `.ai/project.md`, architecture notes and API docs.
- Router attaches only the rules relevant to the task, instead of the full
  `rules/` set, to each worker's context.
- The index is rebuilt by the same enforcement hook, and `doctor.sh` checks
  that it is fresh.
- A `rules/README.md` index stays the fallback when retrieval returns
  nothing.

Exit: average worker context size drops versus baseline, with no rise in
rule violations caught by enforcement.

## Phase 3: Router changes (`router/ROUTER.md`)

### 3.1 Retrieval order

1. Deterministic tools (Phase 1)
2. RAG over prose (Phase 2)
3. `explorer` agent, only if the question needs multi-step synthesis across
   results (e.g. "which modules does the auth flow pass through")

### 3.2 `model_tier` in router output

| Role | Tier |
|---|---|
| builder / architect | high |
| critic | high |
| tester, explorer, researcher | medium |

Document the tier → model mapping in `router/ORCA-INTEGRATION.md`.

### 3.3 Critic triggers

Critic is advisory, read-only and never writes code. The router calls it
only at:

- **plan gate**: before implementation of a non-simple task
- **repeat failure**: the same error occurs a second time
- **pre-done**: before reporting completion on build-review/complex

The `simple` workflow never calls critic.

### 3.4 Failure escalation (`rules/failure.md`, new)

1. A failure allows at most 1 retry with a changed approach.
2. The same error a second time → critic.
3. Still failing after the critic's advice → escalate to a human, with a
   summary of attempts.

A human is only called at step 3.

Exit: router docs updated, and 3 benchmark tasks routed correctly by hand
review.

## Phase 4: `explorer` / `researcher` roles (pilot)

New files `agents/explorer.md` and `agents/researcher.md`.

Constraints:

- **Locate, never conclude.** No root-cause analysis, no fix proposals.
- **Pointer output only**, in a strict format:
  ```
  found:
    - path: src/auth/session.ts
      lines: 40-72
      excerpt: <≤15 lines>
      why: <one line>
  not_found: [<queries with no result>]
  uncertain: [<items needing builder check>]
  ```
- The builder verifies pointers by opening only the cited ranges.
- Router threshold: call explorer only when the search spans more than 10
  files, or after Phase 1 tools returned nothing useful.
- Pilot in the `complex` workflow only.

Feedback loop:

- The builder logs `explorer_miss` when a pointer is wrong or missing.
- If the miss rate for a task type exceeds 20% in the maintenance review,
  raise that type's explorer to the high tier, or disable explorer for it.

Exit: the pilot has run on the benchmark set with the miss rate measured.

## Phase 5: Evaluate & roll out

- Re-run the Phase 0 benchmark and compare all metrics.
- Roll out explorer to `build-review` only if:
  - cost per task drops, and
  - first-pass verification does not drop, and
  - the explorer miss rate is ≤ 20%
- Otherwise keep Phases 1–3 (low risk) and revise Phase 4.

---

## Expected impact (estimates, to be validated)

| Change | Est. cost reduction | Risk |
|---|---|---|
| Deterministic retrieval + repo map | high on large repos | low (stale index → guarded by doctor) |
| Selective rule loading | small but on every task | low |
| Critic by trigger | 5–15% if critic currently runs every task | low |
| Failure escalation rules | large on stuck tasks | low |
| Explorer on cheap model | 0–30%, can be negative | **medium**: wrong pointers cause rework |

Raw token count may stay flat. The main gain is price-weighted cost and
fewer human interventions.

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Explorer returns wrong info → rework costs more | Pointer-only output, builder verifies, miss-rate feedback, pilot first |
| Stale repo map / RAG index | Rebuild on commit, `doctor.sh` freshness check |
| Selective rule loading misses a needed rule | `rules/README.md` fallback, enforcement still runs all checks |
| Critic triggers too rare → late detection | Track defects found after done, tune triggers in maintenance |
| Policy drifts into orchestration | Review every change against "never build a second orchestration system" |

## Order of work

Phase 0 → 1 → 3 → 2 → 4 → 5

Phases 1 and 3 are low-risk and deliver most of the value. Phase 4 is the
only experimental part.
