---
normative-status: Authoritative specification for the IMPLEMENT phase.
name: baton-implement
description: >
  Use when plan.md contains BATON:GO and the user says "implement", "generate
  todolist", "start building", "实施", or "开始实施". Also use when resuming
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

Approved write set = files listed in plan/todo, plus only those A/B-level additions that satisfy Step 4 criteria and are explicitly recorded during implementation.

## Red Flags

These thoughts mean STOP — you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This small change isn't in the plan but makes sense" | A/B-level? Record and continue. C/D-level? Stop and update plan |
| "Tests passed, no need for self-check" | Self-check is re-reading code, not looking at test results |
| "This todo is too simple to need verification" | Every todo has a Verify field. Use it |
| "Three failures in a row but I'm close" | 3-failure rule. Stop and report |
| "I'll just fix this one more thing" | Is it in the write set? Is it A/B-level? If not, stop |
| "The plan implied this change" | Implied ≠ approved. If it's not in the write set, it's a discovery |
| "I can skip the review, the changes are small" | Completion review is mandatory. Prefer independent review; otherwise explicit self-review. No exceptions |

## When to Use

- Plan has `<!-- BATON:GO -->` and user says to implement or generate todolist
- Resuming: BATON:GO present + unchecked todos or `## Lessons Learned` exists

**When NOT to use**: No plan, no BATON:GO, or during research/planning.

## The Process

### Step 1: Generate Todolist

If `## Todo` doesn't exist and human said "generate todolist":

- Read the plan carefully
- Generate items per baton-plan schema. Each item must have five fields: Change (what), Files (write set), Verify (validation command), Deps (blocked by), Artifacts (produced)
- Order by dependencies; parallelization must satisfy the independence criteria in Step 3

**After generating, review the todolist:**
- Preferred: independent review — dispatch review subagent via Agent tool with only the todolist + plan text
- Fallback: explicit self-review checklist in current agent (re-read plan, verify each todo traces to a plan section, check ordering and deps)
- If neither review method performed: do not claim reviewed

Resolve review findings in the todolist before presenting it.

### Step 2: Execute Each Todo Item

**CONTINUOUS EXECUTION: Once the user says "implement", execute ALL todo items
to completion without pausing between items. Only stop for: blocking errors,
C/D unexpected discoveries, or 3-failure limit (3 failed remediation attempts for the same blocking issue; cosmetic edits or log-print additions do not reset the counter). Do not stop to show progress
or ask for confirmation between items — the approved plan IS the confirmation.**

For each item:
1. **Understand intent** — re-read the plan section this todo implements and identify the specific contract, restrictions, and boundary conditions it must preserve
2. **Implement** — make the change
3. **Self-check** — perform the 4 essential self-checks listed below
4. **Verify** — run the verification method specified
5. **Mark complete** — only after self-check and verify both pass

### Step 3: Handle Dependencies

- Dependent items: sequential. Independent items may be parallelized only when write sets, validation paths, and interface assumptions are all independent.
- Before subagents: assign explicit file ownership. Overlapping files = sequential.
- Consider baton-subagent when items are independent in write set, validation path, and interface assumptions. Item count alone is not sufficient — evaluate whether merge/rebase cost and shared abstraction coupling justify parallelization.

### Self-Checks (4 essential)

1. **Re-read code, not from memory** — after every edit
2. **Check behavior against plan contract** — does the change match the approved interface, restrictions, and boundary conditions? Not just "does the code work" but "does it do what the plan said"
3. **Grep for same bug elsewhere** — after fixing any bug
4. **Run the required validation commands before marking done** — no exceptions

### Step 4: Unexpected Discoveries

**A. Local completion aid** — does not change public contract; only serves current todo; no new cross-module dependency → continue, record in `## Implementation Notes` in plan (create section on first use).
**B. Adjacent integration** — wires up already-approved changes; does not change requirement boundary or introduce new behavior branches → continue only after appending to write set and recording rationale in `## Implementation Notes`.
**C. Scope extension** — requires new capability, scenario, data flow, or file surface not listed in plan → STOP. Update plan. Wait for human. If scope expansion changes the file surface, data flow, or validation strategy assumed by the original plan, escalate to D-level.
**D. Design change** — requires changing established design assumptions, interface contracts, data models, or validation strategy → STOP. Record D-level discovery and rationale in `## Implementation Notes`. Human removes BATON:GO. Return to plan phase.

### Step 5: Completion

After ALL items verified:
1. **Implementation review** — review all changes independently:
   - Preferred: dispatch review subagent via Agent tool with the diff (`git diff` of all changes)
   - Fallback: perform explicit self-review in current agent against plan contract
   - Review criteria: does each change match plan intent? Unintended side effects? Missed edge cases? Were any B-level additions made, and are their rationales in `## Implementation Notes` justified?
   - Fix findings before proceeding.
2. **Full test suite** — run the project's complete suite (as defined by repo conventions or plan), not just per-item tests
3. **Retrospective** — append `## Retrospective` to plan (≥3 lines: wrong predictions,
   surprises, research improvements)
4. **Mark complete** — add `<!-- BATON:COMPLETE -->` on its own line in the plan file. Only after steps 1-3 above are all satisfied (review passed, full suite passed, retrospective recorded).
5. **Branch disposition** — present options (merge/PR/keep/discard) with status only; do not merge, open PR, or discard without explicit human choice

**NO BATON:COMPLETE WITHOUT FULL TEST SUITE PASS. NO MERGE WITHOUT FULL TEST SUITE PASS.**

### Session Handoff

When stopping mid-work: append `## Lessons Learned` to plan with:
- **Stop reason** (one of: blocking error, C-level scope extension, D-level design change, 3-failure limit, external interruption)
- What worked, what didn't, what to try next, current blockers

**Lessons Learned vs Retrospective**: Lessons Learned is for mid-session handoff (operational, recovery-oriented — "where I stopped and how to resume"). Retrospective is for completion (process improvement — "what we predicted wrong and what to change next time"). Do not duplicate content between them.
