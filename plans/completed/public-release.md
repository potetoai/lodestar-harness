# Plan: public release

> **For Claude Code:** Completed plan, kept for reference. Its decisions still
> apply.

## 1. Why this plan

Prepare the repo for public, open-source use. An audit on 2026-10-02 found:

- The repo had no license.
- `rules/principles.md` reused wording from another project.
- The Router depended by name on third-party plugins (superpowers, gstack).
- Personal paths and project names remained in the files.

Goal: runs with Claude Code alone, treats Orca as optional, MIT license,
fresh git history.

## 2. Phases

### Phase A — No third-party plugin dependency

- Own methods: `skills/investigate.md`, `skills/explore-options.md`. TDD,
  verify before done and review are covered by `rules/testing.md`,
  `verify-before-stop.sh` and `workflows/build-review.md`.
- `skills/capabilities.md` points to them; browser QA names a generic browser
  automation tool. `rules/principles.md` rewritten in our own words.
- Global `CLAUDE.md` template: the Plugins section is generic. After a change,
  run `setup-machine.sh` to sync `~/.claude/CLAUDE.md`.

### Phase B — Orca optional, no personal data

- README: runs with Claude Code; Orca ADE is an optional orchestrator
  ("Running without an orchestrator"). `router/ORCA-INTEGRATION.md` is an
  optional adapter; other Orca mentions say "the orchestrator".
- `<lodestar-home>` replaces personal paths.

### Phase C — License and fresh repo

- `LICENSE`: MIT, copyright `potetoai`. `THIRD_PARTY.md`: tools used but not
  bundled.
- `bootstrap.sh` no longer exits when lodestar-harness has no origin remote
  (a downloaded copy); test added.
- Repo `potetoai/lodestar-harness` recreated with one initial commit.

## 3. Decision log

| Date | Phase | Decision |
|---|---|---|
| 2026-10-02 | A | Own methods are plain markdown in `skills/`, not a Claude Code plugin: any agent can read them and they add no base tokens |
| 2026-10-02 | A | No template VERSION bump: the global `CLAUDE.md` is machine-level, not copied into projects |
| 2026-10-02 | B | Keep `router/ORCA-INTEGRATION.md`; a note maps Orca terms to subagents. Most of it is runtime-neutral |
| 2026-10-02 | C | Copyright and commits use `potetoai` with the GitHub noreply email; no real name in the repo |
| 2026-10-02 | C | Owner: MIT license; recreate the repo under the same name so old history and PRs are gone |
