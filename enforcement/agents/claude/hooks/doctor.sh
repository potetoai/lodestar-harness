#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# Check this project against the lodestar-harness Project Readiness Standard.
# Usage: doctor.sh [project-dir] [--quiet]
#   --quiet  print only the items that are not OK
# Exit 1 when a required item fails, 2 when the wrong bash ran it (nothing checked).
quiet=0 dir=.
for a in "$@"; do
  case "$a" in
    --quiet) quiet=1 ;;
    *) dir=$a ;;
  esac
done
cd "$dir" || { echo "doctor: cannot open $dir" >&2; exit 1; }

# A wrong bash makes healthy items fail. On Windows plain `bash` can be the
# WSL shim (no make, jq or git there), and Git's usr\bin\bash.exe started
# directly has no grep. Stop before any check, so the result is not read as
# a project failure.
wrong_bash() {
  echo "doctor: wrong bash, nothing was checked: $1."
  echo "On Windows run it with Git Bash: & \"C:\\Program Files\\Git\\bin\\bash.exe\" .claude/hooks/doctor.sh"
  echo "This is not a project failure: do not start onboarding for it."
  exit 2
}
for tool in grep awk find sort tail tr wc date dirname; do
  command -v "$tool" >/dev/null 2>&1 || wrong_bash "this shell has no $tool"
done
if grep -qi microsoft /proc/version 2>/dev/null && [[ $(pwd) == /mnt/[a-z]/* ]]; then
  for tool in make jq git; do
    command -v "$tool" >/dev/null 2>&1 || wrong_bash "this is WSL in a Windows folder, without $tool"
  done
fi

fails=0
ok()   { [ $quiet = 1 ] || echo "✅ $1  $2"; }
warn() { echo "⚠️  $1  $2"; }
fail() { echo "❌ $1  $2"; fails=$((fails + 1)); }
# check ID TEXT SEVERITY(fail|warn) COMMAND...
check() {
  local id=$1 text=$2 sev=$3; shift 3
  if "$@" >/dev/null 2>&1; then ok "$id" "$text"; else "$sev" "$id" "$text"; fi
}

# A line that is only a template placeholder, e.g. "[Project name]" or "* [Goal 1]".
no_placeholders() { [ -f "$1" ] && ! grep -qE '^[[:space:]]*([*-][[:space:]]*)?\[[^]]+\][[:space:]]*$' "$1"; }
# Native Windows make (Git Bash: `pwd -W` works) cannot read a Makefile in a
# folder whose path has non-ASCII characters. Other systems are fine.
ascii_path() { local w; w=$(pwd -W 2>/dev/null) || return 0; ! LC_ALL=C grep -q '[^ -~]' <<<"$w"; }
# Agents follow a long AGENTS.md less well; it is loaded into every session.
short_agents_md() { [ "$(wc -l < AGENTS.md)" -le 200 ]; }
# Claude reads AGENTS.md only when there is no CLAUDE.md, so a CLAUDE.md may
# only be the import line that pulls AGENTS.md in.
no_own_claude_md() { [ ! -e CLAUDE.md ] || [ "$(tr -d '\r' < CLAUDE.md)" = "@AGENTS.md" ]; }
# `make -n` understands every way to declare a target (variables, includes).
has_targets() { local t; for t in "$@"; do make -n "$t" >/dev/null 2>&1 || return 1; done; }
# registered FILE EVENT MATCHER PATTERN...: each command PATTERN sits under
# EVENT with exactly MATCHER ("" = no matcher). A hook on another event or
# tool never runs where the guard is needed, so it does not count.
registered() {
  local f=$1 e=$2 m=$3; shift 3
  jq -e --arg e "$e" --arg m "$m" '$ARGS.positional as $want
    | [.hooks[$e][]? | select((.matcher // "") == $m) | .hooks[]?.command | strings] as $have
    | all($want[]; . as $w | any($have[]; test($w)))' --args "$@" < "$f"
}
has_hooks() {
  local h f=.claude/settings.json
  for h in lodestar-lib lint-file verify-before-stop protect-tests sensitive-gate guard-install approval-record feedback-check ci-checks; do [ -f ".claude/hooks/$h.sh" ] || return 1; done
  registered $f PreToolUse 'Edit|Write|MultiEdit|NotebookEdit' 'protect-tests\.sh' 'sensitive-gate\.sh' &&
    registered $f PreToolUse 'Bash|PowerShell' 'guard-install\.sh' &&
    registered $f PostToolUse 'Edit|Write|MultiEdit' 'lint-file\.sh' &&
    registered $f Stop '' 'verify-before-stop\.sh' 'feedback-check\.sh' &&
    registered $f UserPromptSubmit '' 'approval-record\.sh'
}
# Codex reads .codex/hooks.json and runs the same hooks through codex-hook.sh.
codex_checks='protect-tests sensitive-gate guard-install lint-file verify-before-stop feedback-check approval-record'
has_codex_hooks() {
  local h f=.codex/hooks.json
  for h in codex-hook.sh codex-patch.jq reminder-lib.sh codex-owner.jq; do [ -f ".claude/hooks/$h" ] || return 1; done
  registered $f PreToolUse apply_patch 'codex-hook\.sh protect-tests' 'codex-hook\.sh sensitive-gate' &&
    registered $f PreToolUse Bash 'codex-hook\.sh guard-install' &&
    registered $f PostToolUse apply_patch 'codex-hook\.sh lint-file' &&
    registered $f Stop '' 'codex-hook\.sh verify-before-stop' 'codex-hook\.sh feedback-check' &&
    registered $f UserPromptSubmit '' 'codex-hook\.sh approval-record'
}
# Codex runs project hooks only when the owner trusts the project and each
# hook (/hooks in Codex), kept in config.toml of its home, and a hook whose
# text changed needs trust again. Only Codex can tell whether a recorded hash
# is current, so ask it (app-server hooks/list); config.toml text alone is
# not proof. An orchestrator may start Codex with its own CODEX_HOME, so A4c
# names the home it asked. Fine when Codex is not installed. Not in --quiet
# (session start): it starts Codex.
codex_home=${CODEX_HOME:-$HOME/.codex}
codex_trust() {
  command -v codex >/dev/null || { echo "Codex not installed"; return 0; }
  local root out list bad to=
  command -v timeout >/dev/null && to="timeout 20"
  root=$(pwd -W 2>/dev/null || pwd)
  out=$(mktemp) || return 1
  # Keep stdin open until the answer arrives (closing it stops the server).
  { printf '%s\n' '{"id":1,"method":"initialize","params":{"clientInfo":{"name":"lodestar-doctor","version":"1"}}}' \
      '{"method":"initialized"}' \
      "$(jq -nc --arg d "$root" '{id:2,method:"hooks/list",params:{cwds:[$d]}}')"
    for _ in $(seq 1 75); do grep -q '"id":2' "$out" && break; sleep 0.2; done
  } | $to codex app-server > "$out" 2>/dev/null
  list=$(tr -d '\r' < "$out" | jq -c 'select(.id == 2) | .result.data' 2>/dev/null | head -n1)
  rm -f "$out"
  [ -n "$list" ] && [ "$list" != null ] || { echo "unverified: Codex did not answer hooks/list"; return 1; }
  # One line per required check: missing (project untrusted, or no such
  # hook), disabled, or the trust status Codex reports. Every copy of a check
  # counts: a trusted copy does not hide an untrusted one.
  bad=$(jq -r --arg c "$codex_checks" '[.[].hooks[]? | select(.source == "project")] as $h
    | ($c | split(" "))[] as $k
    | [$h[] | select((.command // "") | test("codex-hook\\.sh " + $k + "\\b"))] as $xs
    | if $xs == [] then "\($k): missing (project not trusted, or not registered)"
      elif any($xs[]; .enabled != true) then "\($k): disabled"
      else ([$xs[] | select(.trustStatus != "trusted") | .trustStatus] | first // empty) as $s | "\($k): \($s)" end' <<<"$list") ||
    { echo "unverified: unreadable hooks/list answer"; return 1; }
  [ -z "$bad" ] || { echo "${bad//$'\n'/; }"; return 1; }
}
env_ok() {
  git ls-files 2>/dev/null | grep -qE '(^|/)\.env$' && return 1
  # Every .env (root or a part such as backend/) needs a .env.example next to it.
  local f
  while IFS= read -r f; do
    [ -f "$(dirname "$f")/.env.example" ] || return 1
  done < <(find . -name .env -not -path '*/node_modules/*' -not -path './.git/*' -not -path '*/.venv/*')
}
ai_files() {
  local f; for f in invariants.md feedback-log.md tech-debt.md; do [ -f ".ai/$f" ] || return 1; done
  [ -d .ai/plans/active ] && [ -d .ai/plans/completed ]
}
template_current() {
  local src ver
  src=$(jq -j '.source // empty' .ai/enforcement.json) || return 1
  [ -f "$src/enforcement/VERSION" ] || return 0   # lodestar-harness not on this machine (e.g. CI)
  ver=$(jq -j '.version' .ai/enforcement.json)
  [ "$(printf '%s\n%s\n' "$ver" "$(tr -d '\r\n' < "$src/enforcement/VERSION")" | sort -V | tail -n1)" = "$ver" ]
}
# A fresh clone or a moved folder has no tools installed until `make setup`.
stack_env() {
  local s sub
  for s in $(jq -r '.stack // empty' .ai/enforcement.json); do
    sub=.; case "$s" in *=*) sub=${s#*=} ;; esac
    case "${s%%=*}" in
      python) [ -d "$sub/.venv" ] || return 1 ;;
      node-ts) [ -d "$sub/node_modules" ] || return 1 ;;
    esac
  done
}
# .ai/last-maintenance holds the date (YYYY-MM-DD) of the last maintenance run.
# ponytail: GNU date (Linux, Git Bash); macOS needs `gdate` if it ever matters.
maintenance_recent() {
  local d; d=$(tr -d '\r\n' < .ai/last-maintenance 2>/dev/null) || return 1
  [ $(( ($(date +%s) - $(date -d "$d" +%s)) / 86400 )) -le 14 ]
}
# A tag (2nd column) seen twice or more whose rows are not all "enforced".
# Tags starting with lodestar- (orca- before 2.0.0) are Lodestar's own mistakes, fixed upstream: skipped.
no_repeated_mistakes() {
  [ -f .ai/feedback-log.md ] || return 0
  ! awk -F'|' 'NR > 2 && NF > 5 {
      tag = $3; gsub(/^ +| +$/, "", tag); st = $6; gsub(/^ +| +$/, "", st)
      if (tag == "" || tag == "Tag" || tag ~ /^-+$/ || tag ~ /^(lodestar|orca)-/) next
      n[tag]++; if (st != "enforced") open[tag] = 1
    }
    END { for (t in n) if (n[t] >= 2 && open[t]) { print "   repeated: " t > "/dev/stderr"; bad = 1 }; exit !bad }' .ai/feedback-log.md
}
main_protected() {
  command -v gh >/dev/null || return 1
  gh api "repos/{owner}/{repo}/rules/branches/main" --jq 'length > 0' 2>/dev/null | grep -q true ||
    gh api "repos/{owner}/{repo}/branches/main/protection" >/dev/null 2>&1
}

[ $quiet = 1 ] || echo "Lodestar readiness check: $(pwd)"
check T1  "make is installed"  fail command -v make
check T2  "jq is installed"    fail command -v jq
check T3  "git repository"     fail git rev-parse --git-dir
check T4  "project path has no accented characters (Windows make cannot run there; rename the folder)" fail ascii_path

check A1  "AGENTS.md exists, no [placeholders]"          fail no_placeholders AGENTS.md
check A1b "no CLAUDE.md with its own text (Claude would skip AGENTS.md; move it there)" fail no_own_claude_md
check A2  ".ai/project.md filled in, no [placeholders]"  fail no_placeholders .ai/project.md
check A3  "Makefile has setup, lint, test, verify"       fail has_targets setup lint test verify
check A4  ".claude/settings.json registers the hooks"    fail has_hooks
check A4b ".codex/hooks.json registers the hooks (Codex)" fail has_codex_hooks
check A5  ".github/workflows/ci.yml exists"              fail test -f .github/workflows/ci.yml
check A6a ".gitignore exists"                            fail test -f .gitignore
check A6b "no committed .env; .env.example if .env used" fail env_ok
check A7  "CI runs a secret scan (gitleaks)"             fail grep -q gitleaks .github/workflows/ci.yml
check A7b "CI runs the PR checks (ci-checks.sh)"          fail grep -q ci-checks .github/workflows/ci.yml
check A8  ".ai/ invariants, feedback-log, tech-debt, plans/" fail ai_files
check A9  ".ai/enforcement.json records template version" fail jq -e .version .ai/enforcement.json
check A9b "template is current (else bootstrap.sh --upgrade)" warn template_current
check B5  "sensitive_paths declared in .ai/project.md"   fail grep -q '^sensitive_paths:' .ai/project.md
check B6  ".ai/invariants.md lists at least one invariant" fail grep -qE '^\| *INV-' .ai/invariants.md
check A10 "Makefile has format-check, lint-file, verify-full" warn has_targets format-check lint-file verify-full
check A11 "AGENTS.md under 200 lines (move detail to .claude/rules/ with paths:, or docs)" warn short_agents_md
check A12 "stack tools installed (.venv / node_modules), else run make setup" warn stack_env
check D1  "maintenance done in the last 14 days (workflows/maintenance.md)" warn maintenance_recent
check D2  "no repeated mistake without a machine rule (.ai/feedback-log.md)" warn no_repeated_mistakes
# A4c starts Codex and C1 calls the GitHub API: skip both in quiet mode
# (session-start hook) to stay fast.
if [ $quiet = 0 ]; then
  a4c="Codex trusts this project's hooks (checked $codex_home; run /hooks in a Codex that uses this home; again after .codex/hooks.json changes)"
  if why=$(codex_trust); then ok A4c "$a4c${why:+ - $why}"
  else warn A4c "$a4c - ${why:-unverified}"
  fi
fi
# A private repo on GitHub Free cannot lock main: say so, since the usual
# advice cannot be followed there. guard-install blocks agent pushes to main.
if [ $quiet = 0 ]; then
  if main_protected; then ok C1 "main branch requires PR + checks"
  elif gh api "repos/{owner}/{repo}/branches/main/protection" 2>&1 | grep -qi 'upgrade to github pro'; then
    warn C1 "main cannot be locked: private repo on GitHub Free (needs Pro). The guard-install hook blocks agent pushes to main; accepted unless the owner upgrades"
  else warn C1 "main branch requires PR + checks (else set it on GitHub)"
  fi
fi

if [ $fails -gt 0 ]; then
  echo "Not ready: $fails required item(s) failed."
  exit 1
fi
[ $quiet = 1 ] || echo "Ready: all required items pass."
exit 0
