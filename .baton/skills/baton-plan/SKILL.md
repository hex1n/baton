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
NO TODO LIST WITHOUT HUMAN SAYING "GENERATE TODO LIST"
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

## Gotchas

> Operational failure patterns. Add entries when observed in real usage.
> Empty until then — do not pre-fill with theory.

## When to Use

- After research is complete, or whenever a code-changing task reaches the point where a concrete, reviewable implementation contract is needed
- When the user asks to plan, design, or propose an approach

**When NOT to use**: Pure research (use baton-research).

For trivial changes, the plan artifact may collapse to a brief 3-5 line
contract rather than a full structured document.

### Complexity-Based Scope

Complexity level is determined by verification complexity (see constitution.md
§Task Sizing). When in doubt: how many independent steps are needed to confirm
correctness? One step = Small. Multiple coordinated steps = Medium. Verification
itself requires design = Large.

- **Trivial**: 3-5 line contract. Surface scan and Steps 5-6 normally skipped.
- **Small**: Requirements + 2 brief alternatives (1–2 sentences each, including trade-offs) + recommendation.
- **Medium/Large**: Full process.

Surface scan depth is determined by impact uncertainty and surface breadth;
see Step 3.

Complexity is proposed by AI and may be corrected by the human if the scope,
risk, or review depth appears misclassified. If the Sizing Checkpoint
(constitution.md §Sizing Checkpoint) triggered a level change after research,
record that change at the top of this plan and apply the higher level's process.

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

**If resuming from a BLOCKED implementation**: before deriving, read `## Implementation Notes` in the plan (if present) and any research supplement added by baton-debug. Record which discovery caused the block and what assumption it invalidated — this determines whether plan revision is localized or requires upstream research revision.

**Research 批注区 check**: before deriving conclusions from a research artifact, scan its `## 批注区` for any annotation whose Impact = "affects conclusions" or "blocks next phase" and Status = ❓. Unresolved annotations at these impact levels may invalidate conclusions used as plan inputs. Surface them to the human before proceeding.

### Step 3: Surface Scan

**Any plan whose correctness depends on multi-surface impact analysis must show
evidence-based coverage. Build the table from codebase evidence, not from
memory. Verify coverage is complete before building the table. Never fabricate
table entries — every row must cite a tool invocation or file read that produced
the evidence.**

**L1 — Direct references**: Search for terms being changed.
**L2 — Dependency tracing**: Who imports/sources/references each L1 file?
**L3 — Behavioral equivalence** (human-assisted): Flag as ❓ for explicit
human confirmation; record why static evidence is insufficient.

L3 triggers (static analysis cannot answer these — must flag):
- Does the change preserve the *semantics* of a contract, not just its signature?
- Does correctness depend on execution order, timing, or runtime state?
- Does a caller rely on a side effect that won't appear in its import graph?
- Does "this looks compatible" depend on an assumption about current behavior that you have not directly observed running?

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| ... | L1/L2/L3 | modify / skip | ... |

Do not default uncovered surfaces to "skip". Any "skip" decision requires
explicit justification.

**Self-audit before finalizing the table**: For each row, identify the exact
tool call or file read from the current session that produced it. Any row you
cannot point to must be removed or replaced with a ❓ entry noting it was
inferred, not verified. A partially-fabricated table is worse than a shorter
honest one — it creates false confidence about coverage.

### Step 4: Present Approaches & Recommend

**Present 2-3 fundamentally different approaches to the human** with trade-offs
before converging on one. Do not internally enumerate and silently reject — the
human must see the alternatives and the reasoning.

> **What makes approaches "fundamentally different"**: they impose different
> control points, abstraction layers, or responsibility allocations. Storage
> format variations (JSON vs YAML vs SQLite for the same state model) are NOT
> fundamentally different. Ask: "Does this approach change *who or what owns the
> logic* or *where control decisions are made*?"

For each approach:
- **What**: one-sentence description
- **How**: key mechanism / architecture change
- **Trade-offs**: pros, cons, risks relative to constraints from Step 1
- **Fit**: how well it serves the stated problem (not a different problem)

Then state your recommendation with reasoning:
- Which approach and why
- Which research findings support it
- Why the main alternatives were rejected — cite the specific constraint *name* from Step 1, not "it's better/simpler/cleaner." Example: "Approach B rejected because it violates the [shell-only execution] constraint from Step 1." Vague rejection reasoning is a red flag that evaluation was not genuine.

### Step 5: Self-Challenge (write into artifact, not just think)

Write `## Self-Challenge` into the plan. Plan-specific questions:
1. Is this the best approach, or the first one I thought of? What alternatives did I not consider?
2. What assumptions did I make without verifying? Which ones could be wrong?
3. What would a skeptic challenge first about this plan?

After the 3 questions, add a required closing block:

> **Weakest assumption**: [name the single most load-bearing unverified assumption]
> **If this assumption is wrong**: [specific impact — what would need to change in the plan]
> **How to verify before executing**: [what evidence or test would confirm or refute it]

If you cannot state a falsification criterion, the assumption is too vague to
trust — re-examine the plan.

These answers are VISIBLE OUTPUT — the human judges their depth. Shallow
answers ("no other alternatives" / "all assumptions verified") signal that
self-challenge was not genuine. Fix before presenting.

### Step 6: Review Pass

For non-trivial plans:

1. **Dispatch** baton-review via Agent tool: read `./review-prompt.md` + plan text (context isolation)
   - Fallback: explicit self-review using `./review-prompt.md` checklist if subagent unavailable
2. **Process findings**: address accepted items, reject with evidence if disagreeing, keep unresolved as ❓
3. **Fix** — revise the plan to address accepted findings
4. **Re-review** — if materially rewritten, dispatch baton-review again
5. **Repeat** until baton-review passes or circuit breaker (3 cycles → escalate to human)

If no review mechanism is available, state that explicitly rather than silently skipping it.

## Plan Structure

The plan MUST communicate: **What** (changes), **Why** (rationale),
**Impact** (files, callers), **Risks** (mitigation strategy).
The human should predict the diff from reading the plan — key files, key
behavior changes, and verification path should be explicit enough for that.

### Todo List Format

After human says "generate Todo list" and BATON:GO is present:

```markdown
## Todo

- [ ] 1. Change: description
  Files: `a.ts`, `b.ts`
  Verify: how to verify
  Deps: none
  Artifacts: none
```

When generating a Todo list, preserve the agreed item schema so implementation
can map each item back to plan scope and verification requirements.
Mark independent items clearly so later execution can parallelize them safely.

Use `- [ ]` unchecked, `- [x] ✅` checked.

## Output

Create the plan artifact at the workflow-defined task location (default:
`baton-tasks/<topic>/plan.md`). Always include a topic in the title or metadata, and end with `## 批注区`.

## Annotation Protocol

Every plan document ends with the content of `.baton/annotation-template.md`.
Follow using-baton Annotation Protocol for processing rules.

## Evidence Standards

Mark material claims: `✅` verified (state how) / `❓` unverified (state why).
"Should be fine" is not evidence.
