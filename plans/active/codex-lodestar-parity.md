# Plan: apply Lodestar rules and hooks to Codex

## Goal

Apply the existing Lodestar policy to Claude Code and Codex through shared
rules and checks, with runtime adapters only where their inputs differ.
Distinguish installed configuration from hooks that the runtime actually runs.

## Routing and readiness

- Approved route: BUILD_REVIEW, high risk, tests first, independent critic
  and reviewer, including security review of input and path handling.
- Route approved on 2026-10-13: owner instructed "ok làm theo workflow của
  Lodestar đi" after the proposed high-risk route. Criteria approval is separate.
- Source-repository onboarding is already exempt: `check-readiness.sh:19`
  has exempted Lodestar since 4c23d3a, also recorded in `plans/completed/round-2.md`.
  The earlier waiver request was unnecessary; the debt entry is closed.
  Consuming projects still require readiness. This clarification is in scope.
- Independent criteria review and re-review are complete with no remaining
  findings. Owner approved the reviewed criteria; tests are committed at
  `ad7b4bd`. Implementation is partial and paused at the owner's request.
- Use this repository's existing shell self-tests and documentation checks.
  Do not manufacture an approval log or claim installed approval hooks ran.

## Scope

- Claude remains the default agent in Orca, as the owner clarified after
  approving this plan. Codex follows the same Lodestar checks when selected;
  this task does not change Orca's default agent/provider/model or introduce
  automatic dispatch to Codex. "Default Codex home" below is a filesystem
  configuration location, not the default agent in Orca.
- `enforcement/agents/codex/`: project adapter and configuration; global
  adapter/installer where needed.
- Shared hooks under `enforcement/agents/claude/`: retain one implementation
  of each policy; change transcript or runtime plumbing only where required.
- `enforcement/setup-machine.sh`, `enforcement/bootstrap.sh`, doctor,
  `enforcement/test.sh`, and `enforcement/VERSION`.
- `enforcement/README.md`, `enforcement/setup-guide.md`, global bootstrap,
  Router, onboarding/testing workflow text and relevant rules: document
  parity, installation, the existing source-repository exemption and verified limits.
- Machine rollout: default Codex home and the active `CODEX_HOME`; consuming
  project upgrades only after identifying their current configuration and
  preparing a concrete diff. Preserve other settings and owner content.
- Keep the separate `ci-relock-fresh-approval.md` task and its files intact.
  This task does not redesign CI relock history checks.
- This session owns hook/rule parity. The other session has only a draft CI
  plan, not implementation; do not stage that plan, the pre-existing
  `plans/completed/cross-model-dispatch.md` change, or `debug.log`.

## Acceptance criteria

Reviewed and approved by the owner. The indented tables and procedures
below are part of the hashed criteria, not optional implementation notes.

- [ ] C1: Claude and Codex follow one shared Lodestar policy; the shared instructions explicitly preserve the existing source-repository readiness exemption and handoff reminder, while projects without readiness still receive onboarding guidance.
- [ ] C2: Every coverage-table behavior has a documented event, tool, input and output mapping for the supported runtime contract below; missing Codex behaviors are implemented through shared checks or runtime adapters, with Claude behavior preserved by regression tests.

  ## Current coverage

  | Lodestar behavior | Claude | Codex today | Required work |
  |---|---|---|---|
  | Router, workflows, roles and rules | Global bootstrap and project instructions | Shared bootstrap written to `AGENTS.md` in default and active homes | Verify the same references and rules remain in both |
  | Readiness and handoff at session start | Global `check-readiness.sh`; exempts the Lodestar source repository after the handoff reminder | No global installer registration | Share the same exemption, handoff and project-readiness behavior |
  | Readiness at each owner prompt | Global `check-readiness.sh --prompt` | No global installer registration | Add equivalent registration |
  | Maintenance reminder | Session-start readiness hook | No global installer registration | Use the shared check |
  | Context threshold and handoff reminder | Global `context-nudge.sh` reads Claude usage | No Codex equivalent | Normalize supported Codex usage; preserve threshold and deduplication |
  | Protect approvals and locked tests | `protect-tests.sh` | Adapter calls the shared script | Preserve protection and support valid append-only lock updates |
  | Sensitive-code gate | `sensitive-gate.sh` | Adapter calls the shared script | Verify equivalent allow/block behavior |
  | Shell/install/git guard | `guard-install.sh` | Adapter calls the shared script | Verify supported shell tool coverage |
  | Lint after file edits | `lint-file.sh` | Adapter calls it per patch path | Verify equivalent coverage and error reporting |
  | Verify before finishing | `verify-before-stop.sh` | Shared script registered | Verify equivalent failure, retry and success behavior |
  | Record owner criteria approval | `approval-record.sh` | Shared script registered | Preserve owner-only approval and criteria-review gates |
  | Learn from owner corrections | `feedback-check.sh` reads Claude transcript | Not registered | Add Codex input support and registration |
  | Installed/trusted hooks | Settings and doctor checks | Doctor checks commands; trust check only searches for a Stop entry | Verify all required registrations and distinguish usable trust from unknown/stale/disabled state |
  | CI | Shared `ci-checks.sh` | Same CI | Preserve as the independent final gate |
- [ ] C3: Install and upgrade identify Lodestar registrations by their ownership, event and matcher, replace stale managed registrations without duplicates, preserve unrelated settings and hooks including Orca and same-named unrelated commands, refuse ambiguous or malformed hook configuration without overwriting it, and support Windows paths with spaces.
- [ ] C4: Feedback and context reminders isolate sessions, homes and runtimes, handle overlapping invocations atomically, store identifiers and counters rather than message text, and deliver once per owner correction or current-context band; tool/worker messages do not count as owner corrections, and unavailable data or state follows the failure matrix below.
- [ ] C5: Codex patches enforce the existing shared Claude lock semantics: preserve normalized test-path entries during approved additions, reject unauthorized changes/removals and unknown patch results, and preserve initial-lock, approved-relock and completed-plan behavior; all affected paths and rename destinations pass the shared approval-log, test-lock and sensitive-path guards.
- [ ] C6: Verification distinguishes installed configuration from enabled, trusted runtime execution in the actual Codex home; missing, disabled, changed/untrusted and unverified coverage is explicit, stale trust is not accepted as current proof, and installers never grant trust for the owner.
- [ ] C7: Applicable pre-operation guards block when required input or check execution cannot be validated; advisory checks report unavailable status without blocking unrelated work; legitimate non-project events remain harmless; verification failures retain only the existing Stop retry exception, never an exemption for pre-operation guards.
- [ ] C8: New behavior has regression tests that fail before the fix, existing Claude tests and the full self-test/link suite pass, and live Codex evidence covers the lifecycle rows below using owner-trusted hooks; activation remains incomplete while required trust or live evidence is missing.
- [ ] C9: Rollout covers the default and active Codex homes and identifies consuming projects from existing configuration before upgrades; its report names every upgraded and verified target plus pending trust or runtime limits, and does not claim parity for untested runtimes or outdated projects.
- [ ] C10: This source task uses the explicit approval and committed-test-boundary procedure below, without fabricating hook events or approval logs; consuming projects keep their existing hook-recorded approval and test-lock requirements.

  ## Supported runtime contract

  - Primary live target: installed `codex-cli 0.162.1` on Windows, using Git
    Bash hook scripts and the PowerShell `commandWindows` entry points.
    Record the actual runtime version again at the live run; a changed version
    requires validating its payloads before claiming compatibility.
  - Default home: `C:/Users/PC/.codex`. Active Orca home:
    `C:/Users/PC/AppData/Roaming/orca/codex-accounts/3f36c88f-5ff4-4029-b894-98c943f3efa1/home`.
    Preserve Orca registrations. Global `AGENTS.md` and hooks must be installed
    for the home that launches the agent, not just the default home.
  - Consuming-project candidates from existing handoff metadata are App01
    (`F:/MyProjects/App/App01`, with an Orca checkout at `D:/AI/Orca/App01/home`)
    and vn30 (`F:/MyProjects/ProjectS`). Inspect their current configuration and
    active work before preparing rollout diffs; do not assume old handoff
    versions remain current or overwrite unrelated work.
  - Claude compatibility is established by existing and targeted script/config
    regression tests. Do not claim a live Claude run unless actually performed.
  - Codex contract fixtures record observed runtime payloads: `Bash` for shell
    commands and `apply_patch` with patch text in `tool_input.command`, including
    nested cwd and multiple files. Validate actual events before live acceptance;
    unknown payload/transcript formats follow the failure matrix, not heuristics
    that silently approve operations or a universal transcript parser.

  | Event | Required live Codex evidence |
  |---|---|
  | SessionStart | Handoff delivered; source repository exempt; unready consuming project gets readiness guidance; ready project gets due-maintenance guidance when applicable |
  | UserPromptSubmit | Readiness guidance and genuine owner criteria approval handling; delegated/tool content does not create approval |
  | PreToolUse: apply_patch | A forbidden approvals/locked-test or sensitive edit is blocked and an allowed edit succeeds |
  | PreToolUse: Bash | A forbidden install command is blocked and an ordinary command succeeds |
  | PostToolUse: apply_patch | Lint output reaches the agent after an edit |
  | PostToolUse: reminder | Current-context reminder reaches the agent at a test-configured threshold without changing production defaults |
  | Stop | Failing verification requests correction, success finishes, and a genuine correction message triggers the feedback reminder once |

  The focused guard/state/error matrix is exercised exhaustively with fixtures;
  live smoke establishes runtime event execution and message delivery. No claim
  is made that hooks intercept all tools, writes or sandbox behavior. CI remains
  the independent final gate. Pending trust blocks live activation acceptance,
  not fixture development, and is reported as pending rather than success.

  ## Failure matrix

  | Condition | Required behavior |
  |---|---|
  | Applicable pre-operation guard receives empty, malformed, wrong-shaped or unsupported required input | Block the operation with a diagnostic; do not infer permission |
  | Applicable guard cannot find/read/execute its selected script or required executable | Block with a repair diagnostic; do not silently skip enforcement |
  | Repository/project context cannot be resolved for a project hook | Report the failure and block an applicable guard; global reminder outside a Git project remains a harmless nonapplicable event |
  | Feedback/context transcript absent, unreadable, or unsupported; required message/session identity absent; reminder state cannot be persisted | Report that the advisory check is unavailable, do not invent data or record a successful reminder, and do not block unrelated work |
  | Valid advisory input below threshold, ordinary owner request, or duplicate already delivered | Quiet success; do not repeat the reminder |
  | Overlapping reminders for the same qualifying message/band | One invocation claims the reminder atomically; other invocations do not repeat it; independent sessions/homes/runtimes do not suppress each other |
  | Verification fails or cannot execute | Report failure and request correction; only the existing repeated Stop verification escape applies, and only to that hook/event |
  | Source repository or another established nonapplicable policy condition | Preserve the existing deliberate exemption, including the source handoff reminder before skipping readiness |

  ## Source-repository approval and test boundary

  This is an explicit task-scoped procedure presented with the criteria for
  owner approval. It reflects the source repository's existing onboarding
  exemption; it does not install or pretend to run consuming-project hooks.

  1. Complete independent criteria review and record the reviewed hash here.
     Show the owner the final criteria. After the owner explicitly approves,
     record the actual approval message/reference and its criteria hash in this
     plan; never create `.ai/approvals.log` or replay an invented hook event.
  2. A tester writes the scoped regression tests, runs syntax/static checks and
     demonstrates failures caused by missing behavior. Record exact test paths,
     SHA-256 digests and failing results here. Commit those tests and this plan
     with the `Tests-First: codex-lodestar-parity` trailer; then record the commit
     ID as the test boundary. Stage only task-owned files.
  3. The builder must not change the recorded test files. Before implementation
     and during independent review, compare their content against the boundary
     commit and digests. A needed test change returns to the tester and owner
     for reviewed criteria approval before establishing a replacement boundary.
  4. Source CI remains `.github/workflows/test.yml`, running the real self-tests
     and link check. Report this as a committed test boundary and independent
     review, not installed-hook enforcement. Consuming-project approvals,
     test-lock format and CI requirements remain unchanged.

## Criteria review

- Full independent review: read the complete initial plan, critic role,
  Codex adapter/config, Claude registrations/global scripts, doctor, relevant
  installer and shared-lock/approval sections, testing policy and source CI.
  Did not read the full test suite, unrelated CI relock code, all shared
  guards, runtime source, live homes/transcripts, or external runtime docs.
- HIGH: source approval/test-boundary procedure was deferred; fixed by C10
  and the explicit source procedure above, to be approved with the criteria.
- HIGH: byte-for-byte lock preservation exceeded Claude semantics; fixed C5
  to preserve existing normalized-path, initial-lock, relock and expiry rules.
- MEDIUM: reminder state lacked isolation and concurrency requirements;
  fixed C4 and the failure matrix with per-session/home/runtime identity,
  atomic claiming and explicit unavailable-state behavior.
- HIGH: safe failure was undefined; fixed C7 and the failure matrix, including
  restricting the deliberate retry exception to Stop verification.
- MEDIUM: runtime contract and activation completion were unbounded; fixed
  C2/C8/C9 with the named runtime, live event matrix and pending-trust gate.
- MEDIUM: managed entry identity was underspecified; fixed C3 to cover
  ownership/event/matcher, same-named custom hooks and malformed structures.
- Second full independent review found the six earlier issues substantively
  resolved, but HIGH: the detailed contracts were outside the criteria hash.
  Fixed by moving the coverage table into C2 and the runtime/failure/source
  contracts into C10 as indented criterion continuations. Those details are
  now hashed with the criteria; scope/progress prose remains outside.
- Narrowed independent re-review: reread the complete revised plan and
  criteria parsing/review helpers; independently verified all detailed
  contracts are hashed and the six earlier fixes remain intact. Retained the
  prior implementation review without rereading implementation or inspecting
  live runtime data. No remaining findings.
- Reviewed criteria: 57ea0102b66ad1074d4b544653a1e774f66af4e3

## Execution evidence

- Owner criteria approval: actual owner message on 2026-10-13,
  "duyệt codex-lodestar-parity", for reviewed hash
  `57ea0102b66ad1074d4b544653a1e774f66af4e3`. Recorded here according to C10;
  no approval log or hook event was manufactured.
- Subsequent owner clarification: "sửa lại, mặc định Orca thì vẫn là CLaude".
  Preserve Claude as Orca's default; the approved parity criteria are unchanged.
- Test boundary: commit `ad7b4bd` (`Tests-First: codex-lodestar-parity`).
  The following two test files are immutable during implementation.
  `enforcement/test-parity.sh` SHA-256:
  `1e87bc81cf6fc608acc39cc764846d3870310f2a41ebc3a0d51a5093deeb663e`.
  `enforcement/test.sh` SHA-256:
  `4350caf8e15f30a697af10303ae2fa89f07e995f718032dd46dda116323a85ca`.
- Tester red result: `bash enforcement/test-parity.sh` exited 1 with
  46 passed / 75 failed. Failures by criterion: C1=3, C2=7, C3=9,
  C4=24, C5=2, C6=3, C7=27. Syntax checks on both test files and
  whitespace checks passed; both files use LF. C8 live execution,
  C9 rollout and C10 approval/boundary also require coordinator evidence.
- Existing test adjustments before locking: give the Claude feedback fixture
  its real-runtime `session_id` field, require stale Codex trust to remain a
  warning under C6, and invoke the new suite from the existing CI entry point.
  No existing Claude assertion was removed. All tester processes finished;
  disposable homes and the scratch registry key were cleaned.
- Live runtime activation: not performed; no global/project configuration changed.

## Implementation sequence

1. High-risk route and independent criteria review complete.
2. Owner criteria approval received and recorded above.
3. Write regression tests first, demonstrate relevant failures, and establish
   the test boundary before implementation using the source procedure above.
4. Implement shared checks and runtime adapters; run focused and full tests.
5. Independently review correctness, security and criteria coverage; fix findings.
6. Prepare machine/project rollout diffs, apply authorized upgrades, and
   verify with the real runtime. Owner trust review is a separate runtime step.
7. Report verified coverage and remaining activation work; open a PR after
   verification, and leave merging to the owner.

## Verification

- Baseline: `bash enforcement/test.sh` exited 0, `All tests passed`, on
  2026-10-13. `bash scripts/check-links.sh` exited 0.
- Regression fixtures: supported Codex hook payloads and transcript records;
  ordinary requests, owner corrections, tool/worker content, context bands,
  concurrent sessions, missing inputs and runtime prerequisites.
- Disposable repositories and homes: both runtimes' installed configuration,
  idempotent install/upgrade, custom settings preservation, malformed config,
  changed definitions, trust/enablement, active-home selection, nested cwd,
  Windows paths and multi-file/rename patches.
- Live Codex smoke: capture runtime version, configured home and hooks,
  effective trust, hook execution, a denied operation, a normal operation,
  reminder delivery, and failed/successful verification. Do not infer live
  coverage solely from fixture tests or a substring in `config.toml`.
- Final: full self-tests, link checks, whitespace/diff review and independent
  security review. Do not repeat full suites without a relevant change or failure.

## Runtime evidence and limits

Official hook documentation: <https://learn.chatgpt.com/docs/hooks>.
Codex supports project and user hook configuration and requires review of
non-managed hook definitions. Tool hooks are not a complete security boundary.
The transcript format is explicitly not a stable hook interface; normalize
only verified formats and report unsupported data. Preserve CI and sandbox
controls rather than promising that hooks can intercept every possible write.

## Rollout plan (prepared 2026-10-15, nothing applied)

Dry runs on copies only; no real home or project was changed.

- Machine (`setup-machine.sh --check`): tools, PATH, the global Claude block
  and both Codex `AGENTS.md` blocks are current; Claude global hooks are
  installed. Missing: Codex reminder hooks in both homes.
  - Default home `C:/Users/PC/.codex/hooks.json`: `{"hooks": {}}` becomes
    SessionStart readiness, UserPromptSubmit readiness `--prompt` and
    PostToolUse `*` context-nudge, each pointing at
    `D:/AI/Lodestar-harness/enforcement/agents/codex/global/codex-global-hook.sh`.
  - Active Orca home: the same three entries appended as new groups; every
    Orca entry is unchanged. Check in the live smoke whether Orca rewrites
    this file when it starts an account.
  - Apply with `bash enforcement/setup-machine.sh` (asks before each change,
    keeps `hooks.json.bak`). The hooks run this checkout's code, so install
    only with the owner's go, for the live smoke on the reviewed branch.
- Projects, from `main` (App01 `949d3a4`, vn30 `3670f34`), both 2.3.5:
  `bootstrap.sh --upgrade` updates `codex-hook.sh`, `doctor.sh`,
  `feedback-check.sh`, `lodestar-lib.sh` (2.3.6 relock fix), creates
  `reminder-lib.sh`, `codex-owner.jq`, `codex-patch.jq`, rewrites the three
  Codex guard commands (fail closed), adds Codex Stop `feedback-check` and
  sets version 2.4.0; `.claude/settings.json` is unchanged. Six files,
  +241/-67, three new. Doctor on the upgraded copies: Ready; A4c warns that
  Codex has not trusted the hooks (expected).
  - App01: clean on `main`; upgrade on a new branch, PR, CI, merge on green.
  - vn30: its checkout holds another session's uncommitted docs work on
    `docs/rsi-rules-pilot-plan`; do not switch it. Upgrade in a separate
    worktree from `main`, PR, CI, merge on green.
- Trust: changed `.codex/hooks.json` changes every hook hash, so existing
  trust becomes `modified`. The owner reviews and trusts with `/hooks` in a
  Codex using each home (default and Orca), per project. Never written for
  the owner. Doctor A4c then shows trusted or the exact gap.
- Order: owner go → machine install → live smoke in a throwaway
  project (step 8) → source PR merged → project upgrade PRs → owner trust
  → doctor A4c per project and home → report (C9).

## Progress log

| Date | Phase | Result |
|---|---|---|
| 2026-10-13 | Investigation | Audited Claude/Codex registrations, global installers, shared guards and doctor; recorded the parity gaps above. |
| 2026-10-13 | Baseline | Existing self-tests and internal link checks passed. No implementation or configuration was changed. |
| 2026-10-13 | Readiness | Owner explicitly skipped onboarding; recorded a task-scoped exception with a due date. |
| 2026-10-13 | Planning | Draft criteria and delivery scope written; high-risk route approval remains pending. |
| 2026-10-13 | Routing | Owner approved following the proposed Lodestar workflow; independent criteria review started. |
| 2026-10-13 | Criteria review | Full critic returned six findings; criteria, runtime/failure matrices and source test procedure revised for full re-review. |
| 2026-10-13 | Investigation correction | Owner relayed verified source-repository exemption and active-home facts from the other session. Independently confirmed hook blame and historical plan; closed the unnecessary onboarding debt and logged the investigation mistake. |
| 2026-10-13 | Ownership | This session owns all hook/rule parity. Separate CI plan and pre-existing changes stay outside task commits. |
| 2026-10-13 | Criteria review | Second full review found an approval-hash gap; moved detailed contracts into criterion continuations. Narrowed re-review independently confirmed the hash and no remaining findings. Ready to present criteria to the owner. |
| 2026-10-13 | Approval | Owner approved `codex-lodestar-parity` at the reviewed hash; start tests first. |
| 2026-10-13 | Runtime default | Owner clarified that Orca defaults to Claude. Recorded this constraint; no runtime defaults changed and no change to the approved criteria. |
| 2026-10-13 | Tests first | Independent tester produced 121 focused checks: 46 passed, 75 failed on unmodified production. Runtime-derived synthetic transcript fixtures distinguish owner, injected and child-session content. Test hashes verified by coordinator; prepare immutable test commit. |
| 2026-10-13 | Test boundary | Created `ad7b4bd` with the two test files, approved plan and task-owned investigation notes. Start implementation; unrelated files were not staged. |
| 2026-10-13 | Partial implementation | Shared reminder/provenance helpers, feedback/context changes and global Codex adapter written but untested; policy/install docs drafted ahead of implementation. Project adapter replacement interrupted after deletion. No installer, doctor or live rollout completed. |
| 2026-10-13 | Owner pause | Owner requested stop and a detailed handoff. Builder stopped with no background processes. `enforcement/agents/codex/codex-hook.sh` is missing; do not deploy this snapshot. Resume from `.ai/handoff.md`; frozen tests remain unchanged. |
| 2026-10-13 | Evaluation and second pause | Claude session reviewed the partial work and restored `codex-hook.sh` from `ad7b4bd`; parity suite 63 passed / 58 failed, frozen test hashes unchanged. Found helpers not installed by bootstrap, a slower live `context-nudge.sh` and a lock that can stay stuck; recorded in `.ai/handoff.md`. Owner paused again before further implementation. |
| 2026-10-14 | Reminder wiring | Bootstrap installs `reminder-lib.sh` and `codex-owner.jq`; adapter sets `LODESTAR_RUNTIME=codex`; Codex Stop registers `feedback-check`. `context-nudge.sh` reads the last 400 lines again (same speed as `ad7b4bd` on a 14 MB transcript); stale reminder locks are recovered after a minute. Parity 78 passed / 43 failed (C2=3, C3=9, C5=2, C6=3, C7=26); every C4 check passes. Full suite: only parity checks and the new A4c stale-trust check fail; links pass; test hashes unchanged. |
| 2026-10-14 | Project adapter | Rewrote `codex-hook.sh` to fail closed by hook kind (guard blocks, Stop keeps only its repeated-Stop escape, advisory reports unavailable), strip Windows CRLF from jq output (a trailing CR had let a path skip the guards), and check all patch paths. New `codex-patch.jq` rebuilds `.ai/test-lock` exactly or not at all, for `lock_append_only`. Codex `approval-record` records only from the owner's own session (fixture-checked: child and unknown sessions refused, owner recorded). Feedback state moved back into the project git dir after a test run wrote fixture state to the real `~/.claude` (cleaned). Removed the Codex/source-exemption additions from the global CLAUDE.md and shortened README/ROUTER (token cost). Parity 106/15 (C2=3, C3=9, C6=3); full suite fails only those and A4c; links pass; test hashes unchanged. Independent review found 4 issues: Windows path aliases, missing guard library, a guard that cannot start on Windows, and lock rebuild on `@@ `. All fixed; attacks reproduced as blocked; suites unchanged. |
| 2026-10-14 | Installers | New `enforcement/agents/merge-hooks.jq` decides which hooks are Lodestar's by generated command shape (script and check, not path), keeps the first one on the template event/matcher, removes misplaced or duplicate copies, appends missing ones, keeps all other hooks and refuses malformed files unchanged. Bootstrap uses it for both runtimes and refuses malformed configs before any change. New `agents/codex/global/install.sh` (with `--check`) registers readiness, prompt readiness and context nudge with Windows entry points; never writes `config.toml`. `setup-machine.sh` installs it in the default and active Codex homes. Scratch copy of the real Orca home: only three entries added, Orca hooks unchanged, second run no change. Parity 118/3 (C6 doctor only); full suite fails only those and A4c; links pass; test hashes unchanged. Unix `command` text left unchanged: frozen `test.sh` selects hooks by its ending. |
| 2026-10-15 | Doctor | A4 and A4b check each hook on its event and matcher (A4b also requires feedback-check and the Codex helper files). A4c asks Codex `app-server hooks/list` for the project and names each required hook that is missing (untrusted project), disabled, untrusted or modified; no answer is a warning (unverified). Skipped with `--quiet` (it starts Codex). Live probes in a scratch home: untrusted, trusted, modified (stale hash), disabled and full-trust all reported correctly; an edited hook turned modified. Found: project trust is a separate layer; the app-server writes Codex state files into the home. Template 2.4.0; docs aligned. Parity 121/0; full suite, links and diff check pass; test hashes unchanged. |
| 2026-10-15 | Independent review | Sonnet reviewer: 1 major, 3 minor, 2 suggestions; test hashes verified. Fixed: a UNC path (`//localhost/c$/...`) to a project file skipped every `apply_patch` guard (reproduced); network paths now block and subst/junction names map back to the project by file identity (reproduced as blocked). Empty `hooks.json` now merges as `{}` in bootstrap and the global installer. Unix guard commands exit 2 when the adapter is missing (the test-selected command ending is unchanged). Doctor A4c requires every copy of a check to be enabled and trusted. A Codex owner transcript whose user messages all lack the known marker reports unavailable. Indented patch headers make the lock rebuild fail. `runtime-parity.md` drops the unverified exec claim and states the shell-write, path and CLI-only approval limits. Left open: the Codex path slurps the whole transcript on Stop and owner prompts (slower on large rollouts); A4c does not match the event name until live hooks/list output confirms its format. |
| 2026-10-15 | Rollout plan | Dry runs on copies of both Codex homes and of App01/vn30 `main`; diffs and order recorded under Rollout plan. Nothing real changed. vn30 has another session's docs work, so its upgrade goes in a separate worktree. |

## Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-10-13 | Keep shared policies and add runtime plumbing | Both runtimes must apply the same Lodestar system. |
| 2026-10-13 | Distinguish template coverage from live activation | Hook trust and active Codex home affect actual execution. |
| 2026-10-13 | Skip source-repository onboarding only for this task | Explicit owner instruction; keep consuming-project readiness and independent verification. |
| 2026-10-13 | Correct the earlier waiver interpretation | Source readiness exemption already exists; align shared text and tests instead of requesting onboarding or another waiver. |
| 2026-10-13 | Define source test evidence explicitly | Source CI and plan paths differ from consuming-project hook machinery; no fabricated approval records. |
| 2026-10-13 | Keep Claude as Orca's default agent | Explicit owner clarification; parity makes Codex conform when selected, not the default provider. |
| 2026-10-13 | Pause implementation and preserve the partial snapshot | Explicit owner stop request; record completed and remaining work without continuing fixes, tests or rollout. |
