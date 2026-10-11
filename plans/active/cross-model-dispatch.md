# Plan: cross-model dispatch

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time and stop after each for the repo owner's approval. Answer
> nothing in "Open questions" yourself. Update the progress and decision logs
> when a phase moves.

## 1. Why this plan

The owner wants to state a task and nothing else: the Router decides when a
role goes to a second model family (today Codex) instead of a Claude
subagent. The owner never writes a worker prompt and never picks the agent.

Today `router/ROUTER.md` ("Agent Selection") lists "Claude or Codex" for
every kind of task with no criteria, and `router/ORCA-INTEGRATION.md`
section 6 says the choice "may change" without saying when. With no rule,
every role goes to Claude. The machine checks are ready for a second model
(Codex runs the same hooks through `.codex/hooks.json`), but nothing sends
work to it.

## 2. What is known (2026-10-12)

- Codex 0.162.1 inside Orca ran every Lodestar hook in a trusted project:
  sensitive gate, install guard, approvals-log guard, `--no-verify` block,
  Stop hook.
- Codex stores hook trust per Codex home and per `.codex/hooks.json` path.
  It skips untrusted hooks silently. A new worktree is a new path.
- The Stop hook sends Codex back only once; it may end with `make verify`
  still failing. CI is the gate.
- In its Windows sandbox Codex cannot find `make`, so it cannot run
  `make verify` itself (hooks run outside the sandbox and work).
- A long pasted prompt reached Codex cut and doubled. Not yet known whether
  a `--spec` brief has the same limit.
- Subagents are 15.2% of cost (critic 5.5%, reviewer 4.1%, tester 3.7%);
  each Claude subagent run costs 38k-47k before it reads anything
  (`plans/completed/token-efficiency.md`, phase 4). Codex cost per run is
  not measured.
- `workflows/build-review.md` ("Review cost"): a small low/medium-risk
  change gets a same-session review, no subagent. This plan does not change
  that.

Not known: whether an Orca-dispatched Codex worker starts, reports back and
keeps the hooks; what one run costs in time and tokens; whether a second
model finds things a Claude reviewer misses. Phase 0 and phase 2 answer
these before any rule becomes a default.

## 3. Phases

Each phase is one PR. Repo rules apply: `bash enforcement/test.sh` for
`enforcement/` changes (bump `enforcement/VERSION`),
`bash scripts/check-links.sh` for docs, LF line endings, move and link
instead of deleting policy. Nothing here builds orchestration: the runtime
starts and tracks workers; Lodestar only says who gets which role.

### Phase 0 — Evidence before rules

Throwaway folder only (no real repo, no PR, delete everything after).

- Make a throwaway git project, bootstrap it with the Lodestar template,
  trust its hooks in Codex.
- From a Claude session inside Orca, load the Orca orchestration skill
  (`orca skills list`, `orca skills get`), then run one full dispatch:
  `orca orchestration worker-start --agent codex --spec "<brief>"` with a
  review brief on a small prepared diff.
- Record:
  1. Does the worker start, and does its result come back (`worker-read`,
     `worker_done`) without the owner touching anything?
  2. Does it get a new worktree, or work in the current one?
  3. Do the Lodestar hooks run there? Test with one action a hook must
     block. If the hooks are skipped, which of these works: dispatch into
     the current worktree, a trust step, or neither?
  4. Does a brief of normal length (the section 8 task spec, about 30
     lines) arrive whole?
  5. Wall time and tokens of the run, next to a Claude subagent reviewer
     on the same diff.
  6. Without Orca: can plain `codex exec` do the same from a Claude
     session? (Decides whether the rule needs Orca or only Codex.)

Done when: the six answers are in the progress log, and the throwaway
folder and its Codex trust entries are gone.

Stop rule: if hooks are skipped and no option in item 3 works, the plan
stops here. A worker that edits files with no hooks is not allowed; the
only case left would be read-only review (Q4).

### Phase 1 — The rule

Principle: use a second model where a different model adds value, never to
split work evenly. Draft, to be cut down by phase 0 and the answers in
section 4:

1. **Cross review.** When a workflow already calls for a reviewer in a
   separate worker, the reviewer is the other model family than the
   builder.
2. **INDEPENDENT_COMPARE.** One solution from each model family.
3. **High risk, tests-first, `sensitive_paths`.** The critic that attacks
   the acceptance criteria before the owner approves is the other model
   family than the one that wrote them.

Unchanged: SIMPLE and the same-session review of small low/medium-risk
changes stay with one model. The rule replaces a worker that would run
anyway; it does not add a worker (case 3 swaps the critic, it is not a
second critic pass, unless Q1 says otherwise).

The rule is generic: "when a second model family is available in the
runtime", not "Codex on this machine". Fallback, stated in the rule: when
no second model is available, the orchestrator is absent, or the project's
hooks are not trusted for it, use a subagent of the same model and say so
in the routing decision. The Router checks availability; it never asks the
owner to pick.

Files: `router/ROUTER.md` ("Agent Selection": keep "never permanently
assign a model to a role", add the criteria), `router/ORCA-INTEGRATION.md`
section 6, and one pointer line each in `workflows/build-review.md`,
`workflows/independent-compare.md` and `rules/testing.md` (tests-first
critic). The routing decision's `agents` list names the model family per
role, so the owner sees the choice without asking.

Done when: links pass, a critic has read the rule text, and the owner
approves the PR.

### Phase 2 — One real task

One small low-risk task in a real project, picked by the owner, run with
the new rule from a plain task statement. The owner writes no worker
prompt. Record what the Router chose and why, time, tokens, what the
second model found that the first did not, and every owner step that was
needed.

Done when: the task is merged and the record is in the progress log.

### Phase 3 — Measure and decide

For each of the three cases: keep as default, make opt-in, or drop, with
the number behind it in the decision log. Then move this plan to
`plans/completed/`.

## 4. Open questions (for the owner)

- **Q1:** Which of the three cases are on by default, and which only when
  the owner asks? Recommendation, to be checked against phase 0 numbers:
  case 1 on by default (it swaps a worker, adds none); case 2 follows
  INDEPENDENT_COMPARE, which already waits for approval; case 3 as a swap
  on by default, as an extra pass opt-in.
- **Q2:** Does Codex usage count against a separate subscription limit
  from Claude? If separate, moving reviews to Codex also frees Claude
  budget; if not, the rule only pays where it finds more.
- **Q3:** May the second model ever be the builder (it is in case 2), or
  only reviewer and critic outside INDEPENDENT_COMPARE?
- **Q4:** If phase 0 shows hooks are skipped in a dispatched worker, is a
  read-only second-model reviewer (it reads the diff, edits nothing) still
  worth having?

## 5. Not in scope

- Orchestration: starting, tracking and settling workers is the runtime's
  job.
- Weaker safety: hooks, locked tests, the sensitive gate, CI and approvals
  apply to every model the same way.
- A fixed model per role ("Codex = backend").
- Subagent cost (idea 12) and naming the Codex home in `doctor.sh` A4c:
  each needs its own plan. Phase 0 numbers feed idea 12.

## 6. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-10-12 | — | Plan written from the owner's request and the Codex hook tests of the same day |

## 7. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-10-12 | Evidence (phase 0) before any rule text | Hook trust is per path; a dispatched worker with silent, skipped hooks would break the harness's main promise |
| 2026-10-12 | The rule swaps a worker for the other model; it adds no worker | Subagents are already 15.2% of cost and the owner watches tokens |
