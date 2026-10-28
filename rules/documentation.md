# Global Documentation Rules

Version: 1.0
Scope: All projects using Lodestar-harness

---

## Purpose

Keep documentation in step with the code. Verified work that leaves the docs
stale is not fully complete.

Documentation update is proportional to the change. Small internal fixes need
none. Changes that others rely on need matching docs.

---

# 1. Update project.md

Update `<project>/.ai/project.md` when the change alters:

- Architecture or module boundaries
- Technology stack or important dependencies
- Development, test, lint, build, or deploy commands
- Testing strategy
- Security or deployment constraints
- Major technical decisions
- Project conventions

Do not update `.ai/project.md` for temporary, task-specific detail.

---

# 2. User-facing docs

When behavior visible to a user or another team changes, update the matching
surface in the same task:

- README / usage docs for changed commands or setup
- API docs for changed request/response contracts
- Changelog / release notes for user-visible changes
- Inline comments for non-obvious business rules or workarounds
  (explain WHY, not WHAT — see `rules/coding.md`)

---

# 3. Architecture decisions

For a significant architecture decision, record an ADR (problem, context,
options, decision, why, trade-offs, impact) as defined in
`rules/architecture.md`. Small implementation tasks do not need an ADR.

---

# 4. Completion check

Before reporting a task complete, confirm:

- `.ai/project.md` reflects any structural or convention change.
- User-facing docs match the new behavior.
- No doc now describes removed or changed behavior as if it still exists.

Report doc updates as part of the completion summary, or state explicitly that
none were required.

---

# 5. Language

- Talk to the owner in the language set by `owner_language:` in
  `.ai/project.md` (ISO 639-1 code; missing means English), in plain words.
- Write everything else in English: code, comments, docs, notes, plans,
  `.ai/` files, commit messages, PR titles and bodies. One exception: the
  "Meaning" column of "Domain Terms" in `.ai/project.md` is in the owner's
  language, so the owner can check it.
- Acceptance criteria stay in English in the plan file, because the approval
  hook hashes that text. Before asking for approval, show the owner each
  criterion in their language with the English line next to it. The owner
  approves the file, not the translation.
- Ask for the approval word that fits: `duyệt` when `owner_language` is `vi`,
  `approve` otherwise. Both work in every project. The owner types it in the
  chat; an answer picked in AskUserQuestion is not recorded.
- Files written before this rule may stay in another language. Do not
  translate an approved plan's criteria: that voids the approval.

---

# 6. Waiting for data

A plan step that waits for data (to start, decide, keep or revert) names a
data gate, not only a date. A date alone lets a thin count pass as an answer.
Write the gates in a `Data gates` table in the plan, one row each:

| Gate | Measure (source) | Minimum | Check | Stop | Status |
|---|---|---|---|---|---|

- **Measure (source):** what is counted, and the command or file it is read
  from, so every count uses the same method.
- **Minimum:** the sample that is enough to decide, for example "8 plans with
  critic runs, from 2 projects". Count only data made under the condition
  measured (after the change reached that project). Leave out what cannot be
  trusted (a time when the check did not run, such as CI out of minutes) and
  say what was left out.
- **Check:** the first day to count. **Stop:** the last day to wait; default
  three weeks after the check.
- **Status:** `waiting`, `met <date>: <count>`, or `stopped <date>: <count>`.

On the check day, count. Minimum met: decide. Not met: decide nothing; write
the count and the next check day in the progress log. At the stop day with the
minimum still not met: when the gate measures use, no use is the answer (the
thing is not needed as built); otherwise the owner chooses to wait longer,
drop the step, or go on with thin data, and the decision log says the data was
thin.

A plan that waits for another plan starts when that plan's gates are met or
stopped, not on a guessed date.
