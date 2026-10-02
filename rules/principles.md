# Global Engineering Principles

Version: 2.0
Scope: All projects using Lodestar-harness

---

## Purpose

A small set of design reflexes that catch specific failure modes at the moment
they occur. They extend `rules/coding.md` and `rules/architecture.md`; they do
not replace them.

Each covers a failure the other rules miss and that a multi-agent, retry-heavy
setup makes common. Apply each only at its trigger; do not force them where
they do not apply.

---

# 1. Attack the Premise

**Rule:** When several different fixes for the same failure have all failed,
and they rest on one shared assumption, test that assumption before trying
another fix. The failed fixes are evidence against it.

**Trigger:** The second failed fix for the same check, when the fixes have an
assumption in common.

**Do:**

1. Name the assumption in one sentence.
2. Measure before fixing again: write a small, repeatable check that shows
   where the problem concentrates (which files, workers, inputs or steps carry
   it).
3. If the problem sits in the same few places on every run, find what puts it
   there and change that, instead of adding code that compensates downstream.

**Constraint:** No new fix until the assumption is written down and the check
exists. If the check shows the problem spread evenly, the assumption is
probably sound: keep the check and search for a different cause.

This stops fix-thrash: spending attempt after attempt on solutions that all
inherit one wrong belief. `skills/investigate.md` applies it as a stop rule.

---

# 2. Make Operations Idempotent

**Rule:** An operation that may be repeated must reach the same correct end
state however many times it runs and whatever a previous run left behind.

**Trigger:** Writing setup scripts, hooks, migrations, sync jobs, or worker
steps that may be interrupted, retried, or run twice, as orchestrated workers
routinely are.

**Do:**

- Start by looking at what already exists; reuse or repair it instead of
  assuming an empty start.
- Decide "already done" by comparing content, not timestamps or the order
  things were created.
- Make locks expire, or check that their holder is still alive, so one crash
  cannot block every later run.
- On retry, redo the failed unit from clean input instead of patching its
  half-finished output.

**Check:** Run it twice in a row; stop it at each step and run it again. Every
path must end in the same state. If the result depends on leftovers, add a
step that reconciles them first. `enforcement/agents/claude/global/install.sh`
is written this way: it changes nothing when the hooks are already there.

---

# 3. Migrate Callers, Then Delete Legacy APIs

**Rule:** When an internal API is replaced, move every caller to the new one
and remove the old one in the same change. Do not keep both alive "for now".

**Trigger:** A refactor or simplification where every caller lives in this
repo and no outside user relies on the old form.

**Do:**

1. Find all callers: search the whole repo, including tests and scripts.
2. Switch them to the new API.
3. Delete the old API, and any shim, in the same PR or plan phase.
4. Rewrite tests around the new behavior; drop tests that only protected the
   old shape.

**Why:** Two paths double what readers and agents must understand, and a path
kept "for now" usually stays for good.

> Scope note: this applies to a coordinated breaking change with no external
> consumers. When an external contract or a phased rollout requires
> compatibility, `rules/coding.md` §16 (backward compatibility) governs instead.
