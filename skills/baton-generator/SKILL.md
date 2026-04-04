---
name: baton-generator
description: >
  Implement approved changes following the architecture and verification path.
  Trigger when the user asks to "implement", "generate code", "write the code",
  "build this", or "execute the plan". Takes approved requirements.md,
  architecture.md, and verified verification-path.md. Produces code changes
  with checkpoint validation. Produces implementations, not designs or reviews.
user-invocable: true
---

# Generator

> Derived from spec/protocol/role-contracts.md — Generator

## Role Contract

- **Inputs**: approved `requirements.md`, approved `architecture.md`,
  verified `verification-path.md`
- **Outputs**: code changes, execution notes, updated `task-status.md`

## Artifact Language Policy

Read `artifact_language` from `task-status.md` § State Notes (`zh` or `en`).
Write all human-facing artifacts and feedback files in that language.
Do not localize `task-status.md`.

## Precondition

`verification-path.md` must exist and pass Gate 3. If it does not exist or
has unresolved blockers, **hand back to Verifier** — do not proceed.

## Execution Guide

### 1. Reading Phase

Read artifacts in this order — each builds on the previous:

1. `architecture.md` — understand the approach and module breakdown
2. `requirements.md` — understand what must be true when done
3. `verification-path.md` — understand how correctness will be proved
4. `decisions.md` (if exists) — understand rejected alternatives

### 2. Pre-Implementation Check

Before writing any code:
- Check for uncommitted changes: `git status`. If dirty, stash or
  confirm with user before proceeding.
- **Record base commit**: run `git rev-parse HEAD` and write the result
  to `task-status.md` under `## State Notes` as `- base_commit: <hash>`.
  The Evaluator uses this to compute the correct diff range. If you
  skip this step, the Evaluator may review an incomplete diff.
- Verify write surface matches `architecture.md` — list all files to
  create or modify.

### Quality Standards

Every implementation must meet these criteria before handoff. The
Evaluator will reject code that fails these checks, so fix them
proactively rather than consuming repair rounds.

1. **Linting**: Repo linter passes with no new warnings. Fix violations
   instead of suppressing them. If no repo linter exists, follow the
   language's standard style guide.
2. **Typecheck**: Passes cleanly. No untyped escape hatches (`any`,
   `Object`, `dynamic`) without a justifying comment.
3. **Tests**:
   - New public functions and behaviors must have tests.
   - Tests are behavior-driven: they describe *what* the code should do,
     not *how* it does it. A test that passes with a wrong implementation
     is not a test.
   - Write tests alongside or before implementation — do not defer to end.
4. **Code style**: Follow existing repo conventions (naming, formatting,
   module structure). Run the repo's auto-formatter if one exists.
5. **Dependencies**: New dependencies require justification traceable to
   `architecture.md`. No dependencies with known critical vulnerabilities.
6. **Security**:
   - No secrets in code (API keys, passwords, tokens).
   - User input is validated at system boundaries.
   - No injection vulnerabilities (SQL, XSS, command injection).
7. **Performance**: No obvious regressions in paths identified as
   performance-sensitive in `verification-path.md`.
8. **Comments**: Public APIs and non-obvious logic have comments explaining
   *why*, not *what*. Do not add comments to self-evident code.

### 3. Implementation Phase

**Scope files**: list all files to create or modify, cross-check against the
architecture's write surface.

**Implementation order**:
1. If `requirements.md` has priorities, implement all P0 requirements first,
   then P1, then P2.
2. Within a priority level, respect `depends-on` links — implement
   dependencies before dependents.
3. If `architecture.md` has a Delivery Order section, follow its unit
   ordering.

**Implement in logical-unit batches**:
- One batch = one independently verifiable requirement or sub-problem
  (not a fixed file count)
- Write tests alongside or before implementation for each batch — do not
  defer all tests to the end
- After each batch, run the relevant verification commands from
  `verification-path.md`
- Record the checkpoint result (pass/fail/partial)
- Update `task-status.md` notes: `batch N/M complete`
- Commit at each passing checkpoint

### 4. Checkpoint Validation

After each batch:
1. Run the verification commands relevant to the changed files
2. If pass → commit and continue to next batch
3. If fail → fix within the same batch before moving on
4. If fix attempts exceed 2 under the same hypothesis → stop and assess
   whether the architecture assumption is wrong

### Constraint Rules

1. **Do not modify** `requirements.md` or `decisions.md` — these are approved
   artifacts. If you find an issue, note it for the Evaluator.
2. **Stick to the approved write surface** — files listed in the architecture.
   If a file outside the write surface must change, record the reason before
   making the change.
3. **Minimize changes in high-risk areas** identified in `scoped-map.md`.
   Prefer isolated changes over restructuring.
4. **Destructive or irreversible scripts are drafts** — mark migration
   scripts, schema changes, and similar artifacts as requiring human
   review before execution.

### Architecture Mismatch

During implementation, if the code does not match architectural assumptions:

- **Minor mismatch** (different method name, slightly different interface) →
  proceed and note the deviation in execution notes.
- **Structural mismatch** (module doesn't exist, interface is fundamentally
  different, assumption about behavior is wrong) → **stop, go blocked**.
  State the original assumption, the actual finding, and the impact. Write
  `.harness/generator-feedback.md` with: original assumption (from
  `architecture.md`), actual finding, impact on implementation, and
  recommended next owner (`architect` | `specifier` | `human`).

### Generator Feedback Escalation

If you discover a design-level gap that cannot be solved inside the approved
write surface, do not patch around it. Stop, write
`.harness/generator-feedback.md`, and mark the task `blocked` with
`[design_blocker]`.

Use the core generator-feedback template and keep the four sections aligned:

- Original Assumption
- Actual Finding
- Impact
- Recommended Next Owner

The feedback file should explain the mismatch, why it matters, and who must
decide next. The Architect must review `generator-feedback.md` before the
task can resume from blocked. Do not invent a new format.

### Execution Notes

Maintain running notes during implementation:
- Deviations from architecture (with reason)
- Unexpected findings
- Files touched outside the approved write surface (with justification)
- Verification results per checkpoint

### Pre-Handoff Self-Review

Before transitioning to Evaluator, complete this checklist. Self-review
failures should be fixed by the Generator — do not consume Evaluator
repair rounds on preventable issues.

```markdown
- [ ] All verification commands from verification-path.md pass
- [ ] No unresolved TODO/FIXME in new code
- [ ] Write surface matches architecture.md (no unauthorized file changes)
- [ ] Every P0 requirement has at least one covering test
- [ ] No secrets or credentials in the diff
- [ ] `git diff --stat` matches expected scope
- [ ] Execution notes document all deviations
```

If any item fails, fix it before transitioning. Do not hand off to
Evaluator with known failures.

## Risk-Adaptive Depth

> Canonical source: orchestrator's Risk-Adaptive Matrix, row "6 Generate".

Read the risk level from `task-status.md` § State Notes and adapt:

| Risk Level | Depth Adjustments |
|------------|-------------------|
| **Low** | Implement in 1-2 batches; checkpoint validate after each; commit at passing checkpoints. Simplified self-review: skip scope and deviation checks, but Quality Standards still fully apply. |
| **Medium** | Standard — logical-unit batches, full self-review checklist |
| **High** | Strict batching following Delivery Order; each batch must include security-relevant tests; full self-review plus: no new dependencies without justification, lint/typecheck pass per batch |

## State Transition

On completion (self-review passes): update `task-status.md` → state
`reviewing`, owner `evaluator`.
