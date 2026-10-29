# Global Git Rules

Version: 1.0
Scope: All projects using Lodestar-harness

---

## Purpose

Define global Git rules for all agents, whatever runtime runs them.

These rules are especially important when multiple agents work in parallel using separate branches or worktrees.

---

# 1. Core Principle

Git operations must preserve:

* Existing work
* Other agents' changes
* Commit history
* Branch integrity
* Reviewability

Agents must never perform destructive Git operations without explicit authorization.

---

# 2. Inspect Before Changing

Before modifying Git state, inspect:

```bash
git status
git branch
git log
```

When working in a multi-agent environment, also determine:

* Current branch
* Current worktree
* Whether uncommitted changes exist
* Whether another agent may be working on related files

Never assume the repository is clean.

---

# 3. Worktree Isolation

When the runtime assigns independent agents to separate worktrees:

```text
Main Repository
      │
      ├── Agent A → Worktree A
      │
      ├── Agent B → Worktree B
      │
      └── Agent C → Worktree C
```

Each agent should modify only its assigned worktree.

Do not modify another agent's worktree.

Independent agents should not share uncommitted changes.

---

# 4. Branch Responsibility

Each independent implementation should normally have its own branch.

Branch names should be:

* Descriptive
* Related to the task
* Consistent with project conventions

Examples:

```text
feature/user-profile
feature/payment-api
fix/login-timeout
refactor/design-system
```

Do not create unnecessary branches for trivial changes when the project workflow does not require them.

---

# 5. Existing Changes

If the working tree already contains changes:

Do not automatically:

* Delete them
* Reset them
* Stash them
* Overwrite them

First determine whether they belong to:

* Current task
* Another task
* Another agent
* The user

If ownership is unclear, stop and report the situation.

---

# 6. Commit Rules

Commits should represent coherent changes.

Prefer:

```text
One logical change → One meaningful commit
```

Avoid commits containing:

* Unrelated changes
* Temporary debugging code
* Generated noise
* Unnecessary formatting changes

Commit messages should clearly describe the change.

Examples:

```text
feat: add user profile editing
fix: handle expired authentication token
refactor: extract payment service
test: add checkout validation tests
```

Follow project-specific commit conventions when they exist.

---

# 7. Commit Timing

Agents should commit when the workflow requires a stable checkpoint or when work is ready for review.

Do not create excessive commits for every tiny edit.

For independent agent workflows, committing the completed implementation before comparison or merge is recommended.

---

# 8. Uncommitted Changes

Before finishing a task:

```bash
git status
```

Verify that:

* Intended files are modified
* No unexpected files changed
* Temporary files are removed
* Debug code is removed

Do not leave unrelated changes in the working tree.

---

# 9. Diff Review

Before reporting completion, inspect:

```bash
git diff
```

and, when appropriate:

```bash
git diff --stat
```

The final diff should match the requested scope.

Check for:

* Accidental changes
* Debugging code
* Secrets
* Generated files
* Formatting noise
* Unrelated refactoring

---

# 10. Generated Files

Do not commit generated files unless:

* The project tracks them intentionally
* The project requires them
* The existing repository convention requires them

When generated files are tracked, follow the project's generation workflow.

---

# 11. Secrets

Never commit:

* API keys
* Passwords
* Access tokens
* Private keys
* Credentials
* Production secrets
* Sensitive environment files

Before committing, inspect changed files for accidental secrets.

---

# 12. Push, PR, and Merge

When a task's work is complete and its verification has passed, the worker pushes
its own feature branch and opens a pull request against the base branch, with the
verification evidence in the PR body. The PR body also carries the task's route
line (`Lodestar route: <WORKFLOW> risk=<level>`, `router/ROUTER.md`) and, for
BUILD_REVIEW and up, `Lodestar review: <verdict>, <who>, <commit>`; CI fails
without them (`ci-checks.sh`), and `merge-pr.sh` refuses without them even
when CI cannot run. The review line counts only when its verdict starts with
`approve` or `pass` (the review passed, after its findings were fixed) and it
names a commit of this PR (7 or more hex characters), e.g.
`Lodestar review: pass (2 minor fixed), reviewer subagent, 1a2b3c4`. Pushing the worker's own branch and opening
a PR is allowed by default. Pushing directly to a shared or base branch is not.
Commit, push and open the PR without asking the owner; report it in one line.
Push before stopping to wait for the owner too: a commit only on this machine
is lost with it. The Stop hook (`verify-before-stop.sh`) holds a stop once per
HEAD while the branch has commits on no remote branch.

Merge policy by workflow:

- **SIMPLE** — after verification passes and only if there are no conflicts, the
  worker may merge its own PR automatically. A SIMPLE task that escalated to a
  higher workflow mid-execution loses this — it is no longer SIMPLE.
- **BUILD_REVIEW / INDEPENDENT_COMPARE / COMPLEX** — the worker may merge its
  own PR when the review passed: every reviewer (and critic) finding is fixed,
  or rejected with a reason written in the PR. The owner's standing approval
  (2026-10-16) replaces a merge word per PR; the gates below still hold.

Never auto-merge when any of these hold, regardless of workflow — open the PR and
wait for a human instead:

- verification did not pass,
- merge conflicts exist,
- the change is security-sensitive (see `rules/security.md`); a PR that changes
  `sensitive_paths`, a locked test or a safety file is also refused by
  `merge-pr.sh` until the owner types "duyệt merge PR <n>"
  (`rules/enforcement.md`, "Owner-only merge"; adding new tests to the lock
  and editing `.claude/docs/` are not owner-only). The hook knows only those
  file lists: a security change elsewhere still needs the worker to stop and
  ask,
- the operation is destructive (deletes data, writes a real database, rewrites
  history),
- the change weakens a safety check: removes or relaxes a hook, a CI step, a
  locked test, doctor, or a rule in this list,
- the owner said to hold this PR, or the project forbids auto-merge (below).

After an automatic merge, tell the owner in one line what was merged and which
gates it passed. The owner stops automatic merges by saying so; record it in
`.ai/project.md` as a project rule.

Merge only with `bash .claude/hooks/merge-pr.sh <n>` (options `--squash`,
`--rebase`, `--delete-branch`). It waits for CI and merges only when the wait
itself exits 0, so give the command a long timeout or run it in the
background. Hand-written forms failed: `gh pr checks | tail && gh pr merge`
returns the exit code of `tail`, so a red CI still merged, and
`gh pr view && gh pr merge` has the same flaw. The `guard-install.sh` hook
blocks every other merge command, and the script checks state, not text.
Push every commit before the merge: a commit left only on the local branch
is not part of the merge and is lost without a warning (PR #36). The script
refuses while the PR's branch has local commits not pushed, and merges only
the head it checked (`--match-head-commit`), so a push while CI runs means
running it again.

When CI cannot run at all (for example the repo has no Actions minutes left),
`merge-pr.sh` stops on the red checks. Run on the PR's branch `make verify` and
`PR_NUMBER=<n> GITHUB_REPOSITORY=<owner>/<repo> bash .claude/hooks/ci-checks.sh origin/<base>`,
tell the owner both results, and leave the merge to the owner, by hand on GitHub.

A project may forbid auto-merge entirely in its `.ai/project.md` (for example when
the "done" check is run by a human, not CI). The project rule wins.

Follow the project's branch, PR, and remote conventions.

---

# 13. Destructive Commands

Agents must NOT execute destructive Git commands without explicit authorization.

Examples include:

```bash
git reset --hard
git clean -fd
git push --force
git branch -D
git checkout .
```

Also treat commands that discard uncommitted work as destructive.

If such an operation appears necessary, explain the reason and request approval.

---

# 14. Rebase

Do not rebase shared branches without authorization.

Rebase may rewrite commit history.

For isolated agent branches, rebase may be used when the workflow explicitly requires it.

Prefer the least disruptive approach.

---

# 15. Merge

Only merge when the workflow requires integration.

Before merging:

1. Ensure the source branch is complete.
2. Verify tests.
3. Review the diff.
4. Check for conflicts.
5. Understand conflicting changes.

After merging:

1. Run relevant tests.
2. Check Git status.
3. Inspect the final diff.
4. Verify that both intended changes remain intact.

---

# 16. Merge Conflicts

When conflicts occur:

1. Identify the conflicting files.
2. Understand both sides.
3. Determine intended behavior.
4. Resolve deliberately.
5. Do not blindly choose ours/theirs.
6. Run relevant tests.
7. Review the resulting diff.

If the correct resolution is ambiguous, escalate to the appropriate agent or human.

---

# 17. Multi-Agent Integration

For workflows such as:

```text
Agent A ──┐
Agent B ──┼──→ Integration
Agent C ──┘
```

Each agent should:

1. Work independently.
2. Keep changes isolated.
3. Complete implementation.
4. Run relevant tests.
5. Report changed files.
6. Commit when required.
7. Hand off to the integration step.

The integration agent is responsible for resolving interactions between implementations.

---

# 18. Independent Compare Workflow

For independent implementation comparison:

```text
Task
 ├── Agent A → Worktree A
 └── Agent B → Worktree B
          ↓
      Compare
          ↓
   Select / Merge
          ↓
      Verify
```

Do not expose one implementation to the other before independent implementation is complete.

Compare:

* Correctness
* Requirements
* Architecture
* Maintainability
* Test quality
* Complexity
* Performance where relevant

The selected implementation must still pass final verification.

---

# 19. Review Workflow

For Build → Review workflows:

```text
Builder
   ↓
Commit
   ↓
Reviewer
   ↓
Findings
   ↓
Builder Fix
   ↓
Test
   ↓
Final Diff
```

The Reviewer should review the actual Git diff whenever possible.

Review findings should reference:

* File
* Relevant code
* Problem
* Impact
* Recommended fix

---

# 20. Do Not Hide Changes

Agents must not:

* Modify history to hide mistakes
* Delete evidence of changes
* Rewrite another agent's commits without reason
* Force-push to conceal problems

Git history should remain understandable and reviewable.

---

# 21. Pull / Sync

Before synchronizing with the main branch:

1. Check current branch.
2. Check working tree.
3. Ensure local changes are safe.
4. Understand incoming changes.
5. Resolve conflicts carefully.
6. Run relevant verification afterward.

Do not blindly pull or merge when the working tree contains unknown changes.

---

# 22. Final Git Verification

Before declaring a task complete:

```bash
git status
git diff
```

Verify:

* Correct branch
* Expected files changed
* No unrelated files changed
* No secrets
* No temporary files
* No accidental generated files
* Tests completed
* Working tree is in the expected state

---

# 23. Agent Handoff

When handing work to another agent, report:

```text
Branch:
Worktree:

Changed Files:
- ...

Implementation:
- ...

Tests:
- ...

Commit:
- <commit hash/message>

Known Issues:
- ...

Next Action:
- ...
```

This allows the next agent to continue without reconstructing the previous agent's work.

---

# 24. Human Approval

Human approval is required before:

* Destructive Git operations
* Force push
* Deleting important branches
* Discarding unknown changes
* Destructive database migrations
* Irreversible repository changes

When uncertain, preserve the existing state rather than destroying it.

---

# Global Rule

Git is part of the safety system of the multi-agent workflow.

> Inspect before changing.
> Isolate before parallelizing.
> Review before merging.
> Verify before finishing.
> Never destroy work without authorization.
