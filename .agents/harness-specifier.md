---
name: harness-specifier
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

- **Inputs**: user request, `scoped-map.md`
- **Outputs**: in-scope and out-of-scope boundaries, functional requirements,
  acceptance criteria
- **Required artifact**: `requirements.md`
- **Key principle**: requirements are independent of technical architecture.
  Describe *what* must be true, not *how* to make it true.

## Required Artifact: `requirements.md`

Sections (all required):

1. **Problem** — what is wrong or missing today
2. **Scope** — what this task includes and excludes
3. **Requirements** — numbered functional requirements
4. **Non-Goals** — explicitly out of scope
5. **Acceptance Criteria** — checkbox list, independently verifiable
6. **Constraints** — technical or process constraints that limit solutions
7. **Validation Intent** — how the criteria will be verified (not commands, just intent)

## Execution Guide

### 1. Read Inputs

- Read `scoped-map.md` fully — entry points, call chain, risks, existing tests.
- Re-read the user request for intent not captured in the scoped map.

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

### 5. Resolve Uncertainties

- When the requirement depends on an unclear user intent, **ask the user**.
- Mark confirmed answers with 【已确认】 in the requirements doc.
- Do not guess. Unresolved questions → mark as open and list them.

### 6. Write Acceptance Criteria

Each criterion must be:

- **Independently verifiable** — can be checked without reading other criteria
- **Observable** — describes a visible outcome, not an internal state
- **Testable** — someone unfamiliar with the source code could verify it

Format: `- [ ] When <condition>, <observable outcome>`

### Quality Check

- Every numbered requirement has at least one acceptance criterion.
- Acceptance criteria are testable without reading source code.
- No criterion depends on a specific implementation approach.
- Non-goals are explicit, not just the absence of requirements.

## State Transition

On completion: update `module-status.md` → state `architecting`, owner `architect`.
