---
normative-status: Authoritative specification for the PLAN phase.
name: baton-plan
description: >
  Use when the user asks to "plan", "design", "propose", "make a plan", "出 plan",
  or after research is complete. The plan is the contract: human approval via
  BATON:GO gates all implementation.
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

## When to Use

- After research is complete and you need to propose concrete changes
- When the user asks to plan, design, or propose an approach
- For tasks of any complexity that involve code changes

**When NOT to use**: Pure research (use baton-research). Trivial changes
may produce only a 3-5 line summary.

### Complexity-Based Scope

- **Trivial**: 3-5 line summary. Skip Surface Scan.
- **Small**: Requirements + recommendation + L1 scan.
- **Medium**: Full process through L2.
- **Large**: Full process including L3 + disposition table.

Complexity proposed by AI, confirmed by human.

## The Process

### Step 1: First Principles Decomposition

Before proposing any approach (complexity graduation: trivial = implicit,
small = 1-2 sentences, medium/large = full decomposition in artifact):

1. **Problem statement** — state the problem without referencing any solution
2. **Constraints** — architecture, dependencies, backward compatibility, conventions
3. **Solution categories** — enumerate fundamentally different approaches (not variations of one)
4. **Evaluate** — each category against constraints. Pattern-matching is valid when
   chosen deliberately after evaluation, not as unconscious default.

### Step 2: Derive from Research

Plans MUST derive approaches from research findings — don't jump to "how"
without tracing back to "why". If a `## Final Conclusions` section exists,
derive from there. If the human stated requirements in chat, record them
under `## Requirements`.

### Step 3: Surface Scan (Medium/Large)

**EVIDENCE-BASED COVERAGE — build the table from codebase evidence, not from
memory. Record how you verified coverage.**

**L1 — Direct references**: Search for terms being changed.
**L2 — Dependency tracing**: Who imports/sources/references each L1 file?
**L3 — Behavioral equivalence** (human-assisted): Flag as ❓.

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| ... | L1/L2/L3 | modify / skip | ... |

Default disposition is "modify" — "skip" requires justification.

### Step 4: Recommend with Reasoning

Recommendation traces back to specific research findings and first-principles evaluation.

### Step 5: Self-Challenge (write into artifact, not just think)

Before presenting, write `## Self-Challenge` into the plan with answers to:
1. Is this the best approach, or the first one I thought of? What alternatives did I not consider?
2. What assumptions did I make without verifying? Which ones could be wrong?
3. What would a skeptic challenge first about this plan?

These answers are VISIBLE OUTPUT — the human judges their depth. Shallow
answers ("no other alternatives" / "all assumptions verified") signal that
self-challenge was not genuine. Fix before presenting.

### Step 6: Dispatch Review

After self-challenge, dispatch review subagent via Agent tool with the plan
artifact. Process findings and fix issues before presenting.

**Re-dispatch after every rewrite** — annotation-driven rewrites invalidate
the prior review. Each version presented to the human must have been reviewed.

## Plan Structure

The plan MUST communicate: **What** (changes), **Why** (rationale),
**Impact** (files, callers), **Risks** (mitigation strategy).
The human should predict the diff from reading the plan.

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

**Schema ownership**: baton-plan owns the `## Todo` item schema (Change, Files,
Verify, Deps, Artifacts) and structural invariants (`- [ ]`/`- [x]` prefix,
`Files:` for write-set extraction). baton-implement owns runtime execution.
Independent items (no deps, non-overlapping write sets) can be parallelized.

Use `- [ ]` unchecked, `- [x] ✅` checked.

## Annotation Protocol

Cross-cutting rules live in workflow.md. For each annotation: read code first
(cite file:line), infer intent, respond with evidence, check for direction
change or contradiction. Update document body — it's the source of truth.

## Output

Create in `baton-tasks/<topic>/plan.md` — always include a topic. End with `## 批注区`.
`mkdir -p baton-tasks/<topic>` before writing.
