# Managed by lodestar-harness. Edit in lodestar-harness/enforcement, not by hand.
# Reads a Codex apply_patch text (jq -Rs). codex-hook.sh uses two modes:
# - paths: every file header, one "kind<TAB>path" per line, Move to included.
#   Headers are matched after trimming, so no file can hide from the checks.
# - apply: the content of header number $n after the patch, from $cur. Hunks
#   match exactly from the current position, as Codex first tries; anything
#   Codex might place differently is an error, so the caller blocks.
def head: capture("^\\s*\\*\\*\\*\\s*(?<kind>Add File|Update File|Delete File|Move to):\\s*(?<path>.*?)\\s*$");
def ishead: [head] | length > 0;
def lines: gsub("\r"; "") | split("\n");
def seek($f; $pat; $from; $eof):
  ($pat | length) as $k
  | if $eof then (if ($f | length) >= $k and $f[($f | length) - $k:] == $pat then ($f | length) - $k else null end)
    else first(range($from; ($f | length) - $k + 1) | select($f[.:. + $k] == $pat)) // null end;
def chunks:
  reduce .[] as $l ({all: [], c: null};
    if $l | startswith("@@") then
      # As Codex: "@@" alone has no context; "@@ x" seeks line x, even when x is "".
      (if $l == "@@" then null elif $l | startswith("@@ ") then $l[3:] else error("unknown @@ line") end) as $ctx
      | (if .c then .all += [.c] else . end) | .c = {ctx: $ctx, old: [], new: [], eof: false}
    elif $l == "*** End of File" then
      if .c then .c.eof = true else error("End of File before a hunk") end
    else
      .c //= {ctx: null, old: [], new: [], eof: false}
      | ($l[0:1]) as $m | ($l[1:]) as $t
      | if $m == " " or $l == "" then .c.old += [$t] | .c.new += [$t]
        elif $m == "-" then .c.old += [$t]
        elif $m == "+" then .c.new += [$t]
        else error("unknown hunk line") end
    end)
  | if .c then .all + [.c] else .all end
  | if length == 0 then error("empty update") else . end;
def update($cur):
  ($cur | lines | if (length > 0 and last == "") then .[:-1] else . end) as $f
  | (reduce chunks[] as $c ({pos: 0, reps: []};
      (if $c.ctx == null then .pos
       else first(range(.pos; $f | length) | select($f[.] == $c.ctx)) + 1 // error("context not found") end) as $pos
      | if ($c.old | length) == 0 then .reps += [[($f | length), 0, $c.new]] | .pos = $pos
        else seek($f; $c.old; $pos; $c.eof) as $i
          | if $i == null then error("hunk not found") else .reps += [[$i, ($c.old | length), $c.new]] | .pos = $i + ($c.old | length) end
        end)).reps
  | reduce (sort_by(.[0]) | reverse[]) as $r ($f; .[:$r[0]] + $r[2] + .[$r[0] + $r[1]:]);
lines as $ls
| if ([$ls[] | select(test("^\\s*\\*\\*\\*\\s*Begin Patch\\s*$"))] | length) == 0 then error("no Begin Patch") else . end
| if $mode == "paths" then $ls[] | head | .kind + "\t" + .path
  else
    # An indented header could be a context line to Codex; do not guess.
    if any($ls[]; ishead and test("^\\s")) then error("indented file header") else . end
    | [range(0; $ls | length) | select($ls[.] | ishead)] as $hs
    | $hs[$n] as $h
    | if $h == null then error("no such header") else . end
    | ([range($h + 1; $ls | length) | select(($ls[.] | ishead) or ($ls[.] | test("^\\s*\\*\\*\\*\\s*End Patch\\s*$")))] | first // error("no End Patch")) as $end
    | $ls[$h + 1:$end] as $body
    | ($ls[$h] | head.kind) as $kind
    | if $kind == "Add File" then
        if all($body[]; startswith("+")) then $body | map(.[1:]) else error("Add File line without +") end
      elif $kind == "Delete File" then []
      elif $kind == "Update File" then $body | update($cur)
      else error("not a file to rebuild") end
    | if length > 0 then join("\n") + "\n" else "" end
  end
