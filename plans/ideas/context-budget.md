# Plan: cut the fixed context cost of every task

> **Idea plan, not executed as written.** Rated and merged into
> `plans/active/token-efficiency.md` (2026-10-02); see its section 3.

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time and stop after each for the repo owner's approval. Update the
> progress and decision logs at the end when a phase moves. Place this file at
> `plans/active/context-budget.md`.

## 1. Purpose

Orca has two goals: people get real work out of agents with as few human steps
as possible, and the work costs as few tokens as possible. The routing and the
machine checks already serve the first goal well. The second goal has a gap:
every task pays a large, fixed amount of policy reading before the agent reads
a single line of the project's code, and that amount barely changes with the
size of the task. Changing a button colour costs almost as much policy context
as a cross-layer feature.

This plan makes the context an agent loads **scale with the task**, the same way
the Router already makes the number of agents scale with the task.

## 2. What the owner wants from this plan

1. **Fewer tokens per task, measured.** The fixed policy load falls by more than
   half on the common paths (SIMPLE, BUILD_REVIEW). Numbers in section 6.
2. **No loss of quality.** The Router picks the same workflow, risk level and
   tests-first mode as today on a fixed set of sample tasks. Under-routing a hard
   task to SIMPLE is the failure to guard against (Routing Rule 11).
3. **No policy lost.** Every rule in `rules/` still exists and is still the
   source of truth. Nothing is deleted; text is moved and linked (repo
   `CLAUDE.md`, absolute rules).
4. **The budget is a machine rule, not a promise.** CI fails when a load path
   grows past its budget, the same way CI fails when `make verify` fails. Without
   this the savings erode one paragraph at a time.
5. **Fewer human steps where the machine already guards.** Optional, owner
   decides (Q2): a low-risk BUILD_REVIEW no longer waits for a routing approval.

## 3. Current state (measured 2026-10-01)

Estimate: characters ÷ 4 ≈ tokens. Project files use the templates as a proxy;
real `.ai/project.md` files vary. Which rule files a worker reads is an
assumption based on `README.md` ("the rules that apply"): coding, testing, git.

| Load path | Files | ≈ Tokens |
|---|---|---|
| Router, any task | global bootstrap, `README.md`, `router/ROUTER.md`, `router/ORCA-INTEGRATION.md`, project `CLAUDE.md`, `.ai/project.md` | 10,200 |
| SIMPLE worker | `agents/builder.md`, `workflows/simple.md`, `rules/README.md`, coding, testing, git, project files | 11,600 |
| BUILD_REVIEW builder | as above with `workflows/build-review.md` | 11,700 |
| BUILD_REVIEW reviewer | `agents/reviewer.md`, build-review, coding, testing, git, architecture, project files | 12,900 |

So a SIMPLE task carries about **21,800 tokens** of policy, and a BUILD_REVIEW
task about **34,800**, before any project code, task spec, or tool output.
Prompt caching lowers the price of repeated reads but not the room they take in
the context window, and a fuller window makes the agent worse (bootstrap rule 5).

Where the weight comes from:

- **Duplication.** Workflow descriptions live in three places: `ROUTER.md`
  "Workflow Types", `ORCA-INTEGRATION.md` section 5, and `workflows/*.md`.
  Capability selection lives in `ROUTER.md`, `ORCA-INTEGRATION.md` section 7 and
  `skills/capabilities.md`. Verification lives in `ROUTER.md`,
  `ORCA-INTEGRATION.md` section 11 and `rules/testing.md`.
- **Read by default, needed by trigger.** The Router reads the full Orca
  integration contract even for SIMPLE work. Workers read whole rule files
  (`rules/testing.md` is 14K characters) when they need a few sections.
  `rules/README.md` pushes toward reading broadly ("do not assume a rule does not
  exist").
- **Rules the machine already enforces.** `make verify` before stop, locked
  tests, the sensitive-code gate, lint on edit, install guard and secret scan are
  all enforced by hooks or CI, whose messages already say how to fix. Agents
  still read the prose versions in full.
- **Rules that restate default model behaviour.** Many sections of
  `rules/coding.md` (naming, comments, premature optimisation) describe what a
  current model does unprompted. They cost tokens on every worker for little
  change in behaviour.
- **SIMPLE pays twice.** The Router session reads the policy, then a fresh worker
  reads its own policy for a one-file change.

## 4. Design

Five principles, applied in every phase:

1. **One home per fact.** Each piece of policy lives in exactly one file. Other
   files link to it with one line.
2. **Load by trigger, not by default.** An agent starts from a short card and
   opens a full file only when a named trigger fires ("touching auth → read
   `rules/security.md`").
3. **What a machine checks, an agent need not memorise.** For a rule a hook or CI
   enforces, the agent's card carries one line naming the check. The hook message
   teaches the fix at the moment it matters.
4. **Rules stay the source of truth; cards are derived.** Briefs and cards are
   summaries of `rules/` with a source reference on every line. A script detects
   when a source changed after the card was last reviewed.
5. **The budget is checked by CI.** Each load path has a token budget in a
   manifest; CI fails when a path exceeds it.

New and changed files:

| File | What |
|---|---|
| `router/ROUTER.md` | Becomes a short card: intake, readiness, the SIMPLE test, workflow choice, gates, compact output. Draft in Appendix A |
| `router/ROUTER-DETAIL.md` | New. Receives the moved detail (complexity assessment, capability detail, verbose output format). Read only when the card says so |
| `router/ORCA-INTEGRATION.md` | Keeps only Orca-specific content (task spec, dispatch, parallel waves, completion, settlement). Read only when dispatching workers |
| `agents/briefs/<role>.md` | New. One brief per dispatched role (builder, reviewer, tester first). Draft builder brief in Appendix B |
| `scripts/context-budget.sh` + `scripts/context-budget.txt` | New. Measures each load path and fails above budget |
| `scripts/check-briefs.sh` | New. Every `§` reference resolves; every brief's source hashes match |
| `.github/workflows/test.yml` | Runs the two new scripts |

## 5. Phases

Workflow for this plan: BUILD_REVIEW (builder + reviewer). It changes router
policy and adds CI checks; medium risk. Hooks do not change, so
`enforcement/test.sh` must keep passing untouched.

### Phase 0 — Measure before changing

- Write `scripts/context-budget.txt`: one line per load path, its budget, and its
  files. Start with today's numbers as the budget so CI passes.
- Write `scripts/context-budget.sh`: sum characters per path, print ≈ tokens,
  exit 1 when a path exceeds its budget. The failure message says how to fix:
  "move detail behind a trigger or into a `-DETAIL` file".
- Run the benchmark (section 7) on a test project with today's policy. Record
  tokens (`/cost` or `/context` in Claude Code), the routing decision, and the
  number of owner messages for each sample task.

Done when: the script runs in CI and the baseline is in the progress log.

### Phase 1 — One home per fact

Move, do not reword:

| Fact | Single home | Others keep |
|---|---|---|
| What each workflow does | `workflows/*.md` | One line + link |
| Capability detail | `skills/capabilities.md` | The selection rule, one paragraph |
| Verification levels | `rules/testing.md` "Levels as commands" | A link |
| Parallelism | `ORCA-INTEGRATION.md` section 10 | A link |
| No fixed model per role | `ROUTER.md` | A link |

Done when: `ROUTER.md` + `ORCA-INTEGRATION.md` together shrink by at least 40%,
`scripts/check-links.sh` passes, and a diff review shows only moved text.

### Phase 2 — Router fast path

- Split `ROUTER.md` into the card (Appendix A) and `ROUTER-DETAIL.md`.
- The card says when to open the detail file: any doubt at the
  SIMPLE↔BUILD_REVIEW boundary, any COMPLEX or INDEPENDENT_COMPARE candidate.
- `ORCA-INTEGRATION.md` is read only when dispatching workers.
- The global bootstrap points straight to the card instead of `README.md`.
- Compact routing decision for SIMPLE, one line:
  `Route: SIMPLE · risk low · verify L1+L2 (make verify) · reason: <short>`.
  The full format stays for every other workflow.
- If the owner answers yes to Q1: a SIMPLE task runs in the Router's own session,
  with no worker dispatch, so the policy is read once.

Done when: the benchmark gives the same routing decisions as Phase 0, including
T4 (section 7), and the SIMPLE path is within its new budget.

### Phase 3 — Worker briefs

1. **Classify.** For every section of coding, testing, git, architecture,
   security and principles, mark one tag:
   - **M**: a hook or CI enforces it. The brief gets one line naming the check.
   - **J**: a judgement rule no machine checks. The brief gets one short line.
   - **T**: needed only in a situation. The brief gets a trigger row.
   - **D**: default model behaviour. The brief leaves it out; the rule stays.

   Write the table into this plan. **Stop for the owner's approval.** Briefs
   reword rules, and the repo rules require review for that.
2. **Write briefs** for builder, reviewer and tester (the most dispatched roles),
   each at most 1,200 tokens. Every line ends with its source, e.g.
   `(coding §21)`. Header lists the source files and their git blob hashes.
3. **Route rules into the task spec.** The Router adds a `Read also:` line to the
   Task spec's Constraints (`ORCA-INTEGRATION.md` section 8) naming any trigger
   rule it already knows applies, so each worker does not search for it.
4. **Point workers at briefs.** `README.md` and `rules/README.md`: a worker reads
   its brief, the workflow, the project context and the task spec; it opens a
   full rule when a trigger fires. This rewords the `rules/README.md` instruction
   to read broadly, so it is part of the owner's approval in step 1.
5. Write `scripts/check-briefs.sh`: references resolve to real headings; source
   hashes match the current files, else fail with "brief may be stale: re-review
   against <file>, then update its hash".

Done when: the owner approved the classification, the three briefs pass
`check-briefs.sh`, and the benchmark tasks still pass review with no new
BLOCKER or MAJOR findings compared with Phase 0.

### Phase 4 — Budgets become the rule

- Lower the budgets in `scripts/context-budget.txt` to the targets in section 6.
- Add both scripts to `.github/workflows/test.yml`.
- Add one line to the repo `CLAUDE.md` absolute rules: changes must pass
  `bash scripts/context-budget.sh` and `bash scripts/check-briefs.sh`.

Done when: CI runs both scripts and passes at the new budgets.

### Phase 5 — Fewer routing approvals (only if Q2 is yes)

- A BUILD_REVIEW task with risk low or medium, no `sensitive_paths`, no high-risk
  invariant, and uncertainty low reports its decision and proceeds, like SIMPLE.
- Still stops for approval: INDEPENDENT_COMPARE, COMPLEX, high or critical risk,
  tests-first, and any mid-task escalation.
- Reason: unlike SIMPLE, this path already has three independent gates (the
  reviewer, the Stop hook running `make verify`, and CI). The approval adds a
  human step without adding a check.
- Update Routing Rule 14, the Routing Approval Gate, and
  `ORCA-INTEGRATION.md` section 4.

Done when: on benchmark task T2, the owner sends one message (the task) instead
of two (the task and the routing approval).

### Phase 6 — Re-measure and close

- Rerun the benchmark. Compare with Phase 0 in the progress log.
- Record what worked and what did not in the decision log.
- Move the plan to `plans/completed/`.

## 6. Acceptance criteria

The owner approves this list before Phase 1 starts.

- [ ] SIMPLE path fixed policy load ≤ 7,000 tokens (from ≈ 21,800).
- [ ] BUILD_REVIEW path (Router + builder + reviewer) ≤ 16,000 tokens (from ≈ 34,800).
- [ ] Every brief ≤ 1,200 tokens; the Router card ≤ 2,500 tokens.
- [ ] Benchmark routing decisions (workflow, risk, tests-first) match Phase 0 on all four tasks.
- [ ] No rule section is deleted: every heading in `rules/` before the plan still exists after it.
- [ ] `enforcement/test.sh`, `scripts/check-links.sh`, `scripts/context-budget.sh`, `scripts/check-briefs.sh` pass in CI.
- [ ] Hooks are unchanged.
- [ ] If Q2 is yes: a low-risk BUILD_REVIEW task needs one owner message, not two.

The token targets are first guesses. Phase 0 may show they need adjusting; any
change goes into the decision log with the reason.

## 7. Benchmark tasks

Run on a small onboarded test project, same model, fresh session per task.

| # | Task | Expected route | Guards against |
|---|---|---|---|
| T1 | Change a button label | SIMPLE | Over-routing |
| T2 | Add a field to a form and its API (3–4 files) | BUILD_REVIEW | Lost quality in review |
| T3 | Change a file in `sensitive_paths` | BUILD_REVIEW + tests-first | Lost safety gate |
| T4 | Looks like a one-line fix but crosses a layer | BUILD_REVIEW (not SIMPLE) | Under-routing by a slimmer Router |

Record per task: tokens, routing decision, owner messages, review findings.

## 8. Open questions (owner decides)

- **Q1. SIMPLE in-session?** Should a SIMPLE task run in the Router's session
  with no worker dispatch? Saves a whole worker load. Changes
  `ORCA-INTEGRATION.md` section 5 ("Normally use one Orca worker").
  Recommended: yes.
- **Q2. Auto-proceed low-risk BUILD_REVIEW?** Phase 5. Recommended: yes, with
  the limits listed there.
- **Q3. Token targets.** Accept the section 6 numbers as the starting budget?
- **Q4. Brief location.** `agents/briefs/<role>.md`, or a "Brief" section at the
  top of each `agents/<role>.md`? Recommended: separate files, so a worker can
  load the brief without the full role text.

## 9. Out of scope

- Changing any hook or CI enforcement logic.
- Rewriting `workflows/onboarding.md` or `workflows/maintenance.md` (read
  rarely; revisit if the benchmark shows they matter).
- Briefs for architect, frontend, backend, database, qa (after this plan, if
  the first three briefs prove out).
- Model choice per role (stays as `ROUTER.md` says: no fixed mapping).

## 10. How to start (prompt for Claude Code)

> Read `plans/active/context-budget.md`. Run Phase 0 only. Show me the measured
> numbers and the benchmark results, then stop for my approval.

---

## Appendix A — Draft Router card (for owner review)

```markdown
# Router card

You route; you do not implement. Read this card. Open `router/ROUTER-DETAIL.md`
only when a step below says so.

## 1. Intake
- Readiness: run `bash .claude/hooks/doctor.sh`. Missing or failing → route to
  `workflows/onboarding.md` (exceptions: questions, docs-only, onboarding fixes;
  an owner skip goes into `.ai/tech-debt.md` with a due date).
- Clarify only when a wrong reading would change the work; otherwise state the
  assumption. Write the acceptance criteria.
- Read `.ai/project.md` and `.ai/invariants.md`.

## 2. Risk first
Touches `sensitive_paths` or a high-risk invariant → risk high, tests-first
(`rules/testing.md` "Tests-first mode"), at least BUILD_REVIEW.

## 3. SIMPLE needs positive evidence
SIMPLE only when ALL hold: one or very few files, obvious fix, no architecture
change, no cross-layer dependency, low regression risk, no investigation.
Any of these forces at least BUILD_REVIEW: 3+ files, crosses a layer, changes
architecture/API/data model, touches data integrity or security, needs
investigation. Unsure whether a signal holds → treat it as present.

## 4. Choose
| Workflow | When | File |
|---|---|---|
| SIMPLE | Section 3 holds | `workflows/simple.md` |
| BUILD_REVIEW | Normal work where review adds confidence | `workflows/build-review.md` |
| INDEPENDENT_COMPARE | Several viable approaches, choice matters | `workflows/independent-compare.md` |
| COMPLEX | Cross-layer, architecture, high risk, investigation | `workflows/complex.md` |

Unsure between two → the simpler one, except SIMPLE↔BUILD_REVIEW, which goes up.
Considering INDEPENDENT_COMPARE or COMPLEX → read `router/ROUTER-DETAIL.md` first.
Capabilities: none unless the hard part is investigation or product/UI
validation (`skills/capabilities.md`).

## 5. Gates
- SIMPLE: report one line and proceed.
- Others: present the decision and wait for approval.
- High-risk or destructive operations always need the owner's approval.

## 6. Output
SIMPLE: `Route: SIMPLE · risk low · verify L1+L2 (make verify) · reason: <short>`
Others: the full format in `router/ROUTER-DETAIL.md`.
Dispatching workers → read `router/ORCA-INTEGRATION.md`. Add a `Read also:`
line to each Task spec for rules you know apply.
```

## Appendix B — Draft builder brief (for owner review)

```markdown
# Builder brief

Sources: agents/builder.md, rules/coding.md, rules/testing.md, rules/git.md,
rules/principles.md, rules/golden-principles.md (hashes: set by check-briefs.sh)

Read this instead of the full rules. Open a full rule only when a trigger in
the last table fires, or the Task spec says `Read also:`.

## Job
Implement the Task spec: Target, Change, Constraints, Ownership, Observable
Acceptance. The smallest change that meets the acceptance, inside Ownership.

## The machine checks these: obey the message, do not work around it
| Rule | Checked by |
|---|---|
| `make verify` passes before you finish | Stop hook `verify-before-stop.sh` |
| Fix lint, do not silence it; a suppression needs ` -- <reason>` | `lint-file.sh`, CI (G3) |
| Never edit tests listed in `.ai/test-lock` | `protect-tests.sh`, Stop hook, CI |
| No edits in `sensitive_paths` before approved criteria and locked tests | `sensitive-gate.sh`, CI |
| Installs stay in the project; no push to main; no skipping git hooks | `guard-install.sh` |
| No secrets in the repo | gitleaks in CI (G4) |
| Sensitive change comes with a test or a `No-Test-Reason:` trailer | `ci-checks.sh` (G2) |

## Judgement rules
- Read the code before changing it; reuse before creating (coding §1, §3).
- No unrelated refactor, rename, reformat or dependency upgrade (coding §2, §11).
- Found an unrelated problem: report it, do not fix it (coding §21).
- Keep existing behaviour unless the task changes it; check callers first (coding §16, §22).
- No swallowed errors, no fake success (coding §8).
- Validate data where it enters the system (coding §9, G5).
- No hard-coded secrets, URLs or environment values (coding §10, §17).
- Change the generator source, not generated files (coding §18).
- Never claim a check passed that you did not run (testing §2).
- A bug fix comes with a regression test (testing §6).
- Every network call has a timeout; one bad item never stops a batch job (G11).
- No destructive git without the owner's approval (git §13, §24).
- Work only in your worktree; one logical change per commit (git §3, §6).
- Beyond the approved criteria: stop and ask the owner (builder).
- Two fixes on the same premise failed: write the premise down before a third (principles §1).
- Hidden complexity in a SIMPLE task: stop and re-route (workflows/simple.md).
- Stop every background process you started; say so in the report (G10).

## Read the full rule when
| Trigger | Read |
|---|---|
| Adding a dependency | coding §11 |
| Auth, input handling, secrets, files, external URLs | `rules/security.md` |
| Changing an API, data model, schema or module boundary | `rules/architecture.md`, testing §11 |
| Database migration | testing §11, git §24 |
| Tests-first task (`.ai/test-lock` or approved criteria exist) | testing "Tests-first mode" |
| Merge conflict, rebase, multi-agent integration | git §14–17 |
| Retry, restart or lifecycle code | principles §2 |
| Removing a legacy API | principles §3 |

## Report
What changed · files · checks run, PASS/FAIL (testing §25) · remaining risks ·
background processes stopped.
```

---

## Progress log

| Date | Phase | Done | Notes |
|---|---|---|---|
| 2026-10-01 | — | Plan written | Baseline numbers in section 3 are static estimates; Phase 0 replaces them with measured ones |

## Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-10-01 | Rules stay the source of truth; briefs are derived and hash-checked | Repo rule: no deleting policy, no rewording without review |
| 2026-10-01 | Budget enforced by CI, not by a written guideline | Harness principle: text is advice, a machine check is the rule |
