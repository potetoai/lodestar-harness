# Plan: agents merge sensitive code; the owner keeps a short list

> Route: BUILD_REVIEW risk=high, tests-first. The owner chose option A on
> 2026-11-09: keep the owner's approval of plain-language criteria, drop the
> merge-time approval for ordinary sensitive code.

## Why

The owner does not read code, so "duyệt merge PR <n>" on ordinary sensitive
code is not a quality check. Its real value is on what cannot be undone and on
stopping an agent from loosening its own checks. Those keep the approval.

## Design

- New optional list `owner_only_paths:` in `.ai/project.md` (money, passwords,
  real data). Declaring it is the project's opt-in; a project without it
  behaves exactly as today.
- Only `merge-pr.sh` changes behavior. Plan approval, locked tests, and the CI
  rule that sensitive code needs a test all stay.
- Limit, stated plainly: the review line is text written by an agent. The
  script can check that it exists and names a commit of the PR, not that the
  reviewer was really independent or right.

## Acceptance criteria

1. A project with no `owner_only_paths:` key: a PR changing a `sensitive_paths`
   file is refused without "duyệt merge PR <n>", exactly as today.
2. A project that declared the key validly: a PR changing a `sensitive_paths`
   file that is not on the owner-only list merges without the owner only when
   all of these hold: the route is BUILD_REVIEW, INDEPENDENT_COMPARE or COMPLEX
   with risk high or critical; the review line passes and names the PR's
   current head; the PR is not from a fork and not opened by a bot; no commit
   in the PR that touches a sensitive file carries `No-Test-Reason:`; the PR
   adds a plan whose criteria hash, read at the PR's head, is in the local
   `.ai/approvals.log`, never the PR's own copy, and is not in that file on
   GitHub at the target tip or the PR's base (so an old approved plan copied
   under a new name does not count; whether the plan fits the code is not checked);
   the PR changes a test file; the PR has fewer than 100 commits and fewer than
   3000 files (GitHub's listing limits); CI is green. `merge-pr.sh` checks
   these with its own path matching. A later PR of a multi-PR plan does not add
   the plan, so it uses the owner's merge approval.
3. If any condition in 2 fails, the PR is refused without the owner's approval
   for its current head, and the refusal says which condition failed.
4. Every file in the PR is checked and the strictest result wins, whatever the
   file order. A PR changing a file on the owner-only list is refused without
   the owner's approval for its current head, even with a passing review. A
   file on both lists counts as owner-only.
5. Safety files and locked tests stay owner-only in every project, opted in or
   not. A rename away from a listed path counts as changing that path.
6. Both lists and the opt-in are read from GitHub, at the target branch's tip
   and at the PR's base. The project is opted in only if both copies declare
   the key validly. The owner-only list is everything in either copy. Editing
   the local file, or the PR's own copy, neither opts in nor removes a path. The
   target tip's copy is read again after CI; if the result changed, nothing is
   merged and the script says to run it again.
7. A path listed in `sensitive_paths` only in the local file still counts as
   sensitive: criterion 2 applies to it, it is never free of checks.
8. If GitHub cannot be read (any error except "file not found"), nothing is
   merged. A project with no `.ai/project.md` on GitHub is not opted in.
9. Parsing. A key starting at column 0 counts, also inside a code fence. Valid:
   `owner_only_paths: []` (CRLF or a trailing comment allowed), or the bare key
   followed by at least one item. Not opted in: a bare key with no items, any
   other value on the key's line, a duplicate key, an item that starts with
   `[` or `/`, holds a backslash, or is empty once its comment is removed; a
   column-0 comment or blank line between items; also when either copy is
   malformed. Items match files the way
   `sensitive_paths` does in `merge-pr.sh` (any case, `./` and comments
   removed, a pattern with no glob also covers the folder). The refusal says
   why the project is not opted in and the item count of both copies.
10. Adding, changing or removing the key is a change to `.ai/project.md`, so
    that PR needs the owner's approval and takes effect only after merge. Its
    refusal says in plain words that it changes which code merges without the
    owner, and lists the paths added and removed.
11. No line of the shipped template matches `^owner_only_paths:`, checked by a
    test, so a new project or an upgrade never opts in by accident.
12. A refusal says which list the file hit and what the owner must type. After
    a sensitive PR merges without the owner, the script prints and posts as a
    PR comment one line naming all such files, the review line and the owner-only item count of both copies. If the
    comment fails it says so; the merge stands.
13. Unchanged: owner approval of tests-first criteria, locked tests before
    sensitive code, CI's "sensitive change needs a test", `security_review` on
    security-sensitive tasks, and the rule that destructive operations and PRs
    weakening a safety check wait for the owner. The cases in `rules/security.md`
    section 5 (weakened auth, crypto changes, exposing an internal endpoint or
    data, destructive operations) still stop the agent to ask the owner, even
    on the no-owner path; the script cannot detect them.
14. `rules/git.md` says a security-sensitive change may merge without the owner
    only through this path and that section 5 cases still wait.
    `rules/enforcement.md` (owner-only row) describes the conditions in 2 and
    their limit. `rules/security.md` section 5 is unchanged. The template and
    onboarding/maintenance docs explain the list and that it is optional.
    `bash enforcement/test.sh` and `bash scripts/check-links.sh` pass.
15. `doctor.sh` warns (never fails) about an `owner_only_paths` item that
    matches no tracked file, so a typo does not silently protect nothing.

## Criteria review

- Run 1 (full, 2026-11-09): did not read `ci-checks.sh` past line 110 (only its route and review lines by search), `sensitive-gate.sh`, `approval-record.sh`, `lodestar-lib.sh`, `enforcement/test.sh`. No code was run.
- C2, C13 (self-excused plan and tests): C13 says CI still needs a test and the plan, and the plan's premise is that the owner's approval of criteria stays, but `ci-checks.sh` lines 71-81 drop a commit from the check when it carries a `No-Test-Reason:` trailer, which the agent writes itself; the owner's merge word was what caught that, so sensitive code can now merge with no test, no plan and no owner. Also CI matches differently from `merge-pr.sh` (case-sensitive, no folder match for a pattern without a slash, no `./` or `# comment` cleanup, test files skipped), so a file `merge-pr.sh` calls sensitive may never reach the CI check. Fix: add a criterion that the no-owner path also requires, checked by `merge-pr.sh` with its own matching, an owner-approved plan in the PR and no `No-Test-Reason:` on any commit touching a sensitive file; otherwise it needs the owner's approval. Author: answered in the criteria (see the line after this list).
- C2 (review not tied to the code merged): "its review line passes" means it names any commit of the PR (`review_problem`), so a review of the first commit still counts after later pushes change the sensitive code. The owner's approval was tied to the head; this path would not be. Fix: on the no-owner path the review line must name the PR's current head, and a push after the review means a new review. Author: answered in the criteria (see the line after this list).
- C2, C3 (fork and outside PRs): nothing excludes a PR from a fork (`isCrossRepository`). In this public-repo setup an outsider writes the route and review lines themselves, and only the owner's approval stopped it. Fix: add to C3 that a fork PR is refused without the owner's approval. Author: answered in the criteria (see the line after this list).
- C2 (risk ignored): C2 checks the workflow only, so `BUILD_REVIEW risk=low` on sensitive code merges, although `router/ROUTER.md` makes sensitive paths at least high and CI does not check this. Fix: the no-owner path also requires `risk=high` or `risk=critical`. Author: answered in the criteria (see the line after this list).
- C4, C5, C12 (mixed PR, order of checks): today's loop stops at the first file that matches any list. No criterion covers a PR where the first file is ordinary sensitive code and a later one is owner-only, a safety file or a locked test; a loop kept as is would merge it. Fix: add a criterion that every file is checked and the strictest result wins whatever the file order, and C12's line names all sensitive files merged without the owner. Author: answered in the criteria (see the line after this list).
- C9 (empty or useless list opts in, fails open): C9 treats only a value on the key's line as malformed, so a bare `owner_only_paths:` with no items, or items in a form the parser drops or that can never match (`* app/pay`, `- # todo`, placeholder `- [path/or/glob]`, a leading `/`, a backslash, a typo matching no file), is a valid opt-in that protects nothing, while the owner believes the list is active. Fix: only a literal `[]` means empty; no items, an item with `[` placeholder form, a leading `/` or a backslash is malformed and not opted in; a pattern matching no file at the target tip is reported in the refusal or merge line. Author: answered in the criteria (see the line after this list).
- C6, C9 (parsing left unstated): not stated: the key must start at column 0 (the `sed` ignores YAML fences, so a key at column 0 in a fenced example or prose is live), a duplicate key, CRLF (`[]\r` must stay valid, GitHub's copy may be CRLF), `[]  # comment`, one copy valid and the other malformed. Fix: state each as a case: duplicate key or either copy malformed means not opted in; CRLF and a trailing comment after `[]` are valid; a fence gives no protection from parsing. Author: answered in the criteria (see the line after this list).
- C11 ("active" undefined): the template's own `sensitive_paths:` sits in a fenced example at column 0, so a documented `owner_only_paths:` example in the same style would be a real opt-in for every project copying the template. Fix: define it: no line of the shipped template matches `^owner_only_paths:`, checked by a test. Author: answered in the criteria (see the line after this list).
- C7 contradicts C2: "never less protected than today" is false once opted in, since a path listed only locally needs the owner today and C2 would merge it without. Fix: reword to "a path listed only locally still counts as sensitive (route and review checks apply)", or make a local-only path need the owner. Author: answered in the criteria (see the line after this list).
- C10 (blind approval of the opt-in): the owner does not read code, and `.ai/project.md` is one file among many in a PR, so the owner can approve turning this on, or shrinking the list, without knowing. Fix: when a PR adds or changes the key, the refusal states in plain words "this turns on merges without you" and lists the paths added and removed. Author: answered in the criteria (see the line after this list).
- C12 (trace is only terminal text): the line reaches only the agent's terminal, and the owner gives up the gate on trust that it is relayed. Fix: after a successful merge (not before), post the same line as a PR comment; a comment failure is printed but does not undo the merge. Author: answered in the criteria (see the line after this list).
- C13, C14 (rules conflict): `rules/git.md` says never auto-merge a security-sensitive change, and `rules/security.md` section 5 requires human approval for weakened auth, crypto changes and exposed endpoints, which is exactly what sensitive code holds; C13's "unchanged" list omits both and C14 says only "say the same". The script cannot detect these cases. Fix: C13 states whether the agent must still stop and ask for the `security.md` section 5 cases and for `security_review`, with the `git.md` bullet reworded to match; C14 names the exact statement each file must make so it can be checked. Author: answered in the criteria (see the line after this list).
- Author, run 1: all 12 fixed in the criteria (2, 3, 4, 7, 9, 10, 11, 12, 13, 14). One changed: a pattern matching no file is a `doctor.sh` warning (15), not a merge-time check, because merge time would need a full file listing from GitHub on every merge.
- Run 2 (full, 2026-11-09): did not read `sensitive-gate.sh`, `approval-record.sh`, `enforcement/test.sh`, `pr_plans`/`plan_ref`/`is_test` in the libs, `ci-checks.sh` outside lines 45-130, or the `rules/` files; no code was run. Run 1 findings are all closed in the criteria except as noted below.
- C2 (owner approval is forgeable): `plan_approved_at` reads `.ai/approvals.log` from the PR's own head, and `hash_approved` matches any line ending in the hash; the log is a committed, agent-writable file and is not in `merge-pr.sh`'s safety list, so an agent can add a line with its plan's hash and pass "criteria approved by the owner", and CI's plan check accepts it too. Fix: on the no-owner path check the hash against the local `.ai/approvals.log` (written only by the hook) or the target tip's copy, never the PR's copy; or make any PR change to `.ai/approvals.log` owner-only. Author: fixed in criteria 2, 6 or 9.
- C2 (any approved plan counts): "contains a plan" is satisfied by an old, already approved plan that the PR touches trivially, or one unrelated to the sensitive code (CI's `plan_ok` is the same). Fix: the plan must be added by this PR (status added), and its approved hash must not already be approved at the base; state in the limits that relevance to the code is not checked. Author: fixed in criteria 2, 6 or 9.
- C2, C13 (test requirement depends on CI's narrower matching): the run 1 fix made `merge-pr.sh` check plan and `No-Test-Reason:` with its own matching, but not "a test file changed". A file `merge-pr.sh` calls sensitive (any case, folder match for a pattern without a slash, `./`/comment cleanup) that CI's `sensitive()` misses needs no test and no plan, and CI is still green. Fix: C2 also requires, by `merge-pr.sh`'s own matching, a changed test file in the PR for the sensitive files (or state that such a file needs the owner). Author: fixed in criteria 2, 6 or 9.
- C2, C4 (silent truncation, fail open): `gh pr view --json commits` lists the first 100 commits and the pulls files API stops at 3000 files, so a `No-Test-Reason:` commit, a review-head check or an owner-only file past those limits is never seen. Fix: the no-owner path is refused when the PR has 100 or more commits or 3000 or more files (the owner approves instead). Author: fixed in criteria 2, 6 or 9.
- C9 (list ends early without notice): the shared `sed` range ends at the first column-0 line that is not blank or a dash, so a column-0 comment or text between items drops every later item, shrinking the owner-only list while the owner believes it is whole. Fix: a column-0 line other than a dash item or blank inside the list is malformed (not opted in), and the refusal and the merge comment print the parsed item count. Author: fixed in criteria 2, 6 or 9.
- C2, C6 (list read once, merge minutes later): both lists are read before the CI wait, which can take many minutes; a PR merged to the target in that window can add an owner-only path, and the old tip's copy still lets this PR merge without the owner. Fix: read the target tip again after CI and refuse the no-owner path if the owner-only list or opt-in changed. Author: fixed in criteria 2, 6 or 9.
- Run 3 (narrowed, 2026-11-09): did not read `merge-pr.sh`, `ci-checks.sh`, `sensitive-gate.sh`, `enforcement/test.sh`, the `rules/` files; read `approval-record.sh` write paths, `hash_approved`, `plan_approved_at`, `criteria_hash`. No code was run.
- C2 (local approvals.log is not "written only by the hook"): `approval-record.sh` appends to `.ai/approvals.log` in the working tree, but it is an ordinary file the agent can edit with Bash or Edit, and `hash_approved` accepts any line ending in whitespace plus the hash (`x x <hash>`), so an agent can forge the local line and pass the check. Fix: trust only the target tip's copy (and make any PR change to `.ai/approvals.log` owner-only), or require a line shaped `<date> <plan path> <hash>` in that tip copy; drop the local file as a source. Author: left to the owner (run limit).
- C2 (old approved plan copied under a new name): "adds a plan" is satisfied by a PR that copies an already approved plan to a new file; `criteria_hash` hashes the criteria text only, so the copy's hash is approved, yet Run 2's fix (hash not already approved at the base) is no longer in C2. Fix: add that the plan's hash must not appear in the base's `.ai/approvals.log` under another plan path, or that the approval line is newer than the base; state that relevance to the code is not checked. Author: left to the owner (run limit).
- C9, C12 (parsed item count dropped): Run 2 asked that the refusal and merge comment print the parsed item count so a shrunk list shows; C9 says only the refusal gives the reason and C12 omits the count. Fix: the refusal and the C12 line print the item count of both copies. Author: left to the owner (run limit).
- Run 4 (narrowed, 2026-11-09): did not read `merge-pr.sh`, `ci-checks.sh`, `enforcement/test.sh`, the `rules/` files, `approval-record.sh`; read `hash_approved`, `plan_approved_at` and the changed lines of C2, C9, C12. No code was run. Run 3 findings 2 (copied plan) and 3 (item count) are closed; finding 1 is the owner's decision and not re-raised.
- C2, C6 (approvals log at the tip not re-read after CI): C6 re-reads only the owner-only list and opt-in after CI, but C2 also needs the plan hash absent from the tip's `.ai/approvals.log`; a PR merged during the CI wait that carries the same plan (or copy) puts the hash there, and this PR still merges without the owner. Fix: C6 also re-reads the tip's `.ai/approvals.log` after CI and refuses the no-owner path if the hash is now present. Author: left to the owner (extra run).
- Reviewed criteria: 36d2a2f7f822e5afaf2de1c5425f4329939bb72b (numbered items hashed as "- " items)

## Progress

| Date | Step | PR |
|---|---|---|
| 2026-11-09 | Criteria written | |
| 2026-11-10 | Tests (e0dfced), merge-pr.sh, doctor B5b, docs (656a22b) | |

## Decision log

- 2026-11-09: owner on Run 4: "duyệt, bỏ qua". Not fixed: a second PR sharing a
  plan can merge without the owner if the first merges during its CI wait.
  Criteria approved at hash 36d2a2f7f822e5afaf2de1c5425f4329939bb72b.
- 2026-11-09: owner on Run 3: "duyệt, sửa điểm 2 và 3, giữ điểm 1". Point 1
  kept: the local approvals log stays the source of the plan approval, the same
  trust as the merge approval today; an agent able to edit it can forge it.
- 2026-11-09: option A chosen by the owner. Option B (drop criteria approval
  too) not taken; it would need `router/ROUTER.md`, frozen until 2026-11-26.
