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

- **Q5 (from phase 0):** the Codex worker cannot report back through
  Orca from its sandbox. Options: (a) the brief asks for a report file
  and the Router reads the file and the transcript instead of waiting for
  `worker_done`; (b) plain `codex exec` without Orca, which returns when
  done (worked in 73 s, hooks run when trusted); (c) wait for an Orca or
  Codex fix. Recommendation: (b), with (a) when Orca is the runtime.
- **Q6 (from phase 0):** on the test diff the Claude reviewer found more,
  faster. Go on to phase 1 with a narrower rule (second model only as an
  extra opinion on high-risk work, opt-in), run a larger comparison first,
  or stop the plan?

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
| 2026-10-12 | 0 (part) | Throwaway project bootstrapped (python, template 2.3.1, `sensitive_paths: src/billing/**`), a diff with planted bugs on a branch, registered in Orca. Item 1: `worker-start --agent codex` refused, `agent_unconfigured`: Codex is in Orca's disabled agent list on this machine (owner's setting, not changed). Nothing started, no worktree made. Item 2, from the Orca skill: the default placement is the current or an exact existing workspace (`--worktree current`); a new worktree is made only on request (`new-child`, `new-top-level`) |
| 2026-10-12 | 0 (part) | Item 6, plain `codex exec --sandbox workspace-write` from a Claude session, hooks not trusted: ran with no owner step, 73 s, 175k input tokens (154k cached), 1.8k output. Item 4: the 25-line brief arrived whole (end marker quoted back). Item 3, untrusted case: the probe edit of a `sensitive_paths` file was applied, no hook ran and nothing said so (tool result `{}`). Review quality: found the planted even-length median bug, missed the division by zero in `percent_change` and the missing tests. Codex also could not run `make` (known). `codex exec` has a `--dangerously-bypass-hook-trust` flag (runs hooks without stored trust for one run); the auto mode classifier refused the test run with it |
| 2026-10-12 | 0 (open) | Waiting on the owner: enable Codex in Orca and trust the throwaway project's hooks (`/hooks`), then items 1, 3 (trusted case) and 5 (same diff with a Claude subagent reviewer). One `config.toml` entry for the throwaway folder was added by the run |
| 2026-10-12 | 0 | Owner enabled Codex in Orca and trusted the hooks (doctor A4c passed). Item 1: `worker-start --spec ... --worktree id:<existing> --agent codex` started a background worker in about a minute; the review and the report file were done about 1 minute after the turn began. **The result did not come back**: the worker's `orca orchestration send` (its `worker_done`) failed after 106 s inside the Codex sandbox ("Could not read Orca runtime metadata ... Orca is not running"), so `check --wait` timed out at 9 minutes with no message. The coordinator found the result only by reading the transcript (`worker-read`) and the report file, then had to `worker-stop` the worker. Item 2: the worker ran in the existing checkout (`worktree: reused`); no new worktree. Item 3, trusted case: the probe edit of the `sensitive_paths` file was refused by the PreToolUse hook with the full sensitive-gate message, and the Stop hook fired (`make verify` failed, `ruff` not installed; Codex stopped after the one hold). Item 4: brief arrived whole. Review quality the same as the direct run: the even-length median bug found, the division by zero missed. Tokens of the Orca run are not in the transcript Orca returns |
| 2026-10-12 | 0 | Item 5, same diff, Claude subagent reviewer (brief without the hook probe): 12 s, 37.6k tokens, 2 tool calls. It found both planted bugs (even-length median, division by zero in `percent_change`), plus the empty-list crash, a sign question on a negative baseline, and the missing tests. Codex, both runs: 1 of 2 planted bugs, nothing else; 73 s and 175k input tokens (154k cached) in the direct run. One small diff, one run each: a direction, not a measure. Cleanup: the Orca project entry is removed and the folder emptied; 7 `config.toml` entries for the throwaway folder remain in the Orca Codex home (owner's call, same as the earlier 7) |

## 7. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-10-12 | Evidence (phase 0) before any rule text | Hook trust is per path; a dispatched worker with silent, skipped hooks would break the harness's main promise |
| 2026-10-12 | The rule swaps a worker for the other model; it adds no worker | Subagents are already 15.2% of cost and the owner watches tokens |
| 2026-10-12 | Phase 0 stop rule not hit: hooks run for a dispatched Codex worker when it is placed in an existing checkout whose hooks the owner has trusted. The rule must dispatch only there and must check trust first (doctor A4c) | Trusted: the sensitive gate refused the probe. Untrusted: the same edit was applied with no hook and no warning |
| 2026-10-12 | Open for the owner before phase 1: how the result comes back (Q5), and whether phase 1 goes ahead at all (Q6) | The Codex worker could not send `worker_done` from its sandbox, so the coordinator waited 9 minutes for nothing; and on the one test diff Codex found less than the Claude reviewer, slower |
