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
  - execution provenance
  - dry-run result
  - blockers
  - fallback strategies

### `task-status.md`

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

## Conditionally Required Artifacts

### `evaluation.md`

- **Required when**: task reaches `ready_for_human_close` or `complete`
- Writer: Evaluator
- Readers: Human, Generator, Reviewer
- Purpose: capture the independent assessment, verdict, and isolation provenance
- Required sections:
  - inputs
  - execution provenance
  - findings
  - verification results
  - verdict
  - residual risks

## Shared Provenance Block

`verification-path.md` and `evaluation.md` must use one shared provenance block
so validators, status surfaces, and human close can consume the same fields.

Required bullet fields:

- role
- isolation mode
- execution context
- evidence
- fallback policy
- fallback reason

### `generator-feedback.md`

- **Required when**: Generator discovers a requirement gap or architectural
  mismatch that cannot be resolved within the approved write surface
- Writer: Generator or Evaluator
- Readers: Architect, Specifier, Human
- Purpose: escalation channel for design-level issues found during implementation
- Required sections:
  - original assumption (from `architecture.md`)
  - actual finding (what the code shows)
  - impact on implementation
  - recommended next owner: `architect` | `specifier` | `human`

## Optional Artifacts

- `repo-map.md`
- `review-notes.md`
- `handoff.md`

## Formatting Rules

1. Artifacts should be readable without model-specific prompt context.
2. Facts, assumptions, and judgments should be separable.
3. Blockers must be explicit, not implied.
4. Repo-specific paths should be concrete.
