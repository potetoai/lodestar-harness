"""Print per-case scores and tokens from a `claude plugin eval --json` result.

Usage: python evals/tokens.py evals/results/<run>/run.json

Tokens come from each run's trace (`--keep-temp`): input + cache creation +
cache reads + output, as the trace's final result line reports them. A run
whose trace is gone counts as 0 and is flagged with "?".
"""
import json
import sys


def trace_tokens(path):
    lines = []
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                try:
                    obj = json.loads(line)
                except ValueError:
                    continue
                if isinstance(obj, dict) and obj.get("type") == "result":
                    lines.append(obj)
    except (OSError, TypeError):
        return None
    if not lines:
        return None
    u = lines[-1].get("usage", {})
    return sum(u.get(k, 0) for k in ("input_tokens", "cache_creation_input_tokens",
                                       "cache_read_input_tokens", "output_tokens"))


def main(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    total = 0
    print("| Case | With | Without | Tokens with | Tokens without |")
    print("|---|---|---|---|---|")
    for case in data["cases"]:
        row = [case["name"]]
        toks = []
        for arm in ("with", "without"):
            runs = case.get("arms", {}).get(arm, [])
            scores = [r.get("score") or 0 for r in runs]
            row.append("%.2f" % (sum(scores) / len(scores)) if scores else "-")
            t = [trace_tokens(r.get("tracePath")) for r in runs]
            n = sum(x or 0 for x in t)
            total += n
            toks.append("%dk%s" % (round(n / 1000), "?" if None in t else "") if runs else "-")
        print("| " + " | ".join(row + toks) + " |")
    agg = data.get("aggregates", {})
    print()
    print("Overall: with %.2f, mean delta %+.2f, %dk tokens"
          % (agg.get("overallScore", 0), agg.get("meanDelta", 0), round(total / 1000)))


if __name__ == "__main__":
    main(sys.argv[1])
