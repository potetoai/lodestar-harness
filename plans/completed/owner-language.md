# Plan: agents talk to the owner in the owner's language

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time and stop after each for the repo owner's approval. Update the
> progress and decision logs at the end when a phase moves.

## 1. Goal

A project owner who does not speak Vietnamese can use Orca. The owner's
language applies to one thing only: the conversation between the agent and the
owner. Everything written to files stays in English: code, comments, notes,
plans, `.ai/` files, commit messages, PRs, and the CI summary.

Each project declares `owner_language:` in `.ai/project.md`. Missing means
English.

## 2. Current state (surveyed 2026-09-30)

Most hook messages are already English and go to the agent, not the owner.
Vietnamese that remains:

| Where | Change |
|---|---|
| `enforcement/agents/claude/hooks/ci-checks.sh` section 5 (PR summary) | Vietnamese text becomes English |
| `enforcement/test.sh` | The case that looks for Vietnamese in the PR summary checks English instead |
| `approval-record.sh`, `sensitive-gate.sh`, `protect-tests.sh`, `verify-before-stop.sh` | Tell the agent the approval word is `duyệt` or `approve`, chosen by `owner_language` |
| `rules/testing.md`, `rules/enforcement.md`, `router/ROUTER.md` rule 16, `agents/tester.md`, `workflows/onboarding.md`, `enforcement/project/.ai/plans/TEMPLATE.md` | Same: name both approval words instead of only "duyệt" |
| `enforcement/project/.ai/plans/TEMPLATE.md` | "Write it in the owner's language" becomes "Write it in English" |
| `enforcement/cai-dat-may-moi.md` | Vietnamese step-by-step machine-setup guide, read by the owner before Claude Code is installed. Translate to English as `enforcement/setup-guide.md`, same plain step-by-step style; remove the Vietnamese file |

No change needed:

- Approval detection in `approval-record.sh` already accepts
  `duyệt`/`duyet`/`approve`/`approved` and English negations. The owner
  rejected adding "ok" (too common, false approvals).
- Hooks never need to read `owner_language`: they print English for the agent,
  and the agent speaks to the owner.
- Nothing in Orca tells agents to speak Vietnamese today. That comes from this
  machine's private memory, not from Orca.

## 3. Design

- New field in `.ai/project.md`, next to `sensitive_paths:`:
  `owner_language: vi` (ISO 639-1 code: `vi`, `en`, `ja`...). Missing means
  `en`.
- New rule (in `rules/documentation.md`, pointed to from the project
  `CLAUDE.md` template): talk to the owner in `owner_language`, in plain
  words. Write every file, commit, PR and note in English.
- Acceptance criteria stay in English in the plan file (the hook hashes that
  text). The agent shows the owner a faithful translation in chat, with the
  English lines next to it, before asking for approval. The owner approves the
  file, not the translation.
- Approval word: `duyệt` for `vi`, `approve` for every other language. The
  hook accepts both in every project.
- No doctor check: only agents read the field. Onboarding asks for it;
  maintenance adds it to older projects.

## 4. Phases

Workflow: BUILD_REVIEW (builder + reviewer). Touches `enforcement/` and several
docs; medium risk, the approval detection itself does not change.

### Phase 1 — Declare the language and the rule

- `project/.ai/project.md`: add `owner_language:` with a short explanation.
- `rules/documentation.md`: the language rule from section 3.
- `enforcement/project/CLAUDE.md`: one line pointing to that rule.
- `workflows/onboarding.md`: the owner's language is the first interview
  question, in paths A and B.
- `workflows/maintenance.md`: if `owner_language` is missing, ask the owner and
  add it.

### Phase 2 — English machine text, both approval words

- `ci-checks.sh` section 5: PR summary in English.
- `approval-record.sh`, `sensitive-gate.sh`, `protect-tests.sh`,
  `verify-before-stop.sh`: name both approval words; say that
  `owner_language` picks which one to ask for.
- `enforcement/project/.ai/plans/TEMPLATE.md`: English, translation shown in
  chat.

### Phase 3 — Docs

- Files in the section 2 table: "duyệt" becomes "the approval word (`duyệt`
  or `approve`)". Only how the word is named changes, not the rules.
- `enforcement/setup-guide.md`: English translation of `cai-dat-may-moi.md`,
  same plain step-by-step style. Remove `cai-dat-may-moi.md`; update links in
  `enforcement/README.md` and `enforcement/setup-machine.sh`.

### Phase 4 — Verify and release

- `bash enforcement/test.sh` and `bash scripts/check-links.sh` pass; CI green.
- Throwaway project with `owner_language: en`: onboarding plus one tests-first
  task up to a PR. Delete everything afterwards.
- VERSION 1.8.8 to 1.9.0. vn30 gets it at its next maintenance and adds
  `owner_language: vi`.

## 5. Acceptance criteria

- [x] Project with `owner_language: en`: the agent talks in English and asks
  for "approve"; no Vietnamese in anything the owner sees.
- [x] Project with `owner_language: vi`: the agent talks in Vietnamese and asks
  for "duyệt"; files, commits and PRs are in English.
- [x] Project without the field: behaves as `en`.
- [x] Project with `owner_language: ja`: the agent talks in Japanese and asks
  for "approve".
- [x] The PR summary is English in every project.
- [x] "duyệt" and "approve" both approve in every project; "ok" still does not.
- [x] No rule tells the owner "duyệt" is the only approval word.
- [x] `test.sh`, `check-links.sh` and CI pass.

## 6. Open questions (repo owner answers)

- **Q1.** Default when the field is missing: English. Answered 2026-09-30.
- **Q2.** Setup guide: translate to English, keep one copy only. Answered
  2026-09-30 (option A).
- **Q3.** Existing Vietnamese history stays as is (vn30's open plans must not
  change: editing criteria voids their approval). Only the old plan's decision
  log, the one part agents reread, is translated to English. Answered
  2026-09-30; decision log translated the same day.

## 7. Later

- Correction words in `feedback-check.sh` for languages other than Vietnamese
  and English.

## 8. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-09-30 | — | Plan written; Q1–Q3 answered; `plans/completed/harness-upgrade.md` decision log translated to English; phase 1 approved |
| 2026-09-30 | 1 | `owner_language` in the project.md template; language rule in `rules/documentation.md` section 5; pointer in the project CLAUDE.md template; onboarding asks first (both paths); maintenance adds it to older projects. test.sh and check-links pass; reviewer: no findings |
| 2026-09-30 | 2 | PR summary in English; hook messages name both approval words; plan TEMPLATE says English; tests for "ok" (ignored) and "Approve" (recorded); `rules/enforcement.md` no longer says the summary is Vietnamese. test.sh passes; reviewer found only phase 3 doc items |
| 2026-09-30 | 3 | Rules, Router, onboarding, tester role name both approval words; `cai-dat-may-moi.md` translated to `enforcement/setup-guide.md`, links updated. test.sh and check-links pass; reviewer: no findings |
| 2026-09-30 | 4 | VERSION 1.9.0; PR #26 CI green. Throwaway trial (python, `owner_language: ja`, `app/money.py` sensitive), owner writing Japanese: agent replied in Japanese, asked for `approve`, wrote plan and commits in English; "approve" recorded by the hook; tests-first round locked; local `ci-checks.sh` passed with the English summary. Trial project and its session deleted. No GitHub temp repo: the local CI script plus the real CI on #26 cover it |

## 9. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-09-30 | Only the agent-owner conversation follows the owner's language; all files, commits, PRs, notes and the CI summary are English | Owner's choice |
| 2026-09-30 | Missing `owner_language` means English | Owner's choice; Orca is generic |
| 2026-09-30 | Language is per project, in `.ai/project.md` | Each project has its own owner |
| 2026-09-30 | Setup guide becomes English only (`setup-guide.md`) | Owner's choice; two copies drift apart, and owners of any language need a plain guide |
| 2026-09-30 | Old Vietnamese history stays; only the old decision log is translated | Vietnamese costs roughly 2-3x the tokens of English, but only the decision log is reread; translating vn30 open plans would void their approvals |
| 2026-09-30 | "ok" is not an approval word | Owner rejected it: too common, false approvals |
