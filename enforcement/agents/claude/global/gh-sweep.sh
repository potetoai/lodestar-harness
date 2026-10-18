#!/usr/bin/env bash
# Daily GitHub sweep of the projects in the bug inbox (rules/enforcement.md,
# section 8). Run by check-readiness.sh when a lodestar-harness session starts,
# at most once a day. It only reads GitHub and prints what is new since the
# last sweep: merged PRs with no route line or no review, PRs closed unmerged,
# open PRs with failing checks, a failed CI run on main. Silent when nothing is
# new, or when gh, jq or timeout is missing.
# gh-sweep.txt: line 1 is the day of the last full sweep; then one
# "<UTC time> <project>" line per project, its last good sweep. A project
# whose sweep fails keeps its old time, and the next session retries.
inbox=${LODESTAR_INBOX:-$HOME/.lodestar}
stamp=$inbox/gh-sweep.txt
today=$(date +%F)
command -v gh >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || exit 0
to=$(command -v timeout || command -v gtimeout) || exit 0   # a hung gh must not hold the session
[ -f "$stamp" ] && read -r last _ < "$stamp"
[ "$last" = "$today" ] && exit 0
# A project's first sweep looks back one day (GNU date, then BSD).
first=$(date -u -d '1 day ago' +%FT%TZ 2>/dev/null || date -u -v-1d +%FT%TZ)
now=$(date -u +%FT%TZ)

sweep() {   # $1 = project folder, $2 = since; prints "finding<TAB>#n" lines
  local prs runs
  prs=$(cd "$1" && "$to" 10 gh pr list --state all --limit 100 --json number,state,body,mergedAt,closedAt,updatedAt,author,statusCheckRollup) || return 1
  runs=$(cd "$1" && "$to" 10 gh run list --branch main --limit 20 --json conclusion,createdAt,workflowName) || return 1
  jq -r --arg since "$2" '
    def bad: ascii_upcase | IN("FAILURE", "ERROR", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE");
    .[] | select(.author.login // "" | test("\\[bot\\]$|^app/") | not)
    | ((.body // "") | gsub("\r"; "") | split("\n")) as $lines
    | ([$lines[] | capture("^Lodestar route: (?<wf>SIMPLE|BUILD_REVIEW|INDEPENDENT_COMPARE|COMPLEX|PROTOTYPE|ONBOARDING|MAINTENANCE) risk=(low|medium|high|critical)")] | last) as $route
    | ([$lines[] | select(test("^Lodestar review: \\S"))] | length > 0) as $reviewed
    | if .state == "MERGED" and .mergedAt > $since then
        if $route == null then "merged with no route line\t#\(.number)"
        elif ($route.wf | IN("BUILD_REVIEW", "INDEPENDENT_COMPARE", "COMPLEX")) and ($reviewed | not) then "merged as \($route.wf) with no review line\t#\(.number)"
        else empty end
      elif .state == "CLOSED" and .closedAt > $since then "closed without merge (did the owner reject it?)\t#\(.number)"
      elif .state == "OPEN" and .updatedAt > $since and ([.statusCheckRollup[]? | (.conclusion // .state // "") | bad] | any) then "open, with failing checks\t#\(.number)"
      else empty end' <<<"$prs" || return 1
  # Each workflow's newest run on main since the last sweep, if it failed.
  jq -r --arg since "$2" '[.[] | select(.createdAt > $since)] | group_by(.workflowName)[] | max_by(.createdAt)
    | select((.conclusion // "") | ascii_downcase | IN("failure", "timed_out", "startup_failure"))
    | "CI \(.workflowName) failed on main\t"' <<<"$runs"
}

tmp=$(mktemp -d) || exit 0
trap 'rm -rf "$tmp"' EXIT
i=0
while IFS= read -r p; do
  [ -e "$p/.git" ] || continue
  since=$({ tail -n +2 "$stamp" | tr -d '\r' | awk -v p="$p" 'tolower(substr($0, index($0, " ") + 1)) == tolower(p) { s = $1 } END { print s }'; } 2>/dev/null)
  i=$((i + 1)); echo "$p" > "$tmp/$i.p"
  { sweep "$p" "${since:-$first}" > "$tmp/$i.out" && touch "$tmp/$i.ok"; } &
done < <({ tr -d '\r' < "$inbox/projects.txt"; } 2>/dev/null | sort -fu)
wait
all=1; out=""; keep=""
for f in "$tmp"/*.p; do
  [ -f "$f" ] || continue
  p=$(cat "$f"); b=${f%.p}
  if [ ! -f "$b.ok" ]; then all=0; continue; fi
  keep+="$now $p"$'\n'
  # One line per finding, its PRs joined: "  <project>: PR merged with no route line: #9 #8"
  lines=$(cat "$b.out")
  [ -n "$lines" ] && out+=$(awk -F'\t' -v p="$p" '!($1 in n) { k[++m] = $1; n[$1] = "" } { if ($2 != "") n[$1] = n[$1] " " $2 }
    END { for (i = 1; i <= m; i++) print "  " p ": " (n[k[i]] == "" ? k[i] : "PR " k[i] ":" n[k[i]]) }' <<<"$lines")$'\n'
done
# Keep the old time of every project not swept well this time.
old=$({ tail -n +2 "$stamp" | tr -d '\r'; } 2>/dev/null | while IFS= read -r l; do
  grep -qixF "$now ${l#* }" <<<"$keep" || echo "$l"; done)
[ $all = 1 ] && day=$today || day=retry
mkdir -p "$inbox" && printf '%s\n%s%s\n' "$day" "$keep" "$old" | sed '/^$/d' > "$stamp"
if [ -n "$out" ]; then
  echo "Lodestar: daily GitHub sweep of the projects, new since each project's last sweep:"
  printf '%s' "$out"
  echo "Tell the owner. Find the cause: a Lodestar fault is fixed here; a project slip is the"
  echo "project session's job (give the owner a prompt for it; do not edit the project)."
fi
exit 0
