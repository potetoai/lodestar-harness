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
  `.ai/` files, commit messages, PR titles and bodies.
- Acceptance criteria stay in English in the plan file, because the approval
  hook hashes that text. Before asking for approval, show the owner each
  criterion in their language with the English line next to it. The owner
  approves the file, not the translation.
- Ask for the approval word that fits: `duyệt` when `owner_language` is `vi`,
  `approve` otherwise. Both work in every project.
- Files written before this rule may stay in another language. Do not
  translate an approved plan's criteria: that voids the approval.
