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

Read `artifact_language` from `task-status.md` § State Notes (`zh` or `en`).
Write all human-facing artifacts in that language.
Do not localize `task-status.md`.

## Structured Question Tool

When this skill says "use structured question", you MUST use the
platform's structured input mechanism — not free-form text:

- **Claude Code**: Invoke the `AskUserQuestion` tool as a tool call.
- **Codex / Cursor**: Present choices as a numbered list in chat and
  wait for the user to reply with a number (per AGENTS.md contract).
  Do NOT call `request_user_input` — it is only available in Plan mode.
- **Other hosts**: Present choices clearly and wait for the user's response.

**Do NOT present options as unstructured prose.** The user must see
distinct, selectable options.

Right — Claude Code:
> AskUserQuestion({ question: "审批架构？", options: ["通过", "需修改"] })

Right — Codex:
> 审批架构？
> 1. 通过
> 2. 需修改
> (reply with a number)

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
5. **Reversibility Analysis** — for each key decision, can it be undone?
6. **Verification Strategy** — how each requirement will be validated
7. **Delivery Order** — independently mergeable units in dependency order
   (required for High risk; optional for Medium; skip for Low)
8. **Risks** — residual risks with mitigation or acceptance rationale
9. **Self-Challenge** — strongest arguments against the chosen approach

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

Generate multiple approaches that differ in **mechanism**, not just
parameters (at least 2 for non-trivial decisions):

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
- Rough complexity per module: `trivial` / `moderate` / `complex` — this
  helps Generator plan batch sizing and effort allocation

### 5. Module Breakdown (if applicable)

If the change spans multiple modules:
- List each module with its responsibility in the change
- Define interfaces between modules
- Identify the implementation order (what depends on what)

### 6. Surface Scan

Analyze impact at increasing distance from the change:

1. **Direct references** — files that import/call the changed code
2. **Dependency tracing** — transitive consumers of the changed interfaces
3. **Behavioral equivalence** — code that assumes the current behavior without
   direct reference (config files, scripts, documentation)

For Low-risk tasks, direct references may be sufficient. For High-risk
tasks, all levels are expected.

### 7. Reversibility Analysis

For each significant decision in the recommended approach:

```markdown
| Decision | Reversible? | Reversal Cost | Reversal Method |
|----------|-------------|---------------|-----------------|
| Add new internal module | Yes | Low | Delete module + revert |
| Change public interface | No | High | Breaking change for consumers |
| Internal refactor | Yes | Low | Revert commit |
```

This tells the Generator "how far back can I safely go if this assumption
is wrong?" and tells the human reviewer which decisions are irreversible
and need extra scrutiny.

### 8. Delivery Order

For High-risk tasks (required) and Medium-risk tasks (recommended):

List independently mergeable units in dependency order:

```markdown
1. Unit A — [files] — can merge independently, no existing behavior change
2. Unit B — [files] — depends on A
3. Unit C — [files] — depends on A, can parallel with B
```

Each unit should be:
- Independently testable
- Safe to merge without the subsequent units
- Small enough to review in one pass

For Low-risk tasks, skip this section.

### 9. Verification Strategy

Map each requirement to a concrete verification approach:
- What will be tested (unit, integration, manual)
- What existing tests cover the affected code
- What new tests are needed
- Use test type hints from `requirements.md` if available

### 10. Self-Challenge

Write the strongest arguments against your chosen approach:
- What could go wrong that you haven't accounted for?
- What assumption, if wrong, would invalidate the approach?
- Is there a simpler solution you dismissed too quickly?

### 11. Cross-Model Architecture Review (Medium/High risk, default when available)

Before presenting to the human, when Codex is available (check
`codex_available` in `task-status.md` State Notes) and the task is
Medium or High risk, run a cross-model challenge review:

```
Skill("codex:rescue", args: "--wait --fresh Adversarial review of .harness/architecture.md. Challenge: approach choice, assumptions, risk analysis, failure modes. Question whether the current design is the right one. Compare against .harness/requirements.md for coverage. Output: major issues (blockers) vs minor suggestions.")
```

Codex reviews `architecture.md` as an adversarial challenger — questioning
the approach choice, assumptions, and risk analysis.

**Review → Repair Loop:**

```
Write architecture.md
  │
  ▼
Codex adversarial review (via codex:rescue)
  │
  ├─ No major issues → proceed to human gate
  └─ Major issues found:
       │
       ▼
     Revise architecture.md to address findings
       │
       ▼
     Re-run Codex adversarial review
       │
       ├─ Resolved → proceed to human gate
       └─ Still major → present both architecture and
          unresolved findings to human for judgment
```

**Why here and not elsewhere:**
- Architecture errors have the highest downstream cost
- Architecture is a **reasoning quality** problem — a different model
  can spot blind spots that the same model misses
- The human gate comes right after, so the human sees an architecture
  that has already survived cross-model challenge

**What counts as "major issue":**
- Logical contradiction in the approach
- Missing failure mode that could block implementation
- Requirement not addressed by any part of the approach
- Security or data integrity risk not acknowledged

**What does NOT count:**
- Style preferences or alternative phrasings
- Minor suggestions that don't affect correctness
- Disagreements about approach preference (the architect chose, Codex
  can disagree, but that alone is not a blocker)

If Codex is not available, skip this step — the self-challenge
(Step 10) and human gate still provide review coverage.

### 12. Present and Wait

Present the full `architecture.md` to the human, including:
- The architecture itself
- Codex review findings (if ran), noting which were addressed and
  which remain as accepted trade-offs

**Stop and wait for approval.** Use structured question (single-select):
Options: Approved / Partial revision needed / Rejected — wrong direction / Rejected — requirements misunderstood

Do not proceed to verification or implementation.

### 13. Requirements Sync Pass

After human approval, review the confirmed decisions in `architecture.md`.

- If a confirmed decision changes requirements-level truth, update
  `requirements.md` directly or hand it back to Specifier for the update.
- Do not hand off to Verifier until that sync is complete.
- Verification starts only after `requirements.md` and `architecture.md`
  describe the same approved reality.

## Risk-Adaptive Depth

Read the risk level from `task-status.md` § State Notes and adapt:

| Risk Level | Depth Adjustments |
|------------|-------------------|
| **Low** | Single approach is sufficient; skip delivery order; minimal reversibility analysis |
| **Medium** | Multiple approaches compared; delivery order recommended; reversibility for key decisions |
| **High** | Full approach comparison; delivery order required; full reversibility analysis; add security threat modeling for auth/data/API changes; add performance/scalability considerations |

### Security Considerations (High risk only)

For changes involving authentication, authorization, user data, or
external APIs, add a **Security Implications** section:

- Authentication/authorization impact
- Data exposure risks
- Input validation requirements
- Secrets management implications

## Human Feedback Handling

**Approved**
Ensure the requirements sync pass is complete, then update
`task-status.md` → state `verification_check`, owner `verification-explorer`.

**Partial revision requested**
Revise `architecture.md` per feedback. Re-present the changed sections.
Wait for approval again. Do not proceed without explicit approval.

**Rejected — architecture direction wrong**
Return to Step 2 (First-Principles Decomposition). Re-examine approach
categories before proposing a new direction. Re-present and wait.

**Rejected — requirements misunderstood**

1. Write `task-status.md` → state `blocked`, category `design_blocker`.
   Notes: name the specific requirement that is ambiguous or contradictory.

2. Write `.harness/generator-feedback.md` with these fields:
   - **Original assumption**: what `architecture.md` assumed about the requirement
   - **Actual finding**: why that assumption cannot be satisfied as-is
   - **Impact on implementation**: what breaks if proceeding without clarity
   - **Recommended next owner**: `specifier`

3. Stop. Do not re-attempt architecture.

Specifier entry condition: when `generator-feedback.md` exists and
`recommended_next_owner` is `specifier`, resolve the ambiguity in
`requirements.md` before architecture resumes. Architect will then
re-read both files and restart from Step 2 (First-Principles Decomposition).

## Decision Records

For each significant decision:
- **Chosen**: what and why
- **Not chosen**: what and why not
- **When to revisit**: conditions that would change the decision

Record decisions inline in `architecture.md`. If the project uses
a strict overlay that requires a separate `decisions.md`, follow
the overlay convention instead.

## State Transition

On human approval: complete the requirements sync pass, then update
`task-status.md` → state `verification_check`, owner `verification-explorer`.
