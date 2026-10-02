# Plan: round 2 — criteria critic, handoff file, mutation testing, rename

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time and stop after each for the repo owner's approval. Update the
> progress and decision logs at the end when a phase moves.

## 1. Goal

Four ideas found while running vn30 under Orca, built into Orca itself (not
installed as plugins or skills), plus one leftover from the GitHub username
change:

1. A critic attacks acceptance criteria before the owner is asked to approve
   them.
2. Every project keeps its handoff in the same file, and a new session finds
   it, so the owner only types "continue".
3. Mutation testing (break the code on purpose; the tests must fail) runs on
   changed sensitive files and reports in the PR summary.
4. The policy system gets its own name; "Orca" stays only for Orca ADE.
5. The setup guide clones from the new GitHub username `potetoai`.

## 2. Current state (surveyed 2026-10-01)

| Item | Today |
|---|---|
| Criteria review | Nobody checks criteria before approval. On vn30 plan A (2026-09-30) a review by hand found about 6 gaps: thresholds with no data behind them, scope limited to named cases instead of a whole-data diff, rounding tolerance, an approval-phrase trap ("duyệt A / duyệt B" offered when the choice edits the criteria), over-strict bans. Tests-first flow: `rules/testing.md` section 3, steps 1 (criteria) and 2 (owner approval). |
| Handoff | vn30 keeps it in `DANG-LAM.md` (Vietnamese); orca-workflow keeps it in this machine's private memory. Global `CLAUDE.md` step 5 says "the plan's progress log, or the project's status file". `check-readiness.sh` exits early in orca-workflow itself. |
| Mutation testing | None. vn30 did it by hand (M1-M4). Stack Makefiles: `enforcement/stacks/{python,node-ts}/Makefile`; PR summary: `ci-checks.sh` section 5. |
| Name | "Orca" means both Orca ADE (stablyai, the orchestrator) and this policy repo. Rejected names: Keel, Ballast, Trellis, Bridle, Bosun. Still open: Halyard, Lodestar, Sextant, or a coined name. |
| Username | `enforcement/setup-guide.md:24` clones from the old GitHub username. vn30 `.ai/enforcement.json` "repo" too (fixed by vn30 on its next upgrade). |

## 3. Order and why

Phase 1 critic, phase 2 handoff, phase 3 mutation testing, phase 4 rename.
The critic is the smallest change with the biggest effect. The handoff is a
daily pain for the owner. Mutation testing is the heaviest (new tools, two
stacks, CI time). The rename touches almost every file, so it goes last, when
nothing else is in flight, and only after the owner picks a name. Each phase
is one PR and one template version bump. The username fix rides in the
phase 1 PR.

Workflow for every phase: BUILD_REVIEW (builder + reviewer).

## 4. Phases

### Phase 1 — Criteria critic (template 1.10.0)

- `agents/critic.md`: new role. Runs in a fresh subagent (no shared context
  with the author of the criteria). Reads the plan and the code it touches.
  Attacks the criteria, not the code: missing behaviors and error paths;
  numbers with no data behind them; scope limited to named examples where a
  whole-data diff is possible; tolerance and rounding; tests against live data
  that hard-code "latest" dates; real-run steps that do not diff changed data
  against an outside source; open choices left for the approval message
  ("approve A / approve B" when the choice edits the criteria); bans stricter
  than the goal needs. Output: one line per finding, each with a proposed
  criteria fix.
- `rules/testing.md` tests-first: new step between 1 (criteria) and 2 (owner
  approval). The critic runs; the author fixes the criteria or writes why not;
  the plan gets a `## Criteria review` section listing findings and outcomes.
  The owner sees the criteria after the fixes.
- `enforcement/project/.ai/plans/TEMPLATE.md`: add the `## Criteria review`
  section.
- Enforcement (see Q1): `approval-record.sh` records no approval for a plan
  whose `## Criteria review` section is empty, and tells the agent to run the
  critic first.
- `workflows/complex.md` phase 2 and the Plan Approval Gate: the critic
  reviews the plan before it goes to the owner.
- `router/ROUTER.md`: add `critic` to the role lists and to rule 16.
- `enforcement/setup-guide.md:24`: clone URL `potetoai`.
- Tests in `enforcement/test.sh` for the hook change.

### Phase 2 — One handoff file (template 1.11.0)

- File: `.ai/handoff.md` in every project, English, short: state, open
  items, next step, do-not-do. Overwritten, never appended (history lives in
  plans and git). Committed or gitignored: see Q2.
- `check-readiness.sh` (SessionStart): when `.ai/handoff.md` exists, print
  "read .ai/handoff.md first". Runs in orca-workflow too (move the check
  above the early exit).
- Global `CLAUDE.md` template step 5: write the handoff to `.ai/handoff.md`;
  the owner types `/clear`, then "continue".
- `bootstrap.sh`: creates the file's place (and the `.gitignore` line if Q2
  says so). Template for the file in `enforcement/project/.ai/`.
- orca-workflow: move the handoff part of this machine's "Harness state"
  memory into `.ai/handoff.md`; the memory keeps only stable facts.
- vn30: its session moves `DANG-LAM.md` into `.ai/handoff.md` at its next
  maintenance (`workflows/maintenance.md` gets the step). We never edit vn30
  directly.

### Phase 3 — Mutation testing, report only (template 1.12.0)

- First a spike, in a throwaway project: mutmut 3 needs `fork()` and does not
  run on native Windows. Check it on Linux CI; if it cannot limit itself to
  given files, try cosmic-ray. Stryker (node-ts) takes `--mutate <files>`.
  Record the choice in the decision log before building.
- New Makefile target `test-mutation` in both stacks: `make test-mutation FILES="a b"`.
- `ci-checks.sh` new section: run `make test-mutation` on changed files in
  `sensitive_paths` only (see Q3), with a time limit; write the score and the
  surviving mutants to the PR summary. Never fails the PR. A project without
  the target gets one line: "mutation testing not set up".
- `rules/testing.md`: what a surviving mutant means and what to do (add a
  test or say why not). Reviewer role: read the mutation lines.
- Tool installs stay inside the project (`.venv`, `node_modules`).
- Tests in `enforcement/test.sh` with a fake `make test-mutation`.

### Phase 4 — Rename (template 2.0.0)

Name: Lodestar-harness (Q4). Covers: GitHub repo and URL,
README, both CLAUDE.md files, `orca-lib.sh`, `orca-` tags,
`enforcement.json` keys, hook and doctor messages, setup guide. Keep
`router/ORCA-INTEGRATION.md` and every reference to Orca ADE as the
orchestrator. Old projects migrate on their next template upgrade; bootstrap
reads the old keys once and rewrites them.

## 5. Acceptance criteria

- [x] Phase 1: replayed on vn30 plan A's criteria as first written (before the
  hand review), the critic finds at least 4 of the 6 gaps found by hand.
- [x] Phase 1: with the critic section empty, "approve" is not recorded and
  the agent is told to run the critic; filled, it is recorded as before.
- [x] Phase 1: plans approved before 1.10.0 keep their approval (no new
  approval needed for work already in flight).
- [x] Phase 2: a fresh session in a project with `.ai/handoff.md` is told to
  read it; the owner types only "continue" and the agent picks up the right
  task. Same in orca-workflow.
- [x] Phase 3: throwaway python and node-ts projects: a weak test lets a
  mutant survive, and the PR summary names it; strong tests show the score;
  the PR never fails on the mutation result.
- [x] Phase 4: no reference to "Orca" left except for Orca ADE; a project on
  1.x upgrades to 2.0.0 and `doctor.sh` passes.
- [x] Every phase: `bash enforcement/test.sh` and `bash scripts/check-links.sh`
  pass; CI green before merge.

## 6. Open questions (repo owner answers)

- **Q1.** Phase 1: enforce the critic by hook. Answered 2026-10-01 (A).
- **Q2.** Phase 2: `.ai/handoff.md` committed or gitignored? Answered
  2026-10-01: gitignored. The agent may not push to main, so a committed handoff would
  need a PR after every task; the cost is losing it when a project moves to
  another machine (rare; copy the file).
- **Q3.** Phase 3: mutation testing on changed sensitive files only, or every
  changed code file? Answered 2026-10-01: sensitive only (CI time; that is
  where vn30 did it by hand).
- **Q4.** Phase 4: the new name. Answered 2026-10-01: Lodestar-harness
  (repo `lodestar-harness`, short form Lodestar). The GitHub repo is renamed
  after merge; the folder moves to `D:/AI/Lodestar-harness` after merge.

## 7. Later

Reviewed 2026-10-02: nothing here needs work now (decision log).

- Vertical-slice plans in `workflows/complex.md`. Deferred: do it when a real
  complex task shows the gap.
- Guard-install asks the owner to type `! git push --no-verify`, which fails
  from the phone. Candidate: an explicit owner phrase lets the agent run it,
  logged like an approval. Dropped: it weakens the guard, and the one push
  that needed it was blocked by a project hook failing on outside data.
- Candidate rules from vn30: live-data checks report instead of blocking
  pushes of unrelated code; classify a timeout by the exception chain
  (`__cause__`), not only our own clock. The critic covers "no hard-coded
  latest dates", "diff changed data against an outside source" and "settle
  open choices before approval". Not added: the timeout rule is Python code
  detail a reviewer catches. Kept as a candidate in general form: a gate
  blocks only on failures the change caused; failures from outside (network,
  third-party data) are reported. Add it to `rules/testing.md` when a second
  project hits it.
- Orca + Superpowers + gstack are three overlapping process systems on this
  machine; review later. Closed: PR #35 puts the Router over Superpowers;
  gstack is not installed and the Router uses it only when present.
- Missing stack environment goes unnoticed (vn30, 2026-10-01): the project
  moved from `D:` to `F:` and `make setup` never ran there (no
  `backend/.venv`), so `make verify` failed and nothing flagged it at session
  start. Candidate: `doctor.sh` and `check-readiness.sh` detect a missing
  stack environment (`.venv` / `node_modules`) and tell the agent to run
  `make setup`. Done in phase 2 (doctor A12).

## 8. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-10-01 | — | Plan written; Q1 answered (hook); phase 1 approved |
| 2026-10-01 | 1 | `agents/critic.md`; `criteria_reviewed` in `orca-lib.sh`; `approval-record.sh` records nothing for a plan with an empty `## Criteria review`; plan TEMPLATE section; tests-first step 1, `workflows/complex.md` gate, Router, README, `rules/enforcement.md`; setup-guide clones from `potetoai`; VERSION 1.10.0. test.sh and check-links pass |
| 2026-10-01 | 1 | Blind replay on vn30 plan A's first draft (code at `7eac792^`, no transcripts): critic found 4 of the 6 hand-found gaps (whole-DB scope instead of 6 symbols; tolerance on "equal"; tolerance with a unit, absolute for low prices; criterion 3 too strict, shown to contradict criterion 5). Missed: the same whole-DB scope for criterion 6 (only for criterion 4); the approval-phrase trap (it came from a later owner message, not in the draft). Found 5 more: k also drives `_xet_quyen_mua` and `dieu_chinh_qua_muc`; earlier auto-patches not re-checked; checks on live DB state; "explain every difference" untestable; no signal for direction B debt |
| 2026-10-01 | 2 | Q2 answered (gitignored). `check-readiness.sh` tells a new session to read `.ai/handoff.md` (session start only, also in orca-workflow); `bootstrap.sh` gitignores it and does not warn about it; global `CLAUDE.md` step 5 names the file and "continue"; maintenance step 1 moves an old status file into it; doctor A12 warns when `.venv` / `node_modules` is missing and the session hook says "run make setup"; orca-workflow's own handoff moved from machine memory into `.ai/handoff.md`; VERSION 1.11.0. test.sh and check-links pass |
| 2026-10-01 | 2 | Global `CLAUDE.md` "For subagents": a dispatched subagent skips startup steps 1-3 and 5; `workflows/build-review.md` Review cost points to it. Fixed test.sh `git check-ignore -q` with two paths. test.sh and check-links pass |
| 2026-10-01 | 3 | Q3 answered (sensitive only). Spike on Windows in throwaway projects: cosmic-ray limits itself to given files and runs on Windows (mutmut 3 does not); Stryker `--mutate` with the command runner works with any `npm test`. `make test-mutation FILES=...` in both stacks (cosmic-ray added to `requirements-dev.txt`; Stryker is a devDependency the project adds); multi-part root Makefile routes files to each part; `ci-checks.sh` section 6 runs it on changed sensitive files with a 15-minute limit and writes the score and survivors to the PR summary, never failing; `rules/testing.md`, `rules/enforcement.md`, reviewer role; VERSION 1.12.0. End to end on a throwaway python project: weak test, 8 survivors named with lines; strong tests, score shown. Review fixes: incompetent mutants counted apart, `timeout -k` plus restore of the mutated files, empty report, missing Stryker says "not set up". test.sh and check-links pass |
| 2026-10-01 | 3 | Owner review of cost: mutation testing is off by default. It runs only with the PR label `test-mutation`, which the agent adds after the owner agrees to its suggestion; `ci.yml` reruns on `labeled`. test.sh and check-links pass |
| 2026-10-01 | 4 | Q4 answered (Lodestar-harness). Renamed orca-workflow to lodestar-harness in docs and enforcement: `lodestar-lib.sh`, `LODESTAR_SKIP_HOOKS`, `LODESTAR_TEST_MUTATION`, `lodestar-` feedback tags, `lodestar-harness:begin` markers, hook messages. Orca ADE references and `router/ORCA-INTEGRATION.md` kept; completed plans kept as history. Migration: bootstrap `--upgrade` removes `orca-lib.sh`; setup-machine rewrites an `orca-workflow` block; global install drops a `check-readiness.sh` hook left at an old folder path; doctor still skips `orca-` tags. VERSION 2.0.0. test.sh and check-links pass |
| 2026-10-02 | close | Phase 2 confirmed in Lodestar-harness: after `/clear` the session hook pointed to `.ai/handoff.md` and the owner's one-word "continue" picked up the next step. Phase 4 confirmed: a throwaway 1.x project upgraded to 2.0.0 passes doctor; the folder now lives at `D:/AI/Lodestar-harness`. PRs #31, #32 merged on green CI. Plan closed |

## 9. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-09-30 | Build the ideas into Orca; do not install tdd-guard, TDD Guardian, claude-night-market or gate-oriented-sdd | Owner's choice; they duplicate Orca's gates |
| 2026-10-01 | Order: critic, handoff, mutation testing, rename | Smallest and most useful first; the rename touches every file and waits for a name |
| 2026-10-01 | Name Lodestar-harness; category word "harness", not "framework" | It is rules, gates and checks around agents, not a code library; Lodestar (guiding star) fits a policy that points the way while Orca runs the work |
| 2026-10-01 | Q1: the approval hook enforces the critic (empty `## Criteria review` = nothing recorded) | Owner's choice; rules as text get skipped |
| 2026-10-01 | Plans approved before 1.10.0 stay approved; the hook checks the review only when recording | Work in flight must not need a new approval |
| 2026-10-01 | Q2: `.ai/handoff.md` is gitignored | Owner's choice; agents may not push to main, so a committed file would need a PR after every task |
| 2026-10-01 | No template file for the handoff; its sections are named in global `CLAUDE.md` step 5 | A created empty template would make the session hook point to an empty file |
| 2026-10-01 | A12 is a warning, not a failure | A missing env is fixed by one command (`make setup`), not a readiness gap; a failure would block every session until then |
| 2026-10-01 | Small diffs get a cheap review: goal and diff in the prompt, no extra reading, no test rerun, cheapest model (`workflows/build-review.md` Review cost) | A fresh-subagent review of this phase's ~50-line diff cost about 40k tokens re-reading files; owner asked to cut it |
| 2026-10-01 | The review is not tied to the criteria hash: after a criteria edit the agent must rerun the critic by rule, the hook does not check it | A stale-review check needs a second hash per plan; add it if agents skip the rerun |
| 2026-10-01 | Q3: mutation testing runs on changed files in `sensitive_paths` only | Owner's choice; CI time, and that is where vn30 did it by hand |
| 2026-10-01 | Python mutation tool: cosmic-ray, not mutmut | mutmut 3 needs `fork()` (no native Windows, where the owner works); cosmic-ray takes a file list and runs on both |
| 2026-10-01 | The python `test-mutation` recipe runs the tests once first and reports mutants that did not run | cosmic-ray marks a broken test command as killed or incompetent, which would show a perfect score |
| 2026-10-01 | Mutation testing is opt-in per PR (label `test-mutation`; agent suggests, owner agrees) | Owner's choice after the phase cost ~70k tokens; acting on survivors in every sensitive PR costs agent tokens, and sensitive changes already have approved criteria and locked tests |
| 2026-10-01 | Subagents skip the global startup steps | A reviewer of a small diff cost about 50k tokens; global `CLAUDE.md` loads into every subagent and made it re-run Router, doctor and project reading |
| 2026-10-02 | Section 7 closed without changes; the general gate rule waits for a second project | Lodestar targets most projects; one incident in one project is not enough for a rule every agent must read |
