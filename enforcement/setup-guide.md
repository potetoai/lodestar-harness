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
- It creates `~/.claude/CLAUDE.md` pointing to lodestar-harness on this machine.
  If that file already has your own content, the script only **adds** the
  Lodestar part and keeps a backup, `CLAUDE.md.bak`.
- It installs the machine-wide hooks: the readiness reminder, and the
  context nudge that asks for `/clear` once a session passes 200k tokens.
- It runs the self-test (1–2 minutes).

Items already in place show ✅ and are skipped. Running it again is always
safe.

To **only look, without changing anything**: add `--check` at the end of the
command.

## Step 4: Restart

Close Git Bash, open a new terminal, and restart Claude Code (and Orca, if
you use it) so they see `make` and `jq`.

Quick check inside Claude Code:

```
! make --version
! jq --version
```

## Optional: compact long sessions earlier

Claude Code compacts a session on its own only near its 1M-token window. The
environment variables `CLAUDE_CODE_AUTO_COMPACT_WINDOW` and
`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` exist in Claude Code (found in the program,
not documented here). Not set by default: the context nudge already asks for a
handoff and `/clear`, which keeps more than a compaction summary. If you try
one, check the "Auto-compact window" line of `/context` in a new session.

## When to run step 3 again

- After updating lodestar-harness (`git pull`): the Lodestar part of
  `~/.claude/CLAUDE.md` may have a new version.
- When you suspect a problem with the machine: use `--check` to diagnose.
