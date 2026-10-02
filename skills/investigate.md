# Investigate

Version: 1.0
Scope: Global Lodestar-harness

---

## Purpose

A short method for finding why something is broken before changing it. The
Router selects it (Deep-Investigation, `skills/capabilities.md`) when the cause
is unclear. `rules/coding.md`, `rules/testing.md` and `rules/principles.md`
still apply.

---

## Steps

1. **Reproduce.** Get one command or test that shows the failure. If it is
   intermittent, run it N times and record the failure rate: that rate is the
   baseline a fix must beat.
2. **Read the evidence.** Read the whole error, stack trace and logs. Find the
   first place where actual behavior departs from expected. Check what changed
   near that place (`git log`, `git diff`).
3. **Narrow.** Halve the search space until one commit (`git bisect`), one
   input or one step separates pass from fail.
4. **State one hypothesis.** One sentence: "X fails because Y." Name the
   observation that would prove it wrong.
5. **Test the hypothesis, not a fix.** Add a log line, an assertion or a
   failing test that confirms or rejects Y. Change nothing else yet.
6. **Fix the cause.** Write the failing test first, then the smallest change
   that makes it pass. Fix where the wrong value is produced, not where it is
   noticed.
7. **Confirm.** Run the reproduction, the new test and the full suite
   (`make verify`).

---

## Stop rules

- No fix before step 5 has confirmed a cause.
- Two fixes have failed: stop fixing. Write down the assumption they shared and
  apply `rules/principles.md` §1 (Attack the Premise).
- Three hypotheses rejected, or the cause lies outside the repo (tool,
  platform, data): report to the owner with the evidence so far instead of
  guessing.

---

## Report

```text
Symptom:
Reproduction:
Cause (with evidence):
Fix:
Verification:
```
