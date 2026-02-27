---
name: plan-first-plan
description: >
  Use after research is confirmed, or independently to design a solution
  for any code change. Write a design plan with file-by-file changes and
  code snippets. Todo checklist is generated AFTER the design is approved.
  Can run standalone (Layer 0) without .baton/ or as part of a full workflow.
---
# Plan-First Plan

A plan is a contract between the human and the AI. It specifies exactly
what will change, how, and why. The plan goes through two phases:

1. **Design phase** — write the design, get human approval
2. **Todo phase** — generate the implementation checklist from the
   approved design

Do NOT generate the todo checklist during the design phase. The human
approves the DESIGN, then you convert it into actionable steps.

## Quick Reference

| Attribute        | Value                                                              |
|------------------|--------------------------------------------------------------------|
| Trigger          | After research is CONFIRMED, quick-path, or standalone use         |
| Input            | research.md (if available) + human decisions/open questions        |
| Output           | `plan.md` (DRAFT → APPROVED → + `## Todo`)                       |
| Side effects     | None                                                               |
| Sole responsibility | Design planning + Todo checklist generation (Phase 2)          |
| Exit condition   | plan.md is APPROVED and has a generated Todo checklist              |

## Mode Behavior

| Mode               | Cross-skill deps | Output path                           | Gate check |
|--------------------|-------------------|---------------------------------------|------------|
| PURE STANDALONE    | Skip              | `./plan.md`                           | Skip       |
| PROJECT STANDALONE | Skip              | `.baton/scratch/plan-<timestamp>.md`  | Skip       |
| WORKFLOW MODE      | Enforced          | `.baton/tasks/<id>/plan.md`           | Enforced   |

---

## TL;DR

- **When:** After research is CONFIRMED, quick-path, or standalone.
- **Inputs:** research.md (if available) + any human decisions/open questions.
- **Outputs:** `plan.md` (DRAFT → APPROVED → + `## Todo`).
- **Output location:** See Mode Behavior table above.
- **Exit:** plan.md is **APPROVED** and has a generated **Todo checklist**.

## Standalone mode (Layer 0)

This skill can run independently, without `.baton/` or an active task.
Use `baton plan [--from research.md]` to invoke it directly.

When running standalone:
- Output goes to `./plan.md` (current directory) or
  `.baton/scratch/plan-<timestamp>.md` if `.baton/` exists
  but no active task is set.
- No phase-lock enforcement.
- If research.md exists in the same location, it is loaded as context.
- If research.md does NOT exist, the plan proceeds with a degradation
  warning (see below).

## Degradation mode (no prior research)

When no research.md is available, the plan skill still works but adds
a prominent warning to the output:

```markdown
## Context
⚠️ **No prior research phase.** This design is based on a quick code
review, not a systematic research. Design decisions may miss deep
dependencies or edge cases. For high-risk changes, consider running
`baton research` first.
```

This warning is informational — it does not block the plan.

## Phase 1: Design

Announce: "I'm using the plan-first-plan skill."

### Step 1: Detect running mode and check research status

Detect the current mode (see workflow-protocol.md for mode detection):

- **WORKFLOW MODE** → Check research status. If `RESEARCH-STATUS: CONFIRMED`
  is not present, STOP — the human has not confirmed research yet.
  Ask the human to review research.md and confirm before proceeding.
- **WORKFLOW MODE with Quick-path** → If `.baton/tasks/<task-id>/.quick-path`
  file exists, skip research status check. Quick-path tasks go straight
  to planning.
- **STANDALONE MODE** (PURE or PROJECT) → Skip research status check.
  If research.md exists, load it as context. If not, add degradation
  warning and continue.

⚠️ Checkpoint: Are you in WORKFLOW MODE and about to skip the research check? → Only quick-path tasks skip it. Check for `.quick-path` file.

### Step 2: Check open questions
If research.md exists, check the "Open questions" section. If there are
unresolved questions that require human decision, ask the human first or
explicitly state your assumption so the human can catch it.
⚠️ Checkpoint: Are you silently resolving an open question? → State the assumption explicitly or ask the human.

### Step 3: Read hard-constraints.md (if available)
In WORKFLOW MODE or PROJECT STANDALONE: read
`.baton/governance/hard-constraints.md`. In the plan's Risk assessment
section, note for each Active constraint whether the proposed changes
interact with that constraint's Scope. If the design may violate a
constraint, flag it explicitly and propose an alternative or request
human confirmation.
In PURE STANDALONE: skip this step.

### Step 4: Design the solution
Architecture, file changes, data flow.
⚠️ Checkpoint: Are you planning to "figure out details during implementation"? → That's a wish, not a plan. Include code snippets for every non-trivial change.

### Step 5: Write plan.md
Use the structure below. Do NOT include a `## Todo` section yet.

### Step 6: Present to human
Ask: "Please review the design. Add annotations if you want changes,
or approve when ready."

### plan.md structure (design phase)

```markdown
# Plan: <task-id or description>

<!-- STATUS: DRAFT -->

## Context
(If research.md exists: reference key findings.)
(If no research: add the degradation warning above.)

## Summary
One paragraph: what this change does and why.

## Design decisions
### Decision 1: <title>
- **Choice:** The specific technical decision
- **Rationale:** Why this approach was chosen
- **Alternatives considered:** Other approaches and why they were rejected
- **Impact scope:** Files/modules affected

### Decision 2: ...

## File change manifest
Precise list of files to create, modify, or delete:
- **Create:** path/to/new-file.ts — purpose
- **Modify:** path/to/existing.ts — what changes
- **Delete:** (if any)

## File changes (detailed)

### <path/to/module.ext> (modify | create | delete)
What changes and why. Include code snippets for non-trivial changes.

## Risk assessment
- Risk 1: description + mitigation
- Hard constraint interactions: [list any constraints from
  hard-constraints.md whose Scope intersects with this change]

## Review routing
Which review dimensions apply:
- Interface stability: yes/no (reason)
- Database: yes/no
- Performance: yes/no
- Project-specific: [list applicable items]

## Annotation log
(Entries added during annotation cycle)
```

Note: there is NO todo section at this stage.

## Annotation cycle

When the human adds annotations (`[NOTE]`, `[Q]`, `[CHANGE]`,
`[RESEARCH-GAP]`), load the annotation-cycle skill to process them.
Repeat until the human approves.

## Phase 2: Todo generation

When the human sets `<!-- STATUS: APPROVED -->` (or says "approved"):

1. **Read the approved design** — The file changes section is now final.
2. **Generate the todo checklist** — Append `## Todo` to plan.md, based
   on the approved design.
3. **Announce** — "Design is approved. I've generated the implementation
   checklist. Ready to start implementing."

### Todo item rules

**Every item must specify:** which file, what change, how to verify.

**Every item must be 5-15 minutes of work.** If it would take longer,
split it.

**Assume the implementer is a capable but context-free developer.**
Give them enough detail to implement without guessing.

### Good todo item
```
- [ ] 3. Add sms_enabled config flag (config/settings.ext, 5 min)
       Add a boolean flag for SMS channel toggle.
       Default to false/disabled.
       Verify: app starts without errors, flag is readable in test.
```

### Bad todo item
```
- [ ] 3. Update config for SMS
```
Bad because: which file? what specifically? how to verify?

## Cross-task dependency declaration (Layer 1+)

When running within a full workflow, plans can declare dependencies:

```markdown
<!-- DEPENDS-ON: auth-refactor (need new AuthContext type) -->
<!-- TOUCHES: src/api/users/*, src/models/user.ts -->
```

Optional in Layer 0 (standalone) mode.

## Rationalizations to watch for

| You think | Why it's wrong | Do this instead |
| :--- | :--- | :--- |
| "The plan is obvious, I'll just start coding" | Obvious plans have unexamined assumptions | Write plan.md even if brief |
| "I'll figure out the details during implementation" | That's not a plan, that's a wish | Include code snippets for every non-trivial change |
| "Let me include the todo checklist with the design" | The human approves the DESIGN. Todo before approval wastes effort. | Write design only. Generate todo after approval. |
| "One big todo item is fine" | Big items hide complexity | Split into 5-15 minute items |
| "I don't need code snippets for simple changes" | Simple changes misunderstood = bugs | At minimum specify the function signature change |
| "Let me start implementing while waiting for approval" | Design may change after annotation | Wait. Do something else. |
| "The human will understand what I mean" | Ambiguity = wrong approval | Be explicit. Show code. |
| "No research means I should just wing it" | No research = higher risk, not lower bar | Add degradation warning, be extra careful about edge cases |
| "Hard constraints don't apply to my change" | Check the Scope field — constraints may be broader than you think | Read each constraint's Scope, verify against your file change manifest |
