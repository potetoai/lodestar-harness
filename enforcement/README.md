# Enforcement

Machine checks that every Lodestar project must pass. The rules are in
`../rules/enforcement.md`; this folder holds the tooling.

| Path | Kind | What it is |
|---|---|---|
| `bootstrap.sh` | tool | Installs or upgrades the checks in a project |
| `test.sh` | tool | Self-test for bootstrap, doctor and hooks |
| `user-path.ps1` | tool | Windows: puts a folder first in the user `PATH`; called by `setup-machine.sh` |
| `VERSION` | tool | Template version, recorded in each project's `.ai/enforcement.json` |
| `agents/claude/` | [managed] | Claude Code hooks, `settings.json`, `doctor.sh`; `global/` holds the machine-wide reminder |
| `agents/codex/` | [managed] | Codex project adapter/configuration and global installers that run shared Lodestar checks |
| `github/ci.yml` | [managed] | GitHub Actions workflow; calls only `make` |
| `stacks/<lang>/` | [project] | Starting `Makefile`, `.gitignore`, deps for one language |
| `project/` | [project] | Starting `AGENTS.md` and `.ai/` files |

The project `.ai/project.md` comes from `../project/.ai/project.md`.

Claude remains Orca's default agent. Codex uses the same policy when selected;
installing its hooks does not change runtime defaults. See
[runtime parity](runtime-parity.md) for lifecycle coverage and activation checks.

## 1. One-time machine setup

Quick path: run `bash enforcement/setup-machine.sh` from Git Bash. It checks
every item below, installs or creates only what is missing (asking first),
and prints a health report; `--check` changes nothing. Plain step-by-step guide:
[setup-guide.md](setup-guide.md). The manual steps:

Install `make` and `jq`. On Windows:

```powershell
winget install --exact --id ezwinports.make
winget install --exact --id jqlang.jq
```

Then restart the terminal and Claude Code (and Orca, if you use it) so they see
the new User `PATH`. `setup-machine.sh` adds Git Bash, `make`, and `jq` to it,
so direct Windows commands resolve to Git Bash rather than the WSL shim.
On macOS: `brew install make jq`. On Linux both are usually installed.

Then register the global reminder. At the start of every session in a
project that is not ready, it tells the agent to run onboarding first. It
never blocks:

```bash
bash /path/to/lodestar-harness/enforcement/agents/claude/global/install.sh
# Codex: the active CODEX_HOME, or ~/.codex when unset.
bash /path/to/lodestar-harness/enforcement/agents/codex/global/install.sh
```

Global installation registers session-start readiness/maintenance, per-prompt
readiness and post-tool context reminders. Claude uses `~/.claude/settings.json`;
Codex uses `<CODEX_HOME>/hooks.json`. The machine setup command installs Codex
instructions and hooks in both the default and active homes. Existing Orca
hooks and unrelated settings are preserved. Changed configuration is backed
up; malformed or ambiguous hook configuration is reported rather than overwritten.

The shared readiness script already exempts the Lodestar source repository,
after its handoff reminder. This source repository uses its own `AGENTS.md`,
README, self-tests and link checks, without another onboarding waiver.

## 2. Add the checks to a project

Run from Git Bash (Windows) or any shell (macOS/Linux):

```bash
bash /path/to/lodestar-harness/enforcement/bootstrap.sh <project-dir> --stack <node-ts|python>
```

Then:

1. Fill in `AGENTS.md` and `.ai/project.md` (replace every `[placeholder]` line).
2. Adjust the `Makefile` recipes to the project's real tools.
3. Run `make setup`, then `make verify`.
4. Run `bash .claude/hooks/doctor.sh` until it prints "Ready".
5. On GitHub, protect `main`: require a pull request and the `CI` check.

Running `bootstrap.sh` again is safe: it preserves unrelated settings and
hooks, adds missing Lodestar hooks and repairs their managed registrations.
Events and matchers matter as well as commands; a guard on the wrong event
does not satisfy registration checks.

Codex runs project hooks only after the owner trusts them: open Codex in the
project, type `/hooks`, trust the Lodestar hooks. Codex asks again when
the hook definition changes. Doctor A4c asks Codex which required hooks
are missing (an untrusted project shows none), disabled, untrusted or
modified, and warns when Codex does not answer; an old trust entry does not
establish current trust. It starts Codex, so it does not run with `--quiet`.
Codex keeps trust per home (`~/.codex`, or `CODEX_HOME` when an orchestrator
sets it), so trust the hooks once in each; A4c names the home it checked.
Review global hooks as well as project hooks. Activation remains pending
until the required definitions are enabled/trusted and live execution is verified.

Doctor stops with "wrong bash" (exit 2, nothing checked) when it is started
by the WSL shim in a Windows folder or by a bash without `grep`. That is not
a project failure: run it again with Git Bash.

## 3. Upgrade a project after the templates change

Release cadence (owner decision 2026-10-19): batch template changes and
raise `VERSION` at most once every 7-14 days, so each project upgrades
rarely. Merged changes wait on main until the next batch. Release at once
only for a fault that blocks work in a project (a hook blocking correct
work, a false approval, a broken install) or a security fix.

Raise `VERSION`, then in each project:

```bash
bash /path/to/lodestar-harness/enforcement/bootstrap.sh <project-dir> --stack <s> --upgrade
```

`--upgrade` overwrites [managed] files only. [project] files are never touched.
Every run adds the lines it needs to `.gitignore`, `.gitattributes` and, for
node-ts at the repo root, `.prettierignore` (`.claude/`, `.codex/`). Files are
installed with LF line endings, also from a CRLF checkout of this repo.

## 4. Add a language or an agent

- Language: add `stacks/<lang>/` with a `Makefile` that implements the
  command contract, plus `.gitignore`. Update the `ci.yml` toolchain steps if
  the language needs one.
- Agent: add `agents/<name>/` next to `agents/claude/`. The shared core is
  `make verify`; the adapter only wires the agent's hook system to it.

## 5. Before you commit changes here

```bash
bash enforcement/test.sh
bash scripts/check-links.sh
```
