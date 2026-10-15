# Runtime parity

Claude remains the default agent in Orca. Selecting Codex changes the runtime,
not the Lodestar workflow, roles, rules or verification requirements. Installers
do not change Orca's default agent or grant hook trust on the owner's behalf.

## Shared policy and lifecycle checks

`setup-machine.sh` installs one bootstrap text into Claude's global instructions
and Codex `AGENTS.md` in both the default home and active `CODEX_HOME`.
Project instructions remain in `AGENTS.md`. Policy scripts are shared;
runtime adapters translate inputs rather than maintaining a second policy.

| Behavior | Claude event/tool | Codex event/tool |
|---|---|---|
| Readiness, handoff and due maintenance | Global `SessionStart` | Global `SessionStart` |
| Readiness beside each owner prompt | Global `UserPromptSubmit` | Global `UserPromptSubmit` |
| Context and handoff reminder | Global `PostToolUse`, all tools | Global `PostToolUse`, all tools |
| Approval/test-lock and sensitive-path guards | `PreToolUse`, file edits | `PreToolUse`, `apply_patch` |
| Install and Git command guard | `PreToolUse`, shell | `PreToolUse`, `Bash` |
| Lint edited files | `PostToolUse`, file edits | `PostToolUse`, each affected `apply_patch` path |
| Verify and feedback correction reminder | `Stop` | `Stop` |
| Record genuine owner criteria approval | `UserPromptSubmit` | `UserPromptSubmit` |

The readiness script exempts the Lodestar source repository after delivering
its handoff reminder. Missing installed hooks in this source repository does
not trigger onboarding. Consuming projects without readiness still receive
onboarding guidance in both runtimes.

## Installed versus activated

`bootstrap.sh` installs project configurations and shared scripts.
`setup-machine.sh` also installs global Codex hooks in `~/.codex` and the active
`CODEX_HOME`, retaining unrelated hooks such as Orca's integrations. Repeated
installation is idempotent. Review the prepared diff before upgrading an
existing project with its own active work.

Codex loads only trusted project configuration and enabled, trusted hook
definitions. Review the current definitions with `/hooks` in the Codex instance
using the intended home. A changed definition requires another trust review.
Neither a file on disk nor an old `trusted_hash` substring establishes that the
runtime runs every required hook. Doctor reports registration problems and
unverified activation; it must not turn stale trust into a success claim.

For runtime inspection, Codex 0.162.1 exposes the app-server `hooks/list`
method with `cwds`. It changes no trust, but starting the app-server creates
Codex's own state files in the home. Project hooks are listed only when the
project itself is trusted. Its per-hook metadata includes `sourcePath`,
`eventName`, `matcher`, `enabled`, `trustStatus` (`trusted`, `untrusted`,
`modified` for a stale hash, `managed`) and `currentHash`; doctor A4c uses it.
Check the
actual home and checkout, then exercise the required lifecycle events. Do not
write trust state or bypass review to make an activation check pass.

The parity plan targets Codex 0.162.1 on Windows with Git Bash and PowerShell
hook entry points. Record the version and live evidence at verification time;
fixture tests alone are not evidence of activation. The steps are in
[codex-live-smoke.md](codex-live-smoke.md). Claude compatibility is
checked by the existing and targeted regression tests; report any live Claude
run separately. Other versions and platforms require their own verification.

## Runtime data and failure behavior

Codex file patches carry their text in `tool_input.command`; all affected paths,
including rename destinations, must pass the shared guards. Append-only lock
updates preserve the same normalized test-path semantics as Claude. Unknown
patch results cannot authorize a change to a locked file.

Codex transcripts may contain user-role system context. The supported current
format identifies owner content using `content_item_kinds` metadata and excludes
child/guardian sessions and delegated messages. Current context comes from
`token_count.info.last_token_usage.input_tokens`; cumulative totals and cached
input counted a second time would give a wrong threshold. Transcript formats
are not stable interfaces: unsupported or missing data must be reported.

Feedback and context reminders claim delivery atomically and isolate runtime,
home and session. Persistent state contains identifiers/counters, not the
owner's correction text. Advisory failures report that the check is unavailable;
they do not block unrelated work. Applicable pre-operation guards fail closed
on invalid input or failed check execution. The existing repeated Stop escape
belongs only to verification and cannot disable a pre-operation guard.

Hooks cover supported runtime paths, not every possible filesystem write: a
shell command can still write files (for example `apply_patch` run through
`Bash`), and only the install and Git guard sees it. Network, stream and
device paths in a patch are blocked; other names for the project folder
(subst drive, junction) are mapped back to it. Codex approvals are recorded
only from an owner CLI session, not from Codex app or IDE sessions.
CI and sandbox controls remain necessary. See the
[official Codex hook contract](https://learn.chatgpt.com/docs/hooks) and the
[approved execution plan](../plans/active/codex-lodestar-parity.md) for detailed
acceptance and the source repository's committed test boundary.
