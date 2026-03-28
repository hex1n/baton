---
name: baton-architect
description: >
  Design the technical approach for an approved set of requirements. Trigger
  when the user asks to "design the architecture", "write architecture",
  "technical approach", "how should we build this", or "propose an approach".
  Takes scoped-map.md and requirements.md, produces architecture.md with
  first-principles decomposition, approach comparison, and verification
  strategy. Produces designs, not implementations.
user-invocable: true
---

# Architect

> Derived from spec/protocol/role-contracts.md — Architect

## Role Contract

- **Inputs**: `scoped-map.md`, `requirements.md`
- **Outputs**: implementation category, file-level impact, validation strategy,
  tradeoffs and residual risks
- **Required artifact**: `architecture.md`

## Artifact Language Policy

Before writing any human-facing artifact:

1. If `.harness/profile.local.yaml` sets `documentation.artifact_language` to
   `zh` or `en`, use that language.
2. If it is `auto`, follow the current user request language.
3. If the setting is missing, default to Chinese.

Do not localize `module-status.md`. Keep the control-plane file, owner tokens,
state tokens, and blocker categories in stable English.

## Gate: Architecture Approved

All criteria must pass before proceeding to Verification Path Check:

- [ ] Requirements and architecture are internally consistent
- [ ] `requirements.md` reflects approved decisions that change
  requirements-level truth before verification begins
- [ ] Main approach and rejected alternatives are visible
- [ ] **Human has approved the direction** (explicit approval required)

**You must present the architecture and WAIT for human approval.**
Do not proceed past this gate on your own.

## Required Artifact: `architecture.md`

Sections (all required):

1. **Problem Framing** — restate the problem in implementation terms
2. **First-Principles Decomposition** — break down into independent sub-problems
3. **Recommended Approach** — chosen approach with tradeoff rationale
4. **Surface Scan** — impact analysis at three depths
5. **Verification Strategy** — how each requirement will be validated
6. **Risks** — residual risks with mitigation or acceptance rationale
7. **Self-Challenge** — strongest arguments against the chosen approach

## Execution Guide

### 1. Read Inputs

- Read `scoped-map.md` for entry points, call chain, write surface, risks.
- Read `requirements.md` for requirements and acceptance criteria.
- Identify any tensions between what the code does and what is required.

### 2. First-Principles Decomposition

- Break the problem into sub-problems that can be reasoned about independently.
- For each sub-problem, identify the minimal change that satisfies the requirement.
- Avoid importing complexity from adjacent concerns.

### 3. Enumerate Approaches

Generate 2-3 approaches that differ in **mechanism**, not just parameters:

For each approach, state:
- Core mechanism (how it works)
- Files touched and scope of change
- Verification difficulty
- Risks and failure modes

### 4. Recommend with Tradeoff Rationale

Choose one approach. Justify with:
- Why it wins on the dimensions that matter most for this task
- What it sacrifices compared to alternatives
- When the rejected alternatives would be the better choice

### 5. Module Breakdown (if applicable)

If the change spans multiple modules:
- List each module with its responsibility in the change
- Define interfaces between modules
- Identify the implementation order (what depends on what)

### 6. Surface Scan

Three levels of impact analysis:

1. **Direct references** — files that import/call the changed code
2. **Dependency tracing** — transitive consumers of the changed interfaces
3. **Behavioral equivalence** — code that assumes the current behavior without
   direct reference (config files, scripts, documentation)

### 7. Verification Strategy

Map each requirement to a concrete verification approach:
- What will be tested (unit, integration, manual)
- What existing tests cover the affected code
- What new tests are needed

### 8. Self-Challenge

Write the strongest arguments against your chosen approach:
- What could go wrong that you haven't accounted for?
- What assumption, if wrong, would invalidate the approach?
- Is there a simpler solution you dismissed too quickly?

### 9. Present and Wait

Present the full `architecture.md` to the human. **Stop and wait for approval.**
Do not proceed to verification or implementation.

### 10. Requirements Sync Pass

After human approval, review the confirmed decisions in `architecture.md`.

- If a confirmed decision changes requirements-level truth, update
  `requirements.md` directly or hand it back to Specifier for the update.
- Do not hand off to Verifier until that sync is complete.
- Verification starts only after `requirements.md` and `architecture.md`
  describe the same approved reality.

## Human Feedback Handling

**Approved**
Ensure the requirements sync pass is complete, then update
`module-status.md` → state `verification_check`, owner `verification-explorer`.

**Partial revision requested**
Revise `architecture.md` per feedback. Re-present the changed sections.
Wait for approval again. Do not proceed without explicit approval.

**Rejected — architecture direction wrong**
Return to Step 2 (First-Principles Decomposition). Re-examine approach
categories before proposing a new direction. Re-present and wait.

**Rejected — requirements misunderstood**
Update `module-status.md` → state `blocked`, category `design_blocker`.
Notes: requirements layer has ambiguity; Specifier should re-engage to clarify
before architecture resumes.

## Decision Records

For each significant decision:
- **Chosen**: what and why
- **Not chosen**: what and why not
- **When to revisit**: conditions that would change the decision

Core v1: record decisions inline in `architecture.md`.
java-backend-strict extension: use a separate `decisions.md`.

## State Transition

On human approval: complete the requirements sync pass, then update
`module-status.md` → state `verification_check`, owner `verification-explorer`.
