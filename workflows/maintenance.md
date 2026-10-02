# Maintenance Workflow

Maintenance keeps a project healthy, like servicing a car: check, fix small
things, tighten what came loose. It never deletes the project and never
changes what the app does. (Vietnamese: "bảo trì định kỳ".)

## Purpose

Keep an onboarded project healthy between features: learn from repeated
mistakes, pay down debt, shrink the lint baseline, and keep the enforcement
templates current. Every run makes a few small PRs that are easy to review.

## When it runs

Every 14 days. When onboarding finishes (S4), ask the owner where it runs:

- **On this machine (default).** `doctor.sh` warns (D1) when
  `.ai/last-maintenance` is older than 14 days, and the global session hook
  tells the agent. Then offer to run maintenance. Every check runs, including
  the ones that need local services (a database, a dev server).
- **In the cloud, on a schedule (Claude Code `/schedule`).** Only when CI
  already runs every check the project has, so nothing needs this machine.
  The cloud agent sees only GitHub repos, not local paths, so use this
  prompt: "Clone the lodestar-harness repo named in `.ai/enforcement.json`
  (`repo`) and run its `workflows/maintenance.md` in this repo; use that clone
  wherever the repo docs point to a local lodestar-harness path. Skip steps that need local
  services and list them in the report. Open PRs only; never merge." The
  owner approves it once. D1 still warns if the routine stops running.
- When the owner asks.

## Agent Model

One agent. Maintenance never adds features and never changes behavior on purpose.

## Budget

At most **3 PRs per run**, each small enough to review in a few minutes.
Pick the items with the highest value first; leave the rest for the next run.
Stop early when nothing is worth a PR.

## Steps

1. **Health.** Run `bash .claude/hooks/doctor.sh`. If the template is
   outdated (A9b), run `bootstrap.sh <dir> --stack <s> --upgrade` (stacks are
   recorded in `.ai/enforcement.json`) as the first PR. `--upgrade` never
   touches [project] files, so compare them with the new templates in
   `enforcement/project/` and `enforcement/stacks/` (for example the
   `.ai/feedback-log.md` columns, or the `lint-file` recipe) and
   bring them up to date by hand in the same PR. If `.ai/project.md` has no
   `owner_language:` line, ask the owner which language they want to talk in
   and add it. If the project keeps its handoff in another file (a status
   file such as `DANG-LAM.md`), move it into `.ai/handoff.md` (gitignored)
   and delete the old file. Point every reference to the old file at
   `.ai/handoff.md`. The upgrade PR adds the `.gitignore` line, so a branch
   cut from main before it merges does not ignore the handoff yet: stage
   files by name and check that no PR diff lists `.ai/handoff.md`. Rerun the
   onboarding canary (`workflows/onboarding.md`, B1) in each stack: if lint
   passes a file that uses an undefined name, turn that rule on in this PR.
2. **Sweep for missed mistakes.** Since the date in `.ai/last-maintenance`, look
   for agent mistakes that never reached `.ai/feedback-log.md`: commits that
   fix or revert code added shortly before (`git log --since`), and PRs the
   owner closed unmerged or asked to change (`gh pr list --state all`,
   `gh pr view --comments`). Add a row for each, in your own words, with a tag.
3. **Repeated mistakes (D2).** In `.ai/feedback-log.md`, find tags seen two or
   more times that are not `enforced`. Turn each into a machine rule
   (`rules/enforcement.md`, sections 7–8), with a fixture that proves it
   catches the mistake. Set the rows to `enforced`.
   Rows tagged `lodestar-` (or `orca-` before 2.0.0) need no project rule.
   List them in the report, so the owner can have them fixed in
   lodestar-harness; set a row to `fixed-<version>` once the installed
   template contains the fix.
4. **Debt.** In `.ai/tech-debt.md`, take overdue items first, then the
   smallest ones. Fix one, or update its due date with a reason.
5. **Baseline.** Remove one group from the lint baseline (one rule, or one
   file of per-file ignores). Fix what appears. The baseline only shrinks.
6. **Golden principles.** Scan for violations of
   `rules/golden-principles.md` that the checks do not catch yet. Fix small
   ones; record large ones in `tech-debt.md`.
7. **Close.** Write today's date to `.ai/last-maintenance` in the last PR. Report
   to the owner: PRs opened, debt paid, baseline size before and after,
   rules added, what is left.

## Rules

- Same gates as any change: hooks, `make verify`, CI, review. Sensitive paths
  still need tests.
- No behavior change. If a fix would change behavior, record it in
  `tech-debt.md` and ask the owner instead.
- Each PR does one thing, so the owner can merge or reject it alone.
