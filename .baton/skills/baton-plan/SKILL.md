---
normative-status: Authoritative specification for the PLAN phase.
name: baton-plan
description: >
  Use when the user needs an implementation plan before coding — designing the
  approach, comparing alternatives, and defining the write set. Trigger on:
  "plan", "design", "propose", "how should we implement", "what's the approach",
  "write a plan", "implementation proposal", "let's plan this out", or when
  research is done and the next step is deciding HOW to change the code.
  Also use when the user asks to evaluate multiple approaches or create a
  structured proposal with tradeoffs. Do NOT use for: pure research (use
  baton-research), implementing approved plans (use baton-implement), or
  reviewing existing code.
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

> Operational failure patterns observed in real usage.

1. **Plans describe behavior but don't show code.** Without a code skeleton,
   the human cannot predict the diff. Baseline outputs included 50-76 line
   code skeletons; with-skill outputs described behavior in prose only.
   *(Observed: eval-0 iteration-1. Fixed by adding code skeleton guidance.)*

2. **Approach comparisons in prose bury the signal.** When comparing 3+
   approaches, a table (mechanism × pros × cons × constraint fit) is far
   more scannable than paragraphs per approach.
   *(Observed: iteration-1 used prose; iteration-2 switched to tables after
   prompt improvement.)*

3. **Small bugfix gets full First Principles Decomposition.** A 2-line code
   change got 4 constraints, 2 solution categories, and a 3-question
   Self-Challenge (136 lines total). Baseline did the same job in 91 lines.
   *(Observed in eval-1 iteration-1. Fixed by adding Sizing Gate + Light Path.)*

4. **Surface Scan tables grow large without proportional value.** 10+ row
   tables where most entries are "skip — no changes needed" add length but
   not coverage insight. Keep tables lean: only include files that ARE
   impacted or have a non-obvious skip reason.

## When to Use

- After research is complete, or whenever a code-changing task reaches the point where a concrete, reviewable implementation contract is needed
- When the user asks to plan, design, or propose an approach

**When NOT to use**: Pure research (use baton-research).

## Sizing Gate

Assess task size **before** choosing the process path. The sizing determines
how much structure is warranted. Use verification complexity as the decisive
factor (see constitution.md §Task Sizing).

| Size | Signal | Process Path |
|------|--------|-------------|
| **Trivial** | Typo, comment, formatting. Visual inspection sufficient. | **Inline contract**: 3-5 lines (What/Why/Impact/Risks/Verify). No Steps 1-6. |
| **Small** | Single file, one test, clear fix. | **Light path**: Problem → Fix → Predicted Diff → Write Set → Verify. Under 80 lines. No First Principles Decomposition, no Self-Challenge, no Surface Scan. Include 2 brief alternatives (1-2 sentences each) only if the choice is non-obvious. |
| **Medium** | 2+ modules, multi-step verification. | **Standard path**: Full Steps 1-6. |
| **Large** | Design verification, multi-env, manual judgment. | **Full path**: Full Steps 1-6 + multi-approach mandatory + Surface Scan L3. |

When in doubt, size up. But **do not size up reflexively** — a task that
touches one file and answers one question is Small regardless of how
interesting the fix is.

Complexity is proposed by AI and may be corrected by the human. If the Sizing
Checkpoint (constitution.md §Sizing Checkpoint) triggered a level change after
research, record that change at the top of the plan and apply the higher
level's process.

## Two-Phase Mode

When analysis has already been done in chat (comparison tables, code examples,
conclusions), the skill's role shifts from **process guide** to **quality
checklist**. Do not rewrite existing analysis into the template — enhance it.

---

## Inline Contract (Trivial)

```
- **What**: <one-line change description>
- **Why**: <reason>
- **Impact**: <file(s) only; no behavior change>
- **Risks**: None
- **Verify**: <how to confirm>
```

No Steps 1-6. No Self-Challenge. No Review Pass. End with `## 批注区`.

---

## Light Path (Small tasks)

For Small tasks, write a direct plan document focused on clarity and
diff-predictability. The value of the plan for Small tasks is **making the
change reviewable** — the human should be able to approve or reject based on
the plan alone.

**Output structure** (aim for under 80 lines):

```
# Plan: <title>

**Sizing**: Small

## Problem
<What's wrong and why it needs fixing — 2-3 sentences>

## Fix
<What to change and how — specific enough to predict the diff>
<Include the predicted diff (before → after) when possible>

## Alternatives (if choice is non-obvious)
<1-2 sentences per alternative with why rejected>

## Write Set
| File | Change |
|------|--------|
| ... | ... |

## Verify
<How to confirm the fix works — test command or expected behavior>

## Risks
<1-2 bullet points, or "None" for trivial-risk changes>

## 批注区
```

No First Principles Decomposition. No Surface Scan. No Self-Challenge.
No Review Pass. Just answer: what changes, why, what could go wrong, how
to verify.

**Include predicted diffs**: For Small tasks, the plan should show the
approximate code change (current → proposed). This is the most valuable
part for reviewability.

---

## Standard + Full Path (Medium/Large tasks)

### Step 1: First Principles Decomposition

Before proposing any approach, decompose at a depth appropriate to complexity:

1. **Problem statement** — state the problem without referencing any solution
2. **Constraints** — architecture, dependencies, backward compatibility, conventions
3. **Solution categories** — enumerate fundamentally different approaches (not variations of one)
4. **Evaluate** — each category against constraints. Pattern-matching is valid when
   chosen deliberately after evaluation, not as unconscious default.

### Step 2: Derive from Validated Inputs

Plans MUST derive approaches from validated inputs — don't jump to "how"
without tracing back to "why". If a `## Final Conclusions` section exists,
derive from there — each conclusion has: Confidence, Evidence, Verification
path, Uncertainty, and Plan implication (actionable/watchlist/judgment-needed/
blocked). Use the plan implication field to determine which conclusions are
actionable inputs vs. watchlist items. If the human stated requirements in
chat, record them under `## Requirements`. If no formal research artifact
exists, derive from validated user requirements and any directly verified
evidence.

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

**Keep the table lean.** The Surface Scan's value is coverage completeness,
not exhaustive detail per row. One line per file with evidence marker is
sufficient. Save detailed analysis for the approach section.

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

**Use a comparison table** when presenting 3+ approaches — prose comparisons
bury the signal. Example:

| | Approach A | Approach B | Approach C |
|---|---|---|---|
| Mechanism | ... | ... | ... |
| Pro | ... | ... | ... |
| Con | ... | ... | ... |
| Constraint fit | ... | ... | ... |

Then state your recommendation with reasoning:
- Which approach and why
- Which research findings support it
- Why the main alternatives were rejected — cite the specific constraint *name* from Step 1, not "it's better/simpler/cleaner." Example: "Approach B rejected because it violates the [shell-only execution] constraint from Step 1." Vague rejection reasoning is a red flag that evaluation was not genuine.

**Show the recommended approach concretely.** After selecting an approach,
include a code skeleton or pseudo-code showing the key mechanism. The human
should be able to predict the approximate diff from reading the plan. A
plan that describes behavior without showing code leaves too much
interpretation to the implementation phase.

Example for a shell hook:
```bash
# Skeleton: prompt-guard.sh (key logic only)
source lib/common.sh
find_plan; parser_has_go && exit 0  # gate open → allow
PROMPT="$(extract_prompt)"
case "$PROMPT_LOWER" in
    *bypass-pattern*) exit 2 ;;  # block
esac
exit 0
```

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

**Predicted diffs**: For any plan, include the approximate code change (current
→ proposed) for the most important modifications. This is the most valuable
element for the human's review decision.

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
