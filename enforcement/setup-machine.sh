#!/usr/bin/env bash
# One-time (and safe to repeat) machine setup for lodestar-harness.
# Checks every item; installs or creates only what is missing; asks before
# installing software or changing an existing file (backups are kept).
# On a machine that is already set up it changes nothing and prints a health
# report.
#
# Usage (from Git Bash on Windows, or any shell on macOS/Linux):
#   bash <lodestar-harness>/enforcement/setup-machine.sh [--check] [--yes] [--no-selftest]
#     --check        report only, change nothing
#     --yes          answer yes to every question
#     --no-selftest  skip running enforcement/test.sh at the end
# Guide: enforcement/setup-guide.md
check=0 yes=0 selftest=1
for a in "$@"; do
  case "$a" in
    --check) check=1 ;; --yes) yes=1 ;; --no-selftest) selftest=0 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "Unknown option: $a" >&2; exit 2 ;;
  esac
done

here=$(cd "$(dirname "$0")" && pwd)
lodestar=$(cd "$here/.." && { pwd -W 2>/dev/null || pwd; })
home=${SETUP_HOME:-$HOME}
fails=0 warns=0
ok()   { echo "✅ $*"; }
warn() { echo "⚠️  $*"; warns=$((warns + 1)); }
bad()  { echo "❌ $*"; fails=$((fails + 1)); }
ask() {   # ask "question": returns 0 for yes
  [ $check = 1 ] && return 1
  [ $yes = 1 ] && return 0
  local ans; read -r -p "   $1 [y/N] " ans </dev/tty 2>/dev/null || return 1
  [[ $ans =~ ^[yY] ]]
}
windows=0; pwd -W >/dev/null 2>&1 && windows=1

echo "lodestar-harness machine setup: $lodestar"
echo

# 1. Where lodestar-harness lives.
if LC_ALL=C grep -q '[^ -~]' <<<"$lodestar"; then
  bad "lodestar-harness path has accented characters ($lodestar). make on Windows cannot run there; move the folder."
else
  ok "lodestar-harness path: $lodestar"
fi

# 2. Tools. make and jq may be installed but not on this terminal's PATH yet.
winget_bin() {   # add winget's make/jq folders to PATH for this run
  local base d
  [ $windows = 1 ] || return 0
  base="$(cygpath -u "${LOCALAPPDATA:-}" 2>/dev/null)/Microsoft/WinGet/Packages"
  for d in "$base"/jqlang.jq_* "$base"/ezwinports.make_*/bin; do
    [ -d "$d" ] && case ":$PATH:" in *":$d:"*) ;; *) PATH="$PATH:$d" ;; esac
  done
}
# WinGet's portable packages are not added to PATH by winget. A shell that
# runs this script can use winget_bin above, but new Windows terminals (and
# Orca's agent processes) need the paths in the user environment too. Put
# them before WindowsApps so `bash` resolves to Git Bash, not the WSL shim.
user_path() {   # user_path check|add WINDOWS_DIR (see user-path.ps1)
  LODESTAR_PATH_MODE=$1 LODESTAR_PATH_ENTRY=$2 powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$here/user-path.ps1")" >/dev/null 2>&1
}
add_user_path() {   # add_user_path WINDOWS_DIR LABEL
  local d=$1 label=$2
  [ $windows = 1 ] || return 0
  [ -d "$d" ] || return 0
  d=$(cygpath -w "$d")
  if user_path check "$d"; then
    ok "$label is on the Windows user PATH, ahead of WindowsApps"
  elif [ $check = 1 ]; then
    warn "$label is not on the Windows user PATH ahead of WindowsApps (restart Orca after adding it)."
  elif ask "Add $label to the Windows user PATH?"; then
    if user_path add "$d"; then
      ok "added $label to the Windows user PATH (restart Orca to use it)"
    else
      bad "could not add $label to the Windows user PATH"
    fi
  else
    warn "$label is not on the Windows user PATH ahead of WindowsApps. Direct Windows terminals will not find it."
  fi
}
need_tool() {   # need_tool NAME WINGET_ID HINT
  local name=$1 id=$2 hint=$3
  if command -v "$name" >/dev/null 2>&1; then ok "$name: $("$name" --version 2>&1 | head -n1)"; return; fi
  winget_bin
  if command -v "$name" >/dev/null 2>&1; then
    warn "$name is installed, but this terminal was opened before that. Open a new terminal (and restart Claude Code, and Orca if you use it)."
    return
  fi
  if [ $windows = 1 ] && command -v winget >/dev/null 2>&1 && ask "Install $name with winget ($id)?"; then
    winget install --exact --id "$id" --silent --accept-package-agreements --accept-source-agreements >/dev/null 2>&1
    winget_bin
    if command -v "$name" >/dev/null 2>&1; then ok "$name installed. Open a new terminal afterwards."
    else bad "$name: winget install did not work. Install it by hand: winget install --exact --id $id"; fi
  else
    bad "$name is missing. $hint"
  fi
}
command -v git >/dev/null 2>&1 && ok "git: $(git --version)" || bad "git is missing. Install Git for Windows: https://git-scm.com"
need_tool make ezwinports.make "Windows: winget install --exact --id ezwinports.make · macOS: brew install make · Linux: apt install make"
need_tool jq jqlang.jq "Windows: winget install --exact --id jqlang.jq · macOS: brew install jq · Linux: apt install jq"
# Keep Windows-native agent terminals independent of the shell that happened
# to run setup-machine.sh. Git's bin directory supplies bash.exe; the two
# WinGet package paths supply make.exe and jq.exe.
if [ $windows = 1 ]; then
  git_exec=$(cygpath -w "$(git --exec-path)" | tr '\\' /)
  git_bin=$(dirname "$(dirname "$(dirname "$git_exec")")")/bin
  add_user_path "$git_bin" "Git Bash"
  base="$(cygpath -u "${LOCALAPPDATA:-}" 2>/dev/null)/Microsoft/WinGet/Packages"
  for d in "$base"/ezwinports.make_*/bin; do [ -d "$d" ] && add_user_path "$d" "make"; done
  for d in "$base"/jqlang.jq_*; do [ -d "$d" ] && add_user_path "$d" "jq"; done
fi
command -v claude >/dev/null 2>&1 && ok "claude: $(claude --version 2>&1 | head -n1)" || warn "Claude Code is not installed or not on PATH."
command -v gh >/dev/null 2>&1 && ok "gh: $(gh --version | head -n1)" || warn "GitHub CLI (gh) is missing: needed for PRs and CI checks. https://cli.github.com"
command -v python >/dev/null 2>&1 && ok "python: $(python --version 2>&1)" || warn "python is missing: needed for Python projects."
command -v node >/dev/null 2>&1 && ok "node: $(node --version)" || warn "node is missing: needed for web (node-ts) projects."

# 3. Global instructions: the Lodestar bootstrap block, with this machine's
#    path, in ~/.claude/CLAUDE.md (Claude) and ~/.codex/AGENTS.md (Codex, when
#    installed). One template for both.
want=$(sed "s|{{LODESTAR_HOME}}|$lodestar|g" "$here/agents/claude/global/CLAUDE.md" | tr -d '\r')
# Markers before 2.0.0 said orca-workflow; they are found and rewritten.
begin='<!-- \(lodestar-harness\|orca-workflow\):begin'; end='<!-- \(lodestar-harness\|orca-workflow\):end -->'
global_block() {   # global_block TARGET
  local target=$1 have
  if [ ! -f "$target" ]; then
    if [ $check = 1 ]; then bad "$target is missing (run without --check to create it)."
    else mkdir -p "$(dirname "$target")"; printf '%s\n' "$want" > "$target"; ok "created $target"; fi
  elif grep -q "$begin" "$target"; then
    have=$(tr -d '\r' < "$target" | sed -n "/$begin/,/${end//\//\\/}/p")
    if [ "$have" = "$want" ]; then ok "$target has the current Lodestar block"
    elif ask "Update the Lodestar block in $target to the current version? (backup: ${target##*/}.bak)"; then
      cp "$target" "$target.bak"
      { tr -d '\r' < "$target.bak" | sed "/$begin/,\$d"; printf '%s\n' "$want"; tr -d '\r' < "$target.bak" | sed "1,/${end//\//\\/}/d"; } > "$target"
      ok "updated the Lodestar block in $target"
    else warn "$target has an older Lodestar block."; fi
  elif grep -q '^# Orca Workflow Bootstrap' "$target"; then   # oldest form, no markers
    if ask "$target has an old Lodestar section without markers. Replace it with the current version? (backup: ${target##*/}.bak)"; then
      cp "$target" "$target.bak"
      { tr -d '\r' < "$target.bak" | sed '/^# Orca Workflow Bootstrap/,$d'; printf '%s\n' "$want"; } > "$target"
      ok "replaced the old Lodestar section in $target"
    else warn "$target has an old Lodestar section (onboarding rule missing)."; fi
  elif ask "Add the Lodestar block to your existing $target? (your content stays; backup: ${target##*/}.bak)"; then
    cp "$target" "$target.bak"; printf '\n%s\n' "$want" >> "$target"; ok "added the Lodestar block to $target"
  else
    bad "$target has no Lodestar block, so sessions will not follow lodestar-harness."
  fi
}
global_block "$home/.claude/CLAUDE.md"
# Codex reads AGENTS.md from its home: ~/.codex, or CODEX_HOME when set (an
# orchestrator such as Orca gives Codex a home of its own). Write both.
codex_homes=("$home/.codex")
if [ -n "${CODEX_HOME:-}" ]; then
  active=$(cygpath -u "$CODEX_HOME" 2>/dev/null || printf '%s' "${CODEX_HOME//\\//}")
  [ "$active" != "$(cygpath -u "$home/.codex" 2>/dev/null || printf '%s' "$home/.codex")" ] && codex_homes+=("$active")
fi
for d in "${codex_homes[@]}"; do
  if command -v codex >/dev/null 2>&1 || [ -d "$d" ]; then global_block "$d/AGENTS.md"; fi
done

# 4. Global reminder hooks (SessionStart + per-prompt gate).
settings=${CLAUDE_SETTINGS:-$home/.claude/settings.json}
if [ -f "$settings" ] && command -v jq >/dev/null 2>&1 &&
   jq -e '([.hooks.SessionStart[]?.hooks[]?.command] | any(test("check-readiness"))) and
          ([.hooks.UserPromptSubmit[]?.hooks[]?.command] | any(test("check-readiness.*--prompt")))' "$settings" >/dev/null 2>&1; then
  ok "global reminder hooks are installed"
elif [ $check = 1 ]; then
  bad "global reminder hooks are missing (run without --check to install)."
elif command -v jq >/dev/null 2>&1; then
  CLAUDE_SETTINGS=$settings bash "$here/agents/claude/global/install.sh" >/dev/null && ok "installed the global reminder hooks"
else
  bad "global reminder hooks need jq; install jq and run this again."
fi
# Codex: the same reminders in each Codex home's hooks.json. Installing is
# not trusting: the owner reviews them in Codex (/hooks), once per home.
for d in "${codex_homes[@]}"; do
  command -v codex >/dev/null 2>&1 || [ -d "$d" ] || continue
  if ! command -v jq >/dev/null 2>&1; then bad "Codex reminder hooks in $d need jq."
  elif CODEX_HOME=$d bash "$here/agents/codex/global/install.sh" --check >/dev/null 2>&1; then ok "Codex reminder hooks are installed in $d"
  elif [ $check = 1 ]; then bad "Codex reminder hooks are missing in $d (run without --check to install)."
  elif msg=$(CODEX_HOME=$d bash "$here/agents/codex/global/install.sh" 2>&1); then ok "installed the Codex reminder hooks in $d (trust them in Codex: /hooks)"
  else bad "Codex reminder hooks in $d: $msg"; fi
done

# 5. Self-test: proves hooks, bootstrap and doctor work on this machine.
if [ $selftest = 1 ]; then
  if command -v make >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    echo "   running the self-test (1-2 minutes)..."
    out=$(bash "$here/test.sh" 2>/dev/null); n=$(grep -c '^PASS' <<<"$out")
    if grep -q 'All tests passed' <<<"$out"; then ok "self-test: $n checks passed"
    else bad "self-test failed: $(grep '^FAIL' <<<"$out" | head -n3 | tr '\n' ' ')"; fi
  else
    warn "self-test skipped: needs make and jq."
  fi
fi

echo
if [ $fails -gt 0 ]; then
  echo "Not ready: $fails problem(s), $warns warning(s). Fix the ❌ items and run this again."
  exit 1
fi
echo "Ready: $warns warning(s). If anything was installed, open a new terminal and restart Claude Code (and Orca, if you use it)."
