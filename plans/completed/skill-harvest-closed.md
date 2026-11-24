# Plan: skill harvest, closed phases

Closed phases of `plans/active/skill-harvest.md`, moved here so the active
plan holds only open phases. Its decision log stays there in full.

## Phase 0b — How a project adopts a skill or plugin (idea 41)

- `skills/capabilities.md`: extend "Other installed plugins" with a section
  on adopting a third-party skill or plugin: read it first (what it
  installs, writes, starts, sends out; license; pin the commit); turn off
  parts that write their own source of truth, start hooks or dispatch
  subagents; turn on per project; a read-only trial against known bugs
  before keeping it; record the reason and the trial result.
- `project/.ai/project.md` section 2: a small "Agent Skills and Plugins"
  table (name, source and commit, why, trial, status).

Done when: merged.

## Phase 5b, Python LSP trial (idea 45)

- Python project LSP (idea 45). The project is Python (FastAPI,
  SQLAlchemy, pandas; ruff, no type checker) with a JavaScript React frontend (no TypeScript), so only
  pyright-lsp applies; no TypeScript LSP.
  - Pre-check, read only: run pyright once over `backend/` in basic mode
    and count errors. About 30% of its functions declare a return type, so
    many errors may be noise. Go on only if the count is small enough to
    fix or silence in `pyrightconfig.json` (owner decides); a noisy LSP adds
    its errors to the agent's context after every edit.
  - Install inside the project (`requirements-dev.txt` in `backend/.venv`;
    `guard-install.sh` blocks pip outside a venv and global npm); the plugin finds
    `pyright-langserver` only if that `.venv` is on PATH when Claude starts:
    check this on Windows first. The PyPI `pyright` package downloads
    Node.js on first run: allow once or use the node from the frontend.
  - Turn it on in that project's settings only, for 7 days. Keep it if it
    reports at least one error before the tests or the lint hook do, and
    `usage-report.py` shows tokens per task up no more than 10%.
  - Result 2026-11-03: 502 errors, 226 in app code, 0 confirmed bugs, mostly
    pandas/SQLAlchemy typing noise; about 20 `reportOptional*` errors. LSP
    dropped. The project then reviewed the 20 (12 sites) read-only: 0 real
    bugs, each already checks for None. A CI step with only `reportOptional*` was dropped
    too (owner chose (b)). No project code changed.

## Progress log

| Date | Phase | Note |
|---|---|---|
| 2026-11-03 | 0b | Ideas 36-47 rated (Lodestar OS idea, DESIGN:OS, a consuming project's report, 2026 lists); adoption rule and template table, #131 |
| 2026-11-03 | 5b | Python project LSP pre-check: 226 app errors, idea 45 dropped, #133 |
