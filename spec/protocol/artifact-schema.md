# Artifact Schema

## Required Artifacts

### `exploration.md`

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
- Optional sections:
  - human judgment notes (populated during Gate 2; not machine-editable)

### `verification.md`

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
- Optional sections:
  - human judgment notes (populated during Gate 5; not machine-editable)

## Shared Provenance Block

`verification.md` and `evaluation.md` must use one shared provenance block
so validators, status surfaces, and human close can consume the same fields.

Required bullet fields:

- role
- isolation mode
- execution context
- evidence
- fallback policy
- fallback reason

### `decisions.md`

- **Required when**: `architecture.md` contains at least one rejected alternative
  (i.e., significant architectural decisions that need Why / Why Not records)
- Writer: Architect
- Readers: Generator, Evaluator, Human
- Purpose: record architectural decisions with rationale (chosen, rejected, why, why not)
- Required sections:
  - at least one decision block (D1, D2, ...)
  - each block: choice, rejected alternatives, why, why not, impact

### `codebase-map.md`

- **Required when**: Explorer runs in repo-wide mode
  (first adoption on an existing codebase)
- Writer: Explorer
- Readers: all roles
- Purpose: structured understanding of the existing codebase for informed task scoping
- Required sections:
  - project structure
  - module dependencies
  - data model
  - code style and conventions
  - high-risk areas

### `escalation.md`

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

## External Artifacts

These live **outside** `.harness/` but are part of the protocol surface.

### `knowledge/lessons.md`

- Location: `<repo-root>/knowledge/lessons.md` (gitignored; local-only
  by Gate 2 decision D-1, 2026-04-05 — allows capturing company or
  sensitive context without leaking to the shared repo)
- Purpose: accumulated subsidiary knowledge from past task retrospectives
- Writer: `start-task.sh` (auto-extracted during task archival from the
  outgoing `retrospective.md` § Repo-Specific Lessons and § Harness Lessons)
- Readers: non-isolated roles only — Scoped Explorer (MUST read, record
  findings in `exploration.md` §11), Architect (subsidiary context in
  risk assessment)
- **Not consumed by**: Verification Explorer, Evaluator — these roles
  require independent judgment and must not inherit historical reasoning
  bias. See `role-contracts.md` Context Isolation Note.
- Growth policy: LRU — retain lessons from the most recent 30 tasks;
  older entries are pruned on each archival cycle
- Heading format in `retrospective.md`: level-2 with optional numeric
  prefix, e.g. `## 4. Repo-Specific Lessons`, `## Harness Lessons`
- Backward compat: repositories that still carry a legacy
  `.harness/lesson-index.md` should migrate to the new path manually; no
  automatic migration shipped

## Formatting Rules

1. Artifacts should be readable without model-specific prompt context.
2. Facts, assumptions, and judgments should be separable.
3. Blockers must be explicit, not implied.
4. Repo-specific paths should be concrete.
5. When a judgment is based on pattern recognition rather than explicit
   reasoning, flag it as uncertain. Do not fabricate reasoning to
   justify intuitive judgments — honest uncertainty is more useful
   than false precision.
