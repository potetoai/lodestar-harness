# Idea: design review step

Reported by App01, 2026-11-04 (`lodestar-no-design-review-step`). Not yet
rated.

App01 PR #141 put user-facing "Use for" texts (type.* tokens) into a PR with
no UI/UX review. Colors in the same project got one (skill checklists, a
contrast test, a demo) only because that session planned it, not because a
workflow asked. Today UI/UX shows up only in COMPLEX phase 8
(`workflows/complex.md`), and there as browser QA, not as a review of copy,
visual choices or accessibility. A BUILD_REVIEW change to user-facing text or
visuals gets the code reviewer only.

Open: whether a review step pays for its tokens (the owner watches token cost);
what triggers it (files touched, a plan tag, the Router's UI/UX signal);
whether it is a reviewer checklist line, a skill pick in
`skills/capabilities.md` (design critique, UX copy, accessibility), or a new
role. Rate it in an active plan, with App01's PR history as evidence, before
any work.
