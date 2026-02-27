---
name: plan-first-research
description: >
  Use when starting any code change task, or independently to deeply
  understand a codebase area. Before writing a plan or any code, deeply
  read the relevant source files and understand current behavior.
  Write research.md with findings and evidence.
  Can run standalone (Layer 0) without .baton/ or as part of a full workflow.
---
# Plan-First Research

Research is the foundation of every change. You cannot plan what you
do not understand. This skill ensures you read code before writing it.

## Quick Reference

| Attribute        | Value                                                              |
|------------------|--------------------------------------------------------------------|
| Trigger          | Starting any code change task, or need to understand a codebase area |
| Input            | Task goal + relevant source files and tests                        |
| Output           | `research.md` (DRAFT → CONFIRMED)                                 |
| Side effects     | None (read-only skill)                                             |
| Sole responsibility | Deep code reading with evidence-based findings                  |
| Exit condition   | research.md is CONFIRMED by human                                  |

## Mode Behavior

| Mode               | Cross-skill deps | Output path                              | Gate check |
|--------------------|-------------------|------------------------------------------|------------|
| PURE STANDALONE    | Skip              | `./research.md`                          | Skip       |
| PROJECT STANDALONE | Skip              | `.baton/scratch/research-<timestamp>.md` | Skip       |
| WORKFLOW MODE      | Enforced          | `.baton/tasks/<id>/research.md`          | Enforced   |

---

## TL;DR

- **When:** Starting any code change task (before planning or coding),
  or independently when you need to understand a codebase area.
- **Inputs:** Task goal + the relevant source files and tests.
- **Outputs:** `research.md` (DRAFT → CONFIRMED).
- **Output location:** See Mode Behavior table above.
- **Exit:** research.md is **CONFIRMED** (or use `--quick` for eligible tasks).

## Standalone mode (Layer 0)

This skill can run independently, without `.baton/` or an active task.
Use `baton research <scope>` to invoke it directly.

When running standalone:
- Output goes to `./research.md` (current directory) or
  `.baton/scratch/research-<timestamp>.md` if `.baton/` exists
  but no active task is set.
- No phase-lock enforcement.
- No dependency on other skills or artifacts.
- All quality standards still apply — standalone ≠ sloppy.

## Process

Announce: "I'm using the plan-first-research skill."

### Step 1: Identify scope
What files, modules, and interfaces are relevant to this task? List them explicitly.
⚠️ Checkpoint: Are you skipping scope identification because "the task is simple"? → Simple tasks have the most unexamined assumptions. Define scope.

### Step 2: Read deeply
Read each relevant file. Do not skim. Note: current behavior, entry
points, data flow, error handling, edge cases, existing tests.
⚠️ Checkpoint: Are you relying on memory instead of reading files? → Your knowledge is stale. Read the actual files now.

### Step 3: Document findings
Write research.md with the structure below.
⚠️ Checkpoint: Are you putting unverified claims in Findings? → Move them to Assumptions.

### Step 4: Mark status
Add `<!-- RESEARCH-STATUS: DRAFT -->` until the human confirms,
then change to `CONFIRMED`.

## How research gets confirmed

After writing research.md (DRAFT), present the findings to the human
and ask: "Please review the research. If it looks correct and complete,
I'll mark it as CONFIRMED and move to planning."

The human confirms by ANY of:
- Explicitly saying "confirmed" / "looks good" / "proceed to plan"
- Editing research.md and adding `<!-- RESEARCH-STATUS: CONFIRMED -->`

When confirmed, change DRAFT → CONFIRMED in research.md. If the human
has corrections, apply them first, then confirm.

## research.md structure

```markdown
# Research: <task-id or topic>

<!-- RESEARCH-STATUS: DRAFT -->

## Objective
What we are trying to understand and why.

## Scope
Which files and modules were examined.

## Files reviewed
For each file: path, purpose, key observations.

## Current behavior
How the system works today for the area being changed.

## Execution paths
Trace the key code paths relevant to the change.

## Risks and edge cases

For each potential risk, you MUST provide all three parts:

- **Observation:** What you saw in the code (file:line reference)
- **Concern:** What could go wrong and why you think so
- **Verification:** Did you trace the full execution path to confirm?
  - ✅ Verified safe — [evidence: file:line showing why]
  - ❌ Verified unsafe — [evidence: file:line showing the problem]
  - ❓ Unverified — [what you still need to read to confirm]

If a risk is ❓ Unverified, you are NOT done with research. Go read the
files needed to verify it. A risk entry must reach ✅ or ❌ before
research is complete. The ONLY exception is when verification requires
runtime testing that cannot be done by reading code.

DO NOT mark something as a risk based on general knowledge (e.g., "event
publishing inside transactions is usually unsafe"). General patterns
do not apply until you verify them against THIS codebase's actual
configuration. Read the config. Trace the call chain. Then conclude.

## Architecture context
What architectural patterns does this area use? Why were they likely
chosen? Note: for regular changes, the plan should work within these
patterns. For refactoring tasks, this section documents what you are
changing FROM and informs migration strategy.

## Technical references
Official documentation consulted (only if the change involves
unfamiliar technology or uncertain usage). Source URL + key findings.

## Evidence snippets
Short code excerpts that support findings (with file:line refs).

## Assumptions
Assumptions made during research and their risk level. Any claim
without direct code evidence belongs here, not in Findings.

## Open questions
Questions that REQUIRE HUMAN DECISION — not technical questions you
could answer by reading more code.
```

## Research supplements (for [RESEARCH-GAP] support)

When a `[RESEARCH-GAP]` annotation is triggered during the plan's
annotation cycle, this skill is invoked for a targeted supplemental
research. The result is appended to the existing research.md:

    ## Supplement: <topic> (triggered from plan annotation)

    <!-- SUPPLEMENT-DATE: YYYY-MM-DD -->

    ### Objective
    What specific gap we are filling.

    ### Findings
    - **Fact:** ...
    - **Evidence:** file:line or command output

    ### Conclusion
    One-paragraph factual summary of what was learned.

Supplement rules:
- Scope must be narrow — only research the specific gap, do not expand.
- Findings must follow the same evidence standards as the main research.
- Supplements record FACTS ONLY. Do not include design decisions or
  recommendations — those belong in plan.md's annotation log.
- Maximum 2 supplements per annotation round.

## What you MUST do during research

- Read actual source files, not just file names
- Trace execution paths, not just read class signatures
- Note existing test coverage for the area being changed
- Record evidence (file:line references) for every claim
- Every risk must be verified (✅ or ❌) before research is complete
- Identify the architectural patterns in use
- If the change involves unfamiliar technology, check official docs
- Flag anything unclear as an open question
- Separate facts (with evidence) from assumptions (without evidence)

## What you must NOT do during research

- Write or modify any source code files
- Create a plan (that's the next phase)
- Start implementing anything
- Skip files because they "look simple"
- Assume behavior without reading the code
- Mark something as a risk based on general knowledge without verifying
- Put unverified claims in the Findings section (use Assumptions instead)

## Rationalizations to watch for

| You think | Why it's wrong | Do this instead |
| :--- | :--- | :--- |
| "I already know this codebase" | Your knowledge is stale. The code changed since last read. | Read the actual files now. |
| "The task is simple, research is overkill" | Simple tasks have the most unexamined assumptions | Write a brief research.md (can be short) |
| "I'll read as I implement" | Reading during implementation creates confirmation bias | Read first, implement later |
| "The file name tells me enough" | File names lie. Read the implementation. | Open the file. Read it. |
| "Let me just check the tests" | Tests show intended behavior, not actual behavior | Read both source and tests |
| "I know how this technology works" | Training knowledge may be outdated or incomplete | Check the official docs |
| "This pattern is usually unsafe" | General knowledge ≠ this codebase's facts | Trace the full call chain, verify with evidence |
| "I'll flag it as a risk to be safe" | Unverified risks waste human attention | Verify it yourself first |
| "No .baton/ means I can skip structure" | Standalone mode has the same quality bar | Follow the full research.md structure regardless |
