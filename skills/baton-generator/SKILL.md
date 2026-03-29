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
- **Outputs**: code changes, execution notes, updated `module-status.md`

## Artifact Language Policy

Before writing any human-facing artifact or feedback file:

1. If `.harness/profile.local.yaml` sets `documentation.artifact_language` to
   `zh` or `en`, use that language.
2. If it is `auto`, follow the current user request language.
3. If the setting is missing, default to Chinese.

Do not localize `module-status.md`. Keep the control-plane file, owner tokens,
state tokens, and blocker categories in stable English.

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

### 2. Implementation Phase

**Scope files**: list all files to create or modify, cross-check against the
architecture's write surface.

**Implement in batches** of 3-5 files:
- Complete one logical unit per batch
- After each batch, run the relevant verification commands from
  `verification-path.md`
- Record the checkpoint result (pass/fail/partial)
- Commit at each passing checkpoint

**Batch order**: implement dependencies before dependents. If the architecture
defines a module order, follow it.

### 3. Checkpoint Validation

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
4. **Migration and DDL scripts are drafts** — mark them clearly as requiring
   human review before execution.

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
decide next. Do not invent a new format.

### Execution Notes

Maintain running notes during implementation:
- Deviations from architecture (with reason)
- Unexpected findings
- Files touched outside the approved write surface (with justification)
- Verification results per checkpoint

## State Transition

On completion: update `module-status.md` → state `reviewing`, owner `evaluator`.
