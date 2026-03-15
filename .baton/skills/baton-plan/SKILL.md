---
normative-status: Authoritative specification for the PLAN phase.
name: baton-plan
description: >
  Use when the task has moved from investigation into change design: translating
  validated findings and user requirements into an implementation contract
  covering scope, approach, impact, risks, and approval gates. Also use when the
  user explicitly asks for a plan, proposal, design, or implementation approach.
user-invocable: true
---

## Iron Law

```
NO IMPLEMENTATION WITHOUT AN APPROVED PLAN
NO BATON:GO PLACED BY AI — ONLY THE HUMAN PLACES IT
NO TODOLIST WITHOUT HUMAN SAYING "GENERATE TODOLIST"
NO INTERNAL CONTRADICTIONS LEFT UNRESOLVED — FIX BEFORE PRESENTING
VERIFY = VISIBLE OUTPUT. "I checked" is not evidence.
FIRST PRINCIPLES BEFORE FRAMING. State problem → list constraints → enumerate solution categories → then evaluate.
```

## Red Flags

These thoughts mean STOP — you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This approach is obviously the best" | Did you enumerate other solution categories? |
| "Surface Scan not needed, impact is small" | If correctness depends on multi-surface impact, show evidence. Your memory is less reliable than grep |
| "Self-Challenge is done" | Is the depth sufficient? "No other alternatives" is not a genuine answer |
| "I can skip the review pass" | If a review mechanism exists for this workflow, non-trivial plans should be reviewed before presenting |
| "The plan is obvious from the research" | Plans must add: What, Why, Impact, Risks. Research doesn't have all of these |

## When to Use

- After research is complete, or whenever a code-changing task reaches the point where a concrete, reviewable implementation contract is needed
- When the user asks to plan, design, or propose an approach

**When NOT to use**: Pure research (use baton-research).

For trivial changes, the plan artifact may collapse to a brief 3-5 line
contract rather than a full structured document.

### Complexity-Based Scope

- **Trivial**: 3-5 line contract. Surface scan and Steps 5-6 normally skipped.
- **Small**: Requirements + recommendation.
- **Medium/Large**: Full process.

Surface scan depth is determined by impact uncertainty and surface breadth;
see Step 3.

Complexity is proposed by AI and may be corrected by the human if the scope,
risk, or review depth appears misclassified.

## The Process

### Step 1: First Principles Decomposition

Before proposing any approach, decompose at a depth appropriate to complexity:
trivial = implicit, small = 1-2 sentences, medium/large = full decomposition
in artifact.

1. **Problem statement** — state the problem without referencing any solution
2. **Constraints** — architecture, dependencies, backward compatibility, conventions
3. **Solution categories** — enumerate fundamentally different approaches (not variations of one)
4. **Evaluate** — each category against constraints. Pattern-matching is valid when
   chosen deliberately after evaluation, not as unconscious default.

### Step 2: Derive from Validated Inputs

Plans MUST derive approaches from validated inputs — don't jump to "how"
without tracing back to "why". If a `## Final Conclusions` section exists,
derive from there. If the human stated requirements in chat, record them
under `## Requirements`. If no formal research artifact exists, derive from
validated user requirements and any directly verified evidence.

### Step 3: Surface Scan

**Any plan whose correctness depends on multi-surface impact analysis must show
evidence-based coverage. Build the table from codebase evidence, not from
memory. Record how you verified coverage. Never fabricate table entries —
every row must cite a tool invocation or file read that produced the evidence.**

**L1 — Direct references**: Search for terms being changed.
**L2 — Dependency tracing**: Who imports/sources/references each L1 file?
**L3 — Behavioral equivalence** (human-assisted): Flag as ❓ for explicit
human confirmation; record why static evidence is insufficient.

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| ... | L1/L2/L3 | modify / skip | ... |

Do not default uncovered surfaces to "skip". Any "skip" decision requires
explicit justification.

### Step 4: Recommend with Reasoning

Recommendation traces back to specific research findings and first-principles
evaluation. State why the chosen approach wins and why the main alternative
categories were rejected.

### Step 5: Self-Challenge (write into artifact, not just think)

Before presenting, write `## Self-Challenge` into the plan with answers to:
1. Is this the best approach, or the first one I thought of? What alternatives did I not consider?
2. What assumptions did I make without verifying? Which ones could be wrong?
3. What would a skeptic challenge first about this plan?

These answers are VISIBLE OUTPUT — the human judges their depth. Shallow
answers ("no other alternatives" / "all assumptions verified") signal that
self-challenge was not genuine. Fix before presenting.

### Step 6: Review Pass

Before presenting a non-trivial plan, run the designated review pass when that
mechanism exists in the workflow. If the plan is materially rewritten after
review, review it again before presenting the new version. If no review
mechanism is available, state that explicitly rather than silently skipping it.

## Plan Structure

The plan MUST communicate: **What** (changes), **Why** (rationale),
**Impact** (files, callers), **Risks** (mitigation strategy).
The human should predict the diff from reading the plan — key files, key
behavior changes, and verification path should be explicit enough for that.

### Todolist Format

After human says "generate todolist" and BATON:GO is present:

```markdown
## Todo

- [ ] 1. Change: description
  Files: `a.ts`, `b.ts`
  Verify: how to verify
  Deps: none
  Artifacts: none
```

When generating a todo list, preserve the agreed item schema so implementation
can map each item back to plan scope and verification requirements.
Mark independent items clearly so later execution can parallelize them safely.

Use `- [ ]` unchecked, `- [x] ✅` checked.

## Output

Create the plan artifact at the workflow-defined task location (default:
`baton-tasks/<topic>/plan.md`). Always include a topic in the title or metadata, and end with `## 批注区`.
