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

### Phase 2 evidence (measured 2026-10-11, codex-cli 0.155.1, Windows)

Throwaway repo, probe hooks in `.codex/hooks.json`, one `codex exec` run:

- Hook commands run in PowerShell (`$env:OS` expanded, `%OS%` not); `bash`
  is Git Bash (MINGW64). Working folder: the session cwd.
- Input JSON matches Claude's: `tool_input.command` for shell (tool name
  `Bash`), `prompt`, `stop_hook_active`, `transcript_path`, `cwd`.
- A file edit is one `apply_patch`; `tool_input.command` holds the patch,
  with `*** Add/Update/Delete File: <path>` lines (absolute Windows paths
  here; docs allow relative). Matcher `Edit|Write` also matches it.
- No project-dir variable. `CLAUDE_*` variables of a parent Claude session
  leak into Codex, so `CLAUDE_PROJECT_DIR` there may name another folder.
- Project hooks run only after trust (`/hooks`), stored per hook entry hash
  in `config.toml` of the Codex home. Orca gives Codex its own home
  (`CODEX_HOME`), so `setup-machine.sh` wrote `AGENTS.md` only there.
- Second run, real hooks: in PowerShell plain `bash` is WSL's
  (`WindowsAppsash.exe`), with no `jq` or `make`, so the install guard let
  `pip install` through (exit 0) and Stop failed. The first probe saw Git
  Bash only because Codex was started from Git Bash. `powershell -Command`
  also turns a native exit 2 into 1.
- Codex followed the global `AGENTS.md`: it ran doctor and refused to work in
  the unready project.

### Phase 2 design

- `enforcement/agents/codex/hooks.json` -> project `.codex/hooks.json`
  (merged like `settings.json`). Events: `apply_patch` before (protect-tests,
  sensitive-gate) and after (lint-file), `Bash` before (guard-install),
  `Stop` (verify-before-stop), `UserPromptSubmit` (approval-record).
  `feedback-check` is Claude only: it reads Claude's transcript format.
- `codex-hook.sh <hook>` (installed in `.claude/hooks/`): sets
  `CLAUDE_PROJECT_DIR` to the git root, passes other events through, and
  runs file hooks once per file in the patch (relative and `../` paths
  resolved; first block wins). The hook scripts stay one copy.
- Command: `bash -c 'cd ./$(git rev-parse --show-cdup) && exec bash ...'`,
  no double quotes (PowerShell 5 mangles them), no spaces from the path
  (`--show-cdup` is relative). `commandWindows` runs Git Bash found through
  `git --exec-path` and ends with `; exit $LASTEXITCODE`.
- Without `jq` the adapter blocks with the reason (a repeated Stop may end).
- Doctor A4b (required): `.codex/hooks.json` registers the hooks. A4c
  (warn): Codex trusts them (only when `codex` is installed).
- `setup-machine.sh` writes `AGENTS.md` to `~/.codex` and to `CODEX_HOME`.
- Template 2.3.0.

## 5. Open questions

- **Q1:** existing projects (vn30): rename on `--upgrade`, or leave
  `CLAUDE.md` and only warn? **Rename** (owner, 2026-10-11).
- **Q2:** phase 2 now, or after Codex has been used as a reviewer for a while?
  **Now** (owner, 2026-10-11).

## 6. Not in scope

- Orchestration (Orca's job).
- Model choice per role (ROUTER: never fixed).

## 7. Progress log

| Date | Phase | Work |
|---|---|---|
| 2026-10-11 | — | Plan written; section 2 measured |
| 2026-10-11 | 1 (trial) | Prototype on throwaway branch `test/agents-md` (deleted after): 12 files, +90/−53 (sections 3's design; template 2.2.0; doctor A1/A1b/A11; `global_block` in `setup-machine.sh` for `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`; this repo's `CLAUDE.md` renamed). `enforcement/test.sh` 245 pass (5 new in section 22), `check-links.sh` pass. Live: a project with its own `CLAUDE.md` bootstrapped, file moved to `AGENTS.md`, doctor passes; Claude and Codex each quoted its code word from `AGENTS.md`. Not live-tested: Codex reading `~/.codex/AGENTS.md` (would touch the owner's real Codex home; covered by a fake-home test). Side note: on a project with no tests yet, the Claude stop hook blocks even a question-only turn (`pytest` exit 5) |
| 2026-10-11 | 1 | Same change as the trial, on `feat/agents-md`; `enforcement/test.sh` and `check-links.sh` pass |
| 2026-10-11 | 1 | Merged as PR #13 |
| 2026-10-11 | 2 | Codex hooks measured (section 4, phase 2 evidence). Adapter, `.codex/hooks.json`, doctor A4b/A4c, `setup-machine.sh` writes `CODEX_HOME` too; template 2.3.0, on `feat/codex-hooks`. `enforcement/test.sh` passes (15 new in sections 19 and 23; 260 in all) |
| 2026-10-11 | 2 | Live (throwaway project from `bootstrap.sh`, real Codex run): patch to `.ai/approvals.log` blocked; lint reason returned for a BAD file; `pip install` blocked; Stop sent Codex back until `make verify` passed. Open: inside its Windows sandbox Codex itself cannot find `make` (hooks run outside it) |
| 2026-10-11 | 2 | Review (PR #14), fixed: spaces around a patch file line slipped past the guards; a patch with no file line now blocks; `../` resolved in bash (macOS has no `realpath -m`); `--upgrade` refreshes `commandWindows`. `enforcement/test.sh` 268 pass (23 new). Open, same as Claude: a shell write (`echo >> file`) is not seen by the file guards; CI still checks |
| 2026-10-11 | 2 | Merged as PR #14 |
| 2026-10-12 | 2 | App01 upgraded to 2.3.0 (vn30: PR open). Two generic bugs found in that upgrade, fixed on `fix/bootstrap-crlf-prettier` (template 2.3.1): from a CRLF checkout of this repo `--upgrade` rewrote unchanged files as CRLF (files now install as LF, compared without CR); Prettier failed on `.codex/hooks.json` (node-ts at the repo root gets `.claude/` and `.codex/` in `.prettierignore`). `enforcement/test.sh` 278 pass (10 new in sections 24 and 25) |
| 2026-10-12 | — | Merged as PR #15 (template 2.3.1). vn30 on 2.3.0 (its PR merged 2026-10-11). Owner agreed to close; plan moved to `completed/`. Left open for Codex: no `make` inside its Windows sandbox; a shell write is not seen by the file guards (CI is the gate); the PR #14 review fixes had no second live Codex run |

## 8. Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-10-11 | `AGENTS.md` is the file; `CLAUDE.md` only as `@AGENTS.md` | Both agents read it; a real `CLAUDE.md` hides `AGENTS.md` from Claude |
| 2026-10-11 | Owner: move every project to `AGENTS.md` (Q1) | Trial passed; one file for both agents |
| 2026-10-11 | Owner: phase 2 now (Q2) | Codex should follow the same checks as Claude |
| 2026-10-11 | Codex runs the Claude hook scripts through one adapter, no copies | Same input JSON; one copy of each rule to keep correct |
