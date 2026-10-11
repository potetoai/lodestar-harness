# Plan: one instructions file for Claude and Codex (AGENTS.md)

> **For Claude Code:** This is an execution plan. Read all of it first. Do one
> phase at a time and stop after each for the repo owner's approval. Answer
> nothing in "Open questions" yourself. Update the progress and decision logs
> when a phase moves.

## 1. Why this plan

The owner runs Claude and Codex side by side in Orca. Codex reads
`AGENTS.md`; Lodestar writes only `CLAUDE.md`, so a Codex worker starts with
no Lodestar rules. Goal: one instructions file both agents read, so a rule is
written once.

## 2. Evidence (measured 2026-10-11, Claude Code 2.1.296, codex-cli 0.155.1)

Throwaway repos with a code word in the instructions file, agent asked for it
without tools:

| Files in the repo | Claude reads | Codex reads |
|---|---|---|
| `AGENTS.md` only | `AGENTS.md` | `AGENTS.md` |
| `AGENTS.md` + `CLAUDE.md` (own text) | `CLAUDE.md` only; `AGENTS.md` is silently ignored | — |
| `AGENTS.md` + `CLAUDE.md` = `@AGENTS.md` | both (import) | — |

So `AGENTS.md` is a fallback for Claude, not an addition. A project that keeps
a real `CLAUDE.md` next to `AGENTS.md` loses the `AGENTS.md` rules in Claude
with no warning.

Global level: Claude reads `~/.claude/CLAUDE.md`, Codex reads
`~/.codex/AGENTS.md` (missing on the owner's machine). Different folders, so
the global level needs two files from one template.

Codex 0.155 has hooks (`~/.codex/hooks.json`, empty today). Codex sessions get
no Lodestar hook checks; CI still checks every PR.

## 3. Design

- A project's instructions file is `AGENTS.md`. `CLAUDE.md` is allowed only
  as the one line `@AGENTS.md` (for a runtime that needs it).
- `bootstrap.sh` writes `AGENTS.md`. `--upgrade` renames a project's
  `CLAUDE.md` to `AGENTS.md` when `AGENTS.md` is missing (move, not delete).
- `doctor.sh` A1: `AGENTS.md` exists with no placeholders, and `CLAUDE.md`
  is absent or only `@AGENTS.md`. A real `CLAUDE.md` fails with the reason
  (Claude would ignore `AGENTS.md`). A11 measures `AGENTS.md`.
- `setup-machine.sh` writes the same Lodestar block to `~/.claude/CLAUDE.md`
  and, when `codex` is installed, to `~/.codex/AGENTS.md`.
- This repo: `CLAUDE.md` becomes `AGENTS.md`.

## 4. Phases

1. **Instructions file** (template 2.2.0): sections 3's changes, tests in
   `enforcement/test.sh`, docs updated (`rules/enforcement.md`,
   `workflows/onboarding.md`, `enforcement/README.md`, `setup-guide.md`).
   Live check: bootstrap a throwaway project; Claude and Codex each quote its
   `AGENTS.md`; doctor passes.
2. **Codex hooks adapter** (`enforcement/agents/codex/`): map the Claude
   hooks that matter (verify-before-stop, protect-tests, sensitive-gate,
   guard) onto Codex hooks; measure what Codex hook events allow first.
   Until then a Codex worker reviews and takes small low-risk tasks; CI is
   its only check, so anything with locked tests or sensitive paths stays
   with Claude.

## 5. Open questions

- **Q1:** existing projects (vn30): rename on `--upgrade`, or leave
  `CLAUDE.md` and only warn? **Rename** (owner, 2026-10-11).
- **Q2:** phase 2 now, or after Codex has been used as a reviewer for a while?

## 6. Not in scope

- Orchestration (Orca's job).
- Model choice per role (ROUTER: never fixed).

## 7. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-10-11 | — | Plan written; section 2 measured |
| 2026-10-11 | 1 (trial) | Prototype on throwaway branch `test/agents-md` (deleted after): 12 files, +90/−53 (sections 3's design; template 2.2.0; doctor A1/A1b/A11; `global_block` in `setup-machine.sh` for `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`; this repo's `CLAUDE.md` renamed). `enforcement/test.sh` 245 pass (5 new in section 22), `check-links.sh` pass. Live: a project with its own `CLAUDE.md` bootstrapped, file moved to `AGENTS.md`, doctor passes; Claude and Codex each quoted its code word from `AGENTS.md`. Not live-tested: Codex reading `~/.codex/AGENTS.md` (would touch the owner's real Codex home; covered by a fake-home test). Side note: on a project with no tests yet, the Claude stop hook blocks even a question-only turn (`pytest` exit 5) |
| 2026-10-11 | 1 | Same change as the trial, on `feat/agents-md`; `enforcement/test.sh` and `check-links.sh` pass |

## 8. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-10-11 | `AGENTS.md` is the file; `CLAUDE.md` only as `@AGENTS.md` | Both agents read it; a real `CLAUDE.md` hides `AGENTS.md` from Claude |
| 2026-10-11 | Owner: move every project to `AGENTS.md` (Q1) | Trial passed; one file for both agents |
