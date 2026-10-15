#!/usr/bin/env bash
# Self-test for bootstrap.sh, doctor.sh and the Claude hooks.
# Runs in a temp dir, needs no network. Usage: bash enforcement/test.sh
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
# setup-machine.sh writes the Windows user PATH. Every run here gets a scratch
# registry key instead (user-path.ps1), so the self-test never writes the real one.
regkey="HKCU:\\Software\\LodestarHarnessTest-$$"
pshell() { powershell.exe -NoProfile -Command "$1" 2>/dev/null | tr -d '\r'; }
reg_set() { LK=$1 LT=$2 LV=$3 pshell 'New-Item -Path $env:LK -Force | Out-Null; Set-ItemProperty -LiteralPath $env:LK -Name Path -Value $env:LV -Type $env:LT'; }
reg_get() { LK=$1 pshell '$k = Get-Item -LiteralPath $env:LK; $k.GetValueKind("Path").ToString() + " " + $k.GetValue("Path", "", "DoNotExpandEnvironmentNames")'; }
if command -v powershell.exe >/dev/null; then
  export LODESTAR_PATH_KEY=$regkey
  real_path=$(reg_get 'HKCU:\Environment'); reg_set "$regkey" ExpandString 'C:\Scratch'
fi
trap 'rm -rf "$tmp"; command -v powershell.exe >/dev/null && LK=$regkey pshell "Remove-Item -LiteralPath \$env:LK -Recurse -Force"' EXIT
failed=0
pass() { echo "PASS $1"; }
bad()  { echo "FAIL $1"; failed=1; }
t() { local name=$1; shift; if "$@" >/dev/null; then pass "$name"; else bad "$name [$*]"; fi; }
snapshot() { (cd "$1" && find . -path ./.git -prune -o -type f -print | sort | xargs cksum); }
fill() { # replace template placeholder lines, as onboarding would
  sed -i -E 's/^([[:space:]]*([*-][[:space:]]*)?)\[[^]]+\][[:space:]]*$/\1filled/' "$@"
}

# 1. Empty project: doctor fails and names what is missing.
p=$tmp/empty; mkdir -p "$p"; git -C "$p" init -q
out=$(bash "$here/agents/claude/hooks/doctor.sh" "$p"); rc=$?
t "doctor fails on empty project" [ $rc = 1 ]
t "doctor lists missing Makefile" grep -q '❌ A3' <<<"$out"
mkdir "$tmp/nobin"
out=$(PATH="$tmp/nobin" "$BASH" "$here/agents/claude/hooks/doctor.sh" "$p"); rc=$?
t "doctor stops with exit 2 under a bash without grep" [ $rc = 2 ]
t "doctor names the wrong bash and checks nothing" bash -c 'grep -q "wrong bash" <<<"$1" && ! grep -q "❌" <<<"$1"' _ "$out"

# 2. Bootstrap, then a second run changes nothing.
p=$tmp/py; mkdir -p "$p"; git -C "$p" init -q
bash "$here/bootstrap.sh" "$p" --stack python >/dev/null
before=$(snapshot "$p")
out=$(bash "$here/bootstrap.sh" "$p" --stack python)
t "second bootstrap run reports no changes" bash -c '! grep -qE "created|updated|merged|wrote" <<<"$1"' _ "$out"
t "second bootstrap run changes no files" [ "$before" = "$(snapshot "$p")" ]

# 3. Doctor fails while placeholders remain, passes once filled.
bash "$p/.claude/hooks/doctor.sh" "$p" >/dev/null
t "doctor fails with placeholders" [ $? = 1 ]
fill "$p/AGENTS.md" "$p/.ai/project.md"
echo "| INV-01 | Sample invariant | High | test | enforced |" >> "$p/.ai/invariants.md"
out=$(bash "$p/.claude/hooks/doctor.sh" "$p"); rc=$?
t "doctor passes tier A after filling" [ $rc = 0 ] || echo "$out"
t "doctor runs every check (A10 present)" grep -q 'A10 ' <<<"$out"
t "short AGENTS.md passes A11" grep -qE '✅ A11 ' <<<"$out"
cp "$p/AGENTS.md" "$tmp/agents.bak"; seq 201 >> "$p/AGENTS.md"
out=$(bash "$p/.claude/hooks/doctor.sh" "$p"); rc=$?
t "doctor warns on a long AGENTS.md (A11), still ready" bash -c '[ $1 = 0 ] && grep -qE "⚠️ +A11 " <<<"$2"' _ "$rc" "$out"
cp "$tmp/agents.bak" "$p/AGENTS.md"
mkdir -p "$p/backend"; echo X=1 > "$p/backend/.env"
bash "$p/.claude/hooks/doctor.sh" "$p" >/dev/null
t "doctor fails on a nested .env without .env.example" [ $? = 1 ]
echo X= > "$p/backend/.env.example"
bash "$p/.claude/hooks/doctor.sh" "$p" >/dev/null
t "doctor accepts a nested .env with .env.example" [ $? = 0 ]

# 4. Existing settings.json keeps its config and gains the hooks.
p=$tmp/existing; mkdir -p "$p/.claude"
echo '{"permissions":{"allow":["Bash(ls)"]},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo mine"}]}]}}' > "$p/.claude/settings.json"
bash "$here/bootstrap.sh" "$p" --stack node-ts >/dev/null
s=$p/.claude/settings.json
t "merge keeps permissions" jq -e '.permissions.allow == ["Bash(ls)"]' "$s"
t "merge keeps existing Stop hook" jq -e '[.hooks.Stop[].hooks[].command] | index("echo mine") != null' "$s"
t "merge adds verify hook" jq -e '[.hooks.Stop[].hooks[].command] | any(test("verify-before-stop"))' "$s"
t "merge adds lint hook" jq -e '.hooks.PostToolUse | length == 1' "$s"
bash "$here/bootstrap.sh" "$p" --stack node-ts >/dev/null
t "second merge adds no duplicates" jq -e '.hooks.Stop | length == 3' "$s"

p2=$tmp/ignored; mkdir -p "$p2"; git -C "$p2" init -q; printf '.claude/*\n' > "$p2/.gitignore"
out=$(bash "$here/bootstrap.sh" "$p2" --stack python)
t "bootstrap warns when .gitignore hides hooks" grep -q 'WARNING: .gitignore hides' <<<"$out"

# A later template adds a hook to an existing group: upgrade must register it.
p3=$tmp/grouped; mkdir -p "$p3/.claude"
echo '{"hooks":{"PreToolUse":[{"matcher":"Edit|Write|MultiEdit|NotebookEdit","hooks":[{"type":"command","command":"bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/protect-tests.sh\""}]}]}}' > "$p3/.claude/settings.json"
bash "$here/bootstrap.sh" "$p3" --stack python --upgrade >/dev/null
t "upgrade adds a new hook next to an old one in the same group" jq -e '[.hooks.PreToolUse[].hooks[].command] | (map(select(test("sensitive-gate"))) | length == 1) and (map(select(test("protect-tests"))) | length == 1)' "$p3/.claude/settings.json"
bash "$here/bootstrap.sh" "$p3" --stack python --upgrade >/dev/null
t "second upgrade adds nothing more" jq -e '[.hooks.PreToolUse[].hooks[].command] | length == 3' "$p3/.claude/settings.json"

# 5. --upgrade restores managed files, never touches project files.
echo "# edited" >> "$p/.claude/hooks/doctor.sh"
echo "# edited" >> "$p/Makefile"
echo "# 1.x" > "$p/.claude/hooks/orca-lib.sh"
bash "$here/bootstrap.sh" "$p" --stack node-ts --upgrade >/dev/null
t "upgrade from 1.x removes the old orca-lib.sh" bash -c '[ ! -e "$1/orca-lib.sh" ] && [ -f "$1/lodestar-lib.sh" ]' _ "$p/.claude/hooks"
t "upgrade restores managed file" cmp -s "$here/agents/claude/hooks/doctor.sh" "$p/.claude/hooks/doctor.sh"
t "upgrade keeps project file" grep -q '# edited' "$p/Makefile"

# 6. Hooks, with a stub Makefile: files containing BAD fail lint; verify fails on demand.
p=$tmp/hooks; mkdir -p "$p"
printf 'lint-file:\n\t@! grep -q BAD "$(FILE)" || { echo "BAD found in $(FILE)"; exit 1; }\nverify:\n\t@[ ! -f fail ] || { echo "tests fail"; exit 1; }\n' > "$p/Makefile"
echo ok > "$p/good.txt"; echo BAD > "$p/bad.txt"; echo BAD > "$tmp/outside.txt"
# Claude Code sends native paths (C:/... on Windows).
native() { cygpath -m "$1" 2>/dev/null || echo "$1"; }
# Here-strings, not pipes: a hook that exits early would SIGPIPE the writer.
lint() { CLAUDE_PROJECT_DIR=$p bash "$here/agents/claude/hooks/lint-file.sh" 2>/dev/null   <<<"{\"tool_input\":{\"file_path\":\"$(native "$1")\"}}"; }
stop() { CLAUDE_PROJECT_DIR=$p bash "$here/agents/claude/hooks/verify-before-stop.sh" 2>/dev/null   <<<"{\"stop_hook_active\":$1}"; }
lint "$p/good.txt"; t "lint hook passes clean file" [ $? = 0 ]
lint "$p/bad.txt"; t "lint hook blocks bad file (exit 2)" [ $? = 2 ]
lint "$tmp/outside.txt"; t "lint hook ignores files outside project" [ $? = 0 ]
LODESTAR_SKIP_HOOKS=1 lint "$p/bad.txt"; t "LODESTAR_SKIP_HOOKS=1 disables lint hook" [ $? = 0 ]
# A long lint dump is capped at 30 lines plus a count of the rest.
p2=$tmp/longlint; mkdir -p "$p2"; echo x > "$p2/a.txt"
printf 'lint-file:\n\t@seq 1 45; exit 1\n' > "$p2/Makefile"
out=$(CLAUDE_PROJECT_DIR=$p2 bash "$here/agents/claude/hooks/lint-file.sh" 2>&1 >/dev/null <<<"{\"tool_input\":{\"file_path\":\"$(native "$p2/a.txt")\"}}")
t "lint hook caps output at 30 lines" bash -c 'grep -qx 30 <<<"$1" && ! grep -qx 31 <<<"$1" && grep -qE "^\.\.\. [0-9]+ more lines$" <<<"$1"' _ "$out"
stop false; t "stop hook passes when verify passes" [ $? = 0 ]
touch "$p/fail"
stop false; t "stop hook blocks when verify fails (exit 2)" [ $? = 2 ]
stop true; t "stop hook lets go on second attempt" [ $? = 0 ]
stop false; t "stop hook without git holds every failed stop" [ $? = 2 ]

# 6b. Stop hook holds once per state: a later stop with the same files and the
#     same failure ends (CI stays the gate); any change, or another failure,
#     holds again. Digits in the output (timings) do not count as a change.
p=$tmp/rehold; mkdir -p "$p"; git -C "$p" init -q
printf 'verify:\n\t@[ -z "$$MSG" ] || { echo "$$MSG"; echo "took 0.$$N s"; exit 1; }\n' > "$p/Makefile"
echo a > "$p/a.txt"; git -C "$p" add -A; git -C "$p" -c user.name=t -c user.email=t@t commit -qm init
hold() { N=$RANDOM MSG=$1 CLAUDE_PROJECT_DIR=$p bash "$here/agents/claude/hooks/verify-before-stop.sh" 2>/dev/null <<<'{"stop_hook_active":false}'; }
hold "test_a failed"; t "stop hook holds the first failed stop" [ $? = 2 ]
hold "test_a failed"; t "stop hook lets a stop end when nothing changed" [ $? = 0 ]
hold "test_a failed"; t "stop hook keeps letting it end while nothing changes" [ $? = 0 ]
hold "test_b failed"; t "stop hook holds a different failure" [ $? = 2 ]
echo b > "$p/new.txt"
hold "test_b failed"; t "stop hook holds after a new untracked file" [ $? = 2 ]
hold "test_b failed"; t "stop hook lets go again once that state was held" [ $? = 0 ]
echo changed > "$p/a.txt"
hold "test_b failed"; t "stop hook holds after a tracked file changes" [ $? = 2 ]
git -C "$p" add -A
hold "test_b failed"; t "stop hook: staging alone is no change" [ $? = 0 ]
hold ""; t "stop hook passes when verify passes" [ $? = 0 ]
hold "test_b failed"; t "stop hook holds again after a pass" [ $? = 2 ]
rm "$p/a.txt"
hold "test_b failed"; t "stop hook holds after a file is deleted" [ $? = 2 ]
hold "test_b failed"; t "stop hook lets go once the deletion was held" [ $? = 0 ]
# The project may be a subfolder of the repo (git prints paths from the root).
q=$tmp/monorepo; mkdir -p "$q/sub"; git -C "$q" init -q; cp "$p/Makefile" "$q/sub/"
echo a > "$q/sub/code.txt"; git -C "$q" add -A; git -C "$q" -c user.name=t -c user.email=t@t commit -qm init
holdq() { N=$RANDOM MSG=x CLAUDE_PROJECT_DIR=$q/sub bash "$here/agents/claude/hooks/verify-before-stop.sh" 2>/dev/null <<<'{"stop_hook_active":false}'; }
holdq; holdq; t "stop hook in a subfolder project lets go when nothing changed" [ $? = 0 ]
echo b > "$q/sub/code.txt"
holdq; t "stop hook in a subfolder project holds after a tracked edit" [ $? = 2 ]

# 7. Global reminder hook: speaks only in projects that are not ready; never blocks.
g=$here/agents/claude/global/check-readiness.sh
remind() { CLAUDE_PROJECT_DIR=$1 bash "$g" </dev/null; }
mkdir -p "$tmp/nogit"
out=$(remind "$tmp/nogit"); rc=$?
t "global hook silent outside git" bash -c '[ $1 = 0 ] && [ -z "$2" ]' _ "$rc" "$out"
out=$(remind "$tmp/empty"); rc=$?
t "global hook reminds un-onboarded project" bash -c '[ $1 = 0 ] && grep -q "not onboarded" <<<"$2"' _ "$rc" "$out"
out=$(remind "$tmp/py"); rc=$?
t "global hook says run make setup when .venv is missing" bash -c '[ $1 = 0 ] && grep -q "A12.*make setup" <<<"$2"' _ "$rc" "$out"
mkdir "$tmp/py/.venv"
out=$(remind "$tmp/py"); rc=$?
t "global hook silent in ready project" bash -c '[ $1 = 0 ] && [ -z "$2" ]' _ "$rc" "$out"
t "bootstrap gitignores the handoff file" bash -c 'cd "$1" && git check-ignore -q .ai/handoff.md' _ "$tmp/py"
echo "next: x" > "$tmp/py/.ai/handoff.md"
out=$(remind "$tmp/py")
t "global hook tells a new session to read the handoff" grep -q "read .ai/handoff.md" <<<"$out"
out=$(CLAUDE_PROJECT_DIR=$tmp/py bash "$g" --prompt </dev/null)
t "per-prompt gate does not repeat the handoff" bash -c '! grep -q handoff <<<"$1"' _ "$out"
out=$(bash "$here/bootstrap.sh" "$tmp/py" --stack python)
t "bootstrap does not warn about the ignored handoff" bash -c '! grep -q WARNING <<<"$1"' _ "$out"
p=$tmp/nonl; mkdir -p "$p"; git -C "$p" init -q; printf 'dist' > "$p/.gitignore"
bash "$here/bootstrap.sh" "$p" --stack python >/dev/null
t "bootstrap keeps the last .gitignore line when it has no newline" bash -c 'cd "$1" && git check-ignore -q dist && git check-ignore -q .ai/handoff.md' _ "$p"
mkdir -p "$tmp/self/enforcement" "$tmp/self/.ai"; git -C "$tmp/self" init -q
touch "$tmp/self/enforcement/bootstrap.sh"; echo x > "$tmp/self/.ai/handoff.md"
out=$(remind "$tmp/self")
t "global hook points to the handoff in lodestar-harness too" grep -q "read .ai/handoff.md" <<<"$out"
rm "$tmp/py/.ai/handoff.md"
rm "$tmp/py/.ai/invariants.md"
out=$(remind "$tmp/py"); rc=$?
t "global hook lists missing items" bash -c '[ $1 = 0 ] && grep -q "A8" <<<"$2"' _ "$rc" "$out"

s=$tmp/global-settings.json
echo '{"model":"x","hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"other"}]}]}}' > "$s"
CLAUDE_SETTINGS=$s bash "$here/agents/claude/global/install.sh" >/dev/null
CLAUDE_SETTINGS=$s bash "$here/agents/claude/global/install.sh" >/dev/null
t "global install keeps other settings and hooks" jq -e '.model == "x" and .hooks.SessionStart[0].hooks[0].command == "other"' "$s"
t "global install adds the hook once" jq -e '[.hooks.SessionStart[].hooks[].command | select(test("check-readiness"))] | length == 1' "$s"
t "global install adds the per-prompt gate once" jq -e '[.hooks.UserPromptSubmit[].hooks[].command | select(test("check-readiness.*--prompt"))] | length == 1' "$s"
jq '.hooks.SessionStart += [{hooks: [{type: "command", command: "bash \"/old/place/check-readiness.sh\""}]}]' "$s" > "$s.tmp" && mv "$s.tmp" "$s"
CLAUDE_SETTINGS=$s bash "$here/agents/claude/global/install.sh" >/dev/null
t "global install drops the hook left at an old folder path" jq -e '([.hooks.SessionStart[].hooks[].command] | index("bash \"/old/place/check-readiness.sh\"") == null) and .hooks.SessionStart[0].hooks[0].command == "other"' "$s"
out=$(CLAUDE_PROJECT_DIR=$tmp/empty bash "$g" --prompt </dev/null)
t "per-prompt gate tells the agent not to start" grep -q "LODESTAR GATE" <<<"$out"
cp "$here/project/.ai/invariants.md" "$tmp/py/.ai/"; echo "| INV-01 | x | High | test | enforced |" >> "$tmp/py/.ai/invariants.md"
out=$(CLAUDE_PROJECT_DIR=$tmp/py bash "$g" --prompt </dev/null)
t "per-prompt gate silent in a ready project" [ -z "$out" ]
t "global install adds the context nudge once" jq -e '[.hooks.PostToolUse[] | select(.matcher == "*") | .hooks[].command | select(test("context-nudge"))] | length == 1' "$s"
jq '.hooks.PostToolUse += [{matcher: "*", hooks: [{type: "command", command: "bash \"/old/place/context-nudge.sh\""}]}]' "$s" > "$s.tmp" && mv "$s.tmp" "$s"
CLAUDE_SETTINGS=$s bash "$here/agents/claude/global/install.sh" >/dev/null
t "global install drops the context nudge left at an old folder path" jq -e '[.hooks.PostToolUse[].hooks[].command | select(test("context-nudge"))] | length == 1 and (index("bash \"/old/place/context-nudge.sh\"") == null)' "$s"

# 7b. Context nudge: speaks once per 100k step past the threshold; never blocks work.
tr=$tmp/nudge.jsonl; : > "$tr"
used() { jq -nc --argjson r "$1" '{type:"assistant",message:{usage:{input_tokens:5,cache_read_input_tokens:$r,cache_creation_input_tokens:1000}}}' >> "$tr"; }
nudge() { LODESTAR_STATE_DIR=$tmp/nudge-state bash "$here/agents/claude/global/context-nudge.sh" \
  <<<"{\"transcript_path\":\"$(native "${1:-$tr}")\",\"session_id\":\"s1\"}"; }
used 300000; used 149000
out=$(nudge 2>&1); rc=$?
t "context nudge silent below the threshold (last usage counts)" bash -c '[ $1 = 0 ] && [ -z "$2" ]' _ "$rc" "$out"
used 209000
out=$(nudge 2>&1); rc=$?
t "context nudge speaks past the threshold" bash -c '[ $1 = 2 ] && grep -q "handoff.md" <<<"$2" && grep -q "/clear" <<<"$2"' _ "$rc" "$out"
used 250000
out=$(nudge 2>&1); rc=$?
t "context nudge speaks once per step" bash -c '[ $1 = 0 ] && [ -z "$2" ]' _ "$rc" "$out"
used 310000
nudge 2>/dev/null; t "context nudge speaks again at the next step" [ $? = 2 ]
nudge "$tmp/missing.jsonl" 2>/dev/null; t "context nudge silent without a transcript" [ $? = 0 ]
used 900000
LODESTAR_SKIP_HOOKS=1 nudge 2>/dev/null; t "context nudge off with LODESTAR_SKIP_HOOKS" [ $? = 0 ]

# 8. Several parts: root Makefile runs targets in each part, routes lint-file.
p=$tmp/multi; mkdir -p "$p"
bash "$here/bootstrap.sh" "$p" --stack python=backend --stack node-ts=frontend >/dev/null
t "multi: part Makefiles created" test -f "$p/backend/Makefile" -a -f "$p/frontend/Makefile"
p2=$tmp/multijoined; mkdir -p "$p2"
bash "$here/bootstrap.sh" "$p2" --stack "python=backend node-ts=frontend" >/dev/null
t "multi: space-joined --stack (as enforcement.json records it) works" bash -c 'test -f "$1/backend/Makefile" -a -f "$1/frontend/Makefile" && ! ls "$1" | grep -q " "' _ "$p2"
t "multi: root has contract targets" bash -c 'cd "$1" && make -n setup lint test verify' _ "$p"
# Replace the part Makefiles with stubs so no real tools are needed.
printf 'verify:\n\t@echo backend-verify\nlint-file:\n\t@echo "backend-lint $(FILE)"\n' > "$p/backend/Makefile"
printf 'verify:\n\t@echo frontend-verify\ntypecheck:\n\t@echo frontend-typecheck\nlint-file:\n\t@echo "frontend-lint $(FILE)"\n' > "$p/frontend/Makefile"
out=$(make -s -C "$p" verify 2>&1)
t "multi: verify runs in every part" bash -c 'grep -q backend-verify <<<"$1" && grep -q frontend-verify <<<"$1"' _ "$out"
out=$(make -s -C "$p" typecheck 2>&1); rc=$?
t "multi: part without a target is skipped" bash -c '[ $1 = 0 ] && [ "$2" = frontend-typecheck ]' _ "$rc" "$out"
out=$(make -s -C "$p" lint-file FILE='C:\x\proj\frontend\src\a.js' 2>&1)
t "multi: lint-file goes to the owning part" grep -q '^frontend-lint' <<<"$out"
printf 'test-mutation:\n\t@echo "backend-test-mutation $(FILES)"\n' >> "$p/backend/Makefile"
out=$(make -s -C "$p" test-mutation FILES='backend/app/a.py frontend/src/b.ts backend/app/c.py' 2>&1); rc=$?
t "multi: test-mutation gets each part its own files; a part without it is skipped" bash -c '[ $1 = 0 ] && [ "$2" = "backend-test-mutation app/a.py app/c.py" ]' _ "$rc" "$out"
printf 'verify:\n\t@exit 1\n' > "$p/backend/Makefile"
make -s -C "$p" verify >/dev/null 2>&1
t "multi: a failing part fails root verify" [ $? != 0 ]
bash "$here/bootstrap.sh" "$p" --stack python --stack node-ts >/dev/null 2>&1
t "multi: several stacks without subdirs is refused" [ $? = 1 ]

# 9. PR checks (ci-checks.sh): sensitive paths need tests, suppressions need a
#    reason, locked tests stay unchanged.
p=$tmp/pr; mkdir -p "$p/app" "$p/tests" "$p/.ai"; cd "$p"
g() { git -c user.name=t -c user.email=t@t -c core.autocrlf=false "$@"; }
g init -q -b main
printf 'sensitive_paths:\n  - app/money.py\n  - app/db/\n' > .ai/project.md
echo 'x = 1' > app/money.py; echo 'y = 1' > app/ui.py; echo 'def test_a(): pass' > tests/test_a.py
mkdir -p .claude/hooks; cp "$here/agents/claude/hooks/lodestar-lib.sh" .claude/hooks/
g add -A; g commit -qm base
check() { bash "$here/agents/claude/hooks/ci-checks.sh" main >/dev/null 2>&1; }
# stamp FILE: the review names the criteria it covers, as they are now.
stamp() { local h; h=$(. "$here/agents/claude/hooks/lodestar-lib.sh"; criteria_hash < "$1")
  sed -i -e '/^- Reviewed criteria:/d' -e "s/^- No findings\.\$/&\n- Reviewed criteria: $h/" "$1"; }
# mkplan NAME CRITERION...: a plan with acceptance criteria.
mkplan() { local n=$1; shift; mkdir -p .ai/plans/active
  { echo "# Plan: $n"; echo; echo "## Acceptance criteria"; printf -- '- [ ] %s\n' "$@"; echo; echo "## Criteria review"; echo "- No findings."; echo; echo "## Steps"; } > ".ai/plans/active/$n.md"; stamp ".ai/plans/active/$n.md"; }
# approve: the owner types "duyệt" (runs the real approval hook).
approve() { CLAUDE_PROJECT_DIR=$PWD bash "$here/agents/claude/hooks/approval-record.sh" <<<'{"prompt":"Duyệt nguyên bản."}' >/dev/null; }
newbranch() { g checkout -q main; g checkout -q -B "$1"; }
newbranch b1; echo 'x = 2' > app/money.py; g commit -qam "change money"
check; t "PR: sensitive change without test fails" [ $? = 1 ]
g commit -q --allow-empty -m "note" -m "No-Test-Reason: typo only"
check; t "PR: No-Test-Reason on an unrelated commit does not excuse others" [ $? = 1 ]
newbranch b1r; echo 'x = 2' > app/money.py; g commit -qam "typo in money comment" -m "No-Test-Reason: typo only"
check; t "PR: No-Test-Reason on the commit itself lets it pass" [ $? = 0 ]
newbranch b2; echo 'x = 3' > app/money.py; echo 'def test_b(): pass' >> tests/test_a.py; g commit -qam "money + test"
check; t "PR: sensitive change with test but no plan fails" [ $? = 1 ]
mkplan money "money is exact"; g add -A; g commit -qm "plan"
check; t "PR: plan the owner never approved fails" [ $? = 1 ]
printf 'Approved by the owner: 2026-09-29\n' >> .ai/plans/active/money.md; g commit -qam "agent writes its own approval line"
check; t "PR: an approval line written by the agent does not count" [ $? = 1 ]
approve; g add -A; g commit -qm "owner approved"
check; t "PR: sensitive change with test and owner-approved plan passes" [ $? = 0 ]
newbranch b3; echo 'y = 2' > app/ui.py; g commit -qam "ui only"
check; t "PR: non-sensitive change passes" [ $? = 0 ]
newbranch b4; echo 'import os  # noqa: F401' >> app/ui.py; g commit -qam "noqa"
check; t "PR: suppression without reason fails" [ $? = 1 ]
newbranch b5; echo 'import os  # noqa: F401 -- used by plugins' >> app/ui.py; echo 'Use `# noqa` rarely.' > README.md; g add -A; g commit -qm "noqa with reason"
check; t "PR: suppression with reason passes; .md ignored" [ $? = 0 ]
newbranch b6x; echo 'def test_lock(): assert False' > tests/test_lock.py; echo tests/test_lock.py > .ai/test-lock
g add -A; g commit -qm "tests" -m "Tests-First: no plan"
check; t "PR: Tests-First commit without an approved plan fails" [ $? = 1 ]
newbranch b6; mkplan lock-demo "lock demo works"; approve
echo 'def test_lock(): assert False' > tests/test_lock.py; echo tests/test_lock.py > .ai/test-lock
g add -A; g commit -qm "tests" -m "Tests-First: lock demo"
echo 'z = 1' > app/ui.py; g commit -qam "implement"
check; t "PR: code after a valid tests-first round passes" [ $? = 0 ]
g branch -q b6base
echo 'def test_lock(): assert True' > tests/test_lock.py; g commit -qam "weaken test"
check; t "PR: builder editing a locked test fails" [ $? = 1 ]
g checkout -q -B b6l b6base; echo 'def test_lock(): assert True' > tests/test_lock.py; g commit -qam "weaken" -m "Tests-First: sneaky"
check; t "PR: a Tests-First trailer without approved criteria cannot relock" [ $? = 1 ]
g checkout -q -B b6r b6base; mkplan lock-demo "lock demo works" "future dates allowed"; approve
echo 'def test_lock(): assert 1 == 1' > tests/test_lock.py; g add -A; g commit -qm "new round" -m "Tests-First: lock demo v2"
out=$(bash "$here/agents/claude/hooks/ci-checks.sh" main 2>&1); rc=$?
t "PR: a new round with owner-approved changed criteria passes" [ $rc = 0 ]
t "PR: summary shows the criteria in English with approval" bash -c 'grep -q "Acceptance criteria" <<<"$1" && grep -q "The owner approved exactly" <<<"$1" && grep -q "future dates allowed" <<<"$1"' _ "$out"
# Relocking: only fresh approval for a plan changed by the revising round
# authorizes edits; progress-only rounds may add tests and retain older locks.
relock_branch() { g checkout -q -B "$1" "${2:-b6base}"; }
progress_round() {
  echo "- Progress: $1" >> .ai/plans/active/lock-demo.md
  g add -A; g commit -qm "$1" -m "Tests-First: lock demo"
}
add_locked_test() {
  echo 'def test_next(): assert False' > tests/test_next.py
  echo tests/test_next.py >> .ai/test-lock
}
weaken_locked_test() { echo 'def test_lock(): assert True' > tests/test_lock.py; }
for action in modify delete rename; do
  relock_branch "relock-$action"
  case $action in
    modify) weaken_locked_test ;;
    delete) g rm -q tests/test_lock.py ;;
    rename) g mv tests/test_lock.py tests/test_renamed.py ;;
  esac
  progress_round "progress-only $action"
  check; t "PR relock C1: progress-only $action of an old locked test fails" [ $? = 1 ]
done
relock_branch relock-add; add_locked_test; progress_round 'append new tests'
check; t "PR relock C2: add-only round under unchanged criteria passes" [ $? = 0 ]
g branch -q relock-added
weaken_locked_test; progress_round 'rewrite after add-only round'
check; t "PR relock C1: an add-only round cannot authorize an old test rewrite" [ $? = 1 ]

relock_branch relock-between
mkplan lock-demo "lock demo works" "future dates allowed"; approve
g add -A; g commit -qm 'criteria and approval between rounds'
weaken_locked_test; progress_round 'apply criteria approved between rounds'
check; t "PR relock C3: criteria and approval between rounds permit revision" [ $? = 0 ]
relock_branch relock-new-plan
mkplan revised "a genuinely new criterion"; approve; weaken_locked_test
progress_round 'fresh criteria on a new changed plan'
check; t "PR relock C3: a new changed plan with fresh approved criteria permits revision" [ $? = 0 ]
relock_branch relock-unrelated
mkplan other "other fresh criterion"; approve
g add -A; g commit -qm 'approve another plan between rounds'
weaken_locked_test; progress_round 'only old plan progress changes'
check; t "PR relock C3: fresh approval for an unchanged plan cannot authorize revision" [ $? = 1 ]
relock_branch relock-same-criteria
# Approval may be newly appended, but its criteria hash is already in the old log.
approve; weaken_locked_test; progress_round 'approve identical criteria again'
check; t "PR relock C4: approving identical criteria again cannot authorize revision" [ $? = 1 ]
relock_branch relock-copy
cp .ai/plans/active/lock-demo.md .ai/plans/active/copied.md
weaken_locked_test; progress_round 'copy approved criteria'
check; t "PR relock C4: copying already approved criteria cannot authorize revision" [ $? = 1 ]
relock_branch relock-restore b6r
mkplan lock-demo "lock demo works"; weaken_locked_test
progress_round 'restore older approved criteria'
check; t "PR relock C4: restoring older approved criteria cannot authorize revision" [ $? = 1 ]
relock_branch relock-consumed
mkplan lock-demo "lock demo works" "future dates allowed"; approve
add_locked_test; progress_round 'consume fresh approval in an add-only round'
check; t "PR relock C2: fresh approved add-only round passes" [ $? = 0 ]
weaken_locked_test; progress_round 'reuse approval consumed by preceding round'
check; t "PR relock C4: an intervening add-only round consumes fresh approval" [ $? = 1 ]

relock_branch relock-no-approval
mkplan lock-demo "lock demo works" "unapproved criterion"; weaken_locked_test
progress_round 'criteria changed without approval'
check; t "PR relock C5: changed criteria without approval cannot revise locked tests" [ $? = 1 ]
relock_branch relock-ordinary
mkplan lock-demo "lock demo works" "fresh criterion"; approve
g add -A; g commit -qm 'approve fresh criterion'
weaken_locked_test; g commit -qam 'ordinary rewrite despite fresh approval'
progress_round 'valid round after ordinary rewrite'
check; t "PR relock C5: later valid round cannot excuse ordinary rewrite with fresh approval" [ $? = 1 ]
relock_branch relock-trailer
weaken_locked_test; g commit -qam 'rewrite without a plan change' -m 'Tests-First: invalid'
mkplan lock-demo "lock demo works" "fresh criterion"; approve
progress_round 'valid round after invalid trailer'
check; t "PR relock C5: later valid round cannot excuse invalid Tests-First rewrite" [ $? = 1 ]
relock_branch relock-edit-restore
weaken_locked_test; g commit -qam 'unauthorized rewrite'
g checkout b6base -- tests/test_lock.py; g commit -qm 'restore unauthorized rewrite'
check; t "PR relock C5: restoration does not erase an unauthorized intermediate edit" [ $? = 1 ]
relock_branch relock-progress-restore
weaken_locked_test; progress_round 'unauthorized progress-only rewrite'
g checkout b6base -- tests/test_lock.py; progress_round 'restore via progress-only round'
check; t "PR relock C5: progress-only restoration does not erase an unauthorized round" [ $? = 1 ]
relock_branch relock-progress-fresh
weaken_locked_test; progress_round 'unauthorized round before fresh approval'
mkplan lock-demo "lock demo works" "future dates allowed"; approve
progress_round 'fresh valid round after unauthorized revision'
check; t "PR relock C5: fresh valid round does not erase an earlier unauthorized round" [ $? = 1 ]

relock_branch relock-successive b6r
mkplan lock-demo "lock demo works" "future dates allowed" "later dates allowed"; approve
weaken_locked_test; progress_round 'second independently approved revision'
check; t "PR relock C3: two successive independently approved revisions pass" [ $? = 0 ]
relock_branch relock-post-approved b6r
weaken_locked_test; g commit -qam 'ordinary rewrite after approved revision'
check; t "PR relock C6: approved revision cannot release old tests for ordinary edits" [ $? = 1 ]
relock_branch relock-post-approved-round b6r
weaken_locked_test; progress_round 'unapproved rewrite after approved revision'
check; t "PR relock C6: approved revision cannot release old tests for progress-only rewrites" [ $? = 1 ]
for lock_state in omitted missing; do
  relock_branch "relock-lock-$lock_state" relock-added
  if [ "$lock_state" = omitted ]; then
    echo tests/test_next.py > .ai/test-lock
  else
    g rm -q .ai/test-lock
  fi
  mkplan lock-demo "lock demo works" "future dates allowed"; approve
  weaken_locked_test; progress_round "approved revision with old lock $lock_state"
  check; t "PR relock C6: approved revision with old lock $lock_state passes" [ $? = 0 ]
  g branch -q "relock-lock-$lock_state-base"
  echo 'def test_lock(): assert 2 == 2' > tests/test_lock.py
  g commit -qam 'ordinary edit of an omitted old locked path'
  check; t "PR relock C6: old lock $lock_state still protects against ordinary edits" [ $? = 1 ]
  relock_branch "relock-lock-$lock_state-round" "relock-lock-$lock_state-base"
  echo 'def test_lock(): assert 2 == 2' > tests/test_lock.py
  progress_round 'progress-only edit of an omitted old locked path'
  check; t "PR relock C6: old lock $lock_state still protects against unapproved rounds" [ $? = 1 ]
done
newbranch b8; mkdir -p .claude/hooks .github/workflows .ai/plans
cp "$here/agents/claude/hooks/ci-checks.sh" "$here/agents/claude/hooks/lint-file.sh" .claude/hooks/
cp "$here/github/ci.yml" .github/workflows/; cp "$here/project/.ai/plans/TEMPLATE.md" .ai/plans/
g add -A; g commit -qm "onboarding: add Lodestar files"
out=$(bash "$here/agents/claude/hooks/ci-checks.sh" main 2>&1); rc=$?
t "PR: Lodestar's own hook files do not trip the suppression check" [ $rc = 0 ]
t "PR: the plan template is not listed in the owner summary" bash -c '! grep -q "TEMPLATE.md" <<<"$1"' _ "$out"
newbranch b7; echo 'w = 1  # TODO: handle rounding' >> app/ui.py; g commit -qam "todo"
out=$(bash "$here/agents/claude/hooks/ci-checks.sh" main 2>&1); rc=$?
t "PR: new TODO is listed but does not fail" bash -c '[ $1 = 0 ] && grep -q "TODO: handle rounding" <<<"$2"' _ "$rc" "$out"
# Mutation testing: report only, on changed sensitive code only.
t "PR: mutation testing is off without the label" grep -q "Mutation testing off" <<<"$out"
export LODESTAR_TEST_MUTATION=true
out=$(bash "$here/agents/claude/hooks/ci-checks.sh" main 2>&1)
t "PR: no sensitive change skips mutation testing" grep -q "mutation testing skipped" <<<"$out"
newbranch b10; echo 'x = 9' > app/money.py; echo 'y = 9' > app/ui.py; g commit -qam "money" -m "No-Test-Reason: demo"
out=$(bash "$here/agents/claude/hooks/ci-checks.sh" main 2>&1)
t "PR: no make test-mutation target says not set up" grep -q "Mutation testing not set up" <<<"$out"
printf 'test-mutation:\n\t@echo "Mutation score: 50%% for $(FILES)"; echo "  app/money.py:1  survived"\n' > Makefile
g add -A; g commit -qm "makefile"
sum=$tmp/summary.md; : > "$sum"
out=$(GITHUB_STEP_SUMMARY=$sum bash "$here/agents/claude/hooks/ci-checks.sh" main 2>&1); rc=$?
t "PR: mutation runs on the changed sensitive file only and reaches the summary" bash -c '[ $1 = 0 ] && grep -q "50% for app/money.py$" "$2" && grep -q "app/money.py:1  survived" <<<"$3"' _ "$rc" "$sum" "$out"
printf 'test-mutation:\n\t@echo "boom"; exit 3\n' > Makefile
out=$(bash "$here/agents/claude/hooks/ci-checks.sh" main 2>&1); rc=$?
t "PR: a failing mutation run is reported and never fails the PR" bash -c '[ $1 = 0 ] && grep -q "did not finish (exit" <<<"$2"' _ "$rc" "$out"
printf 'test-mutation:\n\t@echo broken > app/money.py; sleep 5\n' > Makefile
out=$(LODESTAR_TEST_MUTATION_TIMEOUT=1 bash "$here/agents/claude/hooks/ci-checks.sh" main 2>&1); rc=$?
t "PR: a mutation run over the time limit is stopped and the mutated file restored" bash -c '[ $1 = 0 ] && grep -q "exit 124" <<<"$2" && grep -q "x = 9" app/money.py' _ "$rc" "$out"
printf 'test-mutation:\n\t@true\n' > Makefile
out=$(bash "$here/agents/claude/hooks/ci-checks.sh" main 2>&1)
t "PR: an empty mutation report says no part ran it" grep -q "No part of the repo ran mutation testing" <<<"$out"
g checkout -q -- Makefile; unset LODESTAR_TEST_MUTATION
cd "$here"

# 10. protect-tests: locked while the task is active; relock window only after
#     the owner approves changed criteria; lock expires when the task is done;
#     the approvals log is never agent-editable.
cd "$p"; g checkout -q -f b6base; g clean -qfd
guard() { CLAUDE_PROJECT_DIR=$p bash "$here/agents/claude/hooks/protect-tests.sh" 2>/dev/null \
  <<<"{\"tool_input\":{\"file_path\":\"$(native "$p/$1")\"}}"; }
guard tests/test_lock.py; t "guard blocks editing a locked test" [ $? = 2 ]
guard .ai/test-lock; t "guard blocks editing the lock" [ $? = 2 ]
guard .ai/approvals.log; t "guard blocks editing the approvals log" [ $? = 2 ]
guard app/ui.py; t "guard allows other files" [ $? = 0 ]
# A later step of the same approved plan adds its tests to the lock: lines may
# be added, and every line already there stays as it is.
# lockedit TOOL TOOL_INPUT_JSON: an edit of .ai/test-lock (it holds "tests/test_lock.py").
lockedit() { CLAUDE_PROJECT_DIR=$p bash "$here/agents/claude/hooks/protect-tests.sh" 2>/dev/null \
  <<<"$(jq -n --arg n "$1" --arg f "$(native "$p/.ai/test-lock")" --argjson i "$2" '{tool_name: $n, tool_input: ({file_path: $f} + $i)}')"; }
lockedit Write '{"content":"tests/test_lock.py\ntests/test_new.py\n"}'; t "lock: Write that adds a line is allowed" [ $? = 0 ]
lockedit Write '{"content":"tests/test_lock.py\r\ntests/test_new.py\r\n"}'; t "lock: Write that adds a line with CRLF is allowed" [ $? = 0 ]
lockedit Edit '{"old_string":"tests/test_lock.py","new_string":"tests/test_lock.py\ntests/test_new.py"}'; t "lock: Edit that adds a line is allowed" [ $? = 0 ]
lockedit MultiEdit '{"edits":[{"old_string":"tests/test_lock.py","new_string":"tests/test_lock.py\ntests/test_new.py"},{"old_string":"tests/test_new.py","new_string":"tests/test_new.py\ntests/test_more.py"}]}'
t "lock: MultiEdit that adds lines is allowed" [ $? = 0 ]
lockedit Write '{"content":"tests/test_new.py\n"}'; t "lock: Write that drops a line is blocked" [ $? = 2 ]
lockedit Write '{"content":""}'; t "lock: Write that empties the lock is blocked" [ $? = 2 ]
lockedit Write '{"content":"# tests/test_lock.py\ntests/test_new.py\n"}'; t "lock: turning a line into a comment is blocked" [ $? = 2 ]
lockedit Write '{"content":"Tests/test_lock.py\ntests/test_new.py\n"}'; t "lock: changing the case of a line is blocked" [ $? = 2 ]
lockedit Write '{"content":"tests/test_lock.py.bak\ntests/test_new.py\n"}'; t "lock: a longer line does not stand for the old one" [ $? = 2 ]
lockedit Write '{}'; t "lock: Write without content is blocked" [ $? = 2 ]
lockedit Edit '{"old_string":"tests/test_lock.py","new_string":"tests/test_other.py"}'; t "lock: Edit that changes a line is blocked" [ $? = 2 ]
lockedit Edit '{"old_string":"test_lock","new_string":"test_x","replace_all":true}'; t "lock: Edit with replace_all that changes a line is blocked" [ $? = 2 ]
lockedit Edit '{"old_string":"tests/no_such.py","new_string":"tests/no_such.py\ntests/test_new.py"}'; t "lock: Edit whose old_string is not in the lock is blocked" [ $? = 2 ]
lockedit Edit '{"old_string":"","new_string":"tests/test_new.py\n"}'; t "lock: Edit with an empty old_string is blocked" [ $? = 2 ]
lockedit MultiEdit '{"edits":[{"old_string":"tests/test_lock.py","new_string":"tests/test_lock.py\ntests/test_new.py"},{"old_string":"tests/test_lock.py\n","new_string":""}]}'
t "lock: MultiEdit that adds, then drops a line is blocked" [ $? = 2 ]
lockedit MultiEdit '{"edits":[]}'; t "lock: MultiEdit without edits is blocked" [ $? = 2 ]
lockedit apply_patch '{"content":"tests/test_lock.py\ntests/test_new.py\n"}'; t "lock: a tool whose result is not known is blocked" [ $? = 2 ]
lockedit Write '{"content":"tests/test\u0000_lock.py\ntests/test_new.py\n"}'; t "lock: Write with a NUL inside an old line is blocked" [ $? = 2 ]
lockedit Edit '{"old_string":"tests/test_lock.py","new_string":"tests/test\u0000_lock.py"}'; t "lock: Edit that puts a NUL inside a line is blocked" [ $? = 2 ]
lockedit Write '{"content":" tests/test_lock.py\ntests/test_new.py\n"}'; t "lock: a space before an old line is blocked" [ $? = 2 ]
lockedit Write '{"content":"tests/test_lock.py\t\ntests/test_new.py\n"}'; t "lock: a tab after an old line is blocked" [ $? = 2 ]
# The Edit tool also removes the line break after text it deletes, so a
# comment line could swallow the path below it: an Edit may only insert.
printf '#x\ntests/test_lock.py\n' > .ai/test-lock
lockedit Edit '{"old_string":"x","new_string":""}'; t "lock: Edit that removes text is blocked (it could join a comment and a path)" [ $? = 2 ]
lockedit Edit '{"old_string":"#x","new_string":"#y"}'; t "lock: Edit that is not an insertion is blocked" [ $? = 2 ]
lockedit Edit '{"old_string":"#x","new_string":"#x\ntests/test_new.py"}'; t "lock: Edit that inserts a line after a comment is allowed" [ $? = 0 ]
printf 'tests/test_lock.py\r\n# note\r\n' > .ai/test-lock
lockedit Edit '{"old_string":"# note","new_string":"# note\ntests/test_new.py"}'; t "lock: Edit that adds a line to a CRLF lock is allowed" [ $? = 0 ]
lockedit Edit '{"old_string":"tests/test_lock.py","new_string":"tests/test_other.py"}'; t "lock: Edit that changes a line of a CRLF lock is blocked" [ $? = 2 ]
printf 'tests/test_lock.py\n# a\n# a\n' > .ai/test-lock
lockedit Edit '{"old_string":"# a","new_string":"# a\ntests/test_new.py"}'; t "lock: Edit whose old_string is there twice is blocked without replace_all" [ $? = 2 ]
g checkout -q -- .ai/test-lock
guard tests/test_lock.py; t "lock: a locked test stays blocked" [ $? = 2 ]
mkplan lock-demo "lock demo works" "changed by the agent alone"
guard tests/test_lock.py; t "guard: criteria changed without approval keep the lock" [ $? = 2 ]
lockedit Write '{"content":"tests/test_lock.py\ntests/test_new.py\n"}'; t "lock: criteria changed without approval block adding a line too" [ $? = 2 ]
approve
guard tests/test_lock.py; t "guard: owner-approved changed criteria open the relock window" [ $? = 0 ]
# The window needs an approval newer than the last round: a copy of the
# approved plan, or criteria the owner approved before that round, do not open it.
g checkout -q -f b6base; g clean -qfd
cp .ai/plans/active/lock-demo.md .ai/plans/active/copy.md
guard tests/test_lock.py; t "guard: a copy of the approved plan does not open the relock window" [ $? = 2 ]
lockedit Write '{"content":"tests/test_new.py\n"}'; t "lock: a copy of the approved plan does not let a line be removed" [ $? = 2 ]
rm .ai/plans/active/copy.md
mkplan second "second works"; approve
guard tests/test_lock.py; t "guard: a new plan the owner approves mid-task opens the relock window" [ $? = 0 ]
g checkout -q -f b6r; g clean -qfd
guard tests/test_lock.py; t "guard: a second round locks its tests again" [ $? = 2 ]
mkplan lock-demo "lock demo works"
guard tests/test_lock.py; t "guard: criteria put back to an earlier approved version do not open the relock window" [ $? = 2 ]
lockedit Write '{"content":"tests/test_new.py\n"}'; t "lock: criteria put back to an earlier approved version do not let a line be removed" [ $? = 2 ]
g checkout -q -f b6base; g clean -qfd
mkdir -p .ai/plans/completed; g mv .ai/plans/active/lock-demo.md .ai/plans/completed/
guard tests/test_lock.py; t "guard: the lock expires when the task is completed" [ $? = 0 ]
mkplan other-task "something else"
guard tests/test_lock.py; t "guard: a stale lock does not block the next task" [ $? = 0 ]
# Two plans in one round: the lock gains lines only while both are approved.
g checkout -q -f b6base; g clean -qfd; newbranch b6m
mkplan two-a "a works"; approve; mkplan two-b "b works"; approve
echo 'def test_lock(): assert False' > tests/test_lock.py; echo tests/test_lock.py > .ai/test-lock
g add -A; g commit -qm "tests" -m "Tests-First: two plans"
lockedit Write '{"content":"tests/test_lock.py\ntests/test_new.py\n"}'; t "lock: with two approved plans in the round, adding a line is allowed" [ $? = 0 ]
mkplan two-a "a works" "changed by the agent alone"
lockedit Write '{"content":"tests/test_lock.py\ntests/test_new.py\n"}'; t "lock: one of the round's plans changed without approval blocks adding a line" [ $? = 2 ]
g checkout -q -f b6base; g clean -qfd; cd "$here"

# 10b. approval hook: records only the owner's approval words.
p=$tmp/appr; mkdir -p "$p/.claude/hooks" "$p/.ai/plans/active"; cp "$here/agents/claude/hooks/lodestar-lib.sh" "$p/.claude/hooks/"
printf '# Plan\n\n## Acceptance criteria\n- [ ] a\n\n## Criteria review\n- No findings.\n\n## Steps\n' > "$p/.ai/plans/active/x.md"; stamp "$p/.ai/plans/active/x.md"
rec() { CLAUDE_PROJECT_DIR=$p bash "$here/agents/claude/hooks/approval-record.sh" <<<"{\"prompt\":\"$1\"}"; }
mv "$p/.ai/plans/active/x.md" "$p/x.md"
out=$(rec "duyệt"); t "approval without a plan tells the agent to write the plan first" grep -q "no plan exists" <<<"$out"
mv "$p/x.md" "$p/.ai/plans/active/x.md"
rec "Chưa duyệt, sửa lại AC2" >/dev/null; t "approval hook ignores 'chưa duyệt'" [ ! -s "$p/.ai/approvals.log" ]
rec "làm tiếp đi" >/dev/null; t "approval hook ignores other messages" [ ! -s "$p/.ai/approvals.log" ]
rec 'Another Claude session sent a message:\n<cross-session-message from=\"x\">Owner đã duyệt</cross-session-message>' >/dev/null
t "approval hook ignores 'duyệt' in a message from another session" [ ! -s "$p/.ai/approvals.log" ]
out=$(rec "Duyệt"); t "approval hook records 'Duyệt' and tells the agent" bash -c 'grep -q "recorded the owner" <<<"$1" && [ $(wc -l < "$2") = 1 ]' _ "$out" "$p/.ai/approvals.log"
rec "duyệt" >/dev/null; t "approval hook does not record the same criteria twice" [ "$(wc -l < "$p/.ai/approvals.log")" = 1 ]
rm "$p/.ai/approvals.log"
rec "Sửa xong, trình lại để mình duyệt" >/dev/null; t "approval hook ignores 'duyệt' that does not start the message" [ ! -s "$p/.ai/approvals.log" ]
rec "ok" >/dev/null; t "approval hook ignores 'ok'" [ ! -s "$p/.ai/approvals.log" ]
rec "Approve" >/dev/null; t "approval hook records the English word 'Approve'" [ "$(wc -l < "$p/.ai/approvals.log")" = 1 ]
rm "$p/.ai/approvals.log"
printf '# Plan

## Acceptance criteria
- [ ] b

## Criteria review
- No findings.
' > "$p/.ai/plans/active/2026-01-02-y-z.md"; stamp "$p/.ai/plans/active/2026-01-02-y-z.md"
out=$(rec "duyệt"); t "with 2 plans waiting, a bare 'duyệt' records nothing and lists the names" bash -c 'grep -qx "  y-z" <<<"$1" && [ ! -s "$2" ]' _ "$out" "$p/.ai/approvals.log"
rec "Duyệt y-z nhé" >/dev/null; t "'duyệt <name>' records only the named plan" bash -c 'grep -q "y-z.md" "$1" && [ $(wc -l < "$1") = 1 ]' _ "$p/.ai/approvals.log"
rec "duyệt" >/dev/null; t "with 1 plan left, a bare 'duyệt' records it" [ "$(wc -l < "$p/.ai/approvals.log")" = 2 ]
sed -i 's/- \[ \] a/- [x] a/' "$p/.ai/plans/active/x.md"
t "ticking a criterion off keeps it approved" bash -c 'cd "$1" && . .claude/hooks/lodestar-lib.sh && plan_approved_now .ai/plans/active/x.md' _ "$p"
printf '# Plan\n\n## Acceptance criteria\n\nProse.\n\n- [ ] c starts here\n      and goes on x 1.37\n\n## Criteria review\n- No findings.\n\n## Steps\n' > "$p/.ai/plans/active/2026-01-03-w.md"; stamp "$p/.ai/plans/active/2026-01-03-w.md"
rec "duyệt w" >/dev/null
sed -i 's/x 1.37/x 1\/1.37/' "$p/.ai/plans/active/2026-01-03-w.md"
t "editing a criterion's second line needs a new approval" bash -c 'cd "$1" && . .claude/hooks/lodestar-lib.sh && ! plan_approved_now .ai/plans/active/2026-01-03-w.md' _ "$p"
n=$(wc -l < "$p/.ai/approvals.log"); out=$(rec "duyệt w")
t "criteria changed after the review are not recorded; the agent is told to re-run the critic" bash -c '[ "$(wc -l < "$2")" = "$3" ] && grep -q "does not cover" <<<"$1" && grep -q "agents/critic.md" <<<"$1"' _ "$out" "$p/.ai/approvals.log" "$n"
stamp "$p/.ai/plans/active/2026-01-03-w.md"
sed -i 's/^Prose\./Other prose./' "$p/.ai/plans/active/2026-01-03-w.md"; rec "duyệt w" >/dev/null
t "a review that covers the changed criteria is recorded" [ "$(wc -l < "$p/.ai/approvals.log")" = $((n + 1)) ]
sed -i 's/^Other prose\./Prose./' "$p/.ai/plans/active/2026-01-03-w.md"
t "editing prose between the criteria keeps them approved" bash -c 'cd "$1" && . .claude/hooks/lodestar-lib.sh && plan_approved_now .ai/plans/active/2026-01-03-w.md' _ "$p"
printf '# Plan

## Acceptance criteria
- [ ] d

## Criteria review
- ...
' > "$p/.ai/plans/active/2026-01-04-v.md"
out=$(rec "duyệt v"); t "a plan without a criteria review is not recorded; the agent is told to run the critic" bash -c '! grep -q "v.md" "$2" && grep -q "agents/critic.md" <<<"$1"' _ "$out" "$p/.ai/approvals.log"
vh=$(. "$here/agents/claude/hooks/lodestar-lib.sh"; criteria_hash < "$p/.ai/plans/active/2026-01-04-v.md")
printf -- '- Reviewed criteria: %s\n' "$vh" >> "$p/.ai/plans/active/2026-01-04-v.md"
rec "duyệt v" >/dev/null; t "a review with only the 'Reviewed criteria' line is not recorded" bash -c '! grep -q "v.md" "$1"' _ "$p/.ai/approvals.log"
sed -i '$d' "$p/.ai/plans/active/2026-01-04-v.md"
printf -- '- AC1 had no threshold: added "within 0.1%%".
' >> "$p/.ai/plans/active/2026-01-04-v.md"
out=$(rec "duyệt v"); t "a filled review that does not name the criteria is not recorded" bash -c '! grep -q "v.md" "$2" && grep -q "does not cover" <<<"$1"' _ "$out" "$p/.ai/approvals.log"
printf -- '- Reviewed criteria: %s\n' "$vh" >> "$p/.ai/plans/active/2026-01-04-v.md"
rec "duyệt v" >/dev/null; t "the same plan with a filled criteria review is recorded" grep -q "v.md" "$p/.ai/approvals.log"
sed -i '/^## Criteria review/,$d' "$p/.ai/plans/active/x.md"
t "a plan approved before the critic existed stays approved" bash -c 'cd "$1" && . .claude/hooks/lodestar-lib.sh && plan_approved_now .ai/plans/active/x.md' _ "$p"
t "the plan template has no criteria to approve" bash -c '. "$1/agents/claude/hooks/lodestar-lib.sh" && [ -z "$(criteria_hash < "$1/project/.ai/plans/TEMPLATE.md")" ]' _ "$here"

# 11. lint-file hook: a new suppression needs a reason.
p=$tmp/hooks
echo 'import os  # noqa: F401' > "$p/sup.py"
lint "$p/sup.py"; t "lint hook blocks a suppression without reason" [ $? = 2 ]
echo 'import os  # noqa: F401 -- used by plugins' > "$p/sup.py"
lint "$p/sup.py"; t "lint hook accepts a suppression with reason" [ $? = 0 ]

# 13. Maintenance clock (D1) and repeated mistakes (D2).
p=$tmp/maint; mkdir -p "$p"; git -C "$p" init -q
bash "$here/bootstrap.sh" "$p" --stack python >/dev/null
t "bootstrap starts the maintenance clock" grep -qx "$(date +%F)" "$p/.ai/last-maintenance"
if git -C "$here/.." remote get-url origin >/dev/null 2>&1; then
  t "enforcement.json records the lodestar-harness repo URL" jq -e '.repo | test("^https://")' "$p/.ai/enforcement.json"
fi
z=$tmp/zipcopy; mkdir -p "$z"; cp -r "$here" "$z/enforcement"; cp -r "$here/../project" "$z/project"
q=$tmp/fromzip; mkdir -p "$q"; git -C "$q" init -q
bash "$z/enforcement/bootstrap.sh" "$q" --stack python >/dev/null 2>&1
t "bootstrap from a copy without git still records the version" jq -e '.version != "" and .repo == ""' "$q/.ai/enforcement.json"
fill "$p/AGENTS.md" "$p/.ai/project.md"
echo "| INV-01 | x | High | test | enforced |" >> "$p/.ai/invariants.md"
out=$(bash "$p/.claude/hooks/doctor.sh" "$p")
t "fresh project: no maintenance warnings" bash -c '! grep -qE "⚠️ +D[12] " <<<"$1"' _ "$out"
date -d '20 days ago' +%F > "$p/.ai/last-maintenance"
out=$(bash "$p/.claude/hooks/doctor.sh" "$p"); rc=$?
t "doctor warns when maintenance is overdue (D1), still ready" bash -c '[ $1 = 0 ] && grep -qE "⚠️ +D1 " <<<"$2"' _ "$rc" "$out"
printf '| 2026-09-01 | tz-missing | used date.today() | TD-02 | open |\n| 2026-09-10 | tz-missing | again | TD-02 | open |\n' >> "$p/.ai/feedback-log.md"
out=$(bash "$p/.claude/hooks/doctor.sh" "$p")
t "doctor warns about a repeated mistake (D2)" grep -qE "⚠️ +D2 " <<<"$out"
out=$(remind "$p")
t "global hook reports maintenance due" bash -c 'grep -q "maintenance is due" <<<"$1" && grep -q "D1" <<<"$1"' _ "$out"
sed -i 's/| open |/| enforced |/' "$p/.ai/feedback-log.md"; date +%F > "$p/.ai/last-maintenance"
out=$(bash "$p/.claude/hooks/doctor.sh" "$p")
t "enforced repeats and fresh maintenance clear D1/D2" bash -c '! grep -qE "⚠️ +D[12] " <<<"$1"' _ "$out"
printf '| 2026-09-11 | orca-x | missing step | - | reported |\n| 2026-09-12 | lodestar-x | again | - | reported |\n' >>"$p/.ai/feedback-log.md"
out=$(bash "$p/.claude/hooks/doctor.sh" "$p")
t "repeated lodestar- and old orca- tags do not trigger D2" bash -c '! grep -qE "⚠️ +D2 " <<<"$1"' _ "$out"
mkdir -p "$p/.venv"; out=$(remind "$p")
t "global hook silent when nothing is due" [ -z "$out" ]

# 14. feedback-check hook: asks once per owner message that looks like a correction.
p=$tmp/fb; mkdir -p "$p/.ai"; git -C "$p" init -q; echo '# Feedback log' > "$p/.ai/feedback-log.md"
tr=$p/transcript.jsonl
say_owner() { # $1 = promptId, $2 = text; then an assistant line and a tool result
  jq -nc --arg id "$1" --arg t "$2" '{type:"user",promptId:$id,message:{role:"user",content:$t}}' >> "$tr"
  jq -nc '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:"ok"}]}}' >> "$tr"
  jq -nc '{type:"user",message:{role:"user",content:[{type:"tool_result",content:"sai sai"}]}}' >> "$tr"
}
fb() { CLAUDE_PROJECT_DIR=$p bash "$here/agents/claude/hooks/feedback-check.sh" 2>/dev/null \
  <<<"{\"transcript_path\":\"$(native "$tr")\",\"session_id\":\"claude-feedback-fixture\",\"stop_hook_active\":$1}"; }
say_owner p1 "thêm cột ngày vào bảng"
fb false; t "feedback hook quiet on a normal request" [ $? = 0 ]
say_owner p2 "sai rồi, phải dùng giờ Việt Nam"
fb false; t "feedback hook asks on a correction" [ $? = 2 ]
fb true; t "feedback hook asks only once per message" [ $? = 0 ]
say_owner p3 "Làm lại đi, chưa đúng ý"
fb true; t "feedback hook asks on a new correction, even after a verify retry" [ $? = 2 ]
say_owner p4 "tôi muốn dashboard mới"
fb false; t "feedback hook ignores 'sai' inside tool results" [ $? = 0 ]
rm "$p/.ai/feedback-log.md"; say_owner p5 "sai rồi"
fb false; t "feedback hook off in projects not onboarded" [ $? = 0 ]

# 15. Hooks never skip silently when make is broken (bad Makefile, or a
#     folder with accents on Windows).
p=$tmp/brokenmake; mkdir -p "$p"; printf 'verify:\n\t@true\nbad line without a colon\n' > "$p/Makefile"; echo x > "$p/a.py"
CLAUDE_PROJECT_DIR=$p bash "$here/agents/claude/hooks/verify-before-stop.sh" <<<'{"stop_hook_active":false}' 2>/dev/null
t "stop hook reports a Makefile make cannot run" [ $? = 2 ]
CLAUDE_PROJECT_DIR=$p bash "$here/agents/claude/hooks/lint-file.sh" 2>/dev/null <<<"{\"tool_input\":{\"file_path\":\"$(native "$p/a.py")\"}}"
t "lint hook reports a Makefile make cannot run" [ $? = 2 ]
printf 'verify:\n\t@true\n' > "$p/Makefile"
CLAUDE_PROJECT_DIR=$p bash "$here/agents/claude/hooks/lint-file.sh" 2>/dev/null <<<"{\"tool_input\":{\"file_path\":\"$(native "$p/a.py")\"}}"
t "lint hook skips when only lint-file is missing" [ $? = 0 ]
if pwd -W >/dev/null 2>&1; then   # Windows only
  p="$tmp/dự án"; mkdir -p "$p"; git -C "$p" init -q
  out=$(bash "$here/bootstrap.sh" "$p" --stack python 2>&1)
  t "bootstrap warns about an accented path (Windows)" grep -q 'accented characters' <<<"$out"
  out=$(bash "$p/.claude/hooks/doctor.sh" "$p")
  t "doctor fails T4 on an accented path (Windows)" grep -qE '❌ T4 ' <<<"$out"
fi

# 16. sensitive-gate hook: tests-first before touching sensitive code.
p=$tmp/gate; mkdir -p "$p/app" "$p/tests" "$p/.ai/plans/active" "$p/.claude/hooks"; cd "$p"
cp "$here/agents/claude/hooks/lodestar-lib.sh" .claude/hooks/
printf 'sensitive_paths:\n  - app/money.py\n' > .ai/project.md
gate() { CLAUDE_PROJECT_DIR=$p bash "$here/agents/claude/hooks/sensitive-gate.sh" 2>/dev/null \
  <<<"{\"tool_input\":{\"file_path\":\"$(native "$p/$1")\"}}"; }
gate app/ui.py; t "gate allows non-sensitive files" [ $? = 0 ]
gate tests/test_money.py; t "gate allows writing tests first" [ $? = 0 ]
gate app/money.py; t "gate blocks sensitive code without a plan" [ $? = 2 ]
mkplan t "money is exact"; echo 'Approved by the owner: 2026-09-29' >> .ai/plans/active/t.md
gate app/money.py; t "gate ignores an approval line the agent wrote itself" [ $? = 2 ]
approve
gate app/money.py; t "gate blocks with an approved plan but no locked tests" [ $? = 2 ]
echo tests/test_money.py > .ai/test-lock
gate app/money.py; t "gate allows after owner approval and locked tests" [ $? = 0 ]
mkplan t "money is exact" "criterion added after approval"
gate app/money.py; t "gate blocks when criteria changed after approval" [ $? = 2 ]
approve; rm .ai/test-lock; echo 'No-Test-Reason: comment typo only' >> .ai/plans/active/t.md
gate app/money.py; t "gate allows an approved plan with No-Test-Reason" [ $? = 0 ]
LODESTAR_SKIP_HOOKS=1 gate app/money.py; t "LODESTAR_SKIP_HOOKS disables the gate" [ $? = 0 ]
# The lock must list a test changed on this branch, not only an earlier task's.
p=$tmp/gate2; mkdir -p "$p/app" "$p/tests" "$p/.ai" "$p/.claude/hooks"; cd "$p"
cp "$here/agents/claude/hooks/lodestar-lib.sh" .claude/hooks/
printf 'sensitive_paths:
  - app/money.py
' > .ai/project.md
g init -q -b main; echo 'x = 1' > app/money.py; echo 'def test_old(): pass' > tests/test_old.py
echo tests/test_old.py > .ai/test-lock; g add -A; g commit -qm "old task"
newbranch feat; mkplan t "money is exact"; approve
gate app/money.py; t "gate blocks when the lock lists only an earlier task's tests" [ $? = 2 ]
echo 'def test_new(): pass' > tests/test_new.py; echo tests/test_new.py >> .ai/test-lock
gate app/money.py; t "gate allows a lock with a new (untracked) test on this branch" [ $? = 0 ]
g add -A; g commit -qm "tests" -m "Tests-First: t"
gate app/money.py; t "gate allows a lock with a test committed on this branch" [ $? = 0 ]
cd "$here"

# 17. Stop hook keeps locked tests unchanged while the task is active, even
#     after .ai/test-lock is removed and without CI; a fake Tests-First
#     trailer cannot reset the lock.
p=$tmp/locallock; mkdir -p "$p/tests" "$p/.claude/hooks"; cd "$p"
cp "$here/agents/claude/hooks/lodestar-lib.sh" .claude/hooks/
g init -q -b main; echo 'def test_a(): assert True' > tests/test_a.py
mkplan t "a works"; approve; echo tests/test_a.py > .ai/test-lock
g add -A; g commit -qm "tests" -m "Tests-First: t"; rm .ai/test-lock; g commit -qam "unlock"
stopl() { CLAUDE_PROJECT_DIR=$p bash "$here/agents/claude/hooks/verify-before-stop.sh" 2>/dev/null <<<'{"stop_hook_active":false}'; }
stopl; t "stop hook passes when locked tests are untouched" [ $? = 0 ]
echo 'def test_a(): pass' > tests/test_a.py
stopl; t "stop hook blocks an edit to a locked test after unlock (no CI)" [ $? = 2 ]
stopl; t "stop hook blocks a locked-test edit on every stop" [ $? = 2 ]
g commit -qam "weaken" -m "Tests-First: sneaky"
stopl; t "stop hook: a fake Tests-First trailer does not reset the lock" [ $? = 2 ]
g reset -q --hard HEAD~1
cp .ai/plans/active/t.md .ai/plans/active/copy.md; echo 'def test_a(): pass' > tests/test_a.py
stopl; t "stop hook: a copy of the approved plan keeps the lock" [ $? = 2 ]
rm .ai/plans/active/copy.md
mkplan t "a works" "b allowed"; approve
echo 'def test_a(): assert 1' > tests/test_a.py
stopl; t "stop hook: relock window after owner approves changed criteria" [ $? = 0 ]
g add -A; g commit -qm "new round" -m "Tests-First: t v2"
stopl; t "stop hook: the new approved round becomes the lock baseline" [ $? = 0 ]
mkdir -p .ai/plans/completed; g mv .ai/plans/active/t.md .ai/plans/completed/; g commit -qm "done"
echo 'def test_a(): pass' > tests/test_a.py
stopl; t "stop hook releases the lock when the task is completed" [ $? = 0 ]
# A completed task's round is no baseline: a new lock being written must not
# flag tests a later merged change touched.
p=$tmp/oldlock; mkdir -p "$p/tests" "$p/.claude/hooks"; cd "$p"
cp "$here/agents/claude/hooks/lodestar-lib.sh" .claude/hooks/
g init -q -b main; echo 'def test_a(): assert True' > tests/test_a.py
mkplan old "a works"; approve; echo tests/test_a.py > .ai/test-lock
g add -A; g commit -qm "tests" -m "Tests-First: old"
mkdir -p .ai/plans/completed; g mv .ai/plans/active/old.md .ai/plans/completed/; g commit -qm "done"
echo 'def test_a(): assert 1' > tests/test_a.py; g commit -qam "later merged change"
mkplan new "n works"; echo tests/test_n.py > .ai/test-lock
stopl; t "stop hook ignores a completed task's round while a new lock is written" [ $? = 0 ]
cd "$here"

# 18. Line endings: a new repo gets LF for all text files; an existing repo
#     only for shell scripts (no mass renormalization).
p=$tmp/eolnew; mkdir -p "$p"; git -C "$p" init -q
bash "$here/bootstrap.sh" "$p" --stack node-ts >/dev/null
t "new repo gets '* text=auto eol=lf'" grep -qxF '* text=auto eol=lf' "$p/.gitattributes"
p=$tmp/eolold; mkdir -p "$p"; cd "$p"; g init -q; echo x > a.txt; g add -A; g commit -qm base; cd "$here"
bash "$here/bootstrap.sh" "$p" --stack node-ts >/dev/null
t "existing repo gets only '*.sh text eol=lf'" bash -c 'grep -qxF "*.sh text eol=lf" "$1" && ! grep -qxF "* text=auto eol=lf" "$1"' _ "$p/.gitattributes"

# 19. setup-machine.sh: creates what is missing, keeps what exists, never
#     overwrites the owner's own content (uses a fake home).
sm() { env -u CODEX_HOME SETUP_HOME=$1 CLAUDE_SETTINGS=$1/.claude/settings.json bash "$here/setup-machine.sh" --no-selftest "${@:2}" >/dev/null 2>&1; }
h=$tmp/home1; mkdir -p "$h"
sm "$h" --check; t "setup --check on a fresh machine reports problems, changes nothing" bash -c '[ $1 = 1 ] && [ ! -e "$2/.claude/CLAUDE.md" ]' _ $? "$h"
sm "$h"; t "setup creates the global CLAUDE.md with this repo's path" grep -qF "$(cd "$here/.." && { pwd -W 2>/dev/null || pwd; })/workflows/onboarding.md" "$h/.claude/CLAUDE.md"
t "setup installs the global reminder hooks" jq -e '[.hooks.UserPromptSubmit[].hooks[].command] | any(test("--prompt"))' "$h/.claude/settings.json"
before=$(cksum "$h/.claude/CLAUDE.md" "$h/.claude/settings.json"); sm "$h"
t "second setup run changes nothing" [ "$before" = "$(cksum "$h/.claude/CLAUDE.md" "$h/.claude/settings.json")" ]
h=$tmp/home2; mkdir -p "$h/.claude"; printf '# My own rules\nBe brief.\n' > "$h/.claude/CLAUDE.md"
sm "$h" --yes; t "setup appends the Lodestar block and keeps the owner's rules" bash -c 'grep -q "Be brief." "$1" && grep -q "lodestar-harness:begin" "$1" && [ -f "$1.bak" ]' _ "$h/.claude/CLAUDE.md"
h=$tmp/home3; mkdir -p "$h/.claude"; printf '# Orca Workflow Bootstrap\n\nold text\n' > "$h/.claude/CLAUDE.md"
sm "$h" --yes; t "setup replaces an old unmarked Orca section" bash -c '! grep -q "old text" "$1" && grep -q "Readiness first" "$1"' _ "$h/.claude/CLAUDE.md"
h=$tmp/home4; mkdir -p "$h/.claude"
printf 'top\n<!-- lodestar-harness:begin x -->\nstale\n<!-- lodestar-harness:end -->\nbottom\n' > "$h/.claude/CLAUDE.md"
sm "$h" --yes; t "setup updates only the managed block" bash -c 'grep -q "^top$" "$1" && grep -q "^bottom$" "$1" && ! grep -q stale "$1" && grep -q "Readiness first" "$1"' _ "$h/.claude/CLAUDE.md"
h=$tmp/home5; mkdir -p "$h/.claude"
printf 'top\n<!-- orca-workflow:begin x -->\nstale\n<!-- orca-workflow:end -->\nbottom\n' > "$h/.claude/CLAUDE.md"
sm "$h" --yes; t "setup rewrites a block with the old orca-workflow markers" bash -c 'grep -q "^bottom$" "$1" && ! grep -q "orca-workflow:begin" "$1" && grep -q "lodestar-harness:begin" "$1"' _ "$h/.claude/CLAUDE.md"

# 19b. user-path.ps1 (Windows): puts a folder first in the user PATH, keeps
#      %VAR% entries and the value type, and here writes a scratch key only.
if command -v powershell.exe >/dev/null; then
  up() { LODESTAR_PATH_MODE=$1 LODESTAR_PATH_ENTRY=$2 powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$here/user-path.ps1")" >/dev/null 2>&1; }
  reg_set "$regkey" ExpandString '%USERPROFILE%\bin;C:\A;C:\B'
  up check 'C:\New'; t "user PATH: check says a missing folder is missing" [ $? = 1 ]
  t "user PATH: check changes nothing" [ "$(reg_get "$regkey")" = 'ExpandString %USERPROFILE%\bin;C:\A;C:\B' ]
  up add 'C:\New'
  t "user PATH: add puts the folder first, keeps the rest and the %VAR% entry" [ "$(reg_get "$regkey")" = 'ExpandString C:\New;%USERPROFILE%\bin;C:\A;C:\B' ]
  up check 'C:\New'; t "user PATH: check finds the folder after add" [ $? = 0 ]
  up add 'C:\New'
  t "user PATH: a second add changes nothing" [ "$(reg_get "$regkey")" = 'ExpandString C:\New;%USERPROFILE%\bin;C:\A;C:\B' ]
  up add 'c:\a\'
  t "user PATH: a folder already there in another spelling moves, with no duplicate" [ "$(reg_get "$regkey")" = 'ExpandString c:\a\;C:\New;%USERPROFILE%\bin;C:\B' ]
  up check "$(cygpath -w "$USERPROFILE")\\bin"; t "user PATH: check finds a folder stored as a %VAR% entry" [ $? = 0 ]
  reg_set "$regkey" String 'C:\A;C:\B'; up add 'C:\Program Files\Git\bin'
  t "user PATH: a plain-text value stays plain text; a folder with spaces is one entry" [ "$(reg_get "$regkey")" = 'String C:\Program Files\Git\bin;C:\A;C:\B' ]
  reg_set "$regkey" ExpandString 'C:\A;%LOCALAPPDATA%\Microsoft\WindowsApps;C:\Late;"C:\Q dir"'
  up check 'C:\A'; t "user PATH: check accepts a folder ahead of WindowsApps" [ $? = 0 ]
  up check 'C:\Late'; t "user PATH: check rejects a folder that comes after WindowsApps" [ $? = 1 ]
  up check 'C:\Q dir\'; t "user PATH: a quoted entry is the same folder, here after WindowsApps" [ $? = 1 ]
  up add 'C:\Late'
  t "user PATH: add moves a late folder to the front" [ "$(reg_get "$regkey")" = 'ExpandString C:\Late;C:\A;%LOCALAPPDATA%\Microsoft\WindowsApps;"C:\Q dir"' ]
  up add 'C:\Q dir'
  t "user PATH: add replaces the quoted entry, no duplicate" [ "$(reg_get "$regkey")" = 'ExpandString C:\Q dir;C:\Late;C:\A;%LOCALAPPDATA%\Microsoft\WindowsApps' ]
  LODESTAR_PATH_KEY='HKCU:\Software\LodestarHarnessTest-none' up add 'C:\A'; t "user PATH: a key that cannot be read is an error (exit 3), not 'missing'" [ $? = 3 ]
  reg_set "$regkey" ExpandString 'C:\Scratch'; sm "$tmp/home2" --yes
  t "setup --yes writes the scratch key, not the real user PATH" bash -c '[ "$1" = "$2" ] && [[ $3 == *";C:\Scratch" ]]' _ "$real_path" "$(reg_get 'HKCU:\Environment')" "$(reg_get "$regkey")"
fi

# 20. Python template: tools go into .venv; VENV_ARGS can expose system packages.
p=$tmp/venvargs; mkdir -p "$p"; cp "$here/stacks/python/Makefile" "$p/"
dry=$(make -s -n -C "$p" setup 2>/dev/null); dry2=$(make -s -n -C "$p" setup VENV_ARGS=--system-site-packages 2>/dev/null)
t "python setup creates .venv without system packages by default" bash -c 'grep -q -- "-m venv  *\.venv" <<<"$1" && ! grep -q system-site <<<"$1"' _ "$dry"
t "python setup passes VENV_ARGS" grep -q -- "-m venv --system-site-packages .venv" <<<"$dry2"
dry=$(make -s -n -C "$p" lint-file FILE=a.py 2>/dev/null)
t "python lint-file formats the file, then lints it" grep -q "ruff format -q \"a.py\" && .*ruff check \"a.py\"" <<<"$dry"
p=$tmp/nodefmt; mkdir -p "$p"; cp "$here/stacks/node-ts/Makefile" "$p/"
dry=$(make -s -n -C "$p" lint-file FILE=a.ts 2>/dev/null)
t "node lint-file formats the file, then lints it" bash -c 'grep -q "prettier --write --ignore-unknown .*a.ts" <<<"$1" && grep -q "eslint \"a.ts\"" <<<"$1"' _ "$dry"

# 21. guard-install: installs stay in the project.
# Here-string, not a pipe: env prefixes reach the hook, and an early exit
# cannot break a pipe (differs between Windows and Linux bash).
gi() { bash "$here/agents/claude/hooks/guard-install.sh" 2>/dev/null <<<"$(jq -n --arg c "$1" '{tool_input:{command:$c}}')"; }
for c in "pip install ruff" "python -m pip install pytest" 'C:\Users\PC\AppData\Local\Programs\Python\Python312\python.exe -m pip install ruff' \
         "pip3 install -r requirements.txt" "py -3.12 -m pip install x" "npm install -g typescript" "npm i --global eslint"; do
  gi "$c"; t "guard blocks: $c" [ $? = 2 ]
done
for c in ".venv/Scripts/python.exe -m pip install ruff" "source .venv/bin/activate && pip install x" "make setup" \
         "python -m pip download --no-deps -d /tmp/x -r requirements.txt" "npm install" "npm install -D eslint" "pip list"; do
  gi "$c"; t "guard allows: $c" [ $? = 0 ]
done
p=$tmp/gp; mkdir -p "$p"; git -C "$p" init -q -b main
gp() { CLAUDE_PROJECT_DIR=$p bash "$here/agents/claude/hooks/guard-install.sh" 2>/dev/null <<<"$(jq -n --arg c "$1" '{tool_input:{command:$c}}')"; }
for c in "git push origin main" "git push -u origin HEAD:main" "git push origin --delete master" "git push" "git push -u origin" \
         'git commit --no-verify -m "x"' 'git commit -nm "x"' "git add . && git push --no-verify origin fix/a"; do
  gp "$c"; t "guard blocks: $c" [ $? = 2 ]
done
for c in "git push -u origin fix/a" "git push origin fix/main-page" "git pull origin main" "git log main" \
         "git commit -m 'rename -n flag'" "if gh pr checks 3 --watch; then gh pr merge 3 --merge --delete-branch; fi"; do
  gp "$c"; t "guard allows: $c" [ $? = 0 ]
done
# Merge only on green CI: the merge must sit behind the CI wait's exit code.
for c in "gh pr merge 3 --merge" "cd x && gh pr merge 3" \
         "gh pr view 52 --json statusCheckRollup && gh pr merge 52 --merge" \
         "gh pr checks 52 --watch | tail -3 && gh pr merge 52" \
         "if gh pr checks 52 --watch | tail -3; then gh pr merge 52; fi" \
         "if gh pr checks 52; then gh pr merge 52; fi" \
         "if gh pr checks 5 --watch; then gh pr merge 5; fi; gh pr merge 6" \
         'gh pr checks 52 --watch; gh pr merge 52'          "if gh pr checks 5 --watch; then :; else gh pr merge 5; fi" "GH_TOKEN=x gh pr merge 5"          "gh -R o/r pr merge 5" "gh.exe pr merge 5" "/usr/bin/gh pr merge 5" 'bash -c "gh pr merge 5"'          'eval "gh pr merge 5"' 'x=`gh pr merge 5`' "gh api repos/o/r/pulls/5/merge -X PUT"          'gh pr create --body "never run gh pr merge alone"'; do
  gp "$c"; t "guard blocks: $c" [ $? = 2 ]
done
for c in "if gh pr checks 52 --watch --interval 20; then gh pr merge 52 --merge && gh pr view 52; fi" \
         "cd /f/x && if gh pr checks 52 --watch 2>&1; then gh pr merge 52 --merge; fi" \
         $'if gh pr checks 52 --watch\nthen\n  gh pr merge 52 --merge\nfi' \
         'gh pr checks 52 --watch; if ($LASTEXITCODE -eq 0) { gh pr merge 52 --merge }' \
         'gh pr checks 52 --watch; if ($?) { gh pr merge 52 }' \
         'git commit -m "merge only on green CI"' "gh pr view 52" "gh api repos/o/r/pulls/5"; do
  gp "$c"; t "guard allows: $c" [ $? = 0 ]
done
git -C "$p" checkout -q -b fix/a; gp "git push -u origin"; t "guard allows a bare push from a feature branch" [ $? = 0 ]
git -C "$p" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
gp "git push origin develop"; t "guard blocks a push to the remote's default branch (develop)" [ $? = 2 ]
gp "git push origin develop-docs"; t "guard allows a branch that only starts with the default name" [ $? = 0 ]
# C1: a private repo on GitHub Free gets the real reason, not "set it on GitHub".
mkdir -p "$tmp/fakegh"; printf '#!/usr/bin/env bash\necho "gh: Upgrade to GitHub Pro or make this repository public to enable this feature. (HTTP 403)" >&2\nexit 1\n' > "$tmp/fakegh/gh"; chmod +x "$tmp/fakegh/gh"
out=$(PATH="$tmp/fakegh:$PATH" bash "$here/agents/claude/hooks/doctor.sh" "$tmp/maint" 2>&1)
t "doctor C1 names the GitHub Free limit" grep -q "C1  main cannot be locked: private repo on GitHub Free" <<<"$out"
LODESTAR_SKIP_HOOKS=1 bash "$here/agents/claude/hooks/guard-install.sh" 2>/dev/null <<<'{"tool_input":{"command":"pip install ruff"}}'
t "LODESTAR_SKIP_HOOKS disables the install guard" [ $? = 0 ]
# Tests-First commit: blocked unless a changed plan is owner-approved and staged.
p=$tmp/tf; mkdir -p "$p/.claude/hooks" "$p/.ai/plans/active"; cp "$here/agents/claude/hooks/lodestar-lib.sh" "$p/.claude/hooks/"
git -C "$p" init -q -b main; git -C "$p" config user.email t@t; git -C "$p" config user.name t; git -C "$p" commit -q --allow-empty -m init
printf '# P

## Acceptance criteria

- It works.
' > "$p/.ai/plans/active/a.md"
gt() { CLAUDE_PROJECT_DIR=$p bash "$here/agents/claude/hooks/guard-install.sh" 2>/dev/null <<<"$(jq -n --arg c "$1" '{tool_input:{command:$c}}')"; }
tfc='git commit -m "Tests-First: lock tests"'
gt "$tfc"; t "guard blocks a Tests-First commit with an unapproved plan" [ $? = 2 ]
gt 'git commit -m "feat: x"'; t "guard allows a normal commit" [ $? = 0 ]
printf '0 %s
' "$(. "$p/.claude/hooks/lodestar-lib.sh"; cd "$p"; criteria_hash < .ai/plans/active/a.md)" > "$p/.ai/approvals.log"
gt "$tfc"; t "guard blocks a Tests-First commit when the plan and approvals.log are not staged" [ $? = 2 ]
gt "git add -A && $tfc"; t "guard allows a Tests-First commit that stages everything" [ $? = 0 ]
git -C "$p" add -A; gt "$tfc"; t "guard allows a Tests-First commit with the approved plan staged" [ $? = 0 ]
git -C "$p" rm --cached -q .ai/approvals.log; echo .ai/approvals.log > "$p/.gitignore"; gt "git add -A && $tfc"; t "guard blocks a Tests-First commit when approvals.log is gitignored" [ $? = 2 ]

# 12. Link checker (scripts/check-links.sh) catches a broken reference.
p=$tmp/links; mkdir -p "$p/rules"; git -C "$p" init -q
printf 'See `rules/nope.md` and [x](gone.md).
' > "$p/rules/a.md"; git -C "$p" add -A
bash "$here/../scripts/check-links.sh" "$p" >/dev/null; t "link checker fails on broken links" [ $? = 1 ]
printf 'See `rules/a.md`.
' > "$p/rules/a.md"
bash "$here/../scripts/check-links.sh" "$p" >/dev/null; t "link checker passes on good links" [ $? = 0 ]

# 22. AGENTS.md is the instructions file (Claude and Codex). Claude skips it
#     when CLAUDE.md has its own text, so CLAUDE.md may only be "@AGENTS.md".
p=$tmp/own; mkdir -p "$p"; git -C "$p" init -q; printf '# Mine\nKeep me.\n' > "$p/CLAUDE.md"
bash "$here/bootstrap.sh" "$p" --stack python >/dev/null
t "bootstrap moves a project's own CLAUDE.md to AGENTS.md" bash -c 'grep -q "Keep me." "$1/AGENTS.md" && [ ! -e "$1/CLAUDE.md" ]' _ "$p"
p=$tmp/a1b; cp -r "$tmp/py" "$p"
doc() { bash "$p/.claude/hooks/doctor.sh" "$p"; }
printf '@AGENTS.md\n' > "$p/CLAUDE.md"; out=$(doc)
t "doctor accepts CLAUDE.md that only imports AGENTS.md" grep -qE '✅ A1b ' <<<"$out"
printf '# Other rules\n' > "$p/CLAUDE.md"; out=$(doc); rc=$?
t "doctor fails on a CLAUDE.md with its own text (A1b)" bash -c '[ $1 = 1 ] && grep -qE "❌ A1b " <<<"$2"' _ "$rc" "$out"
h=$tmp/home6; mkdir -p "$h/.codex"; sm "$h"
t "setup writes the Lodestar block to ~/.codex/AGENTS.md" bash -c 'grep -q "lodestar-harness:begin" "$1" && cmp -s <(sed -n "/:begin/,/:end/p" "$1") <(sed -n "/:begin/,/:end/p" "$2")' _ "$h/.codex/AGENTS.md" "$h/.claude/CLAUDE.md"
before=$(cksum "$h/.codex/AGENTS.md"); sm "$h"
t "second setup run leaves ~/.codex/AGENTS.md alone" [ "$before" = "$(cksum "$h/.codex/AGENTS.md")" ]
h=$tmp/home7; mkdir -p "$h/.codex" "$h/orca/home"
CODEX_HOME=$h/orca/home SETUP_HOME=$h CLAUDE_SETTINGS=$h/.claude/settings.json bash "$here/setup-machine.sh" --no-selftest >/dev/null 2>&1
t "setup writes AGENTS.md to both ~/.codex and CODEX_HOME" bash -c 'grep -q "lodestar-harness:begin" "$1/.codex/AGENTS.md" && grep -q "lodestar-harness:begin" "$1/orca/home/AGENTS.md"' _ "$h"

# 23. Codex runs the same hooks through codex-hook.sh (.codex/hooks.json).
#     Codex sends Claude's JSON, except file edits: one apply_patch with the
#     paths inside the patch text, absolute or relative to the session cwd.
p=$tmp/cx; mkdir -p "$p/sub"; git -C "$p" init -q
bash "$here/bootstrap.sh" "$p" --stack python >/dev/null
printf 'lint-file:\n\t@! grep -q BAD "$(FILE)" || { echo "BAD found in $(FILE)"; exit 1; }\nverify:\n\t@[ ! -f fail ] || { echo "tests fail"; exit 1; }\n' > "$p/Makefile"
echo ok > "$p/good.txt"; echo BAD > "$p/bad.txt"
t "bootstrap installs .codex/hooks.json and the adapter" bash -c '[ -f "$1/.codex/hooks.json" ] && [ -f "$1/.claude/hooks/codex-hook.sh" ]' _ "$p"
out=$(bash "$p/.claude/hooks/doctor.sh" "$p"); t "doctor A4b passes on a bootstrapped project" grep -qE '✅ A4b ' <<<"$out"
# Trust is kept per Codex home, so A4c names the home it checked.
mkdir -p "$tmp/fakecodex" "$tmp/cxhome"; printf '#!/bin/sh\n' > "$tmp/fakecodex/codex"; chmod +x "$tmp/fakecodex/codex"
cxdoc() { CODEX_HOME=$tmp/cxhome PATH="$tmp/fakecodex:$PATH" bash "$p/.claude/hooks/doctor.sh" "$p"; }
out=$(cxdoc); t "doctor A4c warns and names the Codex home it checked" grep -qE "⚠️ +A4c .*checked $tmp/cxhome;" <<<"$out"
printf '[hooks.state."%s/.codex/hooks.json:stop:0:0"]\ntrusted_hash = "x"\n' "$(cd "$p" && { pwd -W 2>/dev/null || pwd; })" > "$tmp/cxhome/config.toml"
out=$(cxdoc); t "doctor A4c warns on stale trust in that home" grep -qE "⚠️ +A4c .*checked $tmp/cxhome;" <<<"$out"
# Run the hook exactly as .codex/hooks.json words it, from a subfolder, with a
# CLAUDE_PROJECT_DIR inherited from elsewhere (as when Claude starts Codex).
cxcmd() { jq -r --arg e "$1" --arg h "$2'" '.hooks[$e][].hooks[].command | select(endswith(" " + $h))' "$p/.codex/hooks.json"; }
cx() { local cmd; cmd=$(cxcmd "$1" "$2"); [ -n "$cmd" ] || return 99
  (cd "$p/sub" && CLAUDE_PROJECT_DIR=$tmp sh -c "$cmd" 2>/dev/null <<<"$3"); }
patch() { jq -n --arg c "$1" --arg d "$(native "$p/sub")" '{tool_name:"apply_patch", cwd:$d, tool_input:{command:$c}}'; }
w=$(native "$p"); w=${w//\//\\}   # Codex writes Windows paths with backslashes
cx PreToolUse protect-tests "$(patch "*** Begin Patch
*** Add File: $w\\sub\\a.txt
+hi
*** Update File: $w\\.ai\\approvals.log
@@
+x
*** End Patch")"; t "codex: a patch touching the approvals log is blocked, even as 2nd file" [ $? = 2 ]
cx PreToolUse protect-tests "$(patch "*** Begin Patch
*** Update File: ../.ai/approvals.log
*** End Patch")"; t "codex: a relative ../ path is resolved and blocked" [ $? = 2 ]
cx PreToolUse protect-tests "$(patch "*** Begin Patch
*** Add File: a.txt
+hi
*** End Patch")"; t "codex: an ordinary patch passes" [ $? = 0 ]
for hdr in "*** Update File: ../.ai/approvals.log  " "  *** Update File: ../.ai/approvals.log" "*** Delete File: ../.ai/approvals.log" \
           "*** Update File: a.txt
*** Move to: ../.ai/approvals.log"; do
  cx PreToolUse protect-tests "$(patch "*** Begin Patch
$hdr")"; rc=$?; t "codex: blocked: $(tr '\n' ' ' <<<"$hdr")" [ $rc = 2 ]
done
cx PreToolUse protect-tests "$(patch "*** Begin Patch
+x
*** End Patch")"; t "codex: a patch with no file line is blocked (cannot be checked)" [ $? = 2 ]
sed -i 's|^  - \[path/or/glob\]|  - app/money.py|' "$p/.ai/project.md"
cx PreToolUse sensitive-gate "$(patch "*** Begin Patch
*** Add File: ../app/money.py
+x
*** End Patch")"; t "codex: sensitive code without an approved plan is blocked" [ $? = 2 ]
cx PreToolUse sensitive-gate "$(patch "*** Begin Patch
*** Add File: ../tests/test_money.py
+x
*** End Patch")"; t "codex: tests for sensitive code may be written first" [ $? = 0 ]
cx PostToolUse lint-file "$(patch "*** Begin Patch
*** Update File: $w\\good.txt
*** Update File: $w\\bad.txt
*** End Patch")"; t "codex: lint hook blocks a bad file in the patch" [ $? = 2 ]
cx PreToolUse guard-install '{"tool_name":"Bash","tool_input":{"command":"pip install ruff"}}'
t "codex: install guard blocks a global pip install" [ $? = 2 ]
touch "$p/fail"
cx Stop verify-before-stop '{"stop_hook_active":false}'; t "codex: stop hook blocks while verify fails" [ $? = 2 ]
cx Stop verify-before-stop '{"stop_hook_active":true}'; t "codex: stop hook lets go on the second attempt" [ $? = 0 ]
rm "$p/fail"
cx Stop verify-before-stop '{"stop_hook_active":false}'; t "codex: stop hook passes when verify passes" [ $? = 0 ]
# Without jq the hooks would let everything through: the adapter blocks and
# says why, but still lets a Stop end on the second attempt.
fb=$tmp/nojq; mkdir -p "$fb"
for c in git cat grep; do printf '#!/bin/sh\nexec "%s" "$@"\n' "$(command -v $c)" > "$fb/$c"; chmod +x "$fb/$c"; done
nojq() { (cd "$p" && PATH=$fb "$BASH" .claude/hooks/codex-hook.sh "$1" 2>/dev/null <<<"$2"); }
nojq guard-install '{"tool_name":"Bash","tool_input":{"command":"git status"}}'; t "codex: without jq the adapter blocks" [ $? = 2 ]
nojq verify-before-stop '{"stop_hook_active": true}'; t "codex: without jq a repeated Stop may end" [ $? = 0 ]
# On Windows Codex runs commandWindows in PowerShell, where plain `bash` may be
# WSL's; the command finds Git Bash through git and keeps the exit code.
if command -v powershell.exe >/dev/null; then
  cmd=$(jq -r '.hooks.PreToolUse[1].hooks[0].commandWindows' "$p/.codex/hooks.json")
  (cd "$p/sub" && powershell.exe -NoProfile -Command "$cmd" 2>/dev/null <<<'{"tool_name":"Bash","tool_input":{"command":"pip install ruff"}}')
  t "codex: the Windows command blocks through PowerShell (exit 2)" [ $? = 2 ]
fi
jq '.hooks.Stop += [{"hooks":[{"type":"command","command":"mine"}]}]' "$p/.codex/hooks.json" > "$tmp/cxh" && mv "$tmp/cxh" "$p/.codex/hooks.json"
jq '(.hooks.Stop[0].hooks[0].commandWindows) = "old"' "$p/.codex/hooks.json" > "$tmp/cxh" && mv "$tmp/cxh" "$p/.codex/hooks.json"
bash "$here/bootstrap.sh" "$p" --stack python >/dev/null
t "bootstrap brings our hooks' other fields (commandWindows) up to date" jq -e '.hooks.Stop[0].hooks[0].commandWindows | startswith("& ")' "$p/.codex/hooks.json"
t "bootstrap keeps the project's own Codex hooks" jq -e '[.hooks.Stop[].hooks[].command] | index("mine") != null' "$p/.codex/hooks.json"

# 24. Templates checked out as CRLF (Windows, core.autocrlf=true) install as
# LF, and --upgrade does not rewrite a file whose content is the same.
src=$tmp/crlfsrc; mkdir -p "$src"; cp -r "$here" "$src/enforcement"; cp -r "$here/../project" "$src/project"
sed -i 's/$/\r/' "$src/enforcement/github/ci.yml" "$src/enforcement/agents/claude/settings.json" "$src/enforcement/project/AGENTS.md"
p=$tmp/crlf; mkdir -p "$p"; git -C "$p" init -q
bash "$src/enforcement/bootstrap.sh" "$p" --stack node-ts >/dev/null
# Not grep: Git Bash's grep drops the CR before matching.
lf() { local f; for f in "$@"; do tr -d '\r' < "$f" | cmp -s - "$f" || return 1; done; }
same() { tr -d '\r' < "$1" | cmp -s - "$2"; }   # the template may itself be checked out as CRLF
lf "$src/enforcement/github/ci.yml"; t "the test templates are CRLF" [ $? = 1 ]
t "CRLF templates install as LF" lf "$p/.github/workflows/ci.yml" "$p/.claude/settings.json" "$p/AGENTS.md"
t "an installed template has the template's content" same "$here/github/ci.yml" "$p/.github/workflows/ci.yml"
out=$(bash "$src/enforcement/bootstrap.sh" "$p" --stack node-ts --upgrade)
t "upgrade from CRLF templates rewrites no unchanged file" bash -c '! grep -qE "created|updated|merged" <<<"$1"' _ "$out"
echo "# edited" >> "$p/.github/workflows/ci.yml"
bash "$src/enforcement/bootstrap.sh" "$p" --stack node-ts --upgrade >/dev/null
t "upgrade from CRLF templates still restores a changed file, as LF" same "$here/github/ci.yml" "$p/.github/workflows/ci.yml"

# 25. node-ts at the repo root: Prettier skips the hook configs jq writes.
t "node-ts project gets .claude/ and .codex/ in .prettierignore" bash -c 'grep -qxF .claude/ "$1" && grep -qxF .codex/ "$1"' _ "$p/.prettierignore"
t "a second run adds no duplicate .prettierignore lines" [ "$(grep -cxE '\.(claude|codex)/' "$p/.prettierignore")" = 2 ]
p=$tmp/pignore; mkdir -p "$p"; git -C "$p" init -q; printf 'dist/\n.claude/\ndocs' > "$p/.prettierignore"
bash "$here/bootstrap.sh" "$p" --stack node-ts >/dev/null
t "an existing .prettierignore keeps its lines and gains the missing one" [ "$(cat "$p/.prettierignore")" = "$(printf 'dist/\n.claude/\ndocs\n.codex/')" ]
t "a python project gets no .prettierignore" [ ! -e "$tmp/py/.prettierignore" ]
p=$tmp/pparts; mkdir -p "$p"; git -C "$p" init -q
bash "$here/bootstrap.sh" "$p" --stack python=backend --stack node-ts=frontend >/dev/null
t "node-ts in a subdir gets no root .prettierignore" bash -c '[ ! -e "$1/.prettierignore" ] && [ ! -e "$1/frontend/.prettierignore" ]' _ "$p"

bash "$here/test-parity.sh" || failed=1
[ $failed = 0 ] && echo "All tests passed." || { echo "Some tests failed."; exit 1; }
