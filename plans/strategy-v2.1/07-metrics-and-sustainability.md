# Metrics and Sustainability

## Measurement philosophy

Measure adoption without hidden surveillance. Lodestar should not require telemetry to function, and no sensitive project data should be collected by default.

Use public evidence, opt-in reports, pilot follow-ups, and voluntary surveys. Clearly label estimates and self-reported numbers.

## Metric hierarchy

### Product usability
- Time to first successful task.
- Percentage of pilot users who complete setup without live help.
- Common setup failure rate.
- Documentation issues reported.

### Product value
- Early repeat use in days 1–29 after the first accepted real task; retained use is a separate day-30–60 measure below.
- Human interventions per task.
- Acceptance criteria and verification outcomes.
- User-reported reduction in repeated prompting or rework.
- Evidence that a simpler setup would not have been sufficient.

### Adoption
- **External adopting projects:** distinct projects operated independently of the Lodestar maintainer with a confirmed accepted real task. Count projects and people separately; the maintainer's own projects do not count as external adoption.
- **Active external projects:** external projects that report using Lodestar on at least one real task in the measurement period.
- **30-day retained external projects:** adopting projects with at least one further accepted real task in days 30–60 after their first accepted task. At the reporting cutoff, use only projects whose full day-60 window has elapsed in the denominator. Report retained / eligible, pending windows, contacted/responded counts and unknown outcomes separately. Nonresponse is not confirmed retention or proven abandonment.
- **Independent contributors:** people outside the maintainer's close circle who submit a meaningful contribution.
- **Supported integrations in use:** integrations validated by an external user, not merely listed in docs.

Avoid presenting these as precise global counts unless the evidence supports that precision.

## North Star

Use **30-day retained external projects** as the primary outcome once a reliable opt-in reporting process exists.

Before that, use a qualitative milestone: external users independently complete and repeat real tasks.

Do not set a hard target such as 30–50 projects before establishing a baseline. After the first pilot cohort, set:
- Minimum: evidence of repeat use by at least a few independent projects.
- Target: a realistic improvement based on the observed cohort.
- Stretch: ambitious growth that does not drive premature feature expansion.

## Sustainability metrics

- Median maintainer response time for actionable issues.
- Open high-priority bug age.
- Release frequency and regression rate.
- Percentage of changes with documented tests/evidence.
- Number of areas with more than one capable maintainer.
- Dependency and security update backlog.
- Maintainer hours per month.
- Support hours per active project and consecutive weeks above the selected weekly ceiling.
- User-maintained configuration size, concepts misunderstood, and measured upgrade/rollback time, using [05](05-product-validation-and-benchmark.md).

## Governance and maintenance

Define before the project grows:
- Supported environments and compatibility policy.
- Versioning and release cadence.
- Deprecation and migration policy.
- Contribution and review expectations.
- Security vulnerability reporting path.
- Dependency/license review process.
- Code of conduct and community moderation expectations, if a community space is opened.
- Ownership and backup maintainers for critical areas.

Before the first pilot, publish the minimum supported version/environment, upgrade/removal instructions and ordinary/private issue-reporting path. Reuse the existing [7–14 day batched release policy and urgent-fix exceptions](https://github.com/potetoai/lodestar-harness/blob/ebf2587ca3b716ee6cbab2414f6436abe9052ea0/enforcement/README.md); Stage 4 documents and exercises sustainability rather than postponing these basics. Runtime tier criteria live in [01](01-vision-and-positioning.md), capacity and gates in [04](04-roadmap-12-months.md).

Keep governance lightweight until the contributor base justifies more formality.

## Business and sustainability strategy

The open-source core must remain useful, adaptable and self-hostable: users can keep its instructions, rules, roles, workflows and enforcement in their own environment without a Lodestar-hosted account or paid Lodestar service. Coding-agent providers and other external tools still have their own terms and costs. Do not create artificial limits or remove core verification to force upgrades.

The baseline sustainability model is a tightly bounded maintainer commitment supported by reusable documentation, community fixes and ecosystem examples. Voluntary sponsorship or grants may help if available, but no income is assumed. Staying small and useful without revenue is success. Encourage contributions by making scope, checks and ownership legible; do not transfer unbudgeted support obligations to volunteers.

After methodology, value, adoption and maintainable ecosystem practices have evidence, a team/enterprise offering may be explored. Possible hypotheses are paid onboarding/support or assistance adapting shared policy; these are not roadmap features. Require two unrelated organizations to describe the same paid problem, identify a buyer and budget range, and at least one concrete commitment to a scoped paid pilot before building commercial features. Survey enthusiasm alone is not willingness to pay. Prefer a bounded service experiment before product development, and account for sales/support time as maintenance cost.

If commercial discovery is activated, record an owner, capacity allocation, evidence source and actual calendar dates for C1 in [08](08-execution-guide.md). At stop without the demand evidence below, defer commercial work; do not restrict the core to manufacture demand. C1 is optional and is not a dependency of S1–S4. No commercial experiment starts if it would push maintenance above the recorded capacity ceiling.

| Gate | Measure (source) | Minimum | Check | Stop | Status |
|---|---|---|---|---|---|
| C1 Commercial demand | Consented discovery records indexed in 08: organization independence, problem, buyer, budget range and paid-pilot commitment | Two unrelated organizations name the same paid problem, buyer and budget range; at least one concrete commitment to a scoped paid pilot | Recorded discovery start +30 days | Recorded discovery start +51 days | waiting (0 commitments recorded; not started) |

## License and contribution evidence

**Verified repository facts (2026-11-04, local snapshot `ebf2587`):** [LICENSE](https://github.com/potetoai/lodestar-harness/blob/ebf2587ca3b716ee6cbab2414f6436abe9052ea0/LICENSE) is MIT, copyright 2026 potetoai. `git log --follow -- LICENSE` traces it to initial commit `4c23d3a` (2026-10-02), with no later license edit in inspected history. The [public repository](https://github.com/potetoai/lodestar-harness) also identified MIT when checked.

The local repository is not shallow. `git shortlog -sne --all` lists two author identities, `potetoai` and `Poteto`; commit trailers also credit Claude assistants. This is an attribution inventory, not proof that those identities are one legal person, that AI trailers confer copyright, or that all rights are owned by one party. No separate CONTRIBUTING, CLA or DCO document was found among tracked paths. Private agreements, employer rights, material outside fetched history and source provenance remain unverified. [THIRD_PARTY.md](https://github.com/potetoai/lodestar-harness/blob/ebf2587ca3b716ee6cbab2414f6436abe9052ea0/THIRD_PARTY.md) describes external tools; it is not a rights audit.

**Recommendation:** keep MIT for the core. MIT permits commercial use and distribution subject to its notice requirements; a paid service does not itself require changing the core license. See the [official MIT text](https://opensource.org/license/mit).

**Decision requiring verification:** do not assume replacing LICENSE withdraws permissions on previously distributed MIT copies. Distinguish existing contributions and notices from terms offered for future contributions/releases. Before any change, verify provenance, rights holders and employer interests, compatibility obligations, and whether the proposed change needs contributor permission or additional agreements. Do not assume all changes require unanimous consent, or that all are already authorized. Obtain qualified legal review of the actual proposal and consult affected contributors; this revision authorizes no license change or CLA. [GitHub's Open Source Guide](https://opensource.guide/legal/#what-if-i-want-to-change-the-license-of-my-project) distinguishes these cases and their governance implications.

## Practical risk register

Likelihood/impact ratings are qualitative planning judgments, not measured probabilities. The strategy owner checks relevant warning signals at gate reviews or when an incident occurs; do not create a separate reporting process. Record actual decisions in [08](08-execution-guide.md).

| Risk | Likelihood | Impact | Early warning | Mitigation | Contingency / decision trigger |
|---|---|---|---|---|---|
| 1. Lodestar becomes too complicated | High | High | Two pilots cannot explain the required concepts or need recurring setup help; configuration/update effort exceeds their pre-agreed ceilings | One first-use path; count concepts and user-maintained configuration; admit components only for observed needs | Freeze additions; simplify the failing path through reviewed moves/links; if S1 still fails at stop, narrow scope |
| 2. Normal instructions achieve similar results | Medium | High | B matches C on acceptance and corrections while using less time/upkeep | Strong frozen baseline; disclose costs; test bounded use cases | At S2, withdraw unsupported differentiation claims and recommend the lighter setup; do not claim equivalence from an underpowered sample |
| 3. Value is difficult to demonstrate objectively | High | High | Reviewers disagree, outcomes depend on task choice, or baseline is contaminated | Pre-register criteria; isolate homes; blind quality review; retain unsuccessful runs | If smoke cannot produce trustworthy scoring within budget, stop the batch; redesign one case or report only qualitative evidence |
| 4. Runtime changes break compatibility | High | High | Trusted hooks stop running, input formats change, or live checks disagree with fixtures | Version-scoped tiers; live lifecycle checks; retain last verified version and migration notes | Immediately withdraw the affected support claim; repair or demote that combination after the recorded 21-day window under 01 |
| 5. Agents ignore or inconsistently follow workflows | High | High | Unsupported completion claims, missing checks, or repeated owner corrections despite clear instructions | Independent outcome checks; existing Router evals at their mandated triggers; machine checks where appropriate | Contain a serious missed guard immediately; repeated failures within a cohort block the reliability claim and trigger a focused policy/enforcement review |
| 6. Maintenance exceeds capacity | High | High | Two weeks above the weekly ceiling; support crowds out recovery time; unresolved compatibility faults accumulate | One active validation question; reserve maintenance time; no SLA or speculative adapters | Pause recruitment/features; reduce supported scope with notice or enter maintenance mode; resume only after a feasible capacity allocation |
| 7. Attention does not become usage | Medium | Medium | Posts receive responses but few accepted tasks or independent repeats; follow-ups go unanswered | Qualified cohort, real-project tasks, denominators and dated retention records | If S1/S3 stops without use, pause promotion and interview non-returners where consented; narrow the problem or stop external expansion |
| 8. Commercial ambitions undermine open-source trust | Medium | High | Proposals to restrict core verification, ambiguous licensing, or contributor objections to paid priorities | Useful self-hostable MIT core; transparent demand gate; separate commercial obligations and budgets | Suspend the commercial proposal when it requires crippling core value or rights remain unclear; resolve consultation/legal questions before reconsidering |

## Quarterly review

At the end of each quarter, ask:
1. Which user problem is now better understood?
2. Which product claim is supported by evidence?
3. Which feature adds more maintenance than value?
4. What should be removed or simplified?
5. Are users returning?
6. Can someone other than the founder maintain and explain the project?

## Vanity-metric policy

GitHub stars, forks, social impressions, and downloads can help indicate reach, but they are not the North Star and should never justify roadmap decisions by themselves.
