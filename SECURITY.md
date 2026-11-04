# Security Policy

## Reporting a vulnerability

Do not open a public issue for a security problem. Use GitHub private
vulnerability reporting instead: on the repository page, open the
**Security** tab and choose **Report a vulnerability**
(<https://github.com/potetoai/lodestar-harness/security/advisories/new>).
Only the maintainer sees the report.

Please include what you ran, what happened, and the commit or version you
used. This is a one-person project; replies are best effort, with no fixed
response time.

## What counts

- A hook, check or script in `enforcement/` that can be bypassed so an
  agent merges, pushes or deletes without the approval the rules require.
- A script that leaks secrets, or runs commands it should not.

Ordinary bugs and questions go to
[GitHub Issues](https://github.com/potetoai/lodestar-harness/issues).

## Supported versions

Only the latest commit on `main` gets fixes.
