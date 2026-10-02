#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# Stop: when the owner's last message looks like a correction ("sai", "nhầm",
# "làm lại", "wrong"...), hold the agent once and ask it to judge: if it made
# a mistake, it logs one summary row in .ai/feedback-log.md
# (rules/enforcement.md, section 8). The hook itself stores nothing: it reads
# the last message from the session transcript and forgets it.
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ -f .ai/feedback-log.md ] || exit 0      # not onboarded

transcript=$(jq -j '.transcript_path // empty')
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

# Last message the owner typed: string content, not a tool result.
last=$(tac "$transcript" | jq -c 'select(.type == "user" and (.message.content | type) == "string" and (.isMeta | not))
  | [(.promptId // .uuid), .message.content]' 2>/dev/null | head -n1 | tr -d '\r')
[ -n "$last" ] || exit 0
id=$(jq -r '.[0]' <<<"$last" | tr -d '\r')
text=$(jq -r '.[1]' <<<"$last" | tr -d '\r')

# Ask at most once per owner message.
state="$(git rev-parse --git-dir 2>/dev/null)/lodestar-feedback-asked"
[ "$(cat "$state" 2>/dev/null)" = "$id" ] && exit 0

grep -qiE '(^|[^[:alpha:]])(sai|nhầm|nham|làm lại|lam lai|sửa lại|sua lai|không đúng|khong dung|chưa đúng|chua dung|không phải|khong phai|quên|quen mat|wrong|mistake|not what i|redo)([^[:alpha:]]|$)' <<<"$text" || exit 0

echo "$id" > "$state" 2>/dev/null
cat >&2 <<'EOF'
Check before finishing: the owner's last message may correct a mistake you made.
- If it does: add one row to .ai/feedback-log.md now: date | short tag (reuse an
  existing tag for the same kind of mistake) | the mistake, in your own words |
  related rule or invariant | open. Do not copy the owner's message.
  If the Lodestar system caused it (missing workflow step, wrong template or hook),
  start the tag with lodestar-, set the status to reported, and tell the owner.
- If it does not (for example bad source data, or a new request): do nothing.
Then finish as usual.
EOF
exit 2
