# Set up lodestar-harness on a new machine

Step-by-step guide for a Windows machine. Do it once per machine. On a
machine that is already set up, run only step 3 as a health check: the script
only reports and changes nothing.

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
  If a file already has your own content, the script only **adds** the
  Lodestar part and keeps a backup (`CLAUDE.md.bak`, `AGENTS.md.bak`).
- It installs the machine-wide hooks: the readiness reminder, and the
  context nudge that asks for `/clear` once a session passes 200k tokens.
- It runs the self-test (1–2 minutes).

Items already in place show ✅ and are skipped. Running it again is always
safe.

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

## When to run step 3 again

- After updating lodestar-harness (`git pull`): the Lodestar part of
  `~/.claude/CLAUDE.md` may have a new version.
- When you suspect a problem with the machine: use `--check` to diagnose.
