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

#### Phase 2 as planned (2026-10-12, replaces the paragraph above)

The owner changed direction after phase 1 was written: Codex works like a
mid-level engineer, Claude like a senior. So the second model is tried as
the **builder** of clear, low-risk work, and Claude plans, briefs, reviews
and verifies. The phase 1 rule (PR #20) is on hold until this phase is
measured; its line "the second model does not build" will change if the
trial passes.

Division to test (owner agreed 2026-10-12; not policy until phase 3):

| Role | Model | Reason |
|---|---|---|
| Router, intake, plan, architecture | Claude | A wrong decision here is wrong everywhere after it |
| Acceptance criteria, critic | Claude | What the owner signs; finding what is missing is where Codex was weakest |
| Tests for high-risk work (tester) | Claude | The tests judge the code |
| Builder, clear plan, low or medium risk | Codex | The largest token cost; Codex has its own subscription limit |
| Builder, `sensitive_paths`, data, security | Claude | Cost of a mistake |
| Tests that kill a named surviving mutant | Codex, reviewed by Claude | Clear brief, checked by machine |
| Reviewer, final verification | Claude | Last gate |

Codex out of quota or not available: Claude does the role as before.
Mutation runs belong to CI; the agent reads only the list of survivors.

Trial task (owner picked 2026-10-12), in vn30, run from a session opened in
that project (its Claude hooks load only there): tech-debt row of
2026-10-09, CB1 review NIT (a). In `backend/scripts/kiem_db_chuan.py`,
`check_cb1`, the VCI-only loop keeps only dates with
`CB1_FROM <= d <= end`; removing that filter fails no test. Not a
`sensitive_paths` file; no DB write; Codex trusts the project's hooks.

Steps:

1. Claude: doctor passes with A4c OK (not a warning), `main` clean, new
   branch. Route line (expected BUILD_REVIEW, low risk, same-session
   review).
2. Claude writes the brief in the task-spec form. Target: one new test
   file in `backend/tests/`. Change: tests showing a VCI-only row before
   `CB1_FROM` and one after `end` are not reported, and rows on both
   bounds are. Constraints: touch no other file, no locked test, style of
   `test_cb1_check.py`. Acceptance: the tests pass on today's code and
   fail when the filter is removed.
3. Codex: one direct run (`codex exec --sandbox workspace-write`, brief on
   stdin), 10-minute cap.
4. Claude verifies: `git status` shows only the new file; the tests pass;
   with the filter removed by hand at least one new test fails; the file
   is restored and its diff is empty.
5. Claude reviews the tests (reviewer checklist): they state the rule,
   not a copy of today's output.
6. At most one fix round by Codex, from Claude's findings. Still not
   right: Claude finishes the task and the trial counts as failed.
7. `make verify`, commit, PR, green CI, the owner merges. Mark NIT (a)
   done in vn30's `.ai/tech-debt.md`.
8. Record in this plan's progress log: Codex wall time and tokens; Claude
   tokens for the whole task (`scripts/usage-report.py`), next to a
   Claude-only task of similar size (vn30 PR #79) if the report can
   separate it; fix rounds; review findings; every owner step.

Pass, set before the run: the mutant is killed, at most one fix round, no
file touched but the target, and no owner step beyond stating the task and
merging. One task is a direction, not a measure; a second trial where
Codex writes feature code (candidate: App01, the test screen clears the
last error too early, left from its PR #15) follows only if this passes.

Owner steps: approve this plan; open a session in the vn30 folder and
type "continue"; type the merge line at the end.

#### Second trial as planned (2026-10-12)

The first trial met its pass criteria (progress log), so the owner chose
the second trial before any rule text: Codex writes feature code, not only
a test. It runs in App01, from a session opened in that project.

Task: the suggestion left open by App01 PR #15. In
`apps/mobile/src/dev/test-screen-model.ts` the test screen clears the last
error on every core notification while signed in, also on a token refresh.
It must clear only on the change to signed in. Dev test screen only; not a
`sensitive_paths` file; no new dependency. `test-screen-model.test.ts` is a
locked test: the new tests go in a new file.

Start condition: App01 step 6 (Sentry, branch `feat/week1-step6-sentry`,
in work on 2026-10-12) changes the same file. The trial starts only after
that work is merged, on a new branch from the updated `main`, and never in
a new worktree (hook trust is stored per path).

Steps: the eight steps of the first trial, with these changes.

- Step 2, the brief: two targets, `test-screen-model.ts` and one new test
  file in `apps/mobile/src/dev/`. Acceptance: with an error shown and the
  state already signed in, a further core notification keeps the error; a
  change from signed out or loading to signed in clears it; the existing
  tests still pass. Constraints: no other file, no locked test, no new
  dependency.
- Step 4, the mutant: put the old line back by hand
  (`if (core.getState().status === 'signedIn') lastError = null;`), see a
  new test fail, restore the file, confirm its diff is empty.
- Step 5: Claude reviews the code change too, not only the tests.
- Step 8: also record the lines Codex wrote, code and tests apart.

Pass: as in the first trial, with "no file touched but the two targets".

What it can and cannot show: whether Codex writes a correct change to
existing code from a brief. The change is a few lines, so Claude's token
saving will again be inside the noise; that number needs a task where the
builder writes a few hundred lines, picked when one comes up.

Owner steps: when App01 step 6 is merged, tell the App01 session to read
this section and run it; type the merge line at the end.

### Phase 3 — Measure and decide

For each of the three cases: keep as default, make opt-in, or drop, with
the number behind it in the decision log. Then move this plan to
`plans/completed/`.

#### Phase 3 result (2026-10-12): closed, no rule merged

The owner's goal for a second model is one thing: lower the tokens the
first model uses. Measured against that goal:

| Case | Decision | Number behind it |
|---|---|---|
| Second model as reviewer or critic (swap) | Dropped | Phase 0: it found 1 of 2 planted bugs, the same-model reviewer both and more, in 12 s against 73 s |
| Second opinion, one extra pass on high-risk work | Dropped | It adds a pass and replaces none, so it adds tokens for the first model (the brief, the read of the report) |
| Second model as builder of clear low-risk work | Dropped | Trial 1: 331k weighted units against 381k for a like task, inside the noise. Trial 2: failed by its own rule, 262k, no like task to compare. No saving shown |

PR #20 was closed without a merge. Its rule text (the second opinion and
"Second model as builder, on request", after a critic's read) stays on the
branch `docs/cross-model-second-opinion`, last commit c3a1960, for a later
reader. `router/ROUTER.md` is as it was: no criteria for a second model.

What a new test needs before this is opened again: a task where the builder
writes a few hundred lines from a clear brief (the two trials wrote 48 and
92), not `sensitive_paths`, with a same-size task built by the first model
alone next to it, both measured with `scripts/usage-report.py`. The brief
must open with the dispatched-builder line (decision log). Until such a
task comes up, the cheaper place to look for tokens is subagent cost
(idea 12 in section 5).

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

Owner's answers (2026-10-12):

- **Q6:** go on to phase 1 with the narrower rule: an extra, opt-in opinion
  on high-risk work, not a swap of the default reviewer. This also settles
  Q1: no case is on by default. Cases 1 and 2 of the phase 1 draft are
  dropped; case 3 stays only as an extra pass.
- **Q5:** the owner asked for the way that costs the fewest tokens and
  still works. Chosen: (b) the direct run, which returns when done; (a) the
  report file only when the pass must run as an Orca worker. No wait for
  `worker_done`.
- **Q2:** Claude and Codex are both subscription plans (separate limits):
  a Codex pass does not use Claude budget beyond the brief and the read of
  its report.
- **Q3:** later. Until answered the second model does not build.
- **Q4:** not needed: phase 0 showed the hooks run in a trusted checkout.

Owner's later answers (2026-10-12, after PR #20 was opened):

- **Q3:** yes, as a trial: the second model may build clear, low or
  medium-risk work under a Claude plan and a Claude review (phase 2 as
  planned). Never `sensitive_paths`.
- The critic stays with Claude. Tests that kill a named surviving mutant
  may go to Codex with a Claude review.
- When Codex has no quota left, Claude does the work as usual.

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
| 2026-10-12 | 1 | Owner answered Q2, Q5, Q6 and put Q3 off (section 4). Rule written in its narrow form: `router/ROUTER.md` ("Second opinion from another model family"), `router/ORCA-INTEGRATION.md` section 6, pointer lines in `workflows/build-review.md` and `rules/testing.md`. No line in `workflows/independent-compare.md`: the second model does not build. Links pass. A critic read the rule text: 8 findings, 7 taken (read-only mode and a `git status` check, A4c must show OK since it is only a warning in doctor, the report file as the one allowed write, findings judged by the session that holds the task, a 10-minute cap, no model family bound to reviewer or critic, at most one pass per task). Not taken: drop the one-line offer; kept, because the routing decision already waits at this risk, the owner decides at PR review |
| 2026-10-12 | 2 (plan) | Owner judged Codex mid-level next to Claude and asked how to split work. Phase 2 rewritten: Codex builds one clear low-risk task under a Claude brief and review. Task picked from the open work of vn30 and App01: vn30 CB1 NIT (a), one test for an unguarded date filter. Nothing run. PR #20 on hold (draft) |
| 2026-10-12 | 2 | Trial run in a vn30 session (381dab8e), steps 1-7 done but the merge: vn30 PR #80 open, CI green, waiting for the owner's merge line. Codex (codex-cli 0.162.1, gpt-5.6-terra, effort medium, `env -u CODEX_HOME codex exec --sandbox workspace-write`, 35-line brief on stdin): one run, 130 s, exit 0, 22,910 tokens, all four hooks ran. It touched only the target, `backend/tests/test_cb1_vci_only_scope.py` (48 lines, 4 tests). The tests pass on today's code; 5 hand mutants of the filter all killed (filter removed 2 tests fail, each bound removed 1, lower bound strict 3, upper bound strict 1), file restored, diff empty. Fix rounds 0. Claude's review: 0 blocker, 0 major, 0 minor, 2 suggestions not fixed (fakes simpler than the helpers of `test_cb1_check.py`, so the first loop of `check_cb1` is never entered; the docstring does not name the NIT). `make verify` 905 passed, CI `verify` passed. Owner steps: "continue" (1), the merge line (2, to come); no question asked. Pass criteria: all four met, the last one pending the merge. Claude's cost for the task, from the transcript (`scripts/usage-report.py` weights): 19 calls in 10 min, 15.1k output tokens, 77k cache write, 1.59M cache read, peak context 110k, 331k weighted units. Next to it the Claude-only vn30 PR #79 (session df1cfcf0; 33 lines added in 3 files, PR #80 adds 49 in 2): 25 calls, 14.7k output, 82k cache write, 2.06M cache read, 381k weighted units, 4 owner messages. Not a clean pair: the PR #79 session also picked and proposed its task, and the trial session read this plan and wrote a brief. On a task this small the saving is within that noise (13% fewer units); the base context of each call is the cost, not the 48 lines written. Also seen: neither session printed the fixed `Lodestar route:` line (the trial notes name the route, the transcript has no such line) |
| 2026-10-12 | 2 (plan) | Owner chose the second trial before any rule text. Planned ("Second trial as planned"): Codex changes feature code in App01, the test screen's last-error clearing left open by its PR #15. Not started: an App01 session is in the middle of step 6 on `feat/week1-step6-sentry` and changes the same file, so the trial waits for that merge. App01's checkout and handoff were not touched from here. Doctor A4c in App01 with `CODEX_HOME` unset: OK |
| 2026-10-12 | 2 (trial 2) | Run in an App01 session (67012b35) after App01 PR #16 was merged; branch from the updated `main`, no worktree, doctor passed with A4c OK, route line printed (`BUILD_REVIEW risk=low`). Steps 1-7 done: App01 PR #17, CI green (run 38204269374), merged as 2451adc on the owner's merge line. Codex (codex-cli 0.162.1, gpt-5.6-terra, effort medium, `env -u CODEX_HOME codex exec --sandbox workspace-write`, brief on stdin). Run 1 (78-line brief): 302 s, exit 0, 56,786 tokens, hooks ran (UserPromptSubmit, PreToolUse, PostToolUse, Stop). It touched only the two targets: `test-screen-model.ts` +4/-2 (a `previousStatus` kept between notifications; correct, no review finding on the code) and the new `test-screen-error-kept.test.ts`, 88 lines, 3 tests on a hand-written `AuthCore` fake. Old line put back by hand: 1 new test fails; file restored. Claude's review: 0 blocker, 0 major, 1 MINOR in the tests: with `previousStatus = state.status;` deleted all 3 tests still passed, so the usual order (screen opens signed out or loading, sign-in, error later, token refresh) was not covered; every test that kept the error started already signed in. Fix round (53-line brief, test file only): 51 s, exit 0, 17,321 tokens, **no change made**. Codex acted as the Router (the global bootstrap), ran `bash .claude/hooks/doctor.sh` inside its sandbox, got "Not ready: 5 required item(s) failed" (`make` is not in the sandbox, so the Makefile, hook and enforcement checks fail there) and stopped to ask for "skip onboarding". Run 1 read the same Router files but did not run doctor. Neither brief said that the run was a dispatched builder that skips routing. Claude then added the missing cases (15 lines, `it.each` over `signedOut` and `loading`): 5 tests; old line back 3 fail, `previousStatus` never updated 2 fail, file restored each time. `make verify` 54 files, 450 tests. **Trial failed by its own rule** (the one fix round did not make it right and Claude finished). Against the pass criteria: mutant killed yes; at most one fix round yes, but it produced nothing; no file but the two targets yes; owner steps: the instruction to run this section (1), the merge line (2), no question asked. Lines: Codex code +4/-2, Codex tests 88; Claude tests 15. Claude's cost from the transcript, from the owner's instruction to the green CI (`usage-report.py` weights; a lower bound, the transcript lags the last calls): 18 calls, 13.8k output tokens, 34k cache write, 1.51M cache read, peak context 99k, 262k weighted units. Not comparable with trial 1 (the session began after a `/clear` with a small context). What it shows: the code change from the brief was right first time; the test gap is the same kind as in phase 0 (the missing case not seen); and a second Codex run in the same checkout can stop on the readiness check, which costs the fix round |
| 2026-10-12 | 2 | vn30 PR #80 merged by the owner (09b76ab): the first trial is complete, all four pass criteria met. App01 PR #17 (trial 2) merged later the same day (row above) |
| 2026-10-12 | 1 (rewrite) | PR #20 rule rewritten to match both trials. The second opinion is unchanged. New in `router/ROUTER.md`, "Second model as builder, on request": only when the owner asks on that task, never offered; one clear low or medium-risk change, never `sensitive_paths`; trusted checkout, no new worktree; the brief opens by saying the run is a dispatched builder (no routing, no readiness check); the session that holds the task runs the tests, breaks the code by hand to see a test fail, and reviews for the missing case; at most one fix round. One pointer in `workflows/build-review.md`. Links pass. No critic has read the new text yet |
| 2026-10-12 | 1 (rewrite) | A critic read the builder section (owner asked for it): 10 findings (6 major, 3 minor, 1 suggestion), all taken, none needs a new trial. `HEAD` and the branch noted before the run and unchanged after, `git status --porcelain` lists only the targets, a touched locked test, `.ai/`, hook or CI file discards the run; the brief (the fix round's too) also forbids `make`, tests, commit, push and a branch change, and holds no secret; the run's Stop check may fail in its sandbox, the session's `make verify` is the gate; for a small change the check is the workflow's review and the session runs the tests; never in tests-first mode or on a high-risk invariant; a 10-minute stop with a rule for a partial result; "asks" means the owner's own message for that task; direct run only, on the task's branch; "weak in two of three measurements"; one line under "Agent Selection" pointing to the two sections. Links pass; pushed as c3a1960, CI green. The critic run cost 66k tokens |
| 2026-10-12 | 3 | The owner asked whether Codex lowers Claude's tokens; the measured answer is no at this task size. Owner: PR #20 is not used. PR #20 closed without a merge, its branch kept. Phase 3 result written, plan moved to `plans/completed/` |

## 7. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-10-12 | Evidence (phase 0) before any rule text | Hook trust is per path; a dispatched worker with silent, skipped hooks would break the harness's main promise |
| 2026-10-12 | The rule swaps a worker for the other model; it adds no worker | Subagents are already 15.2% of cost and the owner watches tokens |
| 2026-10-12 | Phase 0 stop rule not hit: hooks run for a dispatched Codex worker when it is placed in an existing checkout whose hooks the owner has trusted. The rule must dispatch only there and must check trust first (doctor A4c) | Trusted: the sensitive gate refused the probe. Untrusted: the same edit was applied with no hook and no warning |
| 2026-10-12 | Open for the owner before phase 1: how the result comes back (Q5), and whether phase 1 goes ahead at all (Q6) | The Codex worker could not send `worker_done` from its sandbox, so the coordinator waited 9 minutes for nothing; and on the one test diff Codex found less than the Claude reviewer, slower |
| 2026-10-12 | Phase 1 rule is narrower than the draft: one extra, read-only, opt-in pass on high-risk work; the reviewer and critic are never swapped | Owner's answer to Q6. On the one measured diff the second model found less and was slower, so a swap would lower review quality |
| 2026-10-12 | The pass runs as a direct run that returns when done; a report file only under an orchestrator; never a wait for `worker_done` | Owner's answer to Q5 (fewest tokens that still works). The Orca wait cost 9 minutes and returned nothing |
| 2026-10-12 | The second model does not build, also not in INDEPENDENT_COMPARE | Q3 put off by the owner |
| 2026-10-12 | Hold PR #20; try the second model as builder before any rule is merged | Owner: Codex is the weaker model, so it should not sit at the review gate; building from a clear brief is where a mid-level model costs least risk and saves the most Claude budget. Not measured yet, so a trial first |
| 2026-10-12 | The critic is not moved to the second model | It guards what a non-coder owner signs, and finding missing cases is where Codex did worst in phase 0. Its cost is a matter for idea 12 |
| 2026-10-12 | A second trial (Codex writes feature code) before PR #20 is rewritten | Owner's choice. The first trial passed but was one test file, and Claude's cost did not drop measurably (331k against 381k weighted units, not a clean pair); a rule from that alone would rest on no measured gain |
| 2026-10-12 | The second model as builder is on request only, never offered and never a default (proposed in PR #20; the owner decides at the merge) | Trial 1 passed, trial 2 failed by its own rule (the fix round produced nothing and Claude finished the tests), and Claude's cost did not drop measurably in either. The code Codex wrote was right both times; its tests missed a case once, the same weakness as in phase 0 |
| 2026-10-12 | A builder brief must open by saying the run is a dispatched builder that skips routing and the readiness check | In trial 2 the fix-round run acted as the Router, ran doctor inside its sandbox, failed 5 items (no `make` there) and stopped with no change |
| 2026-10-12 | No second-model rule is merged; all three cases dropped; the plan is closed | Owner: the goal is to lower the first model's tokens with a second model, and if that is not shown the rule is not wanted. Neither trial showed a saving; the second opinion adds cost. A rule that saves nothing would only add text every Router session reads |
| 2026-10-12 | Open again only with a task of a few hundred written lines and a like task to compare | Below that size the first model's cost is its per-call context, not the lines written, so a small trial cannot show a saving either way |
