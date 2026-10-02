# Third-Party Software

Lodestar-harness does not include or redistribute third-party code. It is a
set of documents and shell scripts that call tools you install yourself. Each
tool comes under its own license and terms, between you and its provider.
Lodestar-harness is not affiliated with any of them.

| Tool | Used for | Needed | Provider, license |
|---|---|---|---|
| Claude Code | Agent runtime | Yes | Anthropic, commercial terms |
| Git (Git Bash on Windows) | Version control; hooks run in Bash | Yes | GPL-2.0 |
| jq | JSON in hooks and setup | Yes | MIT (code) |
| GNU Make | Project command contract (`make verify`) | Yes | GPL-3.0 |
| GitHub, GitHub CLI (`gh`), GitHub Actions | Pull requests, CI | Recommended | GitHub; `gh` and `actions/*` MIT |
| gitleaks | Secret scan in CI, downloaded during the CI run | In CI | MIT |
| ruff, pytest, cosmic-ray | Python stack: lint, tests, mutation testing | Python projects | MIT |
| ESLint, Prettier, TypeScript, Stryker | Node stack: lint, format, types, mutation testing | Node projects | MIT; MIT; Apache-2.0; Apache-2.0 |
| Orca ADE | Optional orchestrator for parallel agents | No | Stably, MIT |
| Playwright MCP | Optional browser automation | No | Microsoft, Apache-2.0 |

The project's own dependencies are chosen by the project and are not covered
here.
