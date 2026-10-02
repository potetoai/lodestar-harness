# Global Security Rules

Version: 1.0
Scope: All projects using Lodestar-harness

---

## Purpose

Define baseline security discipline for all agents, and the security-review gate
for sensitive changes. These rules extend `rules/coding.md` (section 10) with a
concrete checklist and an explicit gate; they never replace project-specific
security requirements, which take precedence.

Security is never simplified away, even under a minimal-change or lazy default.

---

# 1. Security-Review Gate

A task is **security-sensitive** when it touches any of:

- Authentication or session handling
- Authorization / access control / multi-tenant boundaries
- Password reset, email change, account recovery, MFA
- Payment, billing, or money movement
- Personal or sensitive data (PII, health, financial, credentials)
- File upload, file access, or path handling
- Untrusted external input reaching a parser, query, template, or shell
- Secrets, tokens, keys, or cryptography
- External URLs / server-side requests (SSRF surface)
- Deserialization of untrusted data

For a security-sensitive task the Router MUST add `security_review` to the
required verification, and the task is not complete until that review passes.

For non-sensitive tasks the baseline checklist (section 2) still applies, but a
dedicated review is not required.

---

# 2. Baseline Checklist

Every change is checked against:

- **Input validation** at trust boundaries (user input, API, external responses,
  config). Server-side validation is authoritative; never rely on the client.
- **Injection**: parameterized queries / safe APIs for SQL, NoSQL, OS commands,
  LDAP, templates. No string-built queries from untrusted input.
- **Output encoding**: context-correct escaping to prevent XSS and template
  injection.
- **AuthN/AuthZ**: verify the caller's identity AND their permission for the
  specific object/action. Check object ownership (no IDOR).
- **Secrets**: never hard-code keys, passwords, tokens. Use the project's secret
  mechanism. Never log secrets or sensitive data.
- **Sensitive data**: minimize collection, encrypt in transit, avoid exposing
  internal detail in errors.
- **Dependencies**: do not add a dependency with known critical vulnerabilities;
  prefer maintained versions.
- **Errors**: fail closed. Do not leak stack traces, internal paths, or versions
  to untrusted callers.

---

# 3. Security-Review Content

When `security_review` runs, the reviewer verifies, for the change:

1. Trust boundaries are identified and inputs validated at each.
2. AuthN and AuthZ are enforced for every new or changed entry point.
3. No injection sink receives untrusted input unsafely.
4. No secret is introduced, logged, or committed.
5. Sensitive data handling matches project and compliance requirements.
6. Error and failure paths do not leak internal information.
7. New external calls / URLs cannot be abused (SSRF, open redirect).

Findings are treated like any review finding: valid ones must be resolved
before completion (see `workflows/build-review.md`). Disputed security findings
escalate; they are never silently dropped.

---

# 4. Never Simplify Away

Regardless of workflow or minimal-change defaults, never remove or skip:

- Input validation at trust boundaries
- Authentication and authorization checks
- Output encoding on untrusted data
- Secret management
- Error handling that prevents data loss or disclosure

---

# 5. Human Approval

The following require explicit human approval before proceeding
(see `rules/git.md`):

- Changes that weaken an existing authentication or authorization control
- Changes to cryptographic handling
- Exposing a previously internal endpoint or dataset
- Destructive operations on data or production systems

---

# Global Rule

> Validate at the boundary. Enforce authorization per object. Never trust the
> client. Never commit a secret. When a change is security-sensitive, review it
> before calling it done.
