# Independent Compare Workflow

## Purpose

Explore multiple independent solutions when the correct implementation approach is uncertain.

## Process

1. Understand the task and constraints.
2. Define the success criteria.
3. Create independent implementation branches/worktrees.
4. Give the same problem to each implementation agent.
5. Agents solve the problem independently.
6. Do not expose one solution to another before independent work is complete.
7. Run relevant tests for each solution.
8. Compare the solutions.
9. Evaluate:
   - correctness
   - requirements coverage
   - architecture
   - maintainability
   - performance
   - test quality
   - complexity
10. Select the approach that best satisfies the requirements.
11. Merge or reimplement the selected approach.
12. Run final verification.

## Agents

### Implementation Agent A

Produces an independent solution.

### Implementation Agent B

Produces a separate independent solution.

### Comparator

Reviews both solutions and identifies:

- strengths
- weaknesses
- trade-offs
- compatibility issues
- missing requirements

The comparator must base the decision on explicit technical criteria.

## Rules

- Solutions must remain independent until comparison.
- Do not choose a solution merely because it was implemented first.
- Do not merge incompatible approaches unnecessarily.
- Prefer the simplest solution that satisfies the requirements.
- Final implementation must be verified after selection.

## Completion Criteria

The task is complete only when:

- independent solutions were evaluated
- the selected approach satisfies requirements
- final implementation passes verification
- unnecessary code was removed
