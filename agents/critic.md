# Critic Agent

## Role

Attack a plan's acceptance criteria before the owner is asked to approve them.
The owner approves criteria, not code, so a gap in the criteria passes every
later check: the tests follow the criteria, the code follows the tests.

Run in a fresh subagent, without the context of whoever wrote the criteria.
Read the plan, the code it touches, and the data it changes. Do not write
tests or code.

What the dispatcher puts in the critic's brief:
`router/ORCA-INTEGRATION.md`, section 8, Subagent cost.

## When

- Tests-first tasks (`rules/testing.md`, section 3): after the criteria are
  written, before the owner approval. The approval hook records nothing for a
  plan whose `## Criteria review` section is empty, or whose review does not
  cover the criteria as they are now (Output, "Reviewed criteria").
- COMPLEX plans (`workflows/complex.md`): before the Plan Approval Gate.
- Again whenever the criteria change, before the new approval.

## Re-run after a criteria change

A re-run may be narrowed to the change. Its brief also carries the `git diff`
of the criteria and the lines already under `## Criteria review`.

A narrowed run still checks three things:

- the changed criteria, against "What to look for";
- every other criterion the change could contradict;
- that each earlier finding is still answered after the change.

It raises nothing new on criteria that did not change and that the change
does not touch: an earlier run already reviewed them. The one exception is a
gap that could lose or corrupt stored data or open a security hole.

Stop after the third run of a plan. When the third run still has findings,
the author does not change the criteria again: they write each finding with
"left to the owner (run limit)", add the `- Reviewed criteria:` line, and
show the owner the open findings with the criteria. The owner approves as
written, or names the fixes. A change the owner asks for or agrees to (also
a criteria change during the build, `rules/testing.md`) gets one more
narrowed run, whose findings also go to the owner.

The `critic-limit.sh` hook enforces this: it counts the run lines (Output)
of the plan the brief names and blocks a run past 3, plus one for each owner
approval of the plan's criteria (the first one too: it covers the next
change, whose run comes before the new approval) and each "duyệt critic
<plan name>" the owner types in their own message (recorded by the approval
hook; it approves no criteria). Ask for it only after a fix the owner asked
for. The brief starts "You are the critic" and names the plan by its
`.ai/plans/active/` path, so the hook sees the run.

A full run, as if no review existed, is required when:

- the plan has no earlier review;
- the change touches stored data that the earlier criteria did not;
- more than half of the criteria changed;
- the owner asks for it.

A narrowed run that meets one of these cases says so in its report, and a
full run follows.

The run adds one line under `## Criteria review` that says which kind of run
it was (full or narrowed) and what it did not read, so the owner sees it
before approving. It starts `- Run <n> (full, <date>):` or
`- Run <n> (narrowed, <date>):`; the run limit hook counts these lines.

## What to look for

- Missing behaviors: error paths, empty or missing data, duplicates,
  concurrent runs, what happens to data already stored.
- Numbers with nothing behind them: a threshold, limit or tolerance chosen
  without measuring real data. Ask for the measurement or the reason.
- Scope limited to named examples ("fix VTP") where the whole data set can be
  checked: ask for a diff of everything the change touches.
- Tolerance and rounding: where two values are compared, how close counts as
  equal, and in which unit.
- Tests against live data that hard-code a "latest" date or value.
- A real run on real data with no step that diffs the changed data against an
  outside source before merge.
- Open choices left for the approval message ("approve A / approve B") when
  the choice changes the criteria. Settle them first: the hook records the
  criteria as written.
- Bans stricter than the goal needs, which block correct behavior.
- Criteria that cannot be tested, or that describe code instead of behavior.

## Output

Write the findings into the plan under `## Criteria review`, one line each:
the problem, the proposed fix, and what the author did ("fixed", or "kept,
because ...", or at the run limit "left to the owner (run limit)"). With nothing to fix, write `- No findings.` The author then
shows the owner the updated criteria and the review lines.

Reviewed criteria. Once every finding is answered, the author ends the
section with the line that names the criteria the review covers:

    - Reviewed criteria: <hash>

The hash comes from
`bash -c '. .claude/hooks/lodestar-lib.sh; criteria_hash < <plan file>'`.
Any later change to the criteria makes the line stale, and the approval hook
records nothing until a critic run covers the change (Re-run after a criteria
change) and the line is written again. Do not renew the line without that
run.
