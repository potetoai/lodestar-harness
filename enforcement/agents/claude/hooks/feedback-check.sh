#!/usr/bin/env bash
# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# Stop: when the owner's last message looks like a correction ("sai", "nhầm",
# "làm lại", "wrong"...), hold the agent once and ask it to judge: if it made
# a mistake, it logs one summary row in .ai/feedback-log.md
# (rules/enforcement.md, section 8). Only hashed message identifiers persist.
[ "$LODESTAR_SKIP_HOOKS" = "1" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ -f .ai/feedback-log.md ] || exit 0      # not onboarded

here=$(cd "$(dirname "$0")" && pwd)
. "$here/reminder-lib.sh" || { echo 'Lodestar feedback unavailable: missing reminder helper.' >&2; exit 0; }
reminder_input || { advisory_unavailable 'missing or invalid feedback transcript/session/dependency'; exit 0; }
if [ "$runtime" = codex ]; then
  last=$(jq -cs -f "$here/codex-owner.jq" "$transcript" 2>/dev/null) || { advisory_unavailable 'unsupported owner transcript'; exit 0; }
else
  # Read backwards and stop at the owner's last message; long transcripts stay cheap.
  last=$(tac "$transcript" | jq -Rc 'fromjson? | select(.type == "user" and (.message.content | type) == "string" and (.isMeta | not)) | {id:(.promptId // .uuid), text:.message.content}' 2>/dev/null | head -n1 | tr -d '\r')
  [ -n "$last" ] || last=null
fi
[ "$last" != null ] || exit 0
id=$(jq -r '.id // empty' <<<"$last")
text=$(jq -r '.text' <<<"$last")
[ -n "$id" ] || { advisory_unavailable 'missing owner message identity'; exit 0; }

grep -qiE '(^|[^[:alpha:]])(sai|nhầm|nham|làm lại|lam lai|sửa lại|sua lai|không đúng|khong dung|chưa đúng|chua dung|không phải|khong phai|quên|quen mat|wrong|mistake|not what i|redo)([^[:alpha:]]|$)' <<<"$text" || exit 0

reminder_project_dir=$(git rev-parse --absolute-git-dir 2>/dev/null)
reminder_claim feedback "$id"; claimed=$?
[ "$claimed" = 1 ] && exit 0
[ "$claimed" = 0 ] || { advisory_unavailable 'cannot persist feedback reminder state'; exit 0; }
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
