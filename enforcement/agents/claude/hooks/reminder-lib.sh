#!/usr/bin/env bash
# Shared advisory plumbing. Persist only hashed identifiers and context counters.
advisory_unavailable() { echo "Lodestar advisory unavailable: $*" >&2; }
reminder_input() {
  command -v jq >/dev/null && command -v sha256sum >/dev/null || return 1
  # One jq call: these hooks run on every tool call or stop.
  { IFS= read -r transcript && IFS= read -r session; } < <(jq -r 'select(type == "object" and (.session_id | type == "string" and length > 0) and (.transcript_path | type == "string" and length > 0)) | .transcript_path, .session_id' 2>/dev/null | tr -d '\r') || return 1
  [ -r "$transcript" ] && [ -s "$transcript" ] || return 1
  runtime=${LODESTAR_RUNTIME:-claude}
  case $runtime in
    codex) reminder_home=${CODEX_HOME:-$HOME/.codex} ;;
    claude) reminder_home=${CLAUDE_CONFIG_DIR:-$HOME/.claude} ;;
    *) return 1 ;;
  esac
}
# The state key is computed only when a reminder is due.
reminder_state() {
  reminder_home=${reminder_home//\\//}
  if [ -d "$reminder_home" ]; then reminder_home=$(cd "$reminder_home" && { pwd -W 2>/dev/null || pwd; }); fi
  reminder_key=$(printf '%s\0%s\0%s' "$runtime" "$reminder_home" "$session" | sha256sum) || return 1
  reminder_key=${reminder_key%% *}
  # A project hook keeps its state in the project's git dir (reminder_project_dir).
  reminder_dir=${LODESTAR_STATE_DIR:-${reminder_project_dir:-$reminder_home}/lodestar-state}
}
# Return 0 for the unique claim, 1 for an existing claim, 2 if persistence fails.
reminder_claim() {
  local kind=$1 identity=$2 key state lock previous attempt
  reminder_state || return 2
  key=$(printf '%s' "$identity" | sha256sum) || return 2
  key=${key%% *}
  state="$reminder_dir/$reminder_key-$kind"
  mkdir -p "$reminder_dir" 2>/dev/null || return 2
  if [ "$kind" = feedback ]; then
    mkdir "$state-$key" 2>/dev/null && return 0
    [ -d "$state-$key" ] && return 1
    return 2
  fi
  lock="$state.lock"
  for ((attempt=0; attempt<40; attempt++)); do
    mkdir "$lock" 2>/dev/null && break
    [ -d "$lock" ] || return 2
    sleep 0.05
  done
  # A lock older than a minute was left by a process that died holding it.
  # Racing recoveries can at worst repeat one advisory reminder.
  if [ "$attempt" -ge 40 ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
    rm -f "$lock/value"; rmdir "$lock" 2>/dev/null
    mkdir "$lock" 2>/dev/null && attempt=0
  fi
  [ "$attempt" -lt 40 ] || return 2
  previous=0
  if [ -e "$state" ]; then
    previous=$(cat "$state" 2>/dev/null)
    if [[ ! $previous =~ ^[0-9]+$ ]]; then rmdir "$lock"; return 2; fi
  fi
  if [ "$previous" -ge "$identity" ]; then rmdir "$lock"; return 1; fi
  if ! printf '%s\n' "$identity" > "$lock/value" || ! mv "$lock/value" "$state"; then
    rm -f "$lock/value"; rmdir "$lock"; return 2
  fi
  rmdir "$lock" || return 2
}
