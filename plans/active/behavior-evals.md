# Plan: behavior evals (Router first)

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time and stop after each for the repo owner's approval. Answer
> nothing in "Open questions" yourself. Update the progress and decision logs
> when a phase moves.

## 1. Why this plan

Rated from `plans/completed/ideas/behavior-evals.md` (harness-health,
2026-11-02). Lodestar's policy files are instructions to a model. A change
to them is checked by review, `enforcement/test.sh` and
`scripts/check-links.sh`; none shows that an agent still behaves right after
the text changes. `router/ROUTER.md` changed in 14 commits from 2026-10-01
to 2026-11-02, `agents/reviewer.md` in 3, `rules/` in 54.

Goal: a small eval suite that (1) stops a Router edit that makes routing
worse, and (2) finds Router text that changes nothing, so it can be cut.
Start with the Router only; build more suites only if the first one earns
its cost (gate EV-3).

## 2. Evidence (2026-11-02)

- Smoke test, throwaway, deleted after: `claude plugin eval` (Claude Code
  2.1.316) ran one case end to end on a scratch plugin with
  `--runs 1 --ablation none --model haiku --no-publish --trust-plugin`:
  score 1.00, 9 s, $0.00. The runner works on this machine.
- Not yet known: whether the runner can load Lodestar (it is not a plugin; it
  loads through `~/.claude/CLAUDE.md`), and whether the baseline arm also
  loads that global file (then it is not a baseline). Phase 0 answers this.
- The runner reports cost only in dollars (`costUsd`, `judgeCostUsd` in its
  `--json` output, checked 2026-11-02), not tokens, and stops a run only on
  `--max-cost-usd`. Its dollars are an API-price estimate: this machine
  logs in with a claude.ai subscription, so a run uses the plan's usage
  limit, not money.
- Owner constraints: token budget is watched, GitHub Free only, test
  artifacts are throwaway.

## 3. Limits

- Use `claude plugin eval`; do not write a custom runner (AGENTS.md: never
  build an orchestration system). A custom runner needs a new rating.
- Not in CI, not in `merge-pr.sh`: CI has no model credential and runs cost
  the owner's quota.
- String-match graders where possible; an LLM judge (haiku) only where a
  string cannot decide.
- Results stay local: `evals/results/` gitignored, `--no-publish`.

## 4. Phases

### Phase 0: Spike (gate EV-0)

One Router case (a task that must route BUILD_REVIEW, not SIMPLE) through
`claude plugin eval`, 1 run, with and without Lodestar. Answer three
questions in the progress log:

1. Can the runner load Lodestar (for example as a skills-dir plugin wrapping
   this repo, or through `--eval-dir` in this repo)?
2. Is the baseline arm clean (no `~/.claude/CLAUDE.md` Lodestar text)?
3. Tokens and time of one run, on haiku and on the day-to-day model. Read
   tokens from the run's session transcripts with `scripts/usage-report.py`
   if the runner leaves them in `~/.claude/projects`; if it does not, log the
   runner's dollar estimate and say tokens could not be read.

Gate EV-0 is a go/stop decision by the owner on these answers, not a counted
gate, so it has no row in the Data gates table. If 1 or 2 is no, stop and
report; the plan ends there unless the owner
rates a new approach. Spike files are throwaway; nothing is committed.

Done when: the three answers are logged and the owner has chosen go or stop.

### Phase 1: Router suite (E1)

About 12 cases under `evals/router/`, each a task text in and the expected
`Lodestar route: <WORKFLOW> risk=<level>` out, graded by string match:

- SIMPLE vs BUILD_REVIEW boundary (3+ files, crosses a layer, needs
  investigation);
- sensitive paths that force tests-first;
- a question that is not a request (answer, no route line);
- high or critical risk that must wait for approval (graded by the haiku
  judge: the reply asks for approval and starts no build; a route line alone
  cannot show the wait);
- PROTOTYPE vs a real fix.

Every case prompt lists the workflow names (SIMPLE, BUILD_REVIEW,
INDEPENDENT_COMPARE, COMPLEX, PROTOTYPE) and the risk levels, so the two
arms differ only in judgment, not in knowing the names (the spike's baseline
scored 0 only for that reason; its judgment matched). Cases run on opus, 1
run each (3 only when a result is borderline), with a ceiling of about 1.5M
tokens per suite run.

Run once on main with the baseline arm. Record per case: score with and
without Lodestar, and the tokens used. Store the main scores in
`evals/router/scores.md` (committed) so later PRs compare against them
without re-running main. Add an `evals/` row to the `AGENTS.md` Map.

Done when: the suite is merged and the main scores and tokens are logged.

### Phase 2: When to run (one rule)

One short rule in `AGENTS.md`. Run the Router suite:

- in a PR that changes `router/ROUTER.md`: run on the branch, compare with
  `evals/router/scores.md`, and put one line in the PR text:
  `Lodestar evals: router <branch score> (main <score>), <N>k tokens`. A drop
  is fixed or explained before merge; a merged change updates `scores.md`;
- when the day-to-day model changes;
- before cutting Router text, to show the cut changes no score.

Do not run it on other PRs, on every push, or on a schedule. The
`Lodestar evals:` line is the agent's own report; `ci-checks.sh` and
`merge-pr.sh` do not check it, and adding such a check needs a new rating.

Done when: the rule is merged.

### Phase 3: More suites (gate EV-3)

Reviewer (E2, about 6 cases: planted bug found, clean diff passes) and
text-only rules (E3, about 4 cases: destructive command asks first, auth
change names a security review) are built only if the Router suite earns its
cost. Same shape as phase 1.

Done when: gate EV-3 is met and the owner has said go, or the gate stopped
and E2/E3 are dropped.

## 5. Data gates

| Gate | Measure (source) | Minimum | Check | Stop | Status |
|---|---|---|---|---|---|
| EV-3 More suites | Router suite runs in PRs that changed `router/ROUTER.md` (PR text `Lodestar evals:` lines), and how many found a drop that was fixed or text that was cut | 5 runs, at least 1 that changed a PR; count only runs after the phase 2 rule is merged (if it is not merged by the check day, log the count and set a new check day) | 2026-12-01 | 2026-12-22 | waiting (0) |

## 6. Open questions (owner)

Questions 1-3 were decided on 2026-11-02; see the decision log.

1. Token ceiling per suite run, after phase 0 measures it. The runner only
   stops on `--max-cost-usd`, so the agent turns the token ceiling into
   dollars at the model's API price and passes that.
2. Which model runs the cases: the day-to-day model (real behavior, costs
   more) or haiku (cheap, may score differently).
3. Runs per case: 3 (default; shows flaky rules) or 1 (a third of the cost).

## 7. Not in scope

- Evals for every file; only where wrong behavior is costly and no hook
  checks it.
- An eval gate in CI or `merge-pr.sh`.
- Rewriting the Router; this plan only measures it.

## 8. Progress log

| Date | Phase | Note |
|---|---|---|
| 2026-11-02 | rating | Idea rated in harness-health; plan written. Smoke test: the runner works (1 case, haiku, $0.00) |
| 2026-11-02 | 0 | Spike, PR #128: (1) yes, a skills-dir plugin whose skill points at this repo, run with `--allow-tools "Read(D:/AI/Lodestar-harness/**)"` (without it the sandbox denies the read); (2) yes, both arms run in a temp home without `~/.claude/CLAUDE.md`; (3) tokens are in each run's `out/trace.jsonl` (needs `--keep-temp`), not `~/.claude/projects`. One route case, with arm: haiku ~47k tokens (mostly cache reads), 11 s; opus ~65k, 32 s. Haiku routed BUILD_REVIEW, opus COMPLEX. Waits for owner go/stop |
| 2026-11-02 | 0 | Gate EV-0: go (owner). Open questions 1-3 decided, PR #129 |
| 2026-11-02 | 1 | Router suite, 13 cases in `evals/router/`, PR #130: with Lodestar 13/13 (1.00), baseline 10/13 (mean delta +0.15), 860k tokens (opus, 1 run). Scores in `evals/router/scores.md`. Waits for owner approval before phase 2 |
| 2026-11-04 | 2 | Owner go; when-to-run rule added to `AGENTS.md`, PR #TBD |

## 9. Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-11-02 | Router suite first; reviewer and text-only suites wait for gate EV-3 | `ROUTER.md` changed 14 times since 2026-10-01, `reviewer.md` 3 times; token budget |
| 2026-11-02 | Measure and report evals in tokens, not dollars | Owner: the subscription charges no money per run, so dollars mislead; the dollar flag stays only as the runner's stop switch |
| 2026-11-02 | Run on Router PRs, model changes and before cuts; never in CI or on a schedule | Same text and model give the same expected result; each run costs the owner's quota |
| 2026-11-02 | Gate EV-0: go | Spike answered yes to questions 1 and 2; owner said go |
| 2026-11-02 | Cases run on opus, 1 run each (3 only when borderline), ceiling about 1.5M tokens per suite run | Opus is the day-to-day model and haiku routed differently in the spike; 12 cases at ~65k + ~22k tokens fit under the ceiling |
| 2026-11-02 | Case prompts list the workflow names and risk levels | The spike's baseline scored 0 only because it did not know the names; the arms should differ only in judgment |
| 2026-11-02 | Case prompts state the project is onboarded (doctor passes) | The eval temp dir has no `doctor.sh`; without it Lodestar routes every case to ONBOARDING (Routing Rule 15) |
| 2026-11-02 | 13 cases, not 12: one INDEPENDENT_COMPARE and one COMPLEX case besides the listed boundaries | Every workflow gets at least one case; 860k tokens stays under the 1.5M ceiling |
