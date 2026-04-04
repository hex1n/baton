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

Write all human-facing artifacts in the language of the user's request.
Do not localize `task-status.md`.

## Required Artifact: `requirements.md`

Sections (all required):

1. **Problem** — root problem statement (outcome of Problem Archaeology);
   if the user's original request was reframed, include the original and
   the reframed version so the user can verify
2. **Assumptions** — load-bearing assumptions with type and consequence if
   wrong (from Step 2c; table for Medium/High risk, inline list for Low)
3. **Scope** — what this task includes and excludes
4. **Requirements** — numbered functional requirements with priority and
   dependencies (see format below)
5. **Non-Goals** — explicitly out of scope
6. **Acceptance Criteria** — checkbox list, independently verifiable, with
   test type hints
7. **Constraints** — true constraints only (conventions stripped in Step 2d)
8. **Validation Intent** — how the criteria will be verified (not commands, just intent)
9. **Traceability** — mapping from `clarification-brief.md` findings to
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

### 2. Problem Archaeology

Before writing any requirements, challenge the problem itself. The most
common failure mode is specifying the wrong problem precisely.

**When to run**: Always. Depth scales with risk (see Risk-Adaptive Depth).
If `clarification-brief.md` exists and already established the root problem
with high confidence, verify rather than re-derive — but still run the
assumption audit.

#### 2a. Root Cause (Five Whys)

Start with the stated problem from Step 1. Ask "why" iteratively until
you reach a circumstance or past decision — not another actionable problem.

```
Stated: "We need to add caching to the API"
Why?   → "API response times exceed 2s at P95"
Why?   → "Each request recalculates aggregations from raw data"
Why?   → "No materialized views or pre-computation exist"
Root:    The problem is redundant computation per request,
         not "missing cache". Caching is one solution category.
```

If the stated problem IS the root problem, say so explicitly and move on.
Do not force depth where none exists.

#### 2b. Solution-as-Problem Detection

Check: is the user's request a **solution** masquerading as a problem?

- **Solution**: "Add a Redis cache" — describes a mechanism
- **Problem**: "Dashboard loads too slowly" — describes an undesirable state

If the request is a solution, reframe it as a problem before proceeding.
Record both the original request and the reframed problem in `requirements.md`
§ Problem so the user can verify the reframing.

#### 2c. Assumption Audit

List the load-bearing assumptions embedded in the problem statement,
scoped-map findings, and user constraints. Focus on assumptions where
"if wrong, the requirements collapse."

| # | Assumption | Type | If wrong... |
|---|-----------|------|-------------|
| A1 | e.g. "The bottleneck is in the API layer" | Testable | Requirements target wrong layer |
| A2 | e.g. "Users need sub-500ms response" | User intent | Over/under-engineering |

For High risk: verify load-bearing assumptions before proceeding (read
code, check metrics, ask the user). For Medium: flag unverified
assumptions and proceed. For Low: list 2-3 key assumptions inline
(no table needed).

#### 2d. Constraints vs. Conventions

For each constraint from the scoped-map or user request, ask:
**"Can this be changed within scope, and what would happen if it were?"**

- **True constraint** (external contract, physical limit, legal, API
  contract): design around it. Record in § Constraints.
- **Convention** (changeable but unquestioned habit): candidate for
  removal if it produces a better solution. Do not include in § Constraints
  unless deliberately preserved.

Litmus test: "Who decided this, when, and does the reason still hold?"

#### 2e. Problem Statement

Write a problem statement that:
- Describes the undesirable state without referencing any solution
- Identifies who is affected and how
- States what "solved" looks like in terms of outcomes, not mechanisms

This becomes § Problem in `requirements.md`. If it differs materially
from the user's original request, present the reframing to the user
before proceeding.

### 3. Decompose Requirements

For each functional requirement, derive:

- **Input**: what triggers or feeds this requirement
- **Output**: what observable result satisfies it
- **Validation**: how to confirm it works (describe, don't script)
- **Exceptions**: what happens when inputs are invalid or missing
- **Boundaries**: where this requirement starts and stops

### 4. Map State Transitions

If the task changes system state, enumerate:

- Before-state → trigger → after-state
- Identify which transitions are new vs. modified.

### 5. Identify Edge Cases

- Null/empty inputs, concurrent access, partial failure
- Boundary values, permission mismatches
- Explicitly mark which edge cases are in-scope and which are non-goals.

### 6. Assign Priorities and Dependencies

For each requirement:
- Assign P0 / P1 / P2 based on: Is the task incomplete without it?
  (P0) Important but not blocking? (P1) Nice to have? (P2)
- Identify dependencies: does this requirement assume another is done first?
  Mark with `depends-on: R<N>`.
- Check for circular dependencies — if found, the requirements are incomplete.
  Ask the user to clarify.

### 7. Resolve Uncertainties

- When the requirement depends on an unclear user intent, **ask the user**.
- Mark confirmed answers with [Confirmed] in the requirements doc.
- Do not guess. Unresolved questions → mark as open and list them.
- When the requirement depends on an unresolved architecture-sensitive decision
  (schema shape, token list, column count, wire format), record the invariant
  and mark the unresolved detail as `Decision Needed`.

### 8. Build Traceability Matrix

If `clarification-brief.md` exists, map every finding from the brief to
a formal requirement or non-goal:
- Every brief finding must trace to at least one requirement or non-goal
- If a brief finding has no corresponding requirement, either add one or
  explicitly document why it was excluded
- This ensures no clarification work is lost in the handoff

### 9. Requirements Sync After Architecture Approval

- After architecture decisions are approved, re-read the confirmed decisions.
- If any approved decision changes requirements-level truth, update
  `requirements.md` before verification begins.
- Verification may not start while `requirements.md` still reflects a
  pre-approval assumption.

### 10. Write Acceptance Criteria

Each criterion must be:

- **Independently verifiable** — can be checked without reading other criteria
- **Observable** — describes a visible outcome, not an internal state
- **Testable** — someone unfamiliar with the source code could verify it

Format: `- [ ] When <condition>, <observable outcome>`

### Risk-Adaptive Depth

> Canonical source: orchestrator's Risk-Adaptive Matrix, row "3 Specify".

Read the risk level from `task-status.md` § State Notes and adapt:

| Risk Level | Problem Archaeology | Requirements Depth |
|------------|--------------------|--------------------|
| **Low** | Inline: 1-line root cause check, 2-3 key assumptions as bullets, skip table | Minimal doc; skip traceability if no brief; P0 only |
| **Medium** | Standard: Five Whys, assumption audit table, constraint/convention check | All sections, P0+P1, traceability if brief exists |
| **High** | Full: Five Whys with verification, full assumption table with load-bearing items verified, constraint audit, present reframing to user before proceeding | All sections, P0+P1+P2, traceability mandatory, add security requirements, add data integrity constraints |

### Quality Check

- § Problem describes an undesirable state, not a solution mechanism.
- § Assumptions lists load-bearing assumptions; none are silently treated as facts.
- § Constraints contains only true constraints; conventions are stripped or
  explicitly preserved with rationale.
- Every numbered requirement has at least one acceptance criterion.
- Every acceptance criterion has a test type hint.
- Acceptance criteria are testable without reading source code.
- No criterion depends on a specific implementation approach.
- Non-goals are explicit, not just the absence of requirements.
- Architecture-sensitive values are either confirmed or explicitly marked as
  pending decision, not guessed.
- P0 requirements have no unresolved dependencies.
- If clarification brief exists, traceability matrix covers all brief findings.

## Cross-Model Advisory Review (Medium/High risk, default when available)

After producing `requirements.md`, when Codex is available (check
`codex_available` in `task-status.md` State Notes) and the task is
Medium or High risk, run a single advisory review:

```
Skill("codex:rescue", args: "--wait --fresh Review .harness/requirements.md against .harness/scoped-map.md. Focus: internal contradictions, coverage gaps, priority assignment consistency, missing edge cases. Output a structured findings list.")
```

Focus: internal contradictions, coverage gaps, priority assignment
consistency, missing edge cases.

This is **advisory only** — a single pass, no repair loop. The findings
are presented to the user alongside the requirements for their review.
The user decides whether to revise; the specifier does not auto-fix
based on Codex findings alone, because requirements correctness depends
on user intent.

If Codex is not available, skip this step.

## State Transition

On completion: update `task-status.md` → state `architecting`, owner `architect`.
