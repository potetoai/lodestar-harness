#!/usr/bin/env python3
"""Token usage report from Claude Code transcripts (~/.claude/projects).

Read-only. Prints where the price-weighted cost of past sessions went, so a
token-saving change can be checked against numbers (plans/active/token-efficiency.md).

  python scripts/usage-report.py --since 2026-09-23 --until 2026-10-02 \
      --match 'my-project|other-project'
  python scripts/usage-report.py --sessions    # one row per session too
  python scripts/usage-report.py --friction --since 2026-10-13   # where agents struggled
  python scripts/usage-report.py --excerpt <transcript> 205-329  # read one flagged range
"""
import argparse
import bisect
import glob
import json
import os
import re
import sys

# Price weights relative to one base input token.
W_IN, W_CW, W_CR, W_OUT = 1.0, 1.25, 0.1, 5.0
POLICY = re.compile(
    r"(Lodestar-harness|Orca-workflow)[/\\](README|router|rules|workflows|agents|skills|project)"
    r"|\.ai[/\\]project\.md|CLAUDE\.md", re.I)
SHELL_READ = re.compile(r"\b(cat|head|tail|sed)\b")
# Fixed-format routing line (router/ROUTER.md, Routing Approval Gate). It must
# start its own line, so a quoted example inside a sentence is not counted.
# ROUTE also accepts off-format lines (bold, no risk=, text after it) so they
# still count; ROUTE_EXACT tells them apart.
ROUTE = re.compile(r"^[ \t]*\**Lodestar route:\**[ \t]*\**([A-Z_]+)\b\**"
                   r"(?:[ \t]+risk=\**([a-z]+)\**)?(?:[ \t]+escalated-from=\**([A-Z_]+)\**)?(.*)$", re.M)
ROUTE_EXACT = re.compile(r"Lodestar route: [A-Z_]+ risk=[a-z]+(?: escalated-from=[A-Z_]+)?")
# A subagent's role is the first role word in the start of its brief.
ROLE = re.compile(r"\b(critic|reviewer|tester|builder|architect|qa)\b", re.I)


def cost(u):
    return (W_IN * u.get("input_tokens", 0) + W_CW * u.get("cache_creation_input_tokens", 0)
            + W_CR * u.get("cache_read_input_tokens", 0) + W_OUT * u.get("output_tokens", 0))


def context(u):
    return (u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0)
            + u.get("cache_creation_input_tokens", 0))


def scan(path):
    """One transcript -> usage per API call (deduped by message id) and counters.
    routes: (call index, workflow, risk, escalated-from); owner: call index of
    each owner message (the next call answers it). A session with no route
    line in its own text but one in a PR body it writes (Bash command or Write
    content; a session continued after /clear) takes that line from its start."""
    usage, ts, policy_ids, tools = {}, {}, {}, {}
    routes, owner, pr_routes = [], [], []
    s = dict(date="", policy=0, hooks=0, asks=0, read_tok=0, tool_tok=0, off_format=0,
             prompt=None, tool_calls=0, pr_route=0)
    tool_turns = set()
    with open(path, encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            try:
                e = json.loads(line)
            except ValueError:
                continue
            s["date"] = s["date"] or (e.get("timestamp") or "")[:10]
            m = e.get("message") or {}
            content = m.get("content")
            if e.get("type") == "assistant" and m.get("usage") and m.get("id"):
                usage[m["id"]] = m["usage"]
                ts.setdefault(m["id"], e.get("timestamp") or "")
            if e.get("type") == "user" and not e.get("isMeta"):
                texts = [content] if isinstance(content, str) else [
                    c.get("text", "") for c in content or [] if isinstance(c, dict) and c.get("type") == "text"]
                if s["prompt"] is None:
                    s["prompt"] = " ".join(texts)
                if any(t.strip() and not t.lstrip().startswith("<") and "Stop hook feedback" not in t
                       for t in texts):
                    owner.append(len(usage))
            if isinstance(content, str):
                s["hooks"] += "Stop hook feedback" in content
                continue
            for c in content or []:
                if not isinstance(c, dict):
                    continue
                if c.get("type") == "tool_use":
                    name, inp = c.get("name"), c.get("input") or {}
                    inp = inp if isinstance(inp, dict) else {}
                    tools[c["id"]] = name
                    s["tool_calls"] += 1
                    tool_turns.add(m.get("id"))
                    s["asks"] += name == "AskUserQuestion"
                    if name in ("Bash", "Write"):
                        pr_routes += ROUTE.findall(str(inp.get("command") or inp.get("content") or ""))
                    target = str(inp.get("file_path") or inp.get("command") or "")
                    if POLICY.search(target) and (name == "Read" or (name == "Bash" and SHELL_READ.search(target))):
                        policy_ids[c["id"]] = True
                elif c.get("type") == "text" and e.get("type") == "assistant":
                    for r in ROUTE.finditer(c.get("text", "")):
                        routes.append((len(usage) - 1,) + r.groups()[:3])
                        s["off_format"] += not ROUTE_EXACT.fullmatch(r.group(0).strip())
                elif c.get("type") == "text" and e.get("type") == "user":
                    s["hooks"] += "Stop hook feedback" in c.get("text", "")
                elif c.get("type") == "tool_result":
                    r = c.get("content")
                    n = (len(r) if isinstance(r, str) else len(json.dumps(r))) // 4
                    s["tool_tok"] += n
                    if tools.get(c.get("tool_use_id")) == "Read":
                        s["read_tok"] += n
                    if c.get("tool_use_id") in policy_ids:
                        s["policy"] += n
    s["usage"], s["ts"] = list(usage.values()), list(ts.values())
    if not routes and pr_routes:
        routes, s["pr_route"] = [(0,) + pr_routes[0][:3]], 1
    s["routes"], s["owner"] = routes, owner
    s["tool_turns"] = len(tool_turns)
    return s


def median(xs):
    return sorted(xs)[len(xs) // 2]


def subagent_report(subs):
    """Per role: where the cost of subagent runs goes. A run pays for its whole
    context again on every call, so calls per run is the number to watch
    (plans/active/subagent-cost.md)."""
    roles = {}
    for sub in subs:
        us = sub["usage"]
        if not us:
            continue
        m = ROLE.search((sub["prompt"] or "")[:600])
        first = cost(us[0]) - W_OUT * us[0].get("output_tokens", 0)
        new = sum(W_IN * u.get("input_tokens", 0) + W_CW * u.get("cache_creation_input_tokens", 0) for u in us[1:])
        again = sum(W_CR * u.get("cache_read_input_tokens", 0) for u in us[1:])
        out = W_OUT * sum(u.get("output_tokens", 0) for u in us)
        ctx = [context(u) for u in us]
        roles.setdefault(m.group(1).lower() if m else "other", []).append(
            (first + new + again + out, len(us), ctx[0], max(ctx), first, new, again, out,
             sub["tool_calls"], sub["tool_turns"]))
    total = sum(r[0] for rs in roles.values() for r in rs)
    if not total:
        return
    print(f"Subagent runs: {sum(len(rs) for rs in roles.values())}, {int(total)} weighted units"
          " (medians per run; split: first call / new input later / context re-sent / output)")
    print(f"  {'role':10} {'runs':>4} {'share':>6} {'cost':>8} {'calls':>5} {'start':>7} {'peak':>7}"
          f" {'split':>15} {'tools/call':>10}")
    for role, rs in sorted(roles.items(), key=lambda kv: -sum(r[0] for r in kv[1])):
        c = sum(r[0] for r in rs)
        split = "/".join(f"{sum(r[i] for r in rs) / c * 100:.0f}" for i in (4, 5, 6, 7))
        turns = sum(r[9] for r in rs)
        print(f"  {role:10} {len(rs):4} {c / total * 100:5.1f}% {int(median([r[0] for r in rs])):8}"
              f" {median([r[1] for r in rs]):5} {median([r[2] for r in rs]):7} {median([r[3] for r in rs]):7}"
              f" {split:>15} {sum(r[8] for r in rs) / turns if turns else 0:10.2f}")


def route_report(sessions, total):
    """Cost, owner follow-ups and escalations per routed workflow. A route line
    starts a segment that runs to the next route line or the session end; calls
    before the first line are "(no route line)". A subagent's cost goes to the
    segment open when it started."""
    stats, esc = {}, {}
    for s in sessions:
        starts = [r[0] for r in s["routes"]]
        names = [r[1] for r in s["routes"]]

        def seg(i):
            k = bisect.bisect_right(starts, i)
            return names[k - 1] if k else "(no route line)"
        for i, u in enumerate(s["usage"]):
            stats.setdefault(seg(i), [0, 0.0, 0])[1] += cost(u)
        for start, c in s["subs"]:
            stats.setdefault(seg(bisect.bisect_right(s["ts"], start) - 1), [0, 0.0, 0])[1] += c
        for i in s["owner"]:
            if starts and i > starts[0]:
                stats[seg(i - 1)][2] += 1
        for _, wf, _, old in s["routes"]:
            stats.setdefault(wf, [0, 0.0, 0])[0] += 1
            if old:
                esc[f"{old}->{wf}"] = esc.get(f"{old}->{wf}", 0) + 1
    unrouted = sum(1 for s in sessions if not s["routes"])
    off = sum(s["off_format"] for s in sessions)
    from_pr = sum(s["pr_route"] for s in sessions)
    print(f"Route lines: {sum(v[0] for v in stats.values())} ({off} off-format,"
          f" {from_pr} from a PR body only); sessions without one: {unrouted} of {len(sessions)}")
    print(f"  {'workflow':20} {'tasks':>5} {'cost':>6} {'per task':>9} {'owner msgs/task':>15}")
    for wf, (n, c, o) in sorted(stats.items(), key=lambda kv: -kv[1][1]):
        per = f"{int(c / n):9}" if n else f"{'-':>9}"
        msgs = f"{o / n:15.1f}" if n else f"{'-':>15}"
        print(f"  {wf:20} {n:5} {c / total * 100:5.1f}% {per} {msgs}")
    up = sum(v for k, v in esc.items() if k.startswith("SIMPLE->"))
    print(f"Escalations: {', '.join(f'{k} {v}' for k, v in sorted(esc.items())) or 'none'}"
          f" (SIMPLE calls that escalated: {up} of {stats.get('SIMPLE', [0])[0]})")


def restart_saving(sessions, threshold, restart=90000):
    """Cost saved had each session handed off and restarted at `restart` tokens
    once its context passed `threshold`. Upper estimate: ignores lost work."""
    base = new = 0.0
    restarts = 0
    for s in sessions:
        offset = 0
        for u in s["usage"]:
            c, cr = cost(u), u.get("cache_read_input_tokens", 0)
            base += c
            if context(u) - offset > threshold:
                offset = context(u) - restart
                restarts += 1
                new += c - W_CR * cr + W_CW * restart
            else:
                new += c - W_CR * min(offset, cr)
    return (1 - new / base) * 100 if base else 0.0, restarts


# Friction (workflows/maintenance.md, step 2): where a session struggled.
# The context nudge is a reminder, not a block, so it does not count.
INTERRUPT = re.compile(r"\[Request interrupted by user|The user doesn't want to proceed")
HOOK_BLOCK = re.compile(r"hook error|^Blocked|Stop hook feedback|denied by", re.M)
NOT_FRICTION = re.compile(r"context-nudge")
GAP = 40  # events closer than this many transcript lines form one range
LEAD = 30  # lines read before a range, to see what led to it


def friction_scan(path):
    """One transcript -> friction events as (line, kind). Kinds: error (a tool
    failed), block (a hook or the permission check stopped it), repeat (the
    same call failed again right after failing), interrupt (the owner)."""
    events, sig, order, failed = [], {}, [], {}
    last_interrupt = -9
    with open(path, encoding="utf-8", errors="ignore") as fh:
        for n, line in enumerate(fh, 1):
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if not isinstance(e, dict):
                continue
            a = e.get("attachment")
            if isinstance(a, dict) and a.get("type") == "hook_blocking_error":
                # One failed call counts once, whether the hook, the tool
                # result or both report it.
                if not NOT_FRICTION.search(str(a.get("blockingError"))) and a.get("toolUseID") not in failed:
                    events.append((n, "block"))
                    failed[a.get("toolUseID")] = n
                continue
            m = e.get("message")
            m = m if isinstance(m, dict) else {}
            content = m.get("content")
            if e.get("type") != "user" and e.get("type") != "assistant":
                continue
            items = [{"type": "text", "text": content}] if isinstance(content, str) else content or []
            for c in items:
                if not isinstance(c, dict):
                    continue
                if c.get("type") == "tool_use":
                    inp = c.get("input") or {}
                    sig[c["id"]] = (c.get("name"), str(inp.get("command") or inp.get("file_path")
                                                       or json.dumps(inp, sort_keys=True))[:300])
                    order.append(c["id"])
                elif c.get("type") == "text" and e.get("type") == "user":
                    t = c.get("text", "")
                    # A rejected tool call also writes an interrupt line; count one.
                    if INTERRUPT.search(t) and n - last_interrupt > 2:
                        events.append((n, "interrupt"))
                        last_interrupt = n
                    elif "Stop hook feedback" in t:
                        events.append((n, "block"))
                elif c.get("type") == "tool_result" and c.get("is_error"):
                    r = c.get("content")
                    t = r if isinstance(r, str) else json.dumps(r)
                    kind = "interrupt" if INTERRUPT.search(t) else "block" if HOOK_BLOCK.search(t) else "error"
                    if kind == "interrupt":
                        events.append((n, kind))
                        last_interrupt = n
                    elif c.get("tool_use_id") not in failed:
                        events.append((n, kind))
                        failed[c.get("tool_use_id")] = n
    last = None  # the last failed call; a success of the same call clears it
    for i in order:
        if i in failed:
            if last is not None and sig[i] == sig[last]:
                events.append((failed[i], "repeat"))
            last = i
        elif last is not None and sig[i] == sig[last]:
            last = None
    return sorted(events)


def friction_ranges(events):
    """Group events into transcript line ranges, most events first."""
    groups = []
    for n, kind in events:
        if groups and n - groups[-1][1] <= GAP:
            groups[-1][1] = n
            groups[-1][2].append(kind)
        else:
            groups.append([n, n, [kind]])
    return sorted(groups, key=lambda g: -len(g[2]))


def friction_report(files, top=5):
    """Top sessions by friction score (an interrupt costs the owner, so it
    counts 3), each with its densest line range: five excerpts at most. The
    agent reads a range with --excerpt, never the whole transcript."""
    rows = []
    for name, path in files:
        ev = friction_scan(path)
        if ev:
            k = [kind for _, kind in ev]
            score = len(k) + 2 * k.count("interrupt")
            rows.append((score, name, path, k, friction_ranges(ev)))
    rows.sort(key=lambda r: -r[0])
    print(f"Friction: {len(rows)} of {len(files)} transcripts have events; top {min(top, len(rows))}"
          " (score = events, an owner interrupt counts 3)")
    for score, name, path, k, groups in rows[:top]:
        counts = ", ".join(f"{x} {k.count(x)}" for x in ("error", "block", "repeat", "interrupt") if x in k)
        print(f"  {score:4}  {name}  ({counts})")
        print(f"        {path}")
        a, b, kinds = groups[0]
        a = max(1, a - LEAD)
        more = f"; {len(groups) - 1} smaller ranges" if len(groups) > 1 else ""
        print(f"        read: --excerpt {path} {a}-{b}  ({len(kinds)} events{more})")


def excerpt(path, span, width=200):
    """One short line per transcript entry in a line range (`A-B`), so a
    flagged range can be read without its full tool output."""
    a, _, b = span.partition("-")
    a, b = int(a), int(b or a)
    with open(path, encoding="utf-8", errors="ignore") as fh:
        for n, line in enumerate(fh, 1):
            if n > b:
                break
            if n < a:
                continue
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if not isinstance(e, dict):
                continue
            at = e.get("attachment")
            if isinstance(at, dict) and at.get("type") == "hook_blocking_error":
                print(f"{n} hook-block: {str(at.get('blockingError'))[:width]}")
                continue
            if e.get("type") not in ("user", "assistant"):
                continue
            m = e.get("message")
            content = m.get("content") if isinstance(m, dict) else None
            for c in [{"type": "text", "text": content}] if isinstance(content, str) else content or []:
                if not isinstance(c, dict):
                    continue
                if c.get("type") == "text":
                    t = c.get("text", "")
                elif c.get("type") == "tool_use":
                    inp = c.get("input") or {}
                    t = f"{c.get('name')}: {inp.get('command') or inp.get('file_path') or json.dumps(inp)}"
                elif c.get("type") == "tool_result":
                    r = c.get("content")
                    t = ("error: " if c.get("is_error") else "ok: ") + (r if isinstance(r, str) else json.dumps(r))
                else:
                    continue
                print(f"{n} {e['type']}: {' '.join(t.split())[:width]}")


def main():
    # A Windows console is cp1252; transcripts hold any character.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--root", default=os.path.expanduser("~/.claude/projects"))
    ap.add_argument("--match", default="", help="regex on project folder names")
    ap.add_argument("--since", default="")
    ap.add_argument("--until", default="9999")
    ap.add_argument("--min-turns", type=int, default=5)
    ap.add_argument("--long", type=int, default=150000, help="long-context turn threshold")
    ap.add_argument("--nudge", type=int, default=200000, help="restart threshold to simulate")
    ap.add_argument("--sessions", action="store_true", help="print one row per session")
    ap.add_argument("--friction", action="store_true",
                    help="top 5 sessions by tool errors, hook blocks, repeats and interrupts")
    ap.add_argument("--excerpt", nargs=2, metavar=("FILE", "A-B"),
                    help="print a flagged transcript range, one short line per entry")
    a = ap.parse_args()
    if a.excerpt:
        excerpt(*a.excerpt)
        return

    sessions = []
    for d in sorted(os.listdir(a.root)):
        if a.match and not re.search(a.match, d):
            continue
        for f in glob.glob(os.path.join(a.root, d, "*.jsonl")):
            s = scan(f)
            if len(s["usage"]) < a.min_turns or not (a.since <= s["date"] <= a.until):
                continue
            subdir = os.path.join(a.root, d, os.path.basename(f)[:-6], "subagents")
            subs = [scan(sf) for sf in glob.glob(os.path.join(subdir, "*.jsonl"))]
            s["subs"] = [(sub["ts"][0] if sub["ts"] else "", sum(cost(u) for u in sub["usage"]))
                         for sub in subs]
            s["sub_cost"] = sum(c for _, c in s["subs"])
            s["sub_scans"] = subs
            s["name"] = f"{d[:28]} {os.path.basename(f)[:8]}"
            s["path"] = f
            s["sub_paths"] = glob.glob(os.path.join(subdir, "*.jsonl"))
            sessions.append(s)
    if not sessions:
        print("No sessions match.")
        return
    if a.friction:
        friction_report([(s["name"], s["path"]) for s in sessions]
                        + [(f"{s['name']} sub {os.path.basename(p)[:14]}", p)
                           for s in sessions for p in s["sub_paths"]])
        return

    total = long_c = base_c = out_c = sub_c = pol_c = 0.0
    turns = hooks = asks = read_tok = tool_tok = 0
    firsts, rows = [], []
    for s in sessions:
        us = s["usage"]
        ctx = [context(u) for u in us]
        c = sum(cost(u) for u in us)
        n = len(us)
        total += c + s["sub_cost"]
        sub_c += s["sub_cost"]
        long_c += sum(W_CR * x for x in ctx if x > a.long)
        base_c += ctx[0] * (W_CW + W_CR * n)
        out_c += W_OUT * sum(u.get("output_tokens", 0) for u in us)
        pol_c += s["policy"] * (W_CW + W_CR * n)  # upper bound: as if read at turn one
        turns += n
        hooks += s["hooks"]
        asks += s["asks"]
        read_tok += s["read_tok"]
        tool_tok += s["tool_tok"]
        firsts.append(ctx[0])
        rows.append((s["date"], s["name"], n, max(ctx), int(c), s["policy"], s["hooks"], int(s["sub_cost"])))

    if a.sessions:
        print(f"{'date':10} {'session':37} {'turns':>5} {'peak':>7} {'cost':>10} {'policy':>6} {'hook':>4} {'subcost':>9}")
        for r in sorted(rows):
            print(f"{r[0]:10} {r[1]:37} {r[2]:5} {r[3]:7} {r[4]:10} {r[5]:6} {r[6]:4} {r[7]:9}")
        print()

    firsts.sort()
    long_sessions = sum(1 for r in rows if r[2] >= 150)
    pct = lambda x: f"{x / total * 100:5.1f}%"
    print(f"Sessions: {len(sessions)} ({min(r[0] for r in rows)}..{max(r[0] for r in rows)}), "
          f"turns {turns}, sessions with 150+ turns {long_sessions}, "
          f"peak context {max(r[3] for r in rows)}")
    print("Shares of price-weighted cost (they overlap):")
    print(f"  turns above {a.long // 1000}k context       {pct(long_c)}")
    print(f"  base context on every turn   {pct(base_c)}  (median turn-one context {firsts[len(firsts) // 2]})")
    print(f"  output                       {pct(out_c)}")
    print(f"  subagents                    {pct(sub_c)}")
    print(f"  policy reading (upper bound) {pct(pol_c)}")
    print(f"Turns forced by a Stop hook: {hooks} of {turns}")
    print(f"Owner questions (AskUserQuestion): {asks}")
    print(f"Read share of tool-result tokens: {read_tok / tool_tok * 100 if tool_tok else 0:.0f}%")
    for th in sorted({150000, a.nudge}):
        saved, n = restart_saving(sessions, th)
        print(f"Restart at {th // 1000}k (handoff + /clear): cost -{saved:.0f}%, {n} restarts (upper estimate)")
    route_report(sessions, total)
    subagent_report([sub for s in sessions for sub in s["sub_scans"]])
    print(f"Total weighted units: {int(total)}")


if __name__ == "__main__":
    main()
