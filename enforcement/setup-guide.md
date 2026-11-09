# Set up lodestar-harness on a new machine

Step-by-step guide for a Windows machine; on macOS or Linux, steps 1–4 are
in [macOS and Linux](#macos-and-linux) below. Do it once per machine. On a
machine that is already set up, run only step 3 as a health check: the script
only reports and changes nothing.

## Where this is tested

Facts only; no support promise beyond them.

| Environment | What is tested | How |
|---|---|---|
| Windows 11, Git Bash (Git for Windows) | Full setup and daily use | The maintainer's machine. Last checked 2026-11-04: Git 2.55.0, Claude Code 2.1.318, Codex 0.166.0; fresh-clone run in step 5 |
| Linux (GitHub `ubuntu-latest`), macOS (GitHub `macos-latest`, Apple Silicon) | Machine setup into a scratch home (`setup-machine.sh --yes`), the self-test (`enforcement/test.sh`) and doc links | CI on every pull request and push to `main`. On macOS, CI first runs `brew install bash coreutils`, as the steps below say. Claude Code itself is not installed there, so no live session runs |
| A person's macOS or desktop Linux machine, WSL | Nothing recorded | If you try one, report the result as a GitHub issue |

Codex hook parity is checked by hand; see the
[runtime parity guide](runtime-parity.md) for the version it was verified on.

## Step 1: Install the base software (by hand, once)

| Software | What for | Where to get it |
|---|---|---|
| Git for Windows | Claude Code needs it; hooks run in Git Bash | https://git-scm.com |
| Claude Code | The main tool | https://claude.com/claude-code |
| GitHub CLI (`gh`) | Open PRs, watch CI. After installing, run `gh auth login` | https://cli.github.com |
| Python | For Python projects | https://python.org |
| Node.js | For web projects (node-ts) | https://nodejs.org |
| Orca ADE (optional; third party, by Stably) | Runs several agents in parallel | |

## Step 2: Get lodestar-harness onto the machine

Open **Git Bash** and run (change the path if you like, but use **no accented
or non-English letters** in it):

```bash
git clone https://github.com/potetoai/lodestar-harness.git /c/lodestar-harness
```

## Step 3: Run the setup script

Still in Git Bash:

```bash
bash /c/lodestar-harness/enforcement/setup-machine.sh
```

The script checks each item and prints a ✅ / ⚠️ / ❌ table:

- `make` or `jq` missing: it asks, then installs them with winget.
- It creates `~/.claude/CLAUDE.md` pointing to lodestar-harness on this machine,
  and the same block in `~/.codex/AGENTS.md` when Codex is installed.
  When `CODEX_HOME` names another home, it installs the same instructions
  and global hooks there too, preserving Orca's existing hooks.
  If a file already has your own content, the script only **adds** the
  Lodestar part and keeps a backup (`CLAUDE.md.bak`, `AGENTS.md.bak`).
- It installs the machine-wide hooks: the readiness reminder, and the
  context nudge that asks for `/clear` when a task ends (`merge-pr.sh`
  merged a PR) or a session passes 200k tokens.
  Claude uses its settings file; Codex uses `hooks.json` in its homes.
  Claude remains the default agent in Orca; these registrations do not
  change the default provider or model.
- It runs the self-test: 1–2 minutes on Linux CI, about 17 minutes on the
  Windows machine recorded in step 5.

Items already in place show ✅ and are skipped. Running it again is always
safe.

In each Codex home you use, inspect `/hooks` and trust the current Lodestar
definitions. New or changed definitions require review. An installed hook
is not evidence that it ran: doctor names unverified activation, and the
[runtime parity guide](runtime-parity.md) describes the live checks.

The Lodestar source checkout itself is exempt from consuming-project
onboarding. Its readiness hook still points to `.ai/handoff.md`; verification
here is `bash enforcement/test.sh` and `bash scripts/check-links.sh`.

To **only look, without changing anything**: add `--check` at the end of the
command.

## Step 4: Restart

Close Git Bash, open a new terminal, and restart Claude Code (and Orca, if
you use it) so they see the updated User `PATH`. Setup adds Git Bash, `make`
and `jq` to that path; Git Bash is placed before WindowsApps so `bash` does
not resolve to the WSL shim.

Quick check in PowerShell or an Orca terminal:

```powershell
make --version
bash --version
jq --version
```

Then, from the project folder, `make verify` and
`bash .claude/hooks/doctor.sh` run directly.

## macOS and Linux

Steps 1–4 differ; step 5 onward is the same.

1. Install Git, Claude Code and `gh` (links in step 1), then the tools:
   - macOS (with [Homebrew](https://brew.sh)): `brew install bash jq coreutils`.
     macOS ships bash 3.2; the hooks need bash 4 or newer. `coreutils` adds
     `gtimeout`, which the daily GitHub sweep and the mutation test limit use.
   - Debian or Ubuntu: `sudo apt install make jq` (bash and `timeout` are
     already there).
2. Clone: `git clone https://github.com/potetoai/lodestar-harness.git ~/lodestar-harness`
3. Run `bash ~/lodestar-harness/enforcement/setup-machine.sh`. It checks the
   bash version and says what is missing; there is no winget or `PATH` step.
4. Open a new terminal and restart Claude Code. `bash --version` must show 4
   or newer there, because Claude Code runs the hooks with the first `bash` on
   `PATH`. On macOS, Homebrew's folder (`/opt/homebrew/bin` on Apple Silicon,
   `/usr/local/bin` on Intel) must come before `/bin`: Homebrew's install
   message gives the `brew shellenv` line that does this.

## Step 5: A first task (example)

A small Python project (`greet.py` and one test in `tests/`), already a git
repository. Open Claude Code in it and ask for one task, for example:

> `greet('')` should return `Hello there`; add a test.

1. **Onboarding comes first.** The project is not ready yet, so the agent runs
   [onboarding](../workflows/onboarding.md): `bootstrap.sh <project> --stack
   python` adds the hooks, CI and `.ai/` files; the agent fills `AGENTS.md`,
   `.ai/project.md` and `.ai/invariants.md`, asks you about the project and
   asks you to approve the invariants; `make setup` creates `.venv`. It ends
   when `bash .claude/hooks/doctor.sh` prints `Ready`. Two warnings can stay:
   Codex hook trust (only if you use Codex) and branch protection (a GitHub
   setting).
2. **Then the task.** The agent writes the failing test first, changes
   `greet.py`, runs `make verify`, and commits on a branch. It opens a pull
   request when the project has a GitHub remote.
3. **What the hooks do on the way.** You do not run them; Claude Code does.
   Each file edit is linted (`lint-file.sh`). A session cannot finish while
   `make verify` fails (`verify-before-stop.sh`). Commands that skip checks
   are blocked, for example `git commit --no-verify`:
   `Blocked: --no-verify (or commit -n) skips the project's git hooks.`

Record (2026-11-04, Windows 11, Git 2.55.0, Claude Code 2.1.318, Python
3.12.10): fresh clone of `main` at `9a0e91f`; `setup-machine.sh` run against
an empty scratch home printed `Ready: 0 warning(s)` and `self-test: 805
checks passed`. On a scratch project, `bootstrap.sh` was run by hand, then
one Claude Code session did the rest of onboarding and the task, with the
owner's questions skipped (the agent marked its invariants "draft; owner to
review"). Doctor `Ready`; 17 turns, about $0.51. Claude Code ran with the
maintainer's own home (set up the same way), because its login lives there.
The session transcript shows these hooks ran: the global readiness hook
(session start, prompt), `lint-file.sh` after a file write,
`verify-before-stop.sh` and `feedback-check.sh` at stop. A second short
session (model Haiku) showed `guard-install.sh` blocking `--no-verify`. The
other guards (`protect-tests.sh`, `sensitive-gate.sh`) leave no trace when
they allow a change; no block by them was exercised.

## Optional: compact long sessions earlier

Claude Code compacts a session on its own only near its 1M-token window. The
environment variables `CLAUDE_CODE_AUTO_COMPACT_WINDOW` and
`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` exist in Claude Code (found in the program,
not documented here). Not set by default: the context nudge already asks for a
handoff and `/clear`, which keeps more than a compaction summary. If you try
one, check the "Auto-compact window" line of `/context` in a new session.

## Optional: trim the base context

Every turn of every session carries the base context: the Claude Code prompt
and tools, the skill list, MCP server names, `CLAUDE.md` and memory. Plugins
and connectors you do not use still add to it.

- Measure the real size from the session transcript, not from `/context`:
  the first assistant turn's `input_tokens` + `cache_read_input_tokens` +
  `cache_creation_input_tokens` in `~/.claude/projects/<project>/*.jsonl`.
  `/context` reads lower (35k shown against 50k billed, 2026-10-12).
- In `/context`, the Skills and MCP tables show the size of each plugin. Turn
  off a plugin nobody used lately by setting it to `false` under
  `enabledPlugins` in `~/.claude/settings.json`; set it back to `true` to
  undo. A plugin needed by one project can be enabled in that project's
  `.claude/settings.json` instead of for the whole machine.
- About 40k of the base is Claude Code itself and cannot be turned off.

Record (2026-10-12, Claude Code 2.1.296): base 50k at turn one. Turned off
`expo` (24 skills, about 4.1k, never used) and `superpowers` (14 skills plus a
session-start text, about 1.9k; its always-on rule conflicts with the Router).
Kept on by the owner: the claude.ai skills and connectors (about 3.9k).
Base after: 42.6k at turn one (51.2k before, about 8.6k less).

Record (2026-10-19): `/context` in a fresh consuming-project session fell from 34.2k to
17.9k (system tools 23.8k to 11.7k, skills 4.8k to 2.1k, Claude Docs MCP
1.3k to 0), about 8% of cost at 5% per 10k. Changes, each undone by removing
the line: in `~/.claude/settings.json`, `"permissions": {"deny":
["PowerShell"]}` (the Bash tool stays), `"disableClaudeAiConnectors": true`
and `"syncClaudeAiSkills": false`; in a project's gitignored
`.claude/settings.local.json`, `"enableArtifact": false`. Confirm with the
billed turn-one number (first bullet above).

## When to run step 3 again

- After updating lodestar-harness (`git pull`): the Lodestar part of
  `~/.claude/CLAUDE.md` may have a new version.
- When you suspect a problem with the machine: use `--check` to diagnose.

## Remove Lodestar

Nothing here is undone by a script. Each step names exactly what Lodestar
wrote; remove only that and keep your own content. Run the commands in
Git Bash. A filter used below drops hook entries whose command matches a
pattern, and drops groups and events it leaves empty:

```bash
drop_hooks() {   # drop_hooks FILE PATTERN
  jq --arg re "$2" 'if .hooks then .hooks |= (map_values(map(.hooks |= map(select((.command // "") | test($re) | not))) | map(select(.hooks | length > 0))) | with_entries(select(.value | length > 0))) else . end' "$1" > "$1.new" && mv "$1.new" "$1"
}
```

### From a project

Do it on a branch and merge it with a pull request, like any change.
`bootstrap.sh` wrote these; `[managed]` files are Lodestar's, `[project]`
files became yours when it created them.

1. Hook registrations, in `.claude/settings.json` (Claude) and
   `.codex/hooks.json` (Codex). Delete a file if nothing else is left in it
   (`{"hooks": {}}` or `{}`).

   ```bash
   drop_hooks .claude/settings.json '\.claude/hooks/(protect-tests|sensitive-gate|critic-limit|guard-install|lint-file|verify-before-stop|feedback-check|approval-record)\.sh'
   [ -f .codex/hooks.json ] && drop_hooks .codex/hooks.json '\.claude/hooks/codex-hook\.sh'
   ```

2. `[managed]` hook scripts and CI:

   ```bash
   cd .claude/hooks && rm -f lodestar-lib.sh lint-file.sh verify-before-stop.sh protect-tests.sh sensitive-gate.sh guard-install.sh approval-record.sh critic-limit.sh feedback-check.sh ci-checks.sh doctor.sh merge-pr.sh pre-push.sh reminder-lib.sh codex-owner.jq codex-hook.sh codex-patch.jq && cd ../..
   git rm .github/workflows/ci.yml   # or keep it as your own CI
   ```

3. Lodestar records in `.ai/`: `enforcement.json`, `last-maintenance`,
   and, if present, `approvals.log` and `test-lock`.
4. `[project]` files: `AGENTS.md` (your `CLAUDE.md` was moved there, if you
   had one), `.ai/project.md`, `.ai/invariants.md`, `.ai/feedback-log.md`,
   `.ai/tech-debt.md`, `.ai/plans/`, and the stack files it created
   (`Makefile`, `.gitignore`, `requirements-dev.txt`; it never overwrote a
   file you already had). Keep what you use; delete the rest.
5. Small lines, harmless to keep: `.ai/handoff.md` in `.gitignore`;
   `*.sh text eol=lf` (or `* text=auto eol=lf` in a repo that had no commits)
   in `.gitattributes`; `.claude/` and `.codex/` in `.prettierignore`;
   `.nvmrc` or `.python-version`.
6. Local only, in every clone (git does not commit these):

   ```bash
   gd=$(git rev-parse --git-common-dir)
   grep -q 'Managed by lodestar-harness' "$gd/hooks/pre-push" 2>/dev/null && rm "$gd/hooks/pre-push"
   rm -rf "$(git rev-parse --absolute-git-dir)"/lodestar-*
   ```

   A `pre-push` hook that is not Lodestar's only had one line added by you:
   `bash .claude/hooks/pre-push.sh "$@" || exit 1`. Delete that line.

### From the machine

1. The Lodestar block in `~/.claude/CLAUDE.md` and, for Codex,
   `~/.codex/AGENTS.md` (and `$CODEX_HOME/AGENTS.md` if you set
   `CODEX_HOME`). Delete a file if the block was all it held.

   ```bash
   for f in ~/.claude/CLAUDE.md ~/.codex/AGENTS.md ${CODEX_HOME:+"$CODEX_HOME/AGENTS.md"}; do
     [ -f "$f" ] && sed -i '/<!-- lodestar-harness:begin/,/<!-- lodestar-harness:end -->/d' "$f"
   done
   ```

2. Global hooks, in `~/.claude/settings.json` and each Codex home's
   `hooks.json`. Delete a `hooks.json` left as `{"hooks": {}}`.

   ```bash
   drop_hooks ~/.claude/settings.json '(check-readiness|context-nudge)\.sh"'
   for f in ~/.codex/hooks.json ${CODEX_HOME:+"$CODEX_HOME/hooks.json"}; do
     [ -f "$f" ] && drop_hooks "$f" 'codex-global-hook\.sh"'
   done
   ```

3. Reminder state and the bug inbox:
   `rm -rf ~/.lodestar ~/.claude/lodestar-state ~/.codex/lodestar-state`
   (and `$CODEX_HOME/lodestar-state`).
4. Backups the setup made before each change: `CLAUDE.md.bak`,
   `settings.json.bak`, `AGENTS.md.bak`, `hooks.json.bak`, next to each
   file. They hold your file as it was before the last change (which may
   include an older Lodestar block). Delete them when you no longer need
   them.
5. Windows only. Setup added Git Bash, `make` and `jq` to your user `PATH`
   and may have installed `make` and `jq` with winget. Other tools use them,
   so keeping them is fine. To remove: `winget uninstall --id ezwinports.make`
   and `winget uninstall --id jqlang.jq`; edit the user `PATH` in Windows
   "Edit environment variables for your account".
6. Delete the lodestar-harness folder, then restart Claude Code (and Orca,
   Codex).
