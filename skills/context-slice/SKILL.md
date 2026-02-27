---
name: context-slice
description: >
  Use after plan is APPROVED to generate per-item context slices for
  the todo checklist. Each slice is a self-contained context package
  that gives a subagent exactly the information needed to implement
  one todo item — no more, no less. Solves long-context AI drift by
  replacing full plan injection with focused slices.
  Can run standalone (Layer 0) on any plan.md with a ## Todo section.
---
# Context Slice

Context slices solve the most critical quality problem in AI-assisted
implementation: **long-context drift.** After multiple annotation rounds,
plan.md can grow to thousands of lines. Injecting the full plan into a
subagent's context dilutes attention — later todo items get progressively
worse implementation quality.

## Quick Reference

| Attribute        | Value                                                              |
|------------------|--------------------------------------------------------------------|
| Trigger          | After plan is APPROVED and `## Todo` is generated                  |
| Input            | plan.md with `## Todo` section                                    |
| Output           | `## Context Slices` section appended to plan.md                   |
| Side effects     | None (appends to plan.md only)                                    |
| Sole responsibility | Generating per-item self-contained context packages            |
| Exit condition   | Every todo item has a corresponding context slice                  |

## Mode Behavior

| Mode               | Cross-skill deps | Output path                             | Gate check |
|--------------------|-------------------|-----------------------------------------|------------|
| PURE STANDALONE    | Skip              | Appended to input plan.md               | Skip       |
| PROJECT STANDALONE | Skip              | Appended to input plan.md               | Skip       |
| WORKFLOW MODE      | Enforced          | Appended to `.baton/tasks/<id>/plan.md` | Enforced   |

---

## Standalone mode (Layer 0)

This skill can run on any plan.md that contains a `## Todo` section.
Use `baton slice <plan.md>` to invoke it directly.

When running standalone:
- Reads the specified plan.md file.
- Appends `## Context Slices` to the same file, or writes a separate
  `slices.md` in the same directory if plan.md would become too large.
- No dependency on `.baton/` directory or active task.

## Process

Announce: "I'm generating context slices for the todo items."

### Step 1: Read the full plan.md
Understand all design decisions, file changes, constraints, and the
complete todo list.

### Step 2: Generate a context slice for each todo item
Each slice contains only the information relevant to that specific item,
with explicit boundaries.
⚠️ Checkpoint: Are you copying the entire design decisions section? → Extract only what each item needs.

### Step 3: Check slice quality
Each slice must pass the self-containment test (see below).
⚠️ Checkpoint: Does removing any piece of information prevent correct implementation? If no, remove it.

### Step 4: Check for parallelism
Identify items with no dependencies and no overlapping files.

### Step 5: Append slices to plan.md

## Context slice format

```markdown
## Context Slices

### #slice-1 (for Todo Item #1)

**Goal:** One sentence — what this item accomplishes.

**Relevant design decisions:**
- Decision #N: [extract only the parts relevant to this item]

**Hard constraints:**
- [Filtered from hard-constraints.md — see Rule 6 below]
- [From plan's risk assessment if relevant]

**Files to modify:**
- path/to/file.ts — what to change

**Files NOT to modify:**
- [Explicit list of files OUT OF SCOPE for this item]

**Depends on:**
- (none) | #item-N: [brief description of what it produces]

**Verify:**
- [Exact verification steps from the todo item]

**Estimated complexity:** low | medium | high
**Estimated time:** 5-15 min
```

## Slice generation rules

### Rule 1: Self-containment
Each slice must be fully self-contained. A subagent reading only the
slice must be able to implement the item without reading plan.md.

### Rule 2: Minimal information
Include ONLY what the item needs. Extract relevant parts, don't copy
entire sections.

### Rule 3: Explicit boundaries
`Files NOT to modify` is as important as `Files to modify`. List at
minimum the files modified by adjacent todo items.

### Rule 4: Granularity check
If a slice hits ANY of these thresholds, consider splitting the todo item:
- Relevant design decisions references more than 3 decisions
- Files to modify lists more than 3 files
- Goal requires more than one sentence
- Estimated time exceeds 15 minutes

### Rule 5: Dependency chains
If item B depends on item A, slice B must describe what A produces
(not how A was implemented).

### Rule 6: Hard constraints propagation
If hard-constraints.md exists, each slice's "Hard constraints" field
must include constraints relevant to that item's file scope:
- Read each constraint's Scope field
- If scope intersects with current item's "Files to modify" → include
- If scope is "all source files" → always include
- This ensures the implementing subagent knows non-negotiable rules
  before writing a single line of code.

## When to regenerate slices

Regeneration happens when:
- Plan amendment during implement (post-review fix workflow)
- Todo item split or merge
- Human re-annotation after approval

There is no separate "stale" state. If the plan changes, slices are
regenerated immediately.

## Integration with implement skill

When the implement skill detects context slices exist, it should:
1. Use the corresponding slice as the primary context for each item
2. NOT inject the full plan.md into the subagent
3. Include hard-constraints.md alongside the slice
4. For items with dependencies, include dependency completion status

## Rationalizations to watch for

| You think | Why it's wrong | Do this instead |
| :--- | :--- | :--- |
| "The plan is short enough, slices aren't needed" | Even short plans benefit from explicit scope boundaries | Generate slices. They're cheap. |
| "I'll just copy the whole design decisions section" | Full context = full drift | Extract only what each item needs |
| "Files NOT to modify is obvious" | Not obvious to a context-free subagent | List them explicitly |
| "This item is simple, a minimal slice is fine" | Simple items with minimal slices get minimal attention | Include enough context for correct implementation |
| "Dependencies are clear from the order" | Order ≠ dependency | State dependencies explicitly |
| "The granularity thresholds are too strict" | Long slices = coarse items = drift | Split the todo item |
| "Parallelism analysis is overkill" | Knowing what can run in parallel saves time | Spend 2 minutes on it |
| "Hard constraints don't apply to this item" | Check the Scope field against Files to modify | Filter and include relevant constraints |
