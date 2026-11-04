# S1 Week 1 — Repository audit against Revision 2.1

Date: 2026-11-04. Main at `f5650aa`. Owner: agent works, owner approves; Normal capacity (4 h/week). Check 2026-12-04, stop 2026-12-25 ([08](08-execution-guide.md)).

This audit changes no policy, support claim or licensing. It proposes Week 2 documentation work; each item waits for the owner's go.

## 1. What changed since the 04 snapshot

04 was written at `ebf2587`. Since then: #141–#142 (this strategy), #143 (eval skill path), #144 (S1 start), #145 (stop hook holds for the review line only when approval is asked). None changes the dependency table in [04](04-roadmap-12-months.md). Gate dates still hold: DT-1, P5-a..c and SH-0 check 2026-11-05; EV-3 checks 2026-12-01.

## 2. Asset map

| Asset | Where | State |
|---|---|---|
| Router | `router/ROUTER.md`; execution contract `router/ORCA-INTEGRATION.md` | Present; Router eval suite in `evals/router/` |
| Workflows | `workflows/`: simple, build-review, independent-compare, complex, prototype, onboarding, maintenance | Present; prototype and maintenance under P5 measurement |
| Roles | `agents/`: 9 roles | Present; critic under P5-c measurement |
| Capabilities | `skills/capabilities.md`, `investigate.md`, `explore-options.md` | Present; skill-harvest waits on SH-0 |
| Rules | `rules/` (index `rules/README.md`) | Present; docs-tidy owns duplicates |
| Enforcement | `enforcement/`: `setup-machine.sh`, `bootstrap.sh`, `doctor.sh`, hooks, CI template, `test.sh` | Template 2.9.6; CI self-test on `ubuntu-latest` |
| Runtime adapters | Claude Code (reference), Codex (`enforcement/agents/codex/`), Orca contract | See section 4 |
| Evals | `evals/` (Router suite, scores) | Run only on Router PRs (AGENTS.md) |
| Install docs | `enforcement/setup-guide.md` (Windows, step by step), `enforcement/README.md` §1 and §3 (manual, upgrade), `workflows/onboarding.md` S1 (per project) | Three places; see finding F6 |
| Consuming projects | vn30, App01, ProjectS | All the owner's; not external adoption |

## 3. Findings

Each finding is marked: **done** (already in the repo), **plan** (an existing plan owns it), **gated** (waits for a gate) or **gap** (new, observed in this audit).

| # | Finding | Evidence | Mark | Proposed action |
|---|---|---|---|---|
| F1 | README has no quick start for a person. It opens with Orca's default agent and the reading order for an agent; install steps are not linked from it | `README.md` lines 1–40; no link to `enforcement/setup-guide.md` | gap | Week 2: a short "Quick start" near the top: what you need, link to the setup guide, first task. Move the Orca paragraph below it |
| F2 | The no-orchestrator path exists but sits low in the README | `README.md` "Running Without an Orchestrator" | done (placement gap) | Week 2: say "Claude Code alone is enough; Orca is optional" in the first lines |
| F3 | No removal instructions, for the machine or a project | No uninstall/remove text in `enforcement/` docs; `setup-machine.sh` writes `~/.claude/CLAUDE.md`, global hooks and `.bak` files; `bootstrap.sh` writes [managed] files | gap | Week 2: "Remove Lodestar" section in `setup-guide.md`, listing exactly what each script writes; verify on a scratch project |
| F4 | No place to report issues, ordinary or sensitive | No `SECURITY.md` or contributing note; issues on, Discussions off (`gh repo view`) | gap | Week 2: a short reporting section (README or `SECURITY.md`). Turning on GitHub private vulnerability reporting is a repo setting: owner's go |
| F5 | Supported environments are not stated. The setup guide is Windows only; macOS/Linux appear only as a `brew` line; CI runs the self-test on Linux, no live Linux/macOS setup is recorded | `setup-guide.md`, `enforcement/README.md` §1, `.github/workflows/test.yml` | gated (tier matrix in [01](01-vision-and-positioning.md)) | Week 2: state facts only (tested where, how), no tier badge. Tier ratification stays with 01 |
| F6 | Install steps are in three files | `setup-guide.md`, `enforcement/README.md` §1, `onboarding.md` S1 | gap (not in docs-tidy's list) | Week 2: README links the setup guide as the single start; the other two stay as reference. No text removed |
| F7 | No minimal end-to-end example | No example or walkthrough in the repo | gap | Week 2: one example (install → onboard a scratch repo → one SIMPLE task), tested from a fresh clone |
| F8 | Codex on this machine is 0.166.0; parity was verified on 0.162.1 | `codex --version`; `runtime-parity.md` | plan (runtime parity) | No change. Do not claim 0.166.0 support until a live smoke runs ([codex-live-smoke.md](../../enforcement/codex-live-smoke.md)) |
| F9 | Claude Code version used daily is 2.1.318 on Windows 11; no recorded live first-use run | `claude --version`; 01 Claude row | gated (01 Tier 1 evidence) | Week 2 fresh-clone test records version, platform and hook activation |
| F10 | Approval words are Vietnamese and English (`duyệt`, `approve`); external docs do not say which word an owner types | `approval-record.sh` line 22 | gap (small) | Week 2: one line in the quick start. The hook is not changed |
| F11 | Large policy files repeat each other | docs-tidy item 9 | plan (docs-tidy, DT-1) | None here. Do not touch `workflows/prototype.md`, `workflows/maintenance.md`, `agents/critic.md` |
| F12 | Skill and role additions | skill-harvest, agent-pitfalls | gated (SH-0, P5) | None here. Pilot findings are routed to those plans |

In the files read for this audit (README, `runtime-parity.md`, the setup guide, `enforcement/README.md`), no conflicting statement on what is installed was found; other files were not checked. The gaps are missing first-use text, not wrong text.

## 4. Supported runtime paths (facts, not tiers)

| Path | Evidence today | Not yet shown |
|---|---|---|
| Claude Code alone, Windows 11, Git Bash | Owner's use on vn30, App01, ProjectS; `enforcement/test.sh` in CI | A fresh-clone setup by someone else; macOS/Linux live setup |
| Codex, Windows | Live smoke on 0.162.1 (`runtime-parity.md`) | 0.166.0 (installed now); other platforms |
| Orca + Claude | Contract `ORCA-INTEGRATION.md`; owner uses Orca | A bounded validation of dispatch and evidence return (01) |

## 5. Top five onboarding questions

What a new Claude Code user is likely to ask first. Week 2 answers these; pilots confirm or replace them.

1. What is this, and do I need Orca? (F1, F2)
2. How do I install it on my OS, and what does it change on my machine and in my repo? (F3, F5, F6)
3. How do I remove it or upgrade it? (F3; upgrade exists in `enforcement/README.md` §3)
4. What does a first task look like, and what do I type to approve? (F7, F10)
5. Where do I report a problem, and what is supported? (F4, F5)

## 6. Where to find pilot users

The cohort is experienced Claude Code users whose projects already carry scattered `CLAUDE.md`, skills and hooks ([02](02-users-and-product-strategy.md), [06](06-adoption-and-community.md)). Candidate channels, best fit first. Community rules were not checked in this audit: read each channel's rules before posting. No contact is made without the owner's separate go.

| Channel | Fit | Cost | Notes |
|---|---|---|---|
| Public GitHub repos with `CLAUDE.md` plus `.claude/hooks` or many skills | High: the target problem is visible in the repo | Search is free; contact only where the person lists a contact | Do not open issues on their repos to recruit; that is spam |
| Reddit r/ClaudeCode, r/ClaudeAI | High: active Claude Code users discuss workflows | One honest post asking for 3–5 testers | Check self-promotion rules; answer comments |
| Anthropic / Claude community Discord | Medium–high | Low | Use the channel meant for projects or showcases |
| Vietnamese developer groups (Facebook, Viblo, personal network) | Medium: easier talks in Vietnamese; fewer target users | Low | Good for the first one or two observed users |
| Hacker News (Show HN), X | Low now | Low | Only after the quick start and one real walkthrough exist (06) |

Before any outreach, F1, F3, F4 and F5 must be done: 04 says to explain supported environments, upgrade/removal and issue reporting before inviting pilots.

## 7. Open gap: who observes pilots

The owner does not read code. Options for the owner to choose before Week 3:

- **A. Agent reviews, owner approves (proposed).** The pilot shares a de-identified transcript excerpt or the PR; an agent scores the task against written acceptance criteria and records help minutes; the owner reads the plain summary.
- **B. Self-report form.** The pilot fills a short form (task, done or not, where stuck, help needed). Cheap, weaker evidence.
- **C. A technical helper** observes live calls. Strongest, but needs a person.

## 8. Proposed Week 2 order

1. README quick start and Orca-optional opening (F1, F2, F6, F10).
2. Removal section and supported-environments facts in `setup-guide.md` (F3, F5).
3. Reporting section; owner decides on private vulnerability reporting (F4).
4. Fresh-clone test with one minimal example; record versions and hook activation (F7, F9).

Each step is one small docs PR (BUILD_REVIEW, low risk). Nothing in `enforcement/` scripts changes.

## Unverified assumptions

- The five onboarding questions are the agent's guess, not user data.
- Channel fit is judged from the cohort definition, not from posts read in those channels.
- "Removal" scope depends on what the scripts write; F3 must check the scripts before writing the steps.
