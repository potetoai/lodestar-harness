# Idea: which rules a machine checks, and which are only written

Not rated. An active plan rates it before any work (`plans/ideas/README.md`);
`plans/active/harness-health.md` is the natural one, since it asks whether
Lodestar catches bugs.

## 1. Why

The owner asked on 2026-10-29 whether an outside "full audit" prompt suited
Lodestar. Answer: most of it already exists (evidence-based plans, data gates,
idea rating), and its 20-30 task benchmark costs too much. The one cheap,
useful part: list the key rules and say which a hook or CI enforces and which
an agent can skip unseen. Read-only; nothing was changed.

## 2. Table (state of main at 59346e7)

| Rule | Where written | Enforced by | Gap |
|---|---|---|---|
| `make verify` passes before stop | `rules/enforcement.md` 1 | `verify-before-stop.sh` (Stop) | Holds once per state, then lets the stop end; CI is the gate (by design) |
| Readiness before feature work | Router rule 15 | global readiness hook, `doctor.sh` | Reminder only; never blocks (by design) |
| Tests-first for sensitive code | Router rule 16, `rules/testing.md` | `sensitive-gate.sh`, `protect-tests.sh`, `approval-record.sh`, `ci-checks.sh` 1, 3 | None found |
| Merge only on green CI, by `merge-pr.sh` | `rules/git.md`, `AGENTS.md` | `guard-install.sh` blocks other merges; `merge-pr.sh` | GitHub web merge by a person is outside it (F2) |
| No push to main, no `--no-verify` | `rules/enforcement.md` 6 | `pre-push.sh`, `guard-install.sh` | None found |
| Route line, SIMPLE small, review for BUILD_REVIEW+ | Router, `workflows/build-review.md` | `ci-checks.sh` 7, `merge-pr.sh` 1 | Review line content is not checked (F1) |
| Risk level chosen honestly | Router "Risk" | none (agent writes `risk=`) | Mitigated: sensitive paths are gated by state, not by `risk=` |
| Security review for security tasks | Router rule 13, `rules/security.md` | none | Text only (F3) |
| Human approval for destructive ops | Router rule 12, `rules/git.md` 13 | none in Lodestar; the runtime's permission mode | Text only (F4) |
| Critic run limit | `agents/critic.md` | `critic-limit.sh` (Claude only) | Codex has no dispatch hook; already listed in `enforcement/runtime-parity.md` line 20 |
| Repeated mistake becomes a machine rule | `rules/enforcement.md` 8 | `feedback-check.sh` (keyword nudge), doctor D2 (warning) | Depends on keywords and on the agent logging the row (F5) |
| Final result meets acceptance criteria (non-sensitive tasks) | Router step 1, rule 10 | reviewer only | No machine check; normal, a script cannot judge it |

## 3. Findings

Kinds: **defect** = a check that should catch a case and does not;
**risk** = a rule with no check, harm possible; **watch** = unclear, needs data.

- **F1 (defect, P1).** The review line passes with any text.
  `ci-checks.sh` line 267 and `merge-pr.sh` line 58 test only
  `^Lodestar review: [^[:space:]]`. So `Lodestar review: changes requested, x, abc`
  passes, and so does a review of an older commit after new commits land.
  Fix idea: require a verdict word from a short list (pass/APPROVE) and a
  commit that is an ancestor of, or equal to, the PR head; with commits after
  it, only `.ai/` or review-fix commits allowed, or fail with "review again".
  Cost: small script change plus tests in `enforcement/test.sh`; risk of
  breaking old PR texts is low (only new merges are checked).
  Check: new tests for "changes requested" and "old commit" fail; existing
  route tests still pass.
- **F2 (risk, P2).** When CI cannot run (no Actions minutes, App01 and ProjectS
  in late October), people merge on GitHub by hand and no Lodestar check runs:
  ProjectS #157-#170 were hand-merged with a missing review line or a wrong route line (`.ai/handoff.md`,
  sweeps 2026-10-28/29). Fix #92 ships with the batch. Idea only: the daily
  maintenance sweep lists merged PRs whose text fails `route_check`, so the
  slip is seen within a day. Check: the sweep names #170 on ProjectS.
- **F3 (risk, P2).** Router rule 13 says a security-sensitive task is not done
  until `security_review` passes; no file under `enforcement/` reads that word.
  Fix idea: the review line names `security` when the route says so, checked
  like F1. First count how often security tasks happen (data gate), since a
  check nobody hits is cost without benefit.
- **F4 (watch, P3).** Destructive git commands (`reset --hard`, force push to
  a feature branch, `clean -fd`) rely on the runtime's permission mode, not on
  Lodestar. `enforcement/agents/claude/settings.json` holds only `hooks`, no
  `permissions.deny`. Fix idea: a few deny entries in the managed settings.
  Needs care: deny rules can block the owner's own work. Decide only after a
  real incident or a count of such commands in session logs.
- **F5 (watch, P3).** Learning from mistakes depends on correction keywords
  (`feedback-check.sh`) and on the agent writing the row; ProjectS has 8 rows,
  App01 none (`harness-health.md` section 1). That plan already measures this
  (HH-3); no separate work.

## 4. Not proposed

- A 20-30 task benchmark with and without Lodestar: proposed before
  (`plans/completed/ideas/context-budget.md`, `lodestar-efficiency-plan.md`)
  and never run; real-project data gates (`rules/documentation.md` 6) are cheaper.
- New agents, workflows or a separate audit file.

## 5. Suggested order if rated

F1 first (confirmed, small, testable). F2 with the next maintenance change.
F3 and F4 only after their data gate is met.
