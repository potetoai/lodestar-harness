# Feedback log

The agent adds one row each time the owner corrects an agent mistake; the
owner never has to. Reuse the same short tag for the same kind of mistake.
When a tag appears a second time, turn it into a lint rule or a test
(`rules/enforcement.md`, section 8) and set its rows to `enforced`.
`doctor.sh` warns about repeated tags that are not enforced yet.

A mistake caused by the Lodestar system itself (a missing workflow step, a wrong
template or hook) gets the prefix `lodestar-` in its tag, for example
`lodestar-install-outside-project`. It is fixed in lodestar-harness, not here, so
`doctor.sh` does not ask for a project rule. Set its status to `reported`,
then `fixed-<version>` once the template that fixes it is installed.

| Date | Tag | Mistake | Rule / invariant | Status |
|---|---|---|---|---|
