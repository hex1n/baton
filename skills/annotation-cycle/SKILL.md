---
name: annotation-cycle
description: >
  Use when the human has added annotations (notes, comments, corrections)
  to plan.md. Process every annotation, update the design, record changes
  in the annotation log. Supports [RESEARCH-GAP] for targeted supplemental
  research. Repeat until human sets STATUS: APPROVED.
  Can run standalone (Layer 0) on any plan.md file.
---
# Annotation Cycle

The annotation cycle is the most important phase of the workflow.
The human reviews plan.md, adds inline notes, and the AI processes
them. This repeats until the design is approved.

## Quick Reference

| Attribute        | Value                                                              |
|------------------|--------------------------------------------------------------------|
| Trigger          | Human has added annotations to plan.md                             |
| Input            | plan.md (with annotations)                                        |
| Output           | Updated plan.md + updated `## Annotation log`                     |
| Side effects     | May append supplement to research.md (via [RESEARCH-GAP])         |
| Sole responsibility | Processing human annotations on the design                     |
| Exit condition   | plan.md is APPROVED (Todo generation is plan-first-plan's job)    |

## Mode Behavior

| Mode               | Cross-skill deps | Output path            | Gate check |
|--------------------|-------------------|------------------------|------------|
| PURE STANDALONE    | Skip              | Same as input plan.md  | Skip       |
| PROJECT STANDALONE | Skip              | Same as input plan.md  | Skip       |
| WORKFLOW MODE      | Enforced          | Same as input plan.md  | Enforced   |

---

## TL;DR

- **When:** The human has added `[NOTE]` / `[Q]` / `[CHANGE]` /
  `[RESEARCH-GAP]` to plan.md.
- **Inputs:** plan.md (with annotations).
- **Outputs:** Updated plan.md + updated `## Annotation log`.
- **Output location:** Same as input plan.md (in-place update).
- **Exit:** plan.md is **APPROVED**. Then hand off to plan-first-plan
  for Todo checklist generation.

## Standalone mode (Layer 0)

This skill can run on any plan.md file, regardless of whether `.baton/`
exists. Use `baton annotate <plan.md>` to invoke it directly.

When running standalone:
- Operates on the specified plan.md file in place.
- If `[RESEARCH-GAP]` is encountered:
  - Look for research.md in the same directory as plan.md.
  - If found, supplements are appended to it.
  - If not found, write the supplement inline in the annotation log
    with a note: "[Inline supplement — no research.md found]"
  - **Do not report an error or STOP.** (Layer 0 zero-dependency guarantee)

## Process

Announce: "I'm processing annotations on the plan."

### Step 1: Read the entire plan.md
Do not rely on memory. Re-read it now.
⚠️ Checkpoint: Are you relying on what you remember from earlier? → Re-read the file from disk.

### Step 2: Find all annotations
Human notes marked with `[NOTE]`, `[Q]`, `[CHANGE]`, `[RESEARCH-GAP]`,
or any free-form text inserted between existing content.

### Step 3: Process EVERY annotation
Update the plan to address each one. Never skip an annotation, even
if you disagree with it.
⚠️ Checkpoint: Are you thinking "this annotation doesn't change anything"? → If the human wrote it, it matters. Process it and record what you did.

### Step 4: Record in annotation log
For each annotation processed, add an entry to the `## Annotation log`
section (see format below).
⚠️ Checkpoint: Are you thinking "I'll address this during implementation"? → Annotations must be resolved in the plan, not deferred.

### Step 5: Check for conflicts
After processing all annotations in this round, check for contradictions
with existing (unmodified) design decisions:

a. **Shared resource conflict:** Do modified and unmodified Decisions
   reference the same data structure, table, API, or shared state?
b. **File scope conflict:** Does the updated File change manifest list
   the same file under multiple Decisions with different intents?
c. **Constraint conflict:** Do new or modified Decisions violate
   hard-constraints.md (if available)?

⚠️ Checkpoint: Are you skipping the conflict check because "changes are small"? → Small changes create the subtlest conflicts. Always check.

Conflict resolution:
- **Resolvable:** Record in log with evidence.
- **Unresolvable:** STOP. Record the conflict, present both sides,
  ask the human for a decision before continuing.

### Step 6: Ask for next round
Tell the human you've processed all annotations and ask if they want
to add more or approve.

**During annotation, you may ONLY modify plan.md** (and research.md
if handling a RESEARCH-GAP). Do not write or modify source code, tests,
configuration, or any file outside the `.baton/` directory.

## Annotation types

| Annotation | Meaning | AI processing |
| :--- | :--- | :--- |
| `[NOTE]` | Supplemental information or constraint | Integrate into design, record impact |
| `[Q]` | Question requiring AI answer | Answer in log, update design if needed |
| `[CHANGE]` | Request to modify design | Execute change, record before/after |
| `[RESEARCH-GAP]` | Knowledge gap discovered during review | Pause, research, append supplement, resume |

## Annotation log format

```markdown
## Annotation log

### Round 1 (YYYY-MM-DD)
- [NOTE] "Database connection pool max 50" → Updated Decision #2
- [CHANGE] "Add error retry mechanism" → New Decision #4
- [Q] "Can the existing logger handle audit logs?" → Yes, ...

⚠️ Conflict check: [results]
```

## [RESEARCH-GAP] protocol

When the human adds a `[RESEARCH-GAP]` annotation:

1. Pause current annotation round
2. Invoke plan-first-research skill in supplement mode
   - Scope: limited to the gap description only
   - Output: appended to research.md as a Supplement section
   - If no research.md exists: write supplement inline in annotation log
     marked as "[Inline supplement — no research.md found]"
3. Record in annotation log with key finding and resulting decision
4. Resume processing remaining annotations

### RESEARCH-GAP constraints

- **Maximum 2 per annotation round.** More than 2 indicates
  insufficient initial research. Process first 2, defer the rest,
  recommend re-running full research.
- **Scope must be precise.** Only research what the annotation describes.
- **Results must be written to research.md** (or inline if unavailable).

## When the human approves

When the human sets `<!-- STATUS: APPROVED -->` (or says "approved",
"looks good", "go ahead"):

1. Change `<!-- STATUS: DRAFT -->` to `<!-- STATUS: APPROVED -->` in
   plan.md if the human hasn't done so already.
2. Record in annotation log: "Design approved. Handing off to
   plan-first-plan for todo checklist generation."
3. **Do NOT generate the Todo checklist.** Todo generation is
   plan-first-plan's Phase 2 responsibility. This skill only processes
   annotations.
4. Tell the human: "Design is approved. Next step: load the
   plan-first-plan skill to generate the implementation checklist."

## Annotation priority

Human annotations have the **highest priority** on design and
preference decisions. They override your technical preferences,
design opinions, and assessment of difficulty.

**Exception: safety and correctness.** If an annotation would
introduce a security vulnerability, data loss risk, or violate a
hard constraint, you must:
1. Explain the specific risk clearly in the annotation log
2. Propose a safe alternative that preserves the human's intent
3. Ask the human to confirm or revise

This is NOT a license to second-guess every annotation. "I think
there's a better way" is not a safety concern.

## Rationalizations to watch for

| You think | Why it's wrong | Do this instead |
| :--- | :--- | :--- |
| "This annotation doesn't change anything" | If the human wrote it, it matters | Process it and record what you did |
| "I'll address this during implementation" | Annotations must be resolved in the plan, not deferred | Update plan.md now |
| "The human is wrong about this" | Preference: implement their intent. Safety: escalate clearly. | Note concern in log. If unsafe, propose alternative. |
| "This is a safety issue" (when it's a preference) | Don't abuse the safety exception | Ask: data loss? security hole? hard constraint violation? If not, it's a preference. |
| "I already processed this in a previous round" | Maybe they added more context | Check every annotation freshly |
| "I'll skip the conflict check, changes are small" | Small changes create the subtlest conflicts | Always check after processing all annotations |
| "I should generate the Todo now since design is approved" | Todo generation belongs to plan-first-plan Phase 2 | Hand off. Do not generate Todo. |
