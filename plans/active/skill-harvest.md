# Plan: skill harvest (good parts of popular plugins)

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time and stop after each for the repo owner's approval. Answer
> nothing in "Open questions" yourself. Update the progress and decision logs
> when a phase moves.

## 1. Why this plan

The owner asked whether to install popular GitHub skills. Eight plugins are
installed on this machine, all set to `false` in `~/.claude/settings.json`
since 2026-10-12 (`enforcement/setup-guide.md`, base context record). Instead
of turning plugins on, this plan rates what they do against Lodestar on main
(2.8.0), takes only the parts Lodestar lacks into its own files, and then
removes the plugins. The owner's goals (2026-10-27): shorter replies, shorter
code, fewer tokens. Every hook, test lock, review and approval stays.

## 2. Evidence (read 2026-10-27)

- Installed, all off: superpowers 6.3.0 (14 skills), andrej-karpathy-skills
  1.0.0 (1), caveman 2.7.0 (24), ponytail 4.10.0 (12), ui-ux-pro-max 2.13.0
  (13), taste-skill 1.0.0 (13), firecrawl 0.1.0 (33), expo 1.13.9 (24). No
  project's `.claude/settings*.json` turns one on.
- Cost split, 2026-10-12..15 (`agent-pitfalls.md`, phase 0): output 16.4%,
  subagents 27.9%, policy reading 1.9%. Subagent reports return to the main
  session as input and are re-read on every later turn there.
- Lodestar already holds most of the karpathy and superpowers content:
  `rules/coding.md` sections 2 (minimal change) and 21 (scope discipline),
  `rules/architecture.md` section 10 (anti-overengineering),
  `skills/investigate.md`, `skills/explore-options.md`, tests-first,
  `verify-before-stop.sh`, `merge-pr.sh`, the Router intake gate.
- Not in Lodestar: a rule for reply length or style (to the owner or between
  agents); a review pass that hunts code to delete; a rule that a builder
  checks a review finding against the code before fixing it; "remove what
  your own change left unused".
- `agents/reviewer.md` asks four fields per finding (location, problem, why,
  fix); no line format, no count of lines that could go.
- gstack (Garry Tan, read 2026-10-27 from github.com/garrytan/gstack):
  `plan-ceo-review` (1,275 lines) and `plan-design-review` (1,229) run their
  own tools, telemetry and question logs. The CEO review defaults to scope
  expansion ("completeness is cheap ... prefer ~150 LOC over ~80"), against
  the owner's short-code goal. Useful parts: the premise challenge (real
  problem, proxy or not, cost of doing nothing) and the UI principles (screen
  hierarchy, "don't make me think", cut words, visible tap targets of 44px on
  mobile, a 0-10 rating that says what a 10 needs).
- `skills/explore-options.md` already restates the goal and lists a "do
  less or do nothing" option, but only when the goal is open; it does not ask
  whether the request fixes the real pain or a proxy. `agents/frontend.md`
  covers loading, error and empty states and accessibility; it has no rule
  on hierarchy, word count or mobile tap targets.
- Matt Pocock's skills (github.com/mattpocock/skills, MIT, read 2026-10-27,
  about 20 core skills of 35): `grilling` asks in numbered rounds, each
  question with a recommended answer that "yes" accepts, and looks facts up
  itself; `diagnosing-bugs` ranks 3-5 hypotheses before testing any, tags
  temporary debug logs for one-grep cleanup, and names the confirmed cause in
  the PR; `code-review` has a spec axis (missing, not asked for, done wrong);
  `tdd` bans tautological tests; `pr` states one-way or two-way door and
  blast radius. `skills/investigate.md` asks for one hypothesis; the reviewer
  compares the diff to the criteria only in tests-first tasks.
- Popular lists (2026) rank superpowers, karpathy, frontend-design,
  agent-browser, claude-mem, ui-ux-pro-max, everything-claude-code highest.

## 3. Rating of every idea

Rating: **Do** · **Check** (measure first, act only if the number says so) ·
**Optional** (owner's choice) · **Covered** (Lodestar has it) · **Drop**.

| # | Source | Idea | Lodestar today | Rating |
|---|---|---|---|---|
| 1 | caveman (lite) | Replies to the owner: result first, short sentences, no filler, no narration between tool calls, quote only the decisive error line | Owner memory only; no rule | **Do**, phase 1 |
| 2 | caveman (full) | Subagent reports terse: fragments allowed, never drop not/only/except, numbers and errors exact | Nothing | **Do**, phase 2 |
| 3 | caveman-review, ponytail-review | One line per finding: `file:Lline: SEVERITY tag problem. fix.` | Four fields per finding | **Do**, phase 2 |
| 4 | ponytail-review, karpathy | Over-engineering pass: tags `delete`, `stdlib`, `native`, `yagni`, `shrink`; ends with `net: -N lines possible` | Anti-overengineering rules, no review step | **Do**, phase 3 |
| 5 | karpathy | Every changed line traces to the request | `rules/coding.md` section 2 | **Do** as a builder self-check, phase 3 (one line) |
| 6 | karpathy | Remove imports and functions your change made unused; leave older dead code (report it) | Section 21 covers the second half | **Do**, phase 3 (one line) |
| 7 | superpowers receiving-code-review | Builder checks each finding against the code; if any finding is unclear, ask before fixing any | Disputed findings escalate (`workflows/build-review.md`) | **Do**, phase 3 (two lines) |
| 8 | ponytail-audit | Whole-repo over-engineering audit | Maintenance scans size, not complexity | **Optional** (Q3), phase 4 |
| 9 | karpathy | Surface assumptions, ask when unclear | Router intake gate | **Covered** |
| 10 | karpathy | Verifiable goal per step | Acceptance criteria, tests-first | **Covered** |
| 11 | superpowers | Debugging, TDD, brainstorming, plans, verify before done, worktrees, finishing a branch | `investigate.md`, tests-first, `explore-options.md`, plans, Stop hook, PROTOTYPE, `merge-pr.sh` | **Covered** |
| 12 | superpowers | Parallel and subagent-driven development | Runtime dispatch (AGENTS.md: never build orchestration) | **Covered** |
| 13 | ponytail-debt | Ledger of shortcut comments | `.ai/tech-debt.md`, reviewer checks it | **Covered** |
| 14 | migration skill | Reversible migrations | `agents/database.md` | **Covered** |
| 15 | caveman-compress | Compress CLAUDE.md and memory files | Policy reading 1.9% of cost; shortening dropped 2026-10-12 | **Drop** |
| 16 | caveman-commit | Terse commit messages | `rules/git.md` commit format | **Drop** |
| 17 | caveman cloud, stats, optimize | Token tracking through an outside gateway | `scripts/usage-report.py`, no outside service | **Drop** |
| 18 | claude-mem, supermemory | Extra memory store | Memory files and `.ai/handoff.md`; a second store drifts | **Drop** |
| 19 | agent-browser | Browser control | Playwright MCP (`skills/capabilities.md`) | **Covered** |
| 20 | everything-claude-code | Full config bundle | Would override the Router | **Drop** |
| 21 | ui-ux-pro-max, taste-skill, frontend-design | UI design guidance | Not covered | **Optional** (Q4): plugin on per project, no Lodestar text |
| 22 | expo, firecrawl | Expo apps, web scraping (paid key) | Not covered | **Optional** (Q4) |
| 23 | gstack plan-ceo-review | Premise check before a new user-facing feature: the real problem, does the plan fix it or a proxy, cost of doing nothing, smallest version that gives most of the value | `explore-options.md` steps 1 and 3, only when the goal is open | **Do**, phase 3b |
| 24 | gstack plan-design-review, design-review | UI checklist: screen hierarchy, cut words, conventions, visible tap targets (44px), every state designed; rate 0-10 and name what a 10 needs | `agents/frontend.md` states and accessibility | **Do**, phase 3b |
| 25 | gstack | Scope expansion modes, "boil the ocean", 12-month dream state | Minimal change rules | **Drop**: against the short-code goal |
| 26 | gstack | Mockup generation, own browser, telemetry, question tuning | Playwright capability; Router asks | **Drop**: heavy, sends usage data out |
| 27 | pocock grilling | For a large or unclear task: questions in numbered rounds, each with a recommended answer worded so "yes" accepts it; ask only decisions the owner can make, look facts up | Intake gate asks once | **Do**, phase 3b |
| 28 | pocock diagnosing-bugs | 3-5 ranked hypotheses, each with the observation that would disprove it; temporary debug logs carry one tag, removed by one grep; the confirmed cause goes in the PR text | `investigate.md` step 4: one hypothesis | **Do**, phase 3 |
| 29 | pocock code-review | Reviewer spec check on every diff: what was asked and is missing, what was not asked for, what looks done but is wrong | Criteria check only in tests-first | **Do**, phase 3 |
| 30 | pocock tdd | No tautological test: the expected value comes from the criteria or a known example, never computed the way the code does | Not covered | **Do**, phase 3 |
| 31 | pocock pr | PR text says whether the change can be undone (one-way or two-way door) and what it can affect | Route and review lines only | **Do**, phase 1 |
| 32 | pocock writing-for-agents | Cut rule lines that change no behaviour; state the wanted behaviour rather than only a ban | Rewording rules needs review; docs-tidy only moves text | **Optional**, owner's call after docs-tidy |
| 33 | pocock prototype | Logic prototype as one HTML file the owner can click | `workflows/prototype.md` | **Check**: decide when PROTOTYPE use is counted (agent-pitfalls phase 5) |
| 34 | pocock (rest) | Git guardrails, handoff, glossary and ADRs, wayfinder map, retro | `guard-install.sh`, `.ai/handoff.md`, Domain Terms, plans, maintenance | **Covered** |
| 35 | pocock (rest) | Parallel implementers and merger agents, architecture HTML report, smell list, questionnaire, wizard, teach, re-pitch | Runtime dispatch; idea 8; idea 4 | **Drop**: orchestration, overlap, or rare use |

## 4. Phases

All phases change text that agents read live from this repo (rules, roles,
Router), so no template release is needed. A phase that changes
`enforcement/` bumps `enforcement/VERSION` with the next batch.

Start only after `agent-pitfalls.md` phase 5 and `docs-tidy.md` phases 2-3
are recorded (Q1): phase 1 changes output length, phases 2-3 change roles
that those plans measure or move.

### Phase 0 — Baseline (read only)

- `python scripts/usage-report.py --since <14 days back>` for all projects:
  output share, subagent share, cost per owner-facing turn.
- Throwaway script in the session scratchpad (not committed): per subagent
  role, the median and 90th percentile length (tokens) of the final report,
  and how often the dispatcher sent a follow-up to the same subagent.
- Reviewer findings in the last 20 BUILD_REVIEW PRs: count, how many named
  code to delete or simplify, how many the builder fixed.
- Lines added per merged builder PR (median), as a rough code-size number.

Done when: the numbers are in the progress log.

### Phase 1 — Reply style to the owner (ideas 1, 31)

- New short section in `rules/documentation.md` (next to section 5,
  Language), about 10 lines: result first; short sentences, one idea each;
  no filler, praise or hedging; one line before the first tool call, no
  narration between calls; quote the shortest error line that decides; keep
  "not", "only", "except" and numbers exact; plain words in the owner's
  language. Full sentences stay: the owner is a non-coder (Q2).
- One pointer line in `router/ROUTER.md` where the final report is described.
- `rules/git.md` PR body (idea 31): one plain line, can it be undone (and
  how) and what it can affect. Text only; `merge-pr.sh` does not check it.

Done when: merged; two live sessions read by the owner.

### Phase 2 — Terse agent reports (ideas 2, 3)

- `router/ORCA-INTEGRATION.md` section 8 (Subagent cost): a report-format
  line every brief carries: terse fragments, never drop negations or
  numbers, errors quoted exact, no restating the brief.
- `agents/reviewer.md`, `agents/critic.md`, `agents/tester.md` Output: one
  line per finding, `file:Lline: SEVERITY problem. fix.`; severity names
  unchanged; "why it matters" only for BLOCKER and MAJOR.
- Report text reaching the owner is rewritten by the main session in the
  phase 1 style; subagent text is never pasted to the owner.

Done when: merged; first 5 subagent runs checked by hand for lost meaning.

### Phase 3 — Shorter code and review checks (ideas 4-7, 28-30)

- `agents/reviewer.md`: an over-engineering pass on every diff with the five
  tags (idea 4) and a closing `net: -N lines possible` (or "lean").
  Findings rate MINOR or SUGGESTION unless they hide a bug.
  A `delete` or `shrink` finding never targets handling of errors that can
  happen (network, empty data, bad input), tests, or security checks
  (`rules/security.md`): missing those is unfinished code, not short code.
- `agents/builder.md` Must Not / Responsibilities: every changed line traces
  to the request (idea 5); remove what your change made unused, report older
  dead code (idea 6); check each review finding against the code, ask about
  unclear ones before fixing any, push back with a reason (idea 7).
- `agents/reviewer.md` (idea 29): a spec check on every diff against the
  request or plan: missing, not asked for, done wrong; findings quote the
  request line.
- `skills/investigate.md` (idea 28): step 4 lists 3-5 ranked hypotheses,
  each with its disproving observation; debug lines carry one tag and are
  removed by grep before the fix commit; the report's cause goes in the PR.
- `rules/testing.md` and `agents/tester.md` (idea 30): one line against
  tautological tests.
- No hook, no CI check: these are judgment rules a script cannot verify.

Done when: merged; a dry run on one recent App01 or vn30 diff (read only)
shows the pass output.

### Phase 3b — Product, UI and intake checks (ideas 23, 24, 27)

- `skills/explore-options.md` step 1: add the premise check (real problem;
  does the request fix it or a proxy; cost of doing nothing; smallest version
  that gives most of the value). The Router selects explore-options for a new
  user-facing feature even when the goal looks clear (one line in
  `router/ROUTER.md`). It recommends; it never adds scope without the owner.
- `agents/frontend.md`: a UI checklist of about 10 lines (idea 24), mobile
  rules included. The reviewer applies it when the diff touches UI files and
  reports a 0-10 rating with the gaps to a 10, as MINOR or SUGGESTION.
- Router intake gate (idea 27): for COMPLEX tasks or requirements still
  unclear after one question, ask in numbered rounds, each question with a
  recommended answer that "yes" accepts; only decisions the owner can make,
  facts are looked up. A small task keeps the single question.
- ui-ux-pro-max stays an optional plugin for deep design work; Lodestar text
  carries only the checklist.

Done when: merged; a dry run on one recent App01 `apps/mobile` diff (read
only) shows the checklist output.

### Phase 4 — Repo audit in maintenance (idea 8, only if Q3 is yes)

- `workflows/maintenance.md`: one step that runs the phase 3 pass over the
  largest or most-changed files (top 10 by `git log` churn), output into the
  maintenance report; the owner picks what to cut.

Done when: one maintenance run shows the list.

### Phase 5 — Remove plugins (machine, not repo)

- Uninstall the plugins Q4 does not keep (`claude plugin uninstall`), record
  the list in `enforcement/setup-guide.md` under the base context record.
- Set a kept UI plugin to `true` only in the project that needs it.

Done when: `installed_plugins.json` matches Q4.

### Phase 6 — Measure and close

About two weeks after phase 3 merges, rerun phase 0. Keep a phase if:

- phase 1: output tokens per owner-facing turn down 20% or more, and the
  owner finds replies clear;
- phase 2: median subagent report down 30% or more, with no rise in
  follow-ups to the same subagent;
- phase 3: lines added per builder PR do not rise, and over half of the
  `delete`/`shrink` findings are fixed (the rest are noise: tighten or drop);
- phase 3b: in the features it ran on, the owner took a smaller or no-build
  option at least once, or found the check useful; over half of the UI
  checklist findings in App01 are fixed; grilling rounds per task stay at
  3 or fewer (median) and the owner finds them easier than open questions;
- ideas 28-31: over half of the spec-check findings are fixed, and no
  owner complaint about PR text length.

Otherwise change or revert, with the number in the decision log. Then move
this plan to `plans/completed/`.

## 5. Open questions

- **Q1 (start):** start after `agent-pitfalls.md` phase 5 and `docs-tidy.md`
  phases 2-3 (about 2026-11-02), or now? Recommended: after; starting now
  mixes their numbers. **Answered 2026-10-27: after 2026-11-02.**
- **Q2 (phase 1):** reply level for the owner. (a) Lite: full sentences,
  no filler. Recommended for a non-coder. (b) Full caveman: fragments.
  **Answered 2026-10-27: (a).**
- **Q3 (phase 4):** add the repo audit to maintenance? It costs one reviewer
  run per maintenance. Recommended: decide after phase 3 numbers.
  **Answered 2026-10-27: decide after phase 3 numbers.**
- **Q4 (phase 5):** which plugins stay. Recommended: keep ui-ux-pro-max (off,
  per project); expo only if a project builds an Expo app; remove the other
  six. **Answered 2026-10-27: as recommended; keep expo (App01
  `apps/mobile` is Expo), on only for App01 via its gitignored
  `.claude/settings.local.json` (App01's session sets it).**

## 6. Not in scope

- Turning any plugin on for all projects.
- Shortening policy files for tokens (dropped 2026-10-12).
- New hooks or CI checks for style: judgment rules stay review text.
- Any orchestration; the runtime dispatches.
- Relaxing any hook, test lock, review or approval.

## 7. Progress log

| Date | Phase | Note |
|---|---|---|
| 2026-10-27 | — | Plan written; 22 ideas from 8 installed plugins and 2026 popular lists rated against main 2.8.0 |
| 2026-10-27 | — | Ideas 23-26 added from gstack (owner asked) |
| 2026-10-27 | — | Phase 3 guard: the over-engineering pass never cuts real error handling, tests or security checks |
| 2026-10-27 | — | Ideas 27-35 added from Matt Pocock's skills (owner asked) |

## 8. Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-10-27 | Harvest ideas into Lodestar files instead of turning plugins on | Owner; plugins add base context every session and their always-on rules conflict with the Router |
| 2026-10-27 | Q1 after 2026-11-02; Q2 (a); Q3 after phase 3; Q4 keep ui-ux-pro-max and expo, remove superpowers, karpathy, caveman, ponytail, taste-skill, firecrawl | Owner; App01 builds an Expo app |
| 2026-10-27 | From gstack take only the premise check and the UI checklist; no gstack install | Owner asked; the rest overlaps Lodestar, expands scope, or sends telemetry |
| 2026-10-27 | From Matt Pocock's skills take grilling rounds, ranked hypotheses, the spec check, the tautological-test ban and the undo line in PRs; no install | Owner asked; the rest is covered, is orchestration, or is rare use |
