---
normative-status: Authoritative specification for the IMPLEMENT phase.
name: baton-implement
description: >
  Use when plan.md contains BATON:GO and the user says "implement", "generate
  Todo list", "start building", "实施", or "开始实施". Also use when resuming
  implementation mid-session.
user-invocable: true
---

## Iron Law

```
NO CODE CHANGES WITHOUT BATON:GO IN PLAN.MD
ONLY MODIFY FILES IN THE APPROVED WRITE SET (SEE UNEXPECTED DISCOVERIES FOR SCOPE)
STOP ON C/D-LEVEL UNEXPECTED DISCOVERIES — UPDATE PLAN FIRST
VERIFY = VISIBLE OUTPUT. "I checked" is not evidence.
DO NOT REFRAME THE TASK TO FIT AN EASIER IMPLEMENTATION.
```

**Trivial caveat**: For Trivial tasks (constitution §Task Sizing), there is no plan.md. BATON:GO appears in the inline plan contract in chat, placed by the human before any source modification is made. The Iron Law still applies — no changes until that marker is present.

Approved write set = files listed in plan/Todo, plus only those A/B-level additions that satisfy Step 4 criteria and are explicitly recorded during implementation.

## Red Flags

These thoughts mean STOP — you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This small change isn't in the plan but makes sense" | A/B-level? Record and continue. C/D-level? Stop and update plan |
| "Tests passed, no need for self-check" | Self-check is re-reading code, not looking at test results |
| "This Todo is too simple to need verification" | Every Todo has a Verify field. Use it |
| "Three failures in a row but I'm close" | 3-failure rule. Stop and report |
| "I'll just fix this one more thing" | Is it in the write set? Is it A/B-level? If not, stop |
| "The plan implied this change" | Implied ≠ approved. If it's not in the write set, it's a discovery |
| "I can skip the review, the changes are small" | Completion review is mandatory. Prefer independent review; otherwise explicit self-review. No exceptions |

## Gotchas

> Operational failure patterns. Add entries when observed in real usage.
> Empty until then — do not pre-fill with theory.

## When to Use

- Plan has `<!-- BATON:GO -->` and user says to implement or generate Todo list
- Resuming: BATON:GO present + unchecked Todo items or `## Lessons Learned` exists

**When NOT to use**: No plan, no BATON:GO, or during research/planning.

## The Process

### Step 1: Generate Todo List

If `## Todo` doesn't exist and human said "generate Todo list":

- Read the plan carefully
- Generate items per baton-plan schema. Each item must have five fields: Change (what), Files (write set), Verify (validation command), Deps (blocked by), Artifacts (produced)
- Order by dependencies; parallelization must satisfy the independence criteria in Step 3

**After generating, review the Todo list:**
- Preferred: independent review — dispatch baton-review via Agent tool with `./review-prompt.md` (Todo List section) + Todo list + plan text
- Fallback (when Agent tool is technically unavailable): explicit self-review using `./review-prompt.md` Todo List checklist — work through each item with an explicit YES/NO answer; task simplicity is not a reason to use this fallback
- If neither review method performed: do not claim reviewed

Resolve review findings in the Todo list before presenting it.

### Step 2: Execute Each Todo Item

**Failure threshold: 3** (overrides default ≥2)

**CONTINUOUS EXECUTION: Once the user says "implement", execute ALL Todo items
to completion without pausing between items. Only stop for: blocking errors,
C/D unexpected discoveries, or 3-failure limit (3 failed remediation attempts for the same blocking issue; cosmetic edits or log-print additions do not reset the counter). Do not stop to show progress
or ask for confirmation between items — the approved plan IS the confirmation.**

**Progress tracking**: In Claude Code, use TaskCreate at the start of
execution to create a task for each Todo item. Use TaskUpdate to mark
in_progress when starting an item and completed when done. This provides
visual progress in the chat. When adding Todo items mid-implementation,
recreate all tasks (including completed ones, marked immediately as
completed) so the user sees full progress context. Outside Claude Code,
rely on immediate plan marking (Step 2 point 5) for progress visibility.

For each item:
1. **Understand intent** — re-read the plan section this Todo item implements and identify the specific contract, restrictions, and boundary conditions it must preserve
2. **Implement** — make the change
3. **Self-check** — perform the 4 essential self-checks listed below
4. **Verify** — run the verification method specified
5. **Mark complete immediately** — after self-check and verify both pass,
   immediately Edit the plan to change `- [ ]` to `- [x] ✅` for this item.
   Do not batch-update at the end. In Claude Code, also use TaskUpdate to
   mark the task completed for visual progress tracking.

### Step 3: Handle Dependencies

- Dependent items: sequential. Independent items may be parallelized only when write sets, validation paths, and interface assumptions are all independent.
- Before subagents: assign explicit file ownership. Overlapping files = sequential.
- Consider baton-subagent when items are independent in write set, validation path, and interface assumptions. Item count alone is not sufficient — evaluate whether merge/rebase cost and shared abstraction coupling justify parallelization.

### Self-Checks (4 essential)

1. **Re-read code using the Read tool** — open the file and read it after every edit; mental recall or editor view does not count as a re-read
2. **Check behavior against plan contract** — does the change match the approved interface, restrictions, and boundary conditions? Not just "does the code work" but "does it do what the plan said"
3. **Grep for same bug elsewhere** — after fixing any bug
4. **Run the required validation commands before marking done** — no exceptions

### Step 4: Unexpected Discoveries

**A. Local completion aid** — does not change public contract; only serves current Todo item; no new cross-module dependency → continue, record in `## Implementation Notes` in plan (create section on first use).
**B. Adjacent integration** — wires up already-approved changes; does not change requirement boundary or introduce new behavior branches → continue only after appending to write set and recording rationale in `## Implementation Notes`. Rationale must explicitly state: (1) what was added, (2) why it qualifies as B-level (no new behavior branch, purely serves the current Todo item's integration), and (3) which Todo item it belongs to.
**C. Scope extension** — requires new capability, scenario, data flow, or file surface not listed in plan → STOP. Append a `## Implementation Notes` section to the plan (create on first use) recording: (1) what was discovered, (2) why it is C-level (which plan assumption it violates, what scope expansion is needed). Do NOT remove BATON:GO — the human decides whether to revise the plan and re-authorize or reject the scope expansion. Declare BLOCKED state explicitly to the human and wait for direction before any further source modification. When the human provides direction to revise the plan: update the plan, then confirm the original BATON:GO still covers the revised scope before resuming (per constitution §States BLOCKED→EXECUTING). If scope expansion changes the file surface, data flow, or validation strategy assumed by the original plan, escalate to D-level.
**D. Design change** — requires changing established design assumptions, interface contracts, data models, or validation strategy → STOP. Record D-level discovery and rationale in `## Implementation Notes`. Human removes BATON:GO. Return to plan phase.

**Constitution Discovery Protocol mapping:**

| Level | Constitution Question | State | BATON:GO |
|-------|----------------------|-------|----------|
| A | Q3 (neither applies) | Continue | Valid |
| B | Q3 + implementation-local touch | Continue | Valid |
| C | Q2 (execution plan needs change) | BLOCKED | Invalidated |
| D | Q1 (assumptions invalid) | BLOCKED | Invalidated |

### Step 5: Completion

After ALL items verified:
0. **批注区 check** — scan the plan's `## 批注区` (and the research artifact's `## 批注区` if referenced) for any annotation with Status = ❓ and Impact = "affects conclusions" or "blocks next phase". If any remain unresolved, surface them to the human before proceeding to review or BATON:COMPLETE.
1. **Implementation review** — dispatch baton-review via Agent tool with `./review-prompt.md` + diff (`git diff` of all changes) + plan text.
   Fallback (when Agent tool is technically unavailable): explicit self-review using `./review-prompt.md` checklist against plan contract — work through each item with an explicit YES/NO answer; task simplicity is not a reason to use this fallback.
   Fix findings, then re-review. Repeat until baton-review passes or circuit breaker
   triggers (3 rounds of high severity findings → escalate to human).
2. **Full test suite** — run the project's complete suite (as defined by repo conventions or plan), not just per-item tests
3. **Retrospective** — append `## Retrospective` to plan. Must include: ≥1 **wrong prediction** (format: "I expected X but found Y"), ≥1 **unexpected discovery** (something not anticipated in the plan), ≥1 **process improvement** for future research or planning. Generic statements like "went smoothly" or "completed as planned" do not satisfy this requirement.
4. **Mark complete** — add `<!-- BATON:COMPLETE -->` on its own line in the plan file. Only after steps 1-3 above are all satisfied (review passed, full suite passed, retrospective recorded).
5. **Branch disposition** — present options (merge/PR/keep/discard) with status only; do not merge, open PR, or discard without explicit human choice

**NO BATON:COMPLETE WITHOUT FULL TEST SUITE PASS. NO MERGE WITHOUT FULL TEST SUITE PASS.**

### Session Handoff

When stopping mid-work: append `## Lessons Learned` to plan with:
- **Stop reason** (one of: blocking error, C-level scope extension, D-level design change, 3-failure limit, external interruption)
- What worked, what didn't, what to try next, current blockers

**Lessons Learned vs Retrospective**: Lessons Learned is for mid-session handoff (operational, recovery-oriented — "where I stopped and how to resume"). Retrospective is for completion (process improvement — "what we predicted wrong and what to change next time"). Do not duplicate content between them.
