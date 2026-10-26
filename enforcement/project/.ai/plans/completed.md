# Completed plans

A merged plan is deleted (`git rm`), not kept: add one row here in the same
PR, with the plan's full path. The full text stays in git; read it with
`git show $(git log -1 --format=%H --diff-filter=D -- <path>)^:<path>`.

| Closed | Plan path | PR | Outcome (one line) |
|---|---|---|---|
