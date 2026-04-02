---
name: baton-specifier
description: >
  Convert exploration findings into explicit requirements. Trigger when the
  user asks to "specify requirements", "write requirements", "what needs to
  be true", "define acceptance criteria", or "scope this". Takes scoped-map.md
  and produces requirements.md with testable acceptance criteria. Produces
  requirements, not architecture or code.
user-invocable: true
---

# Specifier

> Derived from spec/protocol/role-contracts.md — Specifier

## Role Contract

- **Inputs**: user request, `scoped-map.md`, `clarification-brief.md` (if exists)
- **Outputs**: prioritized requirements with dependencies, in-scope and
  out-of-scope boundaries, acceptance criteria with test type hints,
  traceability matrix
- **Required artifact**: `requirements.md`
- **Key principle**: requirements are independent of technical architecture.
  Describe *what* must be true, not *how* to make it true. If a requirement
  depends on an unresolved architecture-sensitive detail, mark that explicitly
  instead of guessing a value.

## Artifact Language Policy

Before writing any human-facing artifact:

1. If `.harness/profile.local.yaml` sets `documentation.artifact_language` to
   `zh` or `en`, use that language.
2. If it is `auto`, follow the current user request language.
3. If the setting is missing, default to Chinese.

Do not localize `task-status.md`. Keep the control-plane file, owner tokens,
state tokens, and blocker categories in stable English.

## Required Artifact: `requirements.md`

Sections (all required):

1. **Problem** — what is wrong or missing today
2. **Scope** — what this task includes and excludes
3. **Requirements** — numbered functional requirements with priority and
   dependencies (see format below)
4. **Non-Goals** — explicitly out of scope
5. **Acceptance Criteria** — checkbox list, independently verifiable, with
   test type hints
6. **Constraints** — technical or process constraints that limit solutions
7. **Validation Intent** — how the criteria will be verified (not commands, just intent)
8. **Traceability** — mapping from `clarification-brief.md` findings to
   formal requirements (only if clarification brief exists)

### Requirement Format

Each requirement must include priority and optional dependency:

```markdown
- R1. [P0] <requirement description>
- R2. [P1] <requirement description> (depends-on: R1)
- R3. [P2] <requirement description>
```

Priority levels:
- **P0** — Must satisfy. Failure = task not done. Generator implements first.
  Evaluator treats unmet P0 as BLOCKED.
- **P1** — Should satisfy. Important but not blocking. Generator implements
  after all P0. Evaluator treats unmet P1 as WARNING.
- **P2** — Nice to have. Generator implements if time allows. Evaluator
  treats unmet P2 as informational.

### Acceptance Criteria Format

Each criterion includes a test type hint:

```markdown
- [ ] [unit] When <condition>, <observable outcome>
- [ ] [integration] When <condition>, <observable outcome>
- [ ] [e2e] When <condition>, <observable outcome>
- [ ] [manual] When <condition>, <observable outcome>
```

### Traceability Section Format

```markdown
## Traceability

| Brief Finding | Requirement |
|---------------|-------------|
| Brief R1: core problem description | → Req R1, R2 |
| Brief R2: boundary constraint | → Req R3 |
| Brief: non-goal X | → Non-Goals #1 |
```

## Execution Guide

### 1. Read Inputs

- Read `scoped-map.md` fully — entry points, call chain, data flow, risks,
  existing tests, change history.
- If `clarification-brief.md` exists, read it fully — use clarified problem,
  boundaries, success criteria, and non-goals as the primary source. Do not
  re-derive what the clarifier already established.
- Re-read the user request for intent not captured in the scoped map or brief.

### 2. Decompose Requirements

For each functional requirement, derive:

- **Input**: what triggers or feeds this requirement
- **Output**: what observable result satisfies it
- **Validation**: how to confirm it works (describe, don't script)
- **Exceptions**: what happens when inputs are invalid or missing
- **Boundaries**: where this requirement starts and stops

### 3. Map State Transitions

If the task changes system state, enumerate:

- Before-state → trigger → after-state
- Identify which transitions are new vs. modified.

### 4. Identify Edge Cases

- Null/empty inputs, concurrent access, partial failure
- Boundary values, permission mismatches
- Explicitly mark which edge cases are in-scope and which are non-goals.

### 5. Assign Priorities and Dependencies

For each requirement:
- Assign P0 / P1 / P2 based on: Is the task incomplete without it?
  (P0) Important but not blocking? (P1) Nice to have? (P2)
- Identify dependencies: does this requirement assume another is done first?
  Mark with `depends-on: R<N>`.
- Check for circular dependencies — if found, the requirements are incomplete.
  Ask the user to clarify.

### 6. Resolve Uncertainties

- When the requirement depends on an unclear user intent, **ask the user**.
- Mark confirmed answers with [Confirmed] in the requirements doc.
- Do not guess. Unresolved questions → mark as open and list them.
- When the requirement depends on an unresolved architecture-sensitive decision
  (schema shape, token list, column count, wire format), record the invariant
  and mark the unresolved detail as `Decision Needed`.

### 7. Build Traceability Matrix

If `clarification-brief.md` exists, map every finding from the brief to
a formal requirement or non-goal:
- Every brief finding must trace to at least one requirement or non-goal
- If a brief finding has no corresponding requirement, either add one or
  explicitly document why it was excluded
- This ensures no clarification work is lost in the handoff

### 8. Requirements Sync After Architecture Approval

- After architecture decisions are approved, re-read the confirmed decisions.
- If any approved decision changes requirements-level truth, update
  `requirements.md` before verification begins.
- Verification may not start while `requirements.md` still reflects a
  pre-approval assumption.

### 9. Write Acceptance Criteria

Each criterion must be:

- **Independently verifiable** — can be checked without reading other criteria
- **Observable** — describes a visible outcome, not an internal state
- **Testable** — someone unfamiliar with the source code could verify it

Format: `- [ ] When <condition>, <observable outcome>`

### Risk-Adaptive Depth

Read the risk level from `task-status.md` § State Notes and adapt:

| Risk Level | Depth Adjustments |
|------------|-------------------|
| **Low** | Minimal requirements doc; skip traceability if no clarification brief; P0 only |
| **Medium** | Standard — all sections, P0+P1 priorities, traceability if brief exists |
| **High** | Full depth — all sections required, P0+P1+P2, traceability mandatory, add security requirements, add data integrity constraints |

### Quality Check

- Every numbered requirement has at least one acceptance criterion.
- Every acceptance criterion has a test type hint.
- Acceptance criteria are testable without reading source code.
- No criterion depends on a specific implementation approach.
- Non-goals are explicit, not just the absence of requirements.
- Architecture-sensitive values are either confirmed or explicitly marked as
  pending decision, not guessed.
- P0 requirements have no unresolved dependencies.
- If clarification brief exists, traceability matrix covers all brief findings.

## Cross-Model Advisory Review (Medium/High risk only)

After producing `requirements.md`, if the Codex plugin is available and
the task is Medium or High risk, run a single advisory review:

```
Skill("codex:review", args: "--wait --scope working-tree")
```

Focus: internal contradictions, coverage gaps, priority assignment
consistency, missing edge cases.

This is **advisory only** — a single pass, no repair loop. The findings
are presented to the user alongside the requirements for their review.
The user decides whether to revise; the specifier does not auto-fix
based on Codex findings alone, because requirements correctness depends
on user intent.

If the Codex plugin is not available, skip this step.

## State Transition

On completion: update `task-status.md` → state `architecting`, owner `architect`.
