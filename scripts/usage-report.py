#!/usr/bin/env python3
"""Token usage report from Claude Code transcripts (~/.claude/projects).

Read-only. Prints where the price-weighted cost of past sessions went, so a
token-saving change can be checked against numbers (plans/active/token-efficiency.md).

  python scripts/usage-report.py --since 2026-09-23 --until 2026-10-02 \
      --match 'my-project|other-project'
  python scripts/usage-report.py --sessions    # one row per session too
"""
import argparse
import glob
import json
import os
import re

# Price weights relative to one base input token.
W_IN, W_CW, W_CR, W_OUT = 1.0, 1.25, 0.1, 5.0
POLICY = re.compile(
    r"(Lodestar-harness|Orca-workflow)[/\\](README|router|rules|workflows|agents|skills|project)"
    r"|\.ai[/\\]project\.md|CLAUDE\.md", re.I)
SHELL_READ = re.compile(r"\b(cat|head|tail|sed)\b")


def cost(u):
    return (W_IN * u.get("input_tokens", 0) + W_CW * u.get("cache_creation_input_tokens", 0)
            + W_CR * u.get("cache_read_input_tokens", 0) + W_OUT * u.get("output_tokens", 0))


def context(u):
    return (u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0)
            + u.get("cache_creation_input_tokens", 0))


def scan(path):
    """One transcript -> usage per API call (deduped by message id) and counters."""
    usage, policy_ids, tools = {}, {}, {}
    s = dict(date="", policy=0, hooks=0, asks=0, read_tok=0, tool_tok=0)
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
            if isinstance(content, str):
                s["hooks"] += "Stop hook feedback" in content
                continue
            for c in content or []:
                if not isinstance(c, dict):
                    continue
                if c.get("type") == "tool_use":
                    name, inp = c.get("name"), c.get("input") or {}
                    tools[c["id"]] = name
                    s["asks"] += name == "AskUserQuestion"
                    target = str(inp.get("file_path") or inp.get("command") or "")
                    if POLICY.search(target) and (name == "Read" or (name == "Bash" and SHELL_READ.search(target))):
                        policy_ids[c["id"]] = True
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
    s["usage"] = list(usage.values())
    return s


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


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--root", default=os.path.expanduser("~/.claude/projects"))
    ap.add_argument("--match", default="", help="regex on project folder names")
    ap.add_argument("--since", default="")
    ap.add_argument("--until", default="9999")
    ap.add_argument("--min-turns", type=int, default=5)
    ap.add_argument("--long", type=int, default=150000, help="long-context turn threshold")
    ap.add_argument("--nudge", type=int, default=200000, help="restart threshold to simulate")
    ap.add_argument("--sessions", action="store_true", help="print one row per session")
    a = ap.parse_args()

    sessions = []
    for d in sorted(os.listdir(a.root)):
        if a.match and not re.search(a.match, d):
            continue
        for f in glob.glob(os.path.join(a.root, d, "*.jsonl")):
            s = scan(f)
            if len(s["usage"]) < a.min_turns or not (a.since <= s["date"] <= a.until):
                continue
            subdir = os.path.join(a.root, d, os.path.basename(f)[:-6], "subagents")
            s["sub_cost"] = sum(cost(u) for sf in glob.glob(os.path.join(subdir, "*.jsonl"))
                                for u in scan(sf)["usage"])
            s["name"] = f"{d[:28]} {os.path.basename(f)[:8]}"
            sessions.append(s)
    if not sessions:
        print("No sessions match.")
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
    print(f"Total weighted units: {int(total)}")


if __name__ == "__main__":
    main()
