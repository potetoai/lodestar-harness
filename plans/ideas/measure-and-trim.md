# Plan: measure every run, trim what agents read, calibrate the router

> **Idea plan, not executed as written.** Rated and merged into
> `plans/active/token-efficiency.md` (2026-10-02); see its section 3.

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time and stop after each for the repo owner's approval. Update the
> progress and decision logs at the end when a phase moves. Place this file at
> `plans/active/measure-and-trim.md`.

## 1. Goal

Make Orca cheaper and less interrupting **based on evidence, not guesses**.

- Every agent session leaves one line of numbers: which task, workflow and
  role, how many tokens, what came out of it.
- Each worker reads less policy text before it starts, with a machine check so
  the amount never grows back.
- Workers hand off by reference, and failures are handled by type, so tokens
  are not burned on blind retries.
- Maintenance turns the numbers into proposals for the Router (thresholds,
  approval gates). The owner approves each change; nothing changes by itself.

Today there is no data, so phase 1 (measuring) comes before anything that
changes behavior.

## 2. Context

Source of ideas: Multica (https://github.com/multica-ai/multica), an
open-source board where coding agents are assigned issues like teammates.
Multica is an orchestrator, the same layer as Orca, so it is **not adopted as
a tool** (absolute rule: never build a second orchestration system beside
Orca). Only these ideas are borrowed:

| Multica feature | What it does there | What we take |
|---|---|---|
| Runs + token usage | Every agent execution is its own record, never overwritten; cost is shown per agent and per issue | Phase 1: run ledger |
| Skills vs agent instructions | Instructions are given on every run; a skill is attached only to agents doing that kind of work | Phase 2: always-read core vs read-when sections, with a budget |
| Squad leader protocol | The leader is terse, does not restate the issue (the assignee can read it), stops after dispatching, never implements | Phase 3: hand off by reference |
| Failure reason codes | Platform faults vs agent errors; transient faults retry a bounded number of times; auth/quota/config errors are not retried; context overflow, iteration limit and timeout mean "narrow the scope"; a retry resumes the previous session when that session is still safe | Phase 3: failure classes |
| Inbox | Notifies people only where something needs their attention; several notifications on one issue merge into one | Phase 3: one batched owner message; phase 4: gate decisions by data |

Not borrowed, and why:

- Board, server, database, multi-CLI runtime daemon: Orca already owns
  execution.
- Human review of every diff before merge: the owner does not read code. Orca
  already does better with plain-language criteria + tests-first + reviewer.
- Auto-retry as a default: `router/ORCA-INTEGRATION.md` section 15 forbids
  retry without positive evidence. Phase 3 keeps that and only adds classes
  where the evidence is explicit.

## 3. Current state (surveyed 2026-10-01)

Estimated policy text a worker reads before touching code (characters ÷ 4,
English; a rough token estimate, phase 2 replaces it with a script):

| Who | Files | ~Tokens |
|---|---|---|
| Router, every task | `README.md`, `router/ROUTER.md`, `router/ORCA-INTEGRATION.md` | 7,600 |
| Builder, typical BUILD_REVIEW | `agents/builder.md`, `rules/coding.md`, `rules/testing.md`, `rules/git.md`, `rules/documentation.md`, `workflows/build-review.md` | 9,700 |
| Reviewer, typical BUILD_REVIEW | `agents/reviewer.md`, `rules/coding.md`, `rules/testing.md`, `rules/README.md`, `workflows/build-review.md` | 7,300 |
| Every worker | `.ai/project.md` (template size) | 1,700 |

So one BUILD_REVIEW task costs roughly 28,000 tokens of policy reading before
any code is read, more with fix loops. Largest files: `rules/testing.md`
(~3,600), `router/ROUTER.md` (~3,500), `router/ORCA-INTEGRATION.md` (~3,400),
`rules/coding.md` and `rules/git.md` (~2,400 each), `agents/architect.md`
(~2,200).

Other facts this plan builds on:

- Hooks already read the session transcript with `jq`
  (`feedback-check.sh`), so a Stop hook can read usage the same way.
- `doctor.sh` already warns on a long CLAUDE.md (A11) and the lint baseline
  "only shrinks" (maintenance step 5). The context budget follows the same
  ratchet idea.
- Maintenance runs every 14 days and may run in the cloud; the cloud agent
  cannot see local files.

Unknown, checked in phase 0: what Orca exposes about workers (errors, exit
reason, tokens), and where Claude Code writes subagent transcripts.

## 4. Phases

Each phase is BUILD_REVIEW unless noted. Changes under `enforcement/` must
pass `bash enforcement/test.sh`; docs must pass `bash scripts/check-links.sh`.
Bump `enforcement/VERSION` (minor) in every phase that changes templates, so
projects get it through `bootstrap.sh --upgrade`.

### Phase 0 — Survey (SIMPLE, no code)

Answer in a table added to section 3 of this plan:

1. Does a Claude Code transcript give per-message usage
   (`message.usage`: input, output, cache read, cache write)? Are entries
   repeated per message (dedupe by `message.id`)? Where do subagent
   (sidechain) transcripts go?
2. Which model name is recorded per message?
3. What does Orca report when a worker ends: exit reason, error text,
   provider error codes, timeout vs crash? Can a worker be resumed in the same
   session and worktree?
4. Do Codex (or other non-Claude) workers leave usage anywhere readable? If
   not, they get ledger lines with `null` tokens.
5. Does `git rev-parse --git-common-dir` resolve to the same folder from every
   worktree Orca creates?

Acceptance:

- [ ] Each question has an answer with the command or file that proves it,
  or "unknown" and what blocks it.
- [ ] Phases 1 and 3 are adjusted in this plan to match the answers before
  they start.

### Phase 1 — Run ledger (measure first)

Design:

- The Router starts every Task prompt with one marker line:
  `Orca-Run: task=<id> workflow=<WORKFLOW> role=<role>`. The Router's own
  session uses `role=router`. Add this to `router/ORCA-INTEGRATION.md`
  section 8 (Task Specification).
- New Stop hook `enforcement/agents/claude/hooks/run-ledger.sh`, registered
  in `settings.json` after the existing Stop hooks. It reads the transcript,
  finds the marker in the first user message, sums usage, and writes **one
  line per session** (replacing that session's previous line) to
  `<git-common-dir>/orca-runs.jsonl`. Machine-local, shared by all worktrees,
  never committed.
- Fields: `date`, `session`, `task`, `workflow`, `role`, `agent`, `model`,
  `turns`, `input`, `output`, `cache_read`, `cache_write`, `findings`,
  `routing`.
- `findings`: `agents/reviewer.md` requires the final report to end with
  `Review-Findings: <blocking> blocking, <minor> minor`. The hook copies the
  numbers from the last assistant message.
- `routing`: the Router ends its decision message with
  `Routing-Final: <chosen> (proposed <proposed>)`. The hook copies both, so an
  owner override is visible.
- Privacy: like `feedback-check.sh`, the hook stores no message text, only
  counts and the marker fields.
- No marker: still write a line with `task: null` (unrouted sessions are
  data too).
- Never block: the hook always exits 0, even on parse errors.

Acceptance:

- [ ] After a routed session ends, its ledger file has exactly one line for
  that session, with the right task, workflow and role.
- [ ] Ending the same session again updates that line instead of adding one.
- [ ] Sessions in two different worktrees of one repo write to the same
  ledger file.
- [ ] A reviewer session records its blocking and minor finding counts.
- [ ] A Router session records the proposed and the chosen workflow.
- [ ] No message text appears in the ledger.
- [ ] A broken or missing transcript never stops the agent.
- [ ] `enforcement/test.sh` has fixtures for each line above.

### Phase 2 — Context budget (read less, keep it small)

Design:

- New `router/read-sets.md`: one table, one row per role × workflow, listing
  the files that role must read before work (always-read). Everything else is
  read-when, with its trigger written in `rules/README.md`.
- New `scripts/context-budget.sh`: computes the always-read size of every row
  (characters ÷ 4 until phase 0 proves a better count), compares with
  `router/context-budget.json`, and fails when any row is above its budget.
  CI runs it next to `check-links.sh`.
- First budget = today's measured size. **The budget only shrinks**, like the
  lint baseline. Raising it needs a decision-log entry and owner approval.
- Then shrink, following the repo's absolute rules (move and link, never
  reword rules without review, never delete policy): split the largest files
  into a short always-read core and read-when sections. Candidates, largest
  first: `rules/testing.md` (tests-first mode, E2E and browser levels only
  apply to some tasks), `rules/git.md`, `rules/coding.md`,
  `agents/architect.md`, and parts of `router/ORCA-INTEGRATION.md` that
  explain Orca rather than instruct the Router (section 18 example, repeated
  boundary text).
- `rules/README.md` keeps listing every file with its read-when trigger, so
  "do not assume a rule does not exist" still holds.

Acceptance:

- [ ] Running `scripts/context-budget.sh` prints the always-read size for
  every role × workflow and fails CI when one goes over budget.
- [ ] A builder on a SIMPLE task reads at least 40% less policy text than
  today; a BUILD_REVIEW builder at least 25% less. (Targets; the owner may
  change them at phase approval.)
- [ ] No rule text was reworded or deleted: every moved section can be found
  by its old heading, and `check-links.sh` passes.
- [ ] Every read-when file has a trigger in `rules/README.md` that a worker
  can match to its task.

### Phase 3 — Lean handoff and failure classes

Design:

- **Hand off by reference** (`router/ORCA-INTEGRATION.md` section 8). A Task
  stays self-contained, but points to files instead of pasting them: plan
  path, acceptance criteria path, rule files by name, `.ai/project.md`. Paste
  only what exists in no file. The Router does not restate the user's request
  when the plan file already holds it.
- **Failure classes** (section 15). Keep "no retry without positive
  evidence". Add a table that says what counts as evidence and what to do:

  | Class | Evidence | Action |
  |---|---|---|
  | Transient provider | Explicit 429, 5xx, or network error from the provider | One retry, resuming the same session and worktree if Orca allows it (phase 0); then escalate |
  | Too big | Context overflow, iteration limit, or timeout while still producing output | No retry of the same Task. The Router splits it into smaller Tasks |
  | Owner must act | Auth failure, quota exhausted, missing config or executable | No retry. One plain message to the owner with the exact fix |
  | Poisoned session | Context overflow or invalid request | Any retry starts a new session in the same worktree, so finished work is kept |
  | Unknown | Anything else, including silence | Unchanged: treat as unverifiable, ask Orca for state, never retry blindly |

- **One owner message** (section 14). When several workers need the owner,
  the Router collects the questions into one message in `owner_language`,
  decisions only, each answerable in a line. Workers never message the owner
  directly.

Acceptance:

- [ ] A Task created by the Router names files instead of pasting their
  contents, except text that exists in no file.
- [ ] A Task that ran out of context is split, not rerun as is.
- [ ] A provider rate-limit error is retried once at most, then reported.
- [ ] An expired login or empty quota produces one message telling the owner
  exactly what to do, and no retry.
- [ ] When two workers are blocked at the same time, the owner gets one
  message, not two.
- [ ] A silent or unclear failure is still handled exactly as today.

### Phase 4 — Router calibration in maintenance

Starts only after the ledger has data: at least 10 routed tasks per workflow
being judged. Until then the step just reports "not enough data".

Design (new step in `workflows/maintenance.md`, before Close; local only, the
cloud routine skips it and lists it, because the ledger is machine-local):

- From the ledger, `git log` and `gh pr list` since the last maintenance,
  report per workflow: tasks, median tokens per task, reviewer blocking
  findings per task, rework rate (fix or revert commits within 7 days of
  merge, already found by maintenance step 2), and owner override rate of the
  routing decision.
- Turn the numbers into at most 2 proposals per run, each with its evidence.
  Examples:
  - SIMPLE rework rate is high → tighten the SIMPLE criteria.
  - Low-risk BUILD_REVIEW: reviewer found no blocking issue in nearly every
    task → lighter review (reviewer reads diff + criteria only).
  - Owner almost never overrides the routing decision for low/medium-risk
    BUILD_REVIEW → change Routing Rule 14 to report-and-proceed for that class,
    like SIMPLE. High risk, tests-first (rule 16), destructive operations
    (rule 12) and the COMPLEX plan gate never lose their approval.
- Each proposal is one small PR the owner merges or rejects. Nothing is
  applied without that.

Acceptance:

- [ ] The maintenance report shows tokens, findings, rework and override
  rate per workflow, or "not enough data".
- [ ] Every proposal shows the numbers behind it.
- [ ] No routing rule changes unless the owner approved that PR.
- [ ] Rules 11, 12, 16 and the COMPLEX plan gate cannot be weakened by a
  proposal.

## 5. Order and risk

0 → 1 → 2 → 3 → 4. Phase 2 can start in parallel with 1 (different files).
Phase 4 waits for real data from 1. Highest risk: phase 3, because it changes
how failures are handled; that is why the Unknown class stays exactly as
today.

## Progress log

| Date | Phase | Done | Notes |
|---|---|---|---|
| 2026-10-01 | — | Plan written | Not started |

## Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-10-01 | (proposed) Do not adopt Multica as a tool; borrow ideas only | It is an orchestrator like Orca; its review model assumes a human reads diffs |
| 2026-10-01 | (proposed) Measure before changing routing | No data exists today; threshold changes would be guesses |
| 2026-10-01 | (proposed) Context budget only shrinks | Same ratchet as the lint baseline; stops policy text from growing back |
| 2026-10-01 | (proposed) Retry only on explicit transient evidence | Keeps section 15 intact; blind retries burn tokens twice |
