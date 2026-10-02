# Plan: token diet — cut the usage every task pays

> **Idea plan, not executed as written.** Rated and merged into
> `plans/active/token-efficiency.md` (2026-10-02); see its section 3.

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time and stop after each for the repo owner's approval. Answer
> nothing in "Open questions" yourself: ask the owner when a phase needs it.
> Update the progress and decision logs when a phase moves.

## 1. Goal

The same work, with fewer tokens and fewer owner round trips. Nothing in the
safety model goes away: hooks, CI, tests-first, locked tests and approvals stay.
What changes is how much text agents read, how often hooks force an extra
turn, and how often the owner must reply before work can start.

Targets (checked in phase 6 against phase 0):

- SIMPLE task: startup reading under ~7k tokens (today about 19k).
- Dispatched subagent: brief under ~1.5k tokens, no startup reading.
- No forced extra turn from a hook when nothing is wrong.
- BUILD_REVIEW, normal risk: zero owner replies needed before work starts.

## 2. Current state (surveyed 2026-10-02, template 2.0.0)

Sizes are bytes / 4, rounded.

| Item | Today |
|---|---|
| Startup reading per task | README (~0.8k) → `router/ROUTER.md` (~3.5k) → `router/ORCA-INTEGRATION.md` (~3.4k) → `.ai/project.md` template (~1.7k) → `rules/README.md` (~0.5k). ORCA-INTEGRATION §3 item 4 says "read every rule that applies", and for code work that is almost always `coding.md` (~2.4k) + `testing.md` (~3.9k) + `git.md` (~2.4k). Total ~19k before the first edit, kept in context for the whole session. |
| Padding | Blank lines: ROUTER 233/601, ORCA-INTEGRATION 248/861, testing 212/674, coding 181/505, git 174/525, architecture 106/291, `project/.ai/project.md` 230/508, `agents/architect.md` 132/411. Most are single words on their own paragraph ("Task", "→ One agent", ...). |
| Duplication | ORCA-INTEGRATION §5 (workflow mapping), §6, §7, §17 (output contract), §18 (example), §19 repeat ROUTER. ROUTER "Workflow Types" repeats `workflows/*.md`. |
| Generic rules | Much of `coding.md` (naming, functions, comments, duplication) and `git.md` is general practice the model already follows. The non-obvious parts (tests-first, no destructive git without approval, suppression needs a reason, G11 timeouts) are spread across files. |
| Subagent reading | README line 30: "A worker dispatched for a task reads: its agent role, the rules that apply, the workflow, and the project context" (~10k+). Global `CLAUDE.md` "For subagents" says the opposite: read only the files the prompt names. Round-2 decision log: a reviewer of a ~50-line diff cost 40–50k tokens. Only the reviewer has a cost rule (`workflows/build-review.md` "Review cost"). |
| Stop hook | `verify-before-stop.sh` runs the full `make verify` at every Stop, including stops that only ask for routing approval, plan approval or answer a question. |
| Tests-first vs Stop hook | The tester writes tests that must fail. `make verify` runs the whole suite, so every Stop in the red phase fails, dumps up to 60 lines and forces one extra turn. |
| Lint hook | `lint-file.sh` prints the linter's full output, with no limit. |
| Feedback hook | `feedback-check.sh` matches common Vietnamese words ("không phải", "quên", "sai" as in "sai số"). Each false match forces one extra turn. |
| Approval gates | ROUTER rule 11 resolves SIMPLE↔BUILD_REVIEW doubt upward; rule 14 makes BUILD_REVIEW wait for the owner. Most normal tasks therefore need one owner reply before any work. The routing decision prints 10 fields every time. |
| Tests-first flow | Four fresh subagents (critic, tester, builder, reviewer), each re-reading code, plus approval round trips. |
| COMPLEX | `agents/architect.md` asks for a 12-section output for every significant task. Verification runs in phases 7, 9 (review) and 10, plus the Stop hook. If superpowers `writing-plans` is active, it plans next to the plan file. |
| INDEPENDENT_COMPARE | Two full implementations before anyone compares. |
| Maintenance | Step 6 scans the whole codebase for golden-principle violations; step 2 reads every PR's comments since the last run. |

## 3. Order and why

Phase 0 measures first, so every later claim has a number. Phase 1 (hooks) is
the safest: pure shell, guarded by `enforcement/test.sh`, no policy wording
changes. Phases 2–3 save the most but restructure policy text, which this
repo's `CLAUDE.md` says needs review. Phases 4–5 change policy and wait for the
owner's answers. Phase 6 measures again.

Workflow for every phase: BUILD_REVIEW, with the cheap-review rule (goal and
diff in the reviewer's prompt). Each phase is one PR. Repo rules still apply:
do not delete policy (move and link), `bash enforcement/test.sh` and
`bash scripts/check-links.sh` pass, LF line endings, bump
`enforcement/VERSION` when anything under `enforcement/` changes.

## 4. Phases

### Phase 0 — Baseline (no code change)

- Make a throwaway python project, onboard it with `bootstrap.sh`, and add one
  `sensitive_paths` entry.
- Run three sample tasks in fresh sessions: **T1** SIMPLE (change a message
  string), **T2** BUILD_REVIEW (a ~50-line feature with a test), **T3**
  tests-first (a change in the sensitive path, two criteria).
- For each, record total tokens (`/cost`, or `npx ccusage` on a subscription),
  number of turns, number of owner replies needed, and number of forced hook
  turns. Write the table into the progress log. Keep the task texts in this
  plan (section 7) so phase 6 reruns the same ones.

### Phase 1 — Hooks (template 2.1.0)

1. **Verify only what changed.** `verify-before-stop.sh`: after a green
   `make verify`, write a stamp to `$(git rev-parse --git-dir)/lodestar-verified`:
   a hash of `HEAD`, `git diff HEAD` and the untracked files, all excluding
   `*.md` and `.ai/`. At the next Stop, if the stamp matches, exit 0 without
   running make. Stops that only ask or answer cost nothing.
2. **Red phase runs lint only.** When `lock_active` holds, no `relock_window`
   is open, and no file outside the locked tests, `.ai/` and docs changed
   since the last valid Tests-First commit, run `make lint` instead of
   `make verify`. The locked-test check above it stays as is. CI is still the
   final gate.
3. **Cap the lint output.** `lint-file.sh`: print at most 30 lines, then
   "… N more lines; run `make lint-file FILE=<path>` to see all".
4. **Fewer false corrections.** `feedback-check.sh`: drop
   `không phải|khong phai`. Match `quên` only as `quên mất|quen mat` or after
   `bạn|em|lại`. Do not match `sai` when followed by `số`. Proposed list goes to
   the owner (Q1) before merge.
5. `enforcement/test.sh`: one case per change. The stamp skips a second Stop
   with no edits, and runs again after a code edit but not after a `.md` edit.
   Red phase passes with failing locked tests and fails on a lint error. Lint
   output is capped. "không phải lo", "sai số" and "quên chưa nói, thêm X" do
   not trigger, while "sai rồi", "làm lại" and "bạn quên test" do.

### Phase 2 — Startup reading

1. **Padding (separate commit, no wording change).** In the files listed in
   section 2, join word-per-line paragraphs into one line ("Execution: Task →
   One agent → Verify → Done"). Keep one blank line between blocks, as
   `CLAUDE.md` requires. Diff must show no changed words.
2. **ROUTER as a decision table.** The top of `router/ROUTER.md` gets one
   table: signal → workflow, plus the hard escalations (sensitive path → high
   risk, 3+ files or cross-layer → at least BUILD_REVIEW). Each workflow
   section shrinks to purpose plus a link to `workflows/<name>.md`. Long text
   moves into the workflow files, not out of the repo. Target: ROUTER under
   ~1.2k tokens.
3. **ORCA-INTEGRATION only when dispatching.** Remove §5, §6, §7, §17, §18
   and §19 duplicates (link to ROUTER and workflows instead). README "Start
   Here" and global `CLAUDE.md` step 4: read it only before dispatching a
   worker, never for SIMPLE.
4. **Rules card.** New `rules/CARD.md`, under ~1k tokens. It holds only the
   rules a capable model would not apply on its own, each with a link to its
   section. Draft list: tests-first and locked tests; no destructive git or
   force-push without approval; inspect `git status` before changing state;
   suppression needs ` -- <reason>`; never reshape code to pass a check;
   network calls have timeouts and per-item failure (G11); debt goes to
   `tech-debt.md`; stop background processes; owner language vs English
   files. `rules/README.md` becomes: always read CARD; read a full rule file
   only when its trigger fires (table of triggers). Update ORCA-INTEGRATION
   §3 item 4 and `rules/README.md` line 8. Full rule files stay as reference.
   The owner reviews the card's list (Q2).
5. **Project template.** Compress `project/.ai/project.md`: padding out, and
   empty stack fields become one "Stack:" line per part. Keep every section
   name that hooks or doctor read (`sensitive_paths:`, `owner_language:`).
   Run `doctor.sh` on a project made from the new template.

### Phase 3 — Subagent briefs

1. README line 30: a dispatched worker reads only its brief and the files a
   finding needs. This matches global `CLAUDE.md` "For subagents".
2. ORCA-INTEGRATION §8 adds **Brief**: the five Task-spec fields; the CARD
   lines that apply; the role in at most 10 lines (from `agents/<role>.md`);
   the diff or the file paths. Budget about 1.5k tokens. The dispatcher writes
   it; the worker does not open the role, rules or workflow files.
3. Generalise "Review cost" (`workflows/build-review.md`) into a
   **Subagent cost** rule covering builder, tester, critic and reviewer. Put
   it in ORCA-INTEGRATION and link to it from build-review.
4. `agents/architect.md`: scale the output. A small or medium change gets
   Problem, Proposal, Plan and Verification. All 12 sections only when the
   architecture changes. The generic pattern catalogue moves to a short
   "consider" list.

### Phase 4 — Tests-first, COMPLEX, COMPARE

1. **Critic scaled (Q3).** Use a fresh-subagent critic when the criteria touch
   stored data or migrations, there are more than 5 criteria, or the owner
   asks. Otherwise the author runs the `agents/critic.md` checklist in the
   same context and writes the findings under `## Criteria review` with
   "(self-review)". The approval hook needs only a non-empty section, so no
   hook change.
2. **Tests-first reviewer.** Brief = approved criteria, the locked test list
   and the diff. It does not rerun the suite, because the Stop hook and CI
   already did.
3. **COMPLEX.** Run phase 10 only if code changed after phase 7. Progress log:
   one line per phase. One planner: when the plan file is used, do not also
   run superpowers `writing-plans` (add this to `skills/capabilities.md`).
4. **INDEPENDENT_COMPARE.** Compare designs first. Two agents write one-page
   approach sketches, with a spike only on the riskiest part. Implement both
   only if the comparator still cannot choose. Update ROUTER §3 and the
   workflow file.

### Phase 5 — Owner round trips and maintenance

1. **Routing approval (Q4).** BUILD_REVIEW at low or medium risk: announce
   the decision in one line and proceed. The owner can stop it with any
   reply. The gate stays for INDEPENDENT_COMPARE, COMPLEX and high/critical
   risk. Update rule 14 and the "Routing Approval Gate" section.
2. **Short routing output.** SIMPLE and BUILD_REVIEW print one line
   (`Route: BUILD_REVIEW · risk medium · builder+reviewer · verify: make
   verify · reason: …`). The 10-field block stays for gated workflows.
3. **Maintenance bounds.** Step 6 scans only files changed since
   `.ai/last-maintenance` and uses grep or linters, not full reads. Step 2
   uses `gh pr list --search "updated:>=<date>" --json number,title,state`
   and opens comments only for PRs that were closed unmerged or got
   "changes requested".

### Phase 6 — Measure and close

Rerun T1–T3 from section 7 on the same throwaway project with the new
template. Put the before/after table in the progress log and record each
target from section 1 as met or not. Move this plan to `plans/completed/`.

## 5. Open questions (ask the owner; do not answer them yourself)

- **Q1** (phase 1): the new `feedback-check.sh` word list.
- **Q2** (phase 2): the exact list of rules in `rules/CARD.md`.
- **Q3** (phase 4): the thresholds that call for a fresh-subagent critic.
- **Q4** (phase 5): BUILD_REVIEW proceeds without approval at low/medium risk —
  yes or no?

## 6. Not in scope

- No change to Orca's orchestration; this repo still only decides and verifies.
- No weaker safety: locked tests, `sensitive-gate.sh`, approval recording, CI
  and the "sensitive path → high risk" rule stay as they are.
- No deleted policy: shortened text moves into a linked file.

## 7. Sample tasks (phase 0 and 6)

- **T1:** "Change the error message shown when the input file is missing to
  `Input file not found: <path>`."
- **T2:** "Add a `--limit N` option to the CLI that stops after N rows, with a
  test."
- **T3:** "In the sensitive module, reject a negative amount with an error and
  write nothing" (tests-first, two criteria).

## 8. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-10-02 | — | Plan written from a review of template 2.0.0 |

## 9. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-10-02 | Measure before and after with the same three tasks | Each saving must show up as a number, as in round-2 |
| 2026-10-02 | Hooks first, policy text last | Hooks are covered by `test.sh`; policy text needs the owner's review |
