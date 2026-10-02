# CLAUDE.md — lodestar-harness

This repo is a policy harness for AI coding agents: the Router,
workflows, agent roles, rules, and the enforcement templates every project
must pass. It does not run orchestration; the agent runtime does (Claude
Code alone, or Orca when present).

## Read in this order

1. `README.md` — entry point and directory map.
2. `router/ROUTER.md` — intake gate and workflow selection.
3. Only the files the task needs: `workflows/`, `agents/`, `rules/README.md`.

## Map

| Path | What |
|---|---|
| `router/` | Router and the execution contract (Orca adapter, optional) |
| `workflows/` | simple, build-review, independent-compare, complex |
| `agents/` | Role definitions |
| `rules/` | Global policy; index in `rules/README.md` |
| `enforcement/` | Hooks, CI, `bootstrap.sh`, `doctor.sh` for projects |
| `project/.ai/project.md` | Per-project context template |
| `plans/active/` | Execution plans in progress, with progress and decision logs |
| `plans/ideas/` | Idea plans kept for reference; rated in an active plan before any work |
| `scripts/` | Repo tooling (`check-links.sh`) |
| `LICENSE`, `THIRD_PARTY.md` | MIT; tools used but not bundled |

## Absolute rules

- Never build an orchestration system; use the runtime's (Claude Code
  subagents, or Orca when present). Hooks, CI and
  doctor only verify.
- Do not delete existing policy. Move and link instead.
- Changes under `enforcement/` must pass `bash enforcement/test.sh`.
- Docs must pass `bash scripts/check-links.sh` (CI runs both).
- Keep one blank line between blocks; no padding. Shorten docs only by
  removing blank lines or moving text, never by rewording rules without review.
- Shell scripts keep LF line endings (`.gitattributes` enforces it).
- Update the active plan's progress and decision logs when a phase moves.
