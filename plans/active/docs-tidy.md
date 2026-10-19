# Plan: docs tidy (rated idea plans, padding and duplicates)

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time and stop after each for the repo owner's approval. Answer
> nothing in "Open questions" yourself. Update the progress and decision logs
> when a phase moves.

## 1. Why this plan

The 2026-10-16 review of the whole harness found policy docs that said
different things in different places (fixed in PR "docs: make routing docs
agree", items 1-7 of that review). Two items were left for this plan:

- **Item 8:** four idea plans in `plans/ideas/` (1,098 lines) were all rated
  and merged into `plans/completed/token-efficiency.md` on 2026-10-02. They
  are still in the folder meant for ideas not yet rated.
- **Item 9:** the large policy files are padded and repeat each other. Lines
  / blank lines on 2026-10-16, after the fix PR: `ORCA-INTEGRATION.md`
  881/248, `rules/testing.md` 687/212, `ROUTER.md` 542/201, `rules/git.md`
  531/175, `rules/coding.md` 508/182, `agents/architect.md` 411/132.

Goal: fewer places for the same rule, so a later edit cannot leave two
versions that disagree. **Not** a token saving: policy reading was 1.1-1.9%
of cost (`plans/completed/token-efficiency.md`, `agent-pitfalls.md` phase 0),
and the owner dropped shortening for tokens on 2026-10-12.

## 2. Limits

- `AGENTS.md`: shorten only by removing blank lines or moving text; never
  reword a rule without review. Every phase that moves text gets a review
  (Sonnet reviewer) that checks no rule was lost or changed.
- Do not delete policy: a duplicate becomes a link to the one place that
  keeps it.
- `bash scripts/check-links.sh` passes after each phase. No file under
  `enforcement/` changes, so no template bump.
- Do not touch `plans/completed/subagent-cost.md` or `agent-pitfalls.md` text
  beyond link paths while they are measuring.

## 3. Phases

### Phase 1: Rated idea plans (item 8)

Depends on Q1. With (a): move the four files to `plans/completed/ideas/`,
update the links in `AGENTS.md`, `plans/completed/token-efficiency.md` and
`plans/completed/subagent-cost.md` (path only), and say in `AGENTS.md` that
`plans/ideas/` holds unrated ideas only.

Done when: `plans/ideas/` holds no rated plan; links pass.

### Phase 2: Padding (item 9, blank lines only)

In the six files above: remove blank lines inside lists, arrow chains
(`Task / → One agent / → Verify`) and examples, and the one-word
`Claude or Codex` repetition in `ROUTER.md` "Agent Selection" (keep one
sentence saying any agent can take any role). Headings, rules and examples
keep their words.

Done when: each file's blank-line count is at least a third lower, the
reviewer finds no changed rule, links pass.

### Phase 3: Duplicates (item 9, move and link)

Candidates, each checked against its source before it becomes a link:

- `rules/git.md` §18 Independent Compare and §19 Review Workflow vs
  `workflows/independent-compare.md` and `workflows/build-review.md`.
- `rules/testing.md` §23 Reviewer and §24 QA vs `agents/reviewer.md` and
  `agents/qa.md`.
- `rules/coding.md` §10 Security vs `rules/security.md`.
- `router/ORCA-INTEGRATION.md` §5 Workflow Mapping and §10 Parallel
  Execution vs `ROUTER.md` and `workflows/*.md`.
- `agents/architect.md` Frontend/Backend Architecture vs
  `rules/architecture.md`.

A line that exists only in the copy moves to the kept place first. One
commit per pair, so a reviewer sees each move.

Done when: each pair is one text plus a link, or kept with a reason in the
decision log; the reviewer finds no lost rule; links pass.

### Phase 4: Check and close

Two weeks after phase 3, read the feedback logs of this repo, vn30 and App01
for any miss traced to a moved rule. None: move this plan to
`plans/completed/`. Any: put the text back where the miss happened.

## 4. Open questions

- **Q1 (phase 1):** on 2026-10-02 the owner chose to keep the four source
  plans in `plans/ideas/` (`token-efficiency.md`, Q3). (a) Move rated ideas
  to `plans/completed/ideas/`, so `plans/ideas/` means "not yet rated".
  Recommended. (b) Keep them where they are; each already says at its top
  that it was merged. **Answered 2026-10-16: (a).**
- **Q2 (phase 2-3):** run phases 2 and 3 now, or after
  `agent-pitfalls.md` phase 5 (about 2026-10-30), so the moved text does not
  mix with that plan's measurements? Recommended: after. **Answered
  2026-10-16: after.**

## 5. Not in scope

- Rewording rules to make them shorter.
- Any change to hooks, CI, tests or `enforcement/`.
- The slow local `enforcement/test.sh` (about 10 minutes on Windows, 1.5 on
  CI); raise it as its own idea if it starts to cost real work.

## 6. Progress log

| Date | Phase | Note |
|---|---|---|
| 2026-10-16 | - | Plan written from the harness review (items 8 and 9); PR #44 merged the fixes for items 1-7 |
| 2026-10-16 | 1 | Four rated idea plans moved to `plans/completed/ideas/`; paths updated in `AGENTS.md`, `token-efficiency.md` (line 10; its 2026-10-02 decision rows kept as history) and `subagent-cost.md` (path only); `plans/ideas/` is now empty. Links pass |
| 2026-10-16 | 1 | PR #45 merged (0dba3f4) on green CI; `plans/ideas/` kept in git with a README |

## 7. Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-10-16 | Plan item 9 although shortening was dropped on 2026-10-12 | Owner asked; the aim is one place per rule (the review found four docs that disagreed), not tokens |
| 2026-10-16 | Q1 (a): rated ideas live in `plans/completed/ideas/` | Owner; `plans/ideas/` then means "not yet rated" |
| 2026-10-16 | Q2: phases 2-3 wait until `agent-pitfalls.md` phase 5 (about 2026-10-30) | Owner; moved text must not mix with that plan's measurements |
