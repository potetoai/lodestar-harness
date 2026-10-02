# Explore Options

Version: 1.0
Scope: Global Lodestar-harness

---

## Purpose

A short method for settling what to build before building it. The Router
selects it when the goal or the approach is open: unclear requirements, more
than one reasonable design, or a change the owner will live with for a long
time. Skip it when the task names one clear outcome and one obvious approach.

---

## Steps

1. **Restate the goal** in one or two sentences: who benefits, and how the
   owner will see that it works. Ask the owner only what changes the design,
   one question at a time, each with a recommended answer.
2. **List the constraints** from `.ai/project.md`, `rules/` and the existing
   code. Look for something to reuse before proposing anything new.
3. **Offer two or three options that really differ.** For each: what it is,
   its cost (files, effort), its risk, and what it rules out later. Include
   "do less" or "do nothing" when that is a real choice.
4. **Recommend one** and say why. Do not pad the list with options you would
   not pick.
5. **The owner chooses.** Record the choice and its reason in the plan's
   decision log, or in an ADR for a significant decision
   (`rules/documentation.md`).
6. **Hand off** to the selected workflow. No code before the choice.

---

## Output

```text
Goal:
Constraints:
Options:
  A. <what> (cost, risk)
  B. <what> (cost, risk)
Recommendation: <option>, because <reason>
Question for the owner:
```
