# Behavior evals

Checks that an agent still behaves right after policy text changes. Plan:
[behavior-evals](../plans/active/behavior-evals.md). Runs only on the
owner's machine (it uses the owner's quota), never in CI.

| Path | What |
|---|---|
| `.claude-plugin/`, `skills/lodestar/` | Wrapper plugin: loads Lodestar the way `~/.claude/CLAUDE.md` does. The skill finds the harness from its own folder (`${CLAUDE_SKILL_DIR}`), so it needs no edit on another machine |
| `router/` | Router suite: 13 cases, each a task in and a route line out |
| `router/scores.md` | Main scores and tokens; a PR compares against them |
| `tokens.py` | Prints per-case scores and tokens from a run's JSON |
| `results/` | Run output (gitignored) |

## Run the Router suite

From the repo root:

```bash
ROOT=$(git rev-parse --show-toplevel)    # D:/... on Windows
case $ROOT in /*) ROOT="/$ROOT";; esac   # macOS/Linux: absolute rules start with //
claude plugin eval evals --eval-dir router --model opus --no-publish \
  --trust-plugin --keep-temp -j 3 --max-cost-usd 4 \
  --allow-tools "Read($ROOT/**)" \
  --output-dir evals/results/<name> --json evals/results/<name>/run.json
python evals/tokens.py evals/results/<name>/run.json
```

- Each case runs twice: with Lodestar and without (baseline). Score 1.00
  means every grader passed.
- `--max-cost-usd` is only the stop switch; $4 is about 1.5M tokens at the
  runner's price estimate. Report tokens, not dollars.
- `--keep-temp` keeps the traces `tokens.py` reads. Delete the kept
  `claude-eval-*` dirs in the temp folder after reading them.
- Run one case with `--case <name>`; rerun a borderline case with `--runs 3`.

## Case shape

Each case is a folder with `prompt.md` (task text) and `graders/*.md`.
Every prompt gives the same project facts (onboarded, `sensitive_paths`,
one high-risk invariant) and lists the workflow names and risk levels, so
the two arms differ only in judgment. Graders are regex on the last
message (`match: contains` or `not_contains`); only
`approval-wait-migration` uses a haiku judge, because a route line alone
cannot show that the agent waits.
