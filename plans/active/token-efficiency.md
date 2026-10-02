# Plan: token efficiency, by evidence

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time and stop after each for the repo owner's approval. Answer
> nothing in "Open questions" yourself. Update the progress and decision logs
> when a phase moves.

## 1. Why this plan

Four idea plans in `plans/ideas/` (`token-diet.md`, `context-budget.md`,
`measure-and-trim.md`, `lodestar-efficiency-plan.md`) all aim at fewer tokens and fewer owner steps.
They overlap, and all assume the main cost is the policy text agents read at
startup (estimated 19k–35k tokens per task). This plan measures real sessions
first, rates each idea against the numbers, and keeps only what pays.

A fifth source, an untracked "Orca Workflow v2" framework spec, was rated on
2026-10-02 (idea 21 and the decision log) and then deleted.

## 2. Evidence (measured 2026-10-02)

Source: 50 Claude Code sessions of 5+ turns, 2026-09-23 to 2026-10-02 (vn30
worktrees, Orca-workflow, this repo), read from `~/.claude/projects/*.jsonl`.
Cost is price-weighted per token: input 1, cache write 1.25, cache read 0.1,
output 5. Shares below overlap (a long-session turn also carries the base
context), so they do not add to 100%.

| Where the cost goes | Share of cost |
|---|---|
| Turns whose context is above 150k tokens (long sessions; 10 of 50 ran 150+ turns, peak 947k) | **63%** |
| Carrying the base context on every turn (median 63k at turn one: Claude Code prompt, tools, skill list, CLAUDE.md, memory) | 21% |
| Output tokens | 12% |
| Subagents | 1.3% |
| Reading Lodestar policy files (upper bound; median ~1k per session, max 37k) | **≤ 2.2%** |
| Turns forced by a Stop hook | 11 of 4,413 turns (0.25%) |

Simulation on the same sessions: had each session written a handoff and
restarted at ~90k context once it passed a threshold, cost would fall by
35% (threshold 150k, 73 restarts), 33% (200k, 33 restarts) or 32% (120k, 159
restarts). This is an upper estimate: it ignores work lost across a restart.

Tool output: `Read` is 42% of all tool-result tokens; a few whole-file reads
cost 40k–60k each. Owner questions: 121 `AskUserQuestion` calls in 50 sessions.

Limits: Codex and other non-Claude workers are not in the data; subscription
limits may weight tokens differently from API prices.

## 3. Rating of every idea

Rating: **Do** (clear payoff, cheap) · **Optional** (owner's choice, mostly
saves owner steps, not tokens) · **Later** (revisit with phase-4 data) ·
**Drop** (cost or risk above the payoff).

| # | Idea (source) | Expected effect, from section 2 | Rating |
|---|---|---|---|
| 1 | Context-size nudge: past a threshold, the agent finishes the step, writes `.ai/handoff.md` and asks for `/clear` (new) | Up to ~30% of all cost; also better agent quality | **Do** |
| 2 | Base context audit: `/context`, turn off unused plugins and MCP servers (new) | ~3% of cost per 10k removed; measured base is 34k, ~7k removable | **Later** (was Do) |
| 3 | Usage report script from transcripts (measure-and-trim P1, simplified: offline script, no Stop hook, no ledger) | No saving itself; makes every later claim checkable | **Do** |
| 4 | Read large files by range after grep (new; replaces retrieval layer) | Small; removes the 40k–60k whole-file reads | **Do** (one rule line) |
| 5 | Fix README line 30: a dispatched worker reads only its brief (token-diet P3.1) | Small; removes a contradiction with global `CLAUDE.md` | **Do** |
| 6 | Cap lint-hook output at 30 lines (token-diet P1.3) | Small; guards against a rare large dump | **Do** |
| 7 | Low/medium-risk BUILD_REVIEW proceeds without routing approval; one-line routing output (token-diet P5.1–2, context-budget P5) | Tokens: ~0. Saves one owner reply per normal task | **Optional** (Q2) |
| 8 | Router card, rules CARD, worker briefs, ORCA-INTEGRATION only when dispatching, padding removal (token-diet P2–3, context-budget P1–3) | At most ~1–1.5% of cost; large policy rewrite needing review | **Later** |
| 9 | CI context budget (context-budget P0/P4, measure-and-trim P2) | Guards a 2% slice; extra CI script | **Later** |
| 10 | Stop hook: skip verify when nothing changed, lint only in red phase (token-diet P1.1–2) | Tokens ~0.25%; saves wall time only | **Later** |
| 11 | Feedback-hook word list (token-diet P1.4) | Few false triggers seen | **Later** |
| 12 | Scale critic, tests-first reviewer, COMPLEX phase skip, COMPARE sketches first, architect output by size (token-diet P4, P3.4) | Subagents are 1.3% of cost | **Later** |
| 13 | Maintenance bounds (token-diet P5.3) | Runs every 14 days; small | **Later** |
| 14 | Failure classes, one batched owner message (measure-and-trim P3) | Depends on what Orca reports; rare events | **Later** |
| 15 | Router calibration from data (measure-and-trim P4) | Needs 10+ tasks per workflow of data | **Later** |
| 16 | Model tier per subagent role (efficiency P3.2) | Subagents are 1.3%; saving < 1% | **Drop** |
| 17 | Repo map, LSP, tree-sitter, RAG over rules (efficiency P1–2) | Grep and Glob already exist; ~20 rule files; new hooks and doctor checks to maintain | **Drop** |
| 18 | Explorer/researcher roles on a cheap model (efficiency P4) | Built-in Explore agent exists; wrong pointers cause rework | **Drop** |
| 19 | Critic triggers and failure escalation (efficiency P3.3–3.4) | `rules/principles.md` §1 already covers repeated failure | **Drop** |
| 20 | Briefs with hash checks (context-budget P3) | Maintenance cost above a ~1% saving | **Drop** |
| 21 | Framework spec "Orca Workflow v2": task analyzer, context router with layers and token budgets, YAML workflows run by code, cost-estimating router, knowledge engine, per-task execution logs | Capability-based agents, risk-scaled workflows, verify-before-done, two-failure stop (`skills/investigate.md`), human gates and learning from mistakes already exist. The rest builds an orchestrator (repo rule), targets the ≤ 2.2% policy-reading slice, or guesses costs before measuring | **Drop** |
| 22 | Fixed-format routing line (`Lodestar route: <WORKFLOW> risk=<level>`) that `scripts/usage-report.py` counts: cost per workflow, SIMPLE calls that escalated, corrections per workflow (from idea 21, observability) | No saving itself; gives idea 15 its data at the cost of one rule line and a small script change | **Do** (was Later; done early so phase 4 has data) |

## 4. Phases

Each phase is one PR. Repo rules apply: `bash enforcement/test.sh` for
`enforcement/` changes (bump `enforcement/VERSION`), `bash scripts/check-links.sh`
for docs, LF line endings, move and link instead of deleting policy.

### Phase 0 — Usage report (idea 3)

- Add `scripts/usage-report.py`: reads `~/.claude/projects/<dir>/*.jsonl` and
  subagent transcripts, dedupes by message id, and prints per session: turns,
  peak context, price-weighted cost, policy-file reads, forced hook turns;
  then the section 2 table for a date range. No hook, nothing in projects.
- Record the section 2 numbers as the baseline in the progress log.

Done when: running it for 2026-09-23..2026-10-02 reproduces section 2.

### Phase 1 — Context-size nudge (idea 1)

- New hook `context-nudge.sh` (template 2.1.0). On `UserPromptSubmit`, and
  once per threshold crossing on `PostToolUse`, it reads the last usage in
  the transcript. Above the threshold (Q1) it prints one line to the agent:
  finish the current step, overwrite `.ai/handoff.md`, then ask the owner to
  type `/clear` and "continue". It never blocks and always exits 0.
- Check whether Claude Code has a setting to auto-compact earlier; if so,
  record it in `enforcement/setup-guide.md` as an option, not a default.
- `enforcement/test.sh`: below the threshold prints nothing; above prints
  the line once; a missing transcript exits 0 silently.

Done when: tests pass, and in one real session the nudge fires once and the
agent writes the handoff.

### Phase 2 — Base context audit (idea 2)

- The owner types `/context` in a fresh session and pastes the result.
- List each plugin, MCP server and skill set with its size and last use.
  The owner picks what to turn off (reversible, as the skills-off move was).
- Record what was turned off and the new base size in
  `enforcement/setup-guide.md`, so other machines can do the same.

Done when: the base context at turn one is measured before and after.

### Phase 3 — Small fixes (ideas 4, 5, 6; idea 7 if Q2 is yes)

- README line 30: a dispatched worker reads only its brief and the files a
  finding needs (matches global `CLAUDE.md` "For subagents").
- One rule line where workers read it: for a large file, grep first and read
  the range, not the whole file.
- `lint-file.sh`: print at most 30 lines, then "… N more lines".
- If Q2 is yes: ROUTER rule 14 and the approval gate let low/medium-risk
  BUILD_REVIEW announce one line and proceed; high risk, tests-first,
  COMPLEX, COMPARE and destructive operations keep their gate.

### Phase 4 — Measure and decide on "Later"

After about two weeks of normal work, rerun `scripts/usage-report.py` for the
new period. Compare with the baseline, and read the route table (idea 22,
added 2026-10-02): routed sessions only, and say how many had no line.
For each Later item, record in the
decision log: start, keep waiting, or drop, with the number behind it. Then
move this plan to `plans/completed/`.

## 5. Open questions (answered 2026-10-02)

- **Q1:** nudge threshold. **200k**: nearly the same saving as 150k (33% vs
  35%) with less than half the restarts (33 vs 73 in the sample).
- **Q2:** low/medium-risk BUILD_REVIEW proceeds without routing approval?
  **Yes**, with the limits in phase 3.
- **Q3:** the four source plans: **moved to `plans/ideas/`**, each with a
  pointer to this plan.

## 6. Not in scope

- Orchestration (Orca's job).
- Weaker safety: locked tests, sensitive gate, CI and approvals stay.
- Main-session model choice: a large price lever, but a quality trade the
  owner makes per task, not a policy.

## 7. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-10-02 | — | Plan merged from four idea plans; section 2 measured from 50 sessions |
| 2026-10-02 | 0 | `scripts/usage-report.py` added. Baseline: `--since 2026-09-23 --until 2026-10-02 --match '^(D--AI-Lodestar-harness\|D--AI-Orca-(Orca-workflow(-vn30)?\|ProjectS-.*\|test-sandbox-chi-tieu)\|F--MyProjects-ProjectS)$'` gives 50 sessions: long turns 62.6%, base 20.6%, output 11.9%, subagents 1.4%, policy ≤ 2.2%, hook turns 11/4,446, 123 owner questions; restart at 200k −33% (33 restarts) |
| 2026-10-02 | 1 | Global hook `context-nudge.sh` (PostToolUse, via `global/install.sh`): past 200k it asks once per 100k step for handoff + `/clear`; ~0.4 s per tool call on Windows. Global, not template 2.1.0: the costliest sessions ran in this repo, which has no project hooks. `CLAUDE_CODE_AUTO_COMPACT_WINDOW` / `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` noted in `setup-guide.md` as an option |
| 2026-10-02 | 2 | Owner's `/context` in a fresh session: 34.3k base (tools 19.9k, skills 7.3k for 56 skills, memory 1.9k, MCP 1.4k, system 2.4k). The 2026-10-02 skill trim already halved the old 63k median; what is left to cut is ~1–2% of cost. Phase 2 moves to Later |
| 2026-10-02 | 3 | README: a worker reads only its brief, the files it names, and the files a finding needs. `rules/coding.md` §1: grep, then read a large file by range. `lint-file.sh` prints at most 30 lines plus "... N more lines" (template 2.1.0, test added). ROUTER rule 14, the approval gate and ORCA-INTEGRATION: SIMPLE and low/medium-risk BUILD_REVIEW announce one line and proceed; high risk, tests-first, COMPARE, COMPLEX keep the gate; rule 12 (destructive ops) unchanged. `workflows/simple.md` escalation still waits: a wrong SIMPLE call is the case to check |
| 2026-10-02 | 4 (prep) | Idea 22: ROUTER approval gate asks for `Lodestar route: <WORKFLOW> risk=<level>` (plus `escalated-from=<old>` on a re-route; `workflows/simple.md` too). `usage-report.py` prints tasks, cost share, cost per task and owner messages per task by workflow (a subagent's cost goes to the route open when it started), escalations, and sessions with no line. Owner messages are a proxy for corrections: approvals and follow-up questions count too |

## 8. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-10-02 | Rate ideas by measured cost share, not by estimated reading size | Policy reading measured ≤ 2.2% of cost, long sessions 63% |
| 2026-10-02 | Measure with an offline script, not a Stop hook ledger | Same numbers, nothing added to every project |
| 2026-10-02 | Owner: nudge at 200k; low/medium BUILD_REVIEW proceeds; idea plans to `plans/ideas/` | Answers to Q1–Q3 |
| 2026-10-02 | Nudge is a global hook, not a project template hook | Covers every session on the machine, including this repo; no project upgrade needed |
| 2026-10-02 | Phase 2 (base context audit) to Later | Base is already 34k; the rest is ~1–2% of cost |
| 2026-10-02 | Owner: small low/medium-risk changes get a same-session review step, not a subagent reviewer (`workflows/build-review.md`, Review cost) | Phase 3's Haiku reviewer cost ~45k weighted tokens (32.8k of it start cost) for a 2k-token diff, ~12% of the task, and its one finding was wrong |
| 2026-10-02 | Framework spec (idea 21) dropped; its observability point kept as idea 22; spec file deleted | Most of it already exists; the rest is an orchestrator or rests on unmeasured cost guesses. Owner approved |
| 2026-10-02 | Owner: do idea 22 now, not at phase 4 | Data only builds up after the line exists; waiting loses two weeks of it. Cost is one rule paragraph and a script change |
