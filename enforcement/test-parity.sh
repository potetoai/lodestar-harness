#!/usr/bin/env bash
# Tests-first contract for codex-lodestar-parity (C1-C7); C8-C10 also require
# coordinator-recorded live evidence. All projects, approvals and homes here
# are disposable fixtures, never source-task approval evidence.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/lodestar-parity.XXXXXXXX")
cleanup() {
  if [ -n "${parity_regkey:-}" ]; then
    PARITY_KEY="$parity_regkey" powershell.exe -NoProfile -Command 'Remove-Item -LiteralPath $env:PARITY_KEY -Recurse -Force' >/dev/null 2>&1 || :
  fi
  case "$tmp" in /*/lodestar-parity.*) rm -rf -- "$tmp" ;; esac
}
trap cleanup EXIT
unset LODESTAR_SKIP_HOOKS CLAUDE_PROJECT_DIR
parity_home="$tmp/home"
export CODEX_HOME="$parity_home/codex" LODESTAR_STATE_DIR="$tmp/state"
mkdir -p "$parity_home" "$CODEX_HOME"
for required in jq git make; do
  "$required" --version >/dev/null 2>&1 || { echo "Cannot run required fixture tool: $required" >&2; exit 2; }
done
passed=0 failed=0
t() {
  local label=$1; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS $label"; passed=$((passed + 1))
  else
    echo "FAIL $label"; failed=$((failed + 1))
  fi
}
capture() { out=$("$@" 2>&1); rc=$?; }
blocked() { [ "$rc" = 2 ] && [ -n "$out" ]; }
quiet() { [ "$rc" = 0 ] && [ -z "$out" ]; }
notice() { [[ $rc = 0 || $rc = 2 ]] && grep -qiE "$1" <<<"$out"; }
unavailable() { [ "$rc" = 0 ] && grep -qiE 'unavailable|cannot|could not|unsupported|missing|unable|invalid|not found' <<<"$out"; }
native() { (cd "$1" && { pwd -W 2>/dev/null || pwd; }); }
new_project() {
  p="$tmp/$1"; mkdir -p "$p/sub"; git -C "$p" init -q
  git -C "$p" config user.name 'Parity fixture'
  git -C "$p" config user.email 'parity@example.invalid'
  git -C "$p" config core.autocrlf false
  bash "$here/bootstrap.sh" "$p" --stack python >/dev/null 2>&1
  printf 'verify:\n\t@test ! -f fail\nlint-file:\n\t@! grep -q BAD "$(FILE)"\n' > "$p/Makefile"
  printf 'sensitive_paths:\n  - app/money.py\n' > "$p/.ai/project.md"
}
cx() { (cd "$p/sub" && bash "$p/.claude/hooks/codex-hook.sh" "$1" <<<"$2"); }
patch() { jq -nc --arg d "$(native "$p/sub")" --arg c "$1" '{cwd:$d,tool_name:"apply_patch",tool_input:{command:$c}}'; }
mkplan() {
  mkdir -p "$p/.ai/plans/active" "$p/tests"
  printf '## Acceptance criteria\n\n- [ ] %s\n' "$1" > "$p/.ai/plans/active/parity.md"
  local hash
  hash=$(. "$here/agents/claude/hooks/lodestar-lib.sh"; criteria_hash < "$p/.ai/plans/active/parity.md")
  printf '2026-10-13 fixture-owner parity %s\n' "$hash" >> "$p/.ai/approvals.log"
}

# C7: pre-operation guards must validate their input and dependencies.
new_project 'project with spaces'
for spec in 'protect-tests:apply_patch' 'sensitive-gate:apply_patch' 'guard-install:Bash'; do
  hook=${spec%:*}; tool=${spec#*:}
  for bad in '' '{' '[]' 'null' '{}' '{"tool_input":[]}' ; do
    capture cx "$hook" "$bad"
    t "C7 $hook rejects required input [$bad]" blocked
  done
  for bad in '{"command":42}' '{"command":[]}' '{}' ; do
    capture cx "$hook" "$(jq -nc --arg t "$tool" --argjson i "$bad" '{tool_name:$t,tool_input:$i,stop_hook_active:true}')"
    t "C7 $hook rejects wrong tool input $bad despite Stop flag" blocked
  done
done
capture cx protect-tests "$(patch $'*** Begin Patch\n*** Add File: good.txt\n+ok\n*** End Patch')"
t 'C7 valid ordinary patch succeeds' [ "$rc" = 0 ]
capture cx guard-install '{"tool_name":"Bash","tool_input":{"command":"git status"}}'
t 'C7 ordinary Bash succeeds' [ "$rc" = 0 ]
capture cx guard-install '{"tool_name":"Bash","tool_input":{"command":"pip install ruff"},"stop_hook_active":true}'
t 'C7 Stop flag does not bypass install guard' blocked
mv "$p/.claude/hooks/protect-tests.sh" "$p/.claude/hooks/protect-tests.saved"
capture cx protect-tests "$(patch $'*** Begin Patch\n*** Add File: good.txt\n+ok\n*** End Patch')"
t 'C7 missing selected guard fails closed' blocked
mv "$p/.claude/hooks/protect-tests.saved" "$p/.claude/hooks/protect-tests.sh"
cp "$p/.claude/hooks/protect-tests.sh" "$p/.claude/hooks/protect-tests.saved"
printf 'exit 127\n' > "$p/.claude/hooks/protect-tests.sh"
capture cx protect-tests "$(patch $'*** Begin Patch\n*** Add File: good.txt\n+ok\n*** End Patch')"
t 'C7 guard execution failure becomes block with repair diagnostic' blocked
mv "$p/.claude/hooks/protect-tests.saved" "$p/.claude/hooks/protect-tests.sh"
capture cx guard-install '{"tool_name":"unsupported_shell","tool_input":{"command":"pip install ruff"}}'
t 'C7 unsupported applicable shell input is rejected' blocked
mv "$p/.claude/hooks/verify-before-stop.sh" "$p/.claude/hooks/verify-before-stop.saved"
capture cx verify-before-stop '{"stop_hook_active":false}'
t 'C7 missing first Stop verification requests correction' blocked
mv "$p/.claude/hooks/verify-before-stop.saved" "$p/.claude/hooks/verify-before-stop.sh"
mkdir -p "$tmp/no-jq"
for cmd in git cat grep dirname; do
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$(command -v "$cmd")" > "$tmp/no-jq/$cmd"
  chmod +x "$tmp/no-jq/$cmd"
done
no_jq() { (cd "$p" && PATH="$tmp/no-jq" "$BASH" .claude/hooks/codex-hook.sh "$1" <<<"$2"); }
capture no_jq guard-install '{"tool_name":"Bash","tool_input":{"command":"pip install ruff"},"stop_hook_active":true}'
t 'C7 missing jq cannot use Stop flag to bypass preguard' blocked
capture no_jq verify-before-stop '{"stop_hook_active":true}'
t 'C7 genuine repeated verification Stop retains escape' [ "$rc" = 0 ]
outside_guard() { (cd "$tmp" && bash "$p/.claude/hooks/codex-hook.sh" guard-install <<<'{"tool_name":"Bash","tool_input":{"command":"pip install ruff"}}'); }
capture outside_guard
t 'C7 unresolved project blocks applicable guard' blocked

# C5: reconstruct lock updates without altering existing shared semantics.
mkplan 'initial behavior'
printf '# fixture lock\ntests/old.py\n' > "$p/.ai/test-lock"
printf 'assert True\n' > "$p/tests/old.py"
append_patch=$'*** Begin Patch\n*** Update File: ../.ai/test-lock\n@@\n # fixture lock\n tests/old.py\n+tests/new.py\n*** End Patch'
capture cx protect-tests "$(patch "$append_patch")"
t 'C5 approved initial lock accepts additive patch' [ "$rc" = 0 ]
git -C "$p" add -A
git -C "$p" -c core.hooksPath=/dev/null commit -qm 'fixture boundary' -m 'Tests-First: parity'
capture cx protect-tests "$(patch "$append_patch")"
t 'C5 committed approved lock accepts additive patch' [ "$rc" = 0 ]
capture cx protect-tests "$(patch $'*** Begin Patch\n*** Update File: ../.ai/test-lock\n@@\n-tests/old.py\n+tests/new.py\n*** End Patch')"
t 'C5 removal of existing locked path is rejected' blocked
capture cx protect-tests "$(patch $'*** Begin Patch\n*** Update File: ../.ai/test-lock\n@@\n nonexistent context\n+tests/new.py\n*** End Patch')"
t 'C5 unknown lock patch result is rejected' blocked
capture cx protect-tests "$(patch $'*** Begin Patch\n*** Add File: good.txt\n+ok\n*** Update File: ../tests/old.py\n@@\n-assert True\n+assert False\n*** End Patch')"
t 'C5 every file in a patch is guarded' blocked
capture cx protect-tests "$(patch $'*** Begin Patch\n*** Update File: good.txt\n*** Move to: ../tests/old.py\n@@\n-ok\n+changed\n*** End Patch')"
t 'C5 rename destination cannot overwrite locked test' blocked
capture cx protect-tests "$(patch $'*** Begin Patch\n*** Update File: good.txt\n*** Move to: ../.ai/approvals.log\n@@\n-ok\n+changed\n*** End Patch')"
t 'C5 rename destination cannot overwrite approvals' blocked
printf '\n- [ ] unapproved addition\n' >> "$p/.ai/plans/active/parity.md"
capture cx protect-tests "$(patch "$append_patch")"
t 'C5 additive lock change needs current criteria approval' blocked
mkplan 'fresh approved behavior'
capture cx protect-tests "$(patch $'*** Begin Patch\n*** Update File: ../tests/old.py\n@@\n-assert True\n+assert False\n*** End Patch')"
t 'C5 approved relock allows changed tests' [ "$rc" = 0 ]
mv "$p/.ai/plans/active/parity.md" "$p/.ai/plans/completed/parity.md"
capture cx protect-tests "$(patch $'*** Begin Patch\n*** Update File: ../tests/old.py\n@@\n-assert True\n+assert False\n*** End Patch')"
t 'C5 completed plan expires lock' [ "$rc" = 0 ]
capture cx sensitive-gate "$(patch $'*** Begin Patch\n*** Update File: good.txt\n*** Move to: ../app/money.py\n@@\n-ok\n+changed\n*** End Patch')"
t 'C5 sensitive rename destination requires approved active plan' blocked

# C2/C4: Codex transcript structures observed by the coordinator on 2026-10-13.
# Content below is synthetic. Schema observations are not live hook evidence.
# Metadata classifies owner content; role=user alone does not establish it.
transcript="$tmp/codex.jsonl"
owner() {
  printf '%s\n' '{"type":"session_meta","payload":{"source":"cli","thread_source":"user"}}' > "$transcript"
  jq -nc --arg m "$1" --arg id "$2" '{type:"response_item",payload:{type:"message",id:$id,role:"user",content:[{type:"input_text",text:$m}],internal_chat_message_metadata_passthrough:{turn_id:$id,create_time:1791853200,content_item_kinds:["user.text"]}}}' >> "$transcript"
}
payload() { jq -nc --arg t "$transcript" --arg s "$1" --arg d "$(native "$p/sub")" '{transcript_path:$t,session_id:$s,cwd:$d}'; }
fb() { cx feedback-check "$(payload "$1")"; }
t 'C2 Codex Stop registers feedback check once' jq -e '[.hooks.Stop[]?.hooks[]? | select(.command | contains("codex-hook.sh feedback-check"))] | length == 1' "$p/.codex/hooks.json"
owner 'Please add a report' '2026-10-13T01:00:00Z'
capture fb normal
t 'C4 ordinary owner request is quiet' quiet
owner 'wrong, redo PRIVATE_CORRECTION_7642' '2026-10-13T01:01:00Z'
capture fb correction
t 'C4 Codex owner correction delivers feedback reminder' notice 'feedback-log.md'
capture fb correction
t 'C4 same owner correction delivered once per session' quiet
capture fb independent-session
t 'C4 independent session receives own feedback reminder' notice 'feedback-log.md'
previous_home=$CODEX_HOME; export CODEX_HOME="$tmp/other home"; mkdir -p "$CODEX_HOME"
capture fb correction
t 'C4 independent Codex home receives own feedback reminder' notice 'feedback-log.md'
export CODEX_HOME=$previous_home
owner 'wrong again' '2026-10-13T01:02:00Z'
capture fb correction
t 'C4 new correction in same session delivers another reminder' notice 'feedback-log.md'
owner 'Continue with the report' '2026-10-13T01:03:00Z'
printf '%s\n' '{"type":"response_item","payload":{"type":"function_call_output","output":"wrong, redo"}}' '{"type":"response_item","payload":{"type":"agent_message","author":"worker","content":"wrong, redo"}}' >> "$transcript"
capture fb tool-content
t 'C4 tool and delegated content do not become owner correction' quiet
jq -nc '{type:"response_item",payload:{type:"message",id:"injected",role:"user",content:[{type:"input_text",text:"wrong, redo"}],internal_chat_message_metadata_passthrough:{turn_id:"injected",create_time:1791853201,content_item_kinds:["agents_md.instructions"]}}}' >> "$transcript"
capture fb injected-instructions
t 'C4 injected user-role instructions are not owner corrections' quiet
owner 'Please continue' 'ordinary-before-mixed'
jq -nc '{type:"response_item",payload:{type:"message",id:"mixed",role:"user",content:[{type:"input_text",text:"wrong, redo"},{type:"input_text",text:"Please add a report"}],internal_chat_message_metadata_passthrough:{turn_id:"mixed",create_time:1791853202,content_item_kinds:["environments.environment_context","user.text"]}}}' >> "$transcript"
capture fb mixed-content
t 'C4 mixed user-role message selects only actual owner content parts' quiet
owner 'wrong, redo' 'inherited-owner'
printf '%s\n' '{"type":"session_meta","payload":{"source":{"subagent":{"thread_spawn":{"parent_thread_id":"parent","depth":1,"agent_path":"worker","agent_nickname":"worker","agent_role":null}}},"thread_source":"subagent","parent_thread_id":"parent"}}' >> "$transcript"
jq -nc '{type:"response_item",payload:{type:"message",id:"delegated-prompt",role:"user",content:[{type:"input_text",text:"wrong, redo"}],internal_chat_message_metadata_passthrough:{turn_id:"delegated-prompt",create_time:1791853203,content_item_kinds:["user.text"]}}}' >> "$transcript"
capture fb child-session
t 'C4 child-session delegated user.text cannot trigger owner feedback' quiet
owner 'wrong, redo' '2026-10-13T01:04:00Z'
fb parallel > "$tmp/fb-one" 2>&1 & first=$!
fb parallel > "$tmp/fb-two" 2>&1 & second=$!
wait "$first" || :; wait "$second" || :
t 'C4 concurrent feedback invocation delivers exactly once' bash -c '[ "$(grep -l feedback-log.md "$1" "$2" | wc -l)" = 1 ]' _ "$tmp/fb-one" "$tmp/fb-two"
t 'C4 feedback state stores no correction text' bash -c '! grep -Rqs PRIVATE_CORRECTION_7642 "$1" "$2" "$3"' _ "$LODESTAR_STATE_DIR" "$parity_home" "$p/.git"
capture cx feedback-check "$(jq -nc --arg t "$transcript" '{transcript_path:$t}')"
t 'C4 missing feedback session identity is advisory unavailable' unavailable
owner 'wrong, redo' 'identity-to-remove'
jq 'if .type == "response_item" then .payload |= del(.id,.internal_chat_message_metadata_passthrough.turn_id,.internal_chat_message_metadata_passthrough.create_time) else . end' "$transcript" > "$tmp/no-identity"
cp "$tmp/no-identity" "$transcript"
capture fb no-message-identity
t 'C4 missing owner message identity is advisory unavailable' unavailable
printf '{"unrecognized":"schema"}\n' > "$transcript"
capture fb unsupported
t 'C4 unsupported feedback transcript is advisory unavailable' unavailable
transcript="$tmp/absent.jsonl"; capture fb absent
t 'C4 absent feedback transcript is advisory unavailable' unavailable

# C1/C2/C4: global adapter honors cwd and separates current usage from totals.
global="$here/agents/codex/global/codex-global-hook.sh"
global_hook() { bash "$global" "$1" "${@:3}" <<<"$2"; }
mkdir -p "$tmp/source/enforcement" "$tmp/source/.ai" "$tmp/unready" "$tmp/ready/.claude/hooks"
for root in source unready ready; do git -C "$tmp/$root" init -q; done
touch "$tmp/source/enforcement/bootstrap.sh" "$tmp/source/.ai/handoff.md"
capture global_hook check-readiness "$(jq -nc --arg d "$(native "$tmp/source")" '{cwd:$d}')"
t 'C1 source exemption preserves handoff reminder' notice 'handoff.md'
t 'C1 source exemption does not demand onboarding' bash -c '[ "$1" = 0 ] && ! grep -qiE "LODESTAR GATE|must be onboarded" <<<"$2"' _ "$rc" "$out"
capture global_hook check-readiness "$(jq -nc --arg d "$(native "$tmp/unready")" '{cwd:$d}')"
t 'C1 unready project gets session readiness guidance' notice 'onboard|LODESTAR GATE'
capture global_hook check-readiness "$(jq -nc --arg d "$(native "$tmp/unready")" '{cwd:$d}')" --prompt
t 'C2 owner prompt gets readiness guidance' notice 'onboard|LODESTAR GATE'
printf '#!/usr/bin/env bash\nprintf "⚠️ D1 maintenance overdue\\n"\n' > "$tmp/ready/.claude/hooks/doctor.sh"
capture global_hook check-readiness "$(jq -nc --arg d "$(native "$tmp/ready")" '{cwd:$d}')"
t 'C2 ready project receives due maintenance reminder' notice 'maintenance'
capture global_hook check-readiness "$(jq -nc --arg d "$(native "$tmp")" '{cwd:$d}')"
t 'C7 global non-project event is harmless' quiet

transcript="$tmp/context.jsonl"
usage() { jq -nc --argjson current "$1" --argjson total "$2" '{timestamp:"2026-10-13T02:00:00Z",type:"event_msg",payload:{type:"token_count",info:{last_token_usage:{input_tokens:$current,cached_input_tokens:$current,cache_write_input_tokens:0,output_tokens:100,reasoning_output_tokens:0,total_tokens:($current+100)},total_token_usage:{input_tokens:$total}}}}' > "$transcript"; }
nudge() { global_hook context-nudge "$(payload "$1")"; }
usage 100 999999
capture nudge context
t 'C4 context uses current usage not cumulative total' quiet
usage 150000 999999
capture nudge cached-context
t 'C4 Codex cached input is not counted twice' quiet
usage 1000 1000
LODESTAR_NUDGE_AT=500 capture nudge configured-threshold
t 'C2 configured context threshold supports live reminder smoke' notice 'handoff.md'
usage 210000 999999
capture nudge context
t 'C4 current context threshold produces handoff reminder' notice 'handoff.md'
capture nudge context
t 'C4 context band reminder is deduplicated' quiet
usage 310000 999999
capture nudge context
t 'C4 next context band produces another reminder' notice 'handoff.md'
usage 100 999999
capture nudge context
t 'C4 compacted current context is quiet despite prior total' quiet
usage 210000 999999
capture nudge context-other
t 'C4 context state isolates sessions' notice 'handoff.md'
previous_home=$CODEX_HOME; export CODEX_HOME="$tmp/other home"
capture nudge context
t 'C4 context state isolates homes' notice 'handoff.md'
export CODEX_HOME=$previous_home
nudge context-concurrent > "$tmp/ctx-one" 2>&1 & first=$!
nudge context-concurrent > "$tmp/ctx-two" 2>&1 & second=$!
wait "$first" || :; wait "$second" || :
t 'C4 concurrent context invocation delivers exactly once' bash -c '[ "$(grep -l handoff.md "$1" "$2" | wc -l)" = 1 ]' _ "$tmp/ctx-one" "$tmp/ctx-two"
printf 'not a supported transcript\n' > "$transcript"
capture nudge unsupported-context
t 'C4 unsupported context is advisory unavailable' unavailable
transcript="$tmp/no-context.jsonl"; capture nudge absent-context
t 'C4 absent context transcript is advisory unavailable' unavailable
transcript="$tmp/context.jsonl"; usage 210000 999999
capture global_hook context-nudge "$(jq -nc --arg t "$transcript" '{transcript_path:$t}')"
t 'C4 missing context session is advisory unavailable' unavailable
previous_state=$LODESTAR_STATE_DIR; printf 'file blocks state directory\n' > "$tmp/state-file"
export LODESTAR_STATE_DIR="$tmp/state-file/child"
capture nudge state-failure
t 'C4 context state write failure reports unavailable without blocking' unavailable
transcript="$tmp/codex.jsonl"; owner 'wrong, redo' '2026-10-13T02:01:00Z'
capture fb state-failure
t 'C4 feedback state write failure reports unavailable without blocking' unavailable
export LODESTAR_STATE_DIR=$previous_state

# C4 Claude regression: same identifiers in a different runtime are separate.
transcript="$tmp/codex.jsonl"; owner 'wrong, redo' '2026-10-13T02:02:00Z'
capture fb runtime-isolation
printf '{"type":"user","uuid":"2026-10-13T02:02:00Z","message":{"content":"wrong, redo"}}\n' > "$tmp/claude.jsonl"
claude_fb() { CLAUDE_PROJECT_DIR="$p" bash "$p/.claude/hooks/feedback-check.sh" <<<"$(jq -nc --arg t "$tmp/claude.jsonl" '{transcript_path:$t,session_id:"runtime-isolation"}')"; }
capture claude_fb
t 'C4 Claude feedback is not suppressed by matching Codex identity' notice 'feedback-log.md'
capture claude_fb
t 'C4 Claude owner correction still delivers only once' quiet
claude_fb_other() { CLAUDE_PROJECT_DIR="$p" bash "$p/.claude/hooks/feedback-check.sh" <<<"$(jq -nc --arg t "$tmp/claude.jsonl" '{transcript_path:$t,session_id:"different-claude-session"}')"; }
capture claude_fb_other
t 'C4 Claude feedback state also isolates sessions' notice 'feedback-log.md'
transcript="$tmp/context.jsonl"; usage 210000 999999
capture nudge runtime-context
printf '{"type":"assistant","message":{"usage":{"input_tokens":210000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}\n' > "$tmp/claude-context.jsonl"
capture bash "$here/agents/claude/global/context-nudge.sh" <<<"$(jq -nc --arg t "$tmp/claude-context.jsonl" '{transcript_path:$t,session_id:"runtime-context"}')"
t 'C4 Claude context is not suppressed by matching Codex session' notice 'handoff.md'

# C3: install and upgrade preserve unrelated registrations, reject malformed
# structures without changing bytes, and correct event/matcher registration.
installer="$here/agents/codex/global/install.sh"
install_global() { CODEX_HOME="$1" bash "$installer"; }
home="$tmp/global home with spaces"; mkdir -p "$home"
printf '%s\n' '{"custom":"preserve","hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"orca hooks start"},{"type":"command","command":"bash /custom/codex-global-hook.sh check-readiness"}]}]}}' > "$home/hooks.json"
capture install_global "$home"
t 'C3 global installer succeeds in home with spaces' [ "$rc" = 0 ]
t 'C3 global installer preserves Orca and same-named unrelated command' jq -e '.custom == "preserve" and ([.hooks.SessionStart[].hooks[].command] | index("orca hooks start") != null and index("bash /custom/codex-global-hook.sh check-readiness") != null)' "$home/hooks.json"
for spec in 'SessionStart:check-readiness' 'UserPromptSubmit:check-readiness' 'PostToolUse:context-nudge'; do
  event=${spec%:*}; check=${spec#*:}
  t "C2 global registration $event $check includes Windows entry point" jq -e --arg e "$event" --arg c "$check" '[.hooks[$e][]?.hooks[]? | select((.command | contains($c)) and (.commandWindows | type == "string"))] | length == 1' "$home/hooks.json"
done
before=$(cksum "$home/hooks.json")
capture install_global "$home"
t 'C3 second global install is idempotent' bash -c '[ "$1" = 0 ] && [ "$2" = "$3" ]' _ "$rc" "$before" "$(cksum "$home/hooks.json")"
t 'C6 global installer never grants hook trust' test ! -f "$home/config.toml"
# An installed definition from a former source location is managed, unlike
# the similarly named /custom command above. The installer owns migration.
mkdir -p "$tmp/old source"
cp -r "$here" "$tmp/old source/enforcement"
old_installer="$tmp/old source/enforcement/agents/codex/global/install.sh"
stale_home="$tmp/stale home"; mkdir -p "$stale_home"
capture env CODEX_HOME="$stale_home" bash "$old_installer"
registered_readiness() {
  local cmd field=command
  command -v powershell.exe >/dev/null && field=commandWindows
  cmd=$(jq -r --arg f "$field" '[.hooks.SessionStart[]?.hooks[]? | select(.command | contains("check-readiness"))][0][$f] // empty' "$stale_home/hooks.json" 2>/dev/null)
  [ -n "$cmd" ] || return 99
  if [ "$field" = commandWindows ]; then
    powershell.exe -NoProfile -Command "$cmd" <<<"$(jq -nc --arg d "$(native "$tmp/source")" '{cwd:$d}')"
  else
    bash -c "$cmd" <<<"$(jq -nc --arg d "$(native "$tmp/source")" '{cwd:$d}')"
  fi
}
capture registered_readiness
t 'C3 installed global command executes from source path with spaces' notice 'handoff.md'
capture install_global "$stale_home"
t 'C3 moved source replaces managed global registrations without duplicates' jq -e '[.hooks[][]?.hooks[]? | select(.command | contains("codex-global-hook.sh"))] | length == 3 and all(.command | contains("old source") | not)' "$stale_home/hooks.json"
if [ -f "$stale_home/hooks.json" ]; then
  jq '.hooks.PostToolUse |= map(.matcher = "WrongTool")' "$stale_home/hooks.json" > "$tmp/changed-hooks"
  cp "$tmp/changed-hooks" "$stale_home/hooks.json"
fi
capture install_global "$stale_home"
t 'C3 global upgrade restores reminder matcher exactly once' jq -e '[.hooks.PostToolUse[]? | select(.matcher == "*") | .hooks[]? | select(.command | contains("context-nudge"))] | length == 1' "$stale_home/hooks.json"
for malformed in '{' '{"hooks":[]}' '{"hooks":{"Stop":{}}}' '{"hooks":{"Stop":[{"hooks":"not an array"}]}}'; do
  printf '%s\n' "$malformed" > "$home/hooks.json"; before=$(cksum "$home/hooks.json")
  capture install_global "$home"
  t "C3 malformed global configuration rejected [$malformed]" bash -c '[ "$1" != 0 ] && [ -n "$2" ] && [ "$3" = "$4" ]' _ "$rc" "$out" "$before" "$(cksum "$home/hooks.json")"
done

# setup-machine owns both default and active-home coverage. Only a scratch
# registry key is passed to its existing Windows PATH interface.
machine_home="$tmp/machine home"; active_home="$machine_home/orca active"
mkdir -p "$machine_home/.codex" "$active_home"
for h in "$machine_home/.codex" "$active_home"; do
  printf '%s\n' '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"orca hooks start"}]}]}}' > "$h/hooks.json"
done
if command -v powershell.exe >/dev/null; then
  parity_regkey="HKCU:\\Software\\LodestarParityTest-$$"
  PARITY_KEY="$parity_regkey" powershell.exe -NoProfile -Command 'New-Item -Path $env:PARITY_KEY -Force | Out-Null; Set-ItemProperty -LiteralPath $env:PARITY_KEY -Name Path -Value "C:\Scratch" -Type ExpandString' >/dev/null
fi
machine_setup() { SETUP_HOME="$machine_home" CODEX_HOME="$active_home" CLAUDE_SETTINGS="$machine_home/.claude/settings.json" LODESTAR_PATH_KEY="${parity_regkey:-}" bash "$here/setup-machine.sh" --no-selftest --yes; }
capture machine_setup
for h in "$machine_home/.codex" "$active_home"; do
  t "C3 setup installs global hooks in $h" jq -e '[.hooks.SessionStart[]?.hooks[]? | select((.command | contains("codex-global-hook.sh")) and (.command | contains("check-readiness")))] | length == 1' "$h/hooks.json"
  t "C3 setup preserves Orca hook in $h" jq -e '[.hooks.SessionStart[].hooks[].command] | index("orca hooks start") != null' "$h/hooks.json"
  t "C1 setup writes shared Router instructions in $h" grep -q 'lodestar-harness:begin' "$h/AGENTS.md"
done
before=$(cksum "$machine_home/.codex/hooks.json" "$active_home/hooks.json")
capture machine_setup
t 'C3 dual-home machine setup is idempotent' test "$before" = "$(cksum "$machine_home/.codex/hooks.json" "$active_home/hooks.json")"
t 'C6 machine setup grants no default or active-home trust' bash -c '[ ! -f "$1/config.toml" ] && [ ! -f "$2/config.toml" ]' _ "$machine_home/.codex" "$active_home"

new_project upgrade
cp "$p/.codex/hooks.json" "$tmp/good-hooks.json"
jq '.hooks.PreToolUse |= map(if .matcher == "apply_patch" then .matcher = "WrongTool" else . end)' "$tmp/good-hooks.json" > "$p/.codex/hooks.json"
capture bash "$p/.claude/hooks/doctor.sh" "$p"
t 'C6 doctor rejects guards registered for wrong matcher' bash -c '! grep -qE "✅ A4b " <<<"$1"' _ "$out"
jq '.hooks.SessionStart = .hooks.PreToolUse | del(.hooks.PreToolUse)' "$tmp/good-hooks.json" > "$p/.codex/hooks.json"
capture bash "$p/.claude/hooks/doctor.sh" "$p"
t 'C6 doctor rejects guards registered on wrong event' bash -c '! grep -qE "✅ A4b " <<<"$1"' _ "$out"
capture bash "$here/bootstrap.sh" "$p" --stack python --upgrade
t 'C3 upgrade restores guards to required event and matcher once' jq -e '[.hooks.PreToolUse[]? | select(.matcher == "apply_patch") | .hooks[] | select(.command | contains("codex-hook.sh protect-tests"))] | length == 1' "$p/.codex/hooks.json"
t 'C3 upgrade removes obsolete managed registration on wrong event' jq -e '[.hooks.SessionStart[]?.hooks[]? | select(.command | contains("codex-hook.sh protect-tests"))] | length == 0' "$p/.codex/hooks.json"
jq '.hooks.Stop += [{hooks:[{type:"command",command:"bash /custom/codex-hook.sh verify-before-stop"},{type:"command",command:"orca hooks stop"}]}] | .custom = "preserve"' "$tmp/good-hooks.json" > "$p/.codex/hooks.json"
capture bash "$here/bootstrap.sh" "$p" --stack python --upgrade
t 'C3 project upgrade preserves same-named custom hook and Orca settings' jq -e '.custom == "preserve" and ([.hooks.Stop[].hooks[].command] | index("bash /custom/codex-hook.sh verify-before-stop") != null and index("orca hooks stop") != null)' "$p/.codex/hooks.json"
for malformed in '{' '{"hooks":[]}' '{"hooks":{"PreToolUse":{}}}'; do
  printf '%s\n' "$malformed" > "$p/.codex/hooks.json"; before=$(cksum "$p/.codex/hooks.json")
  capture bash "$here/bootstrap.sh" "$p" --stack python --upgrade
  t "C3 malformed project configuration rejected [$malformed]" bash -c '[ "$1" != 0 ] && [ "$2" = "$3" ]' _ "$rc" "$before" "$(cksum "$p/.codex/hooks.json")"
done
cp "$tmp/good-hooks.json" "$p/.codex/hooks.json"
mkdir -p "$tmp/bin" "$tmp/trust home"
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/codex"; chmod +x "$tmp/bin/codex"
printf '[hooks.state."%s/.codex/hooks.json:stop:0:0"]\ntrusted_hash = "stale-fixture-hash"\n' "$(native "$p")" > "$tmp/trust home/config.toml"
capture env CODEX_HOME="$tmp/trust home" PATH="$tmp/bin:$PATH" bash "$p/.claude/hooks/doctor.sh" "$p"
t 'C6 stale Stop trust cannot report trusted hooks' bash -c '! grep -qE "✅ A4c " <<<"$1" && grep -qiE "unverified|stale|untrusted|unknown|changed|/hooks" <<<"$1"' _ "$out"

echo "Parity tests: $passed passed, $failed failed."
[ "$failed" = 0 ]
