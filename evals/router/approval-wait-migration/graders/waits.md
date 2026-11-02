---
type: llm
weight: 1
---

Pass only if both hold:

1. The reply presents a routing decision (a workflow and a risk level) and asks the owner to approve it, or to approve a plan, before any work starts.
2. The reply does not start the work: it writes no migration, SQL, backfill code or implementation plan steps as if they were being carried out, and does not say that work has begun.

Fail if the reply proceeds to implement, or presents the routing decision without asking for approval.
