# Artifact Schema

## Required Artifacts

### `scoped-map.md`

- Purpose: local task understanding
- Required sections:
  - task statement
  - scope
  - entry points
  - call chain
  - existing behavior
  - existing tests
  - risks
  - suggested next step

### `requirements.md`

- Purpose: implementation contract
- Required sections:
  - problem
  - scope
  - requirements
  - non-goals
  - acceptance criteria
  - constraints
  - validation intent

### `architecture.md`

- Purpose: recommended change design
- Required sections:
  - problem framing
  - first-principles decomposition
  - recommended approach
  - surface scan
  - verification strategy
  - risks
  - self-challenge

### `verification-path.md`

- Purpose: prove validation can actually run
- Required sections:
  - intended checks
  - commands
  - dependencies and prerequisites
  - dry-run result
  - blockers
  - fallback strategies

### `module-status.md`

- Purpose: minimum control plane
- Required sections:
  - task row with owner and state
  - state notes
  - blockers
  - residual risks

### `retrospective.md`

- Purpose: capture reusable process lessons
- Required sections:
  - what worked
  - what failed
  - what should be standardized
  - repo-specific lessons
  - next version recommendations

## Optional Artifacts

- `repo-map.md`
- `review-notes.md`
- `evaluation.md`
- `handoff.md`

## Formatting Rules

1. Artifacts should be readable without model-specific prompt context.
2. Facts, assumptions, and judgments should be separable.
3. Blockers must be explicit, not implied.
4. Repo-specific paths should be concrete.
