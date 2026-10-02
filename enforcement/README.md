# Enforcement

Machine checks that every Lodestar project must pass. The rules are in
`../rules/enforcement.md`; this folder holds the tooling.

| Path | Kind | What it is |
|---|---|---|
| `bootstrap.sh` | tool | Installs or upgrades the checks in a project |
| `test.sh` | tool | Self-test for bootstrap, doctor and hooks |
| `VERSION` | tool | Template version, recorded in each project's `.ai/enforcement.json` |
| `agents/claude/` | [managed] | Claude Code hooks, `settings.json`, `doctor.sh`; `global/` holds the machine-wide reminder |
| `github/ci.yml` | [managed] | GitHub Actions workflow; calls only `make` |
| `stacks/<lang>/` | [project] | Starting `Makefile`, `.gitignore`, deps for one language |
| `project/` | [project] | Starting `CLAUDE.md` and `.ai/` files |

The project `.ai/project.md` comes from `../project/.ai/project.md`.

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

Then restart the terminal and Claude Code (and Orca, if you use it) so they see the new `PATH`.
On macOS: `brew install make jq`. On Linux both are usually installed.

Then register the global reminder. At the start of every session in a
project that is not ready, it tells the agent to run onboarding first. It
never blocks:

```bash
bash /path/to/lodestar-harness/enforcement/agents/claude/global/install.sh
```

It adds one `SessionStart` hook to `~/.claude/settings.json`, keeps
everything else, and saves a `.bak` copy first.

## 2. Add the checks to a project

Run from Git Bash (Windows) or any shell (macOS/Linux):

```bash
bash /path/to/lodestar-harness/enforcement/bootstrap.sh <project-dir> --stack <node-ts|python>
```

Then:

1. Fill in `CLAUDE.md` and `.ai/project.md` (replace every `[placeholder]` line).
2. Adjust the `Makefile` recipes to the project's real tools.
3. Run `make setup`, then `make verify`.
4. Run `bash .claude/hooks/doctor.sh` until it prints "Ready".
5. On GitHub, protect `main`: require a pull request and the `CI` check.

Running `bootstrap.sh` again is safe: it only adds what is missing. An
existing `.claude/settings.json` keeps its settings; only the hooks are added.

## 3. Upgrade a project after the templates change

Raise `VERSION`, then in each project:

```bash
bash /path/to/lodestar-harness/enforcement/bootstrap.sh <project-dir> --stack <s> --upgrade
```

`--upgrade` overwrites [managed] files only. [project] files are never touched.

## 4. Add a language or an agent

- Language: add `stacks/<lang>/` with a `Makefile` that implements the
  command contract, plus `.gitignore`. Update the `ci.yml` toolchain steps if
  the language needs one.
- Agent: add `agents/<name>/` next to `agents/claude/`. The shared core is
  `make verify`; the adapter only wires the agent's hook system to it.

## 5. Before you commit changes here

```bash
bash enforcement/test.sh
```
