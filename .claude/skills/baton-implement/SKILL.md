---
name: baton-implement
description: >
  This skill MUST be used when plan.md contains BATON:GO and the user says
  "implement", "generate todolist", "start building", "实施", or "开始".
  Also use when resuming implementation mid-session. Without this skill,
  source code changes will be blocked by the write-lock hook.
user-invocable: true
---

## Iron Law

```
NO CODE CHANGES WITHOUT BATON:GO IN PLAN.MD
ONLY MODIFY FILES LISTED IN THE PLAN
STOP ON UNEXPECTED DISCOVERIES — UPDATE PLAN FIRST
```

The plan is the contract. Every change must trace back to a todo item. The write-lock
hook enforces BATON:GO at the filesystem level — this is not just a guideline.

## When to Use

- When plan.md has `<!-- BATON:GO -->` and the user says to implement
- When the user says "generate todolist" (after BATON:GO is present)
- After the annotation cycle is complete and the human has approved

**When NOT to use**: When there's no plan, when BATON:GO is missing, or during
research/planning phases.

## The Process

### Step 1: Generate Todolist

If `## Todo` doesn't exist yet and the human said "generate todolist":

- Read the plan carefully
- Each todo item must include:
  - **Change**: specific change description
  - **Files**: files involved and write set (which files this item modifies)
  - **Verification**: how to verify correctness
  - **Dependencies**: which earlier items must complete first, or "none"
  - **Derived artifacts**: lockfiles, generated types, snapshots expected to change, or "none"
- Format: `- [ ]` unchecked, `- [x] ✅` checked (lowercase x + checkmark)
- Order by dependencies — later items may need earlier code
- Independent items (no dependency, non-overlapping write sets) can be parallelized

### Step 2: Execute Each Todo Item

For each item:

1. **Understand intent** — re-read the plan section this todo implements
2. **Implement** — make the change
3. **Self-check** — re-read the modified code (not from memory). Does it match the
   plan's design intent, or did you drift?
4. **Verify** — run the verification method specified in the todo
5. **Mark complete** — only after steps 3 and 4 pass

### Step 3: Handle Dependencies

- Items with dependencies MUST execute sequentially
- Independent items can run in parallel (subagent) only when their write sets do
  not overlap
- Before launching subagents, assign explicit file ownership. If two items may touch
  the same implementation file, generated file, or test suite, run them sequentially
- Long todolists (10+) should be batched

### Step 4: Completion

After ALL items are done:

1. Run full test suite, record results in plan.md
2. Append `## Retrospective`:
   - What did the plan get wrong? (predictions vs reality)
   - What surprised you during implementation?
   - What would you research differently next time?
3. Remind the human to archive

## Self-Check Triggers

Run these checks automatically — they catch drift before it becomes a problem.

**After writing code**:
- Re-read the modified code (not from memory)
- Does it match the plan's design intent, or did you drift?
- If implementation diverges from plan, record whether the plan was wrong or the
  implementation was wrong
- **Regression check**: re-read the surrounding context (5+ lines above and below).
  Did your edit break adjacent logic, narrow scope, or introduce syntax errors?

**After completing each todo**:
- Run tests directly related to the modified files before moving to next todo
- If tests fail → fix before proceeding
- If no relevant tests exist → note this in the todo completion record

**When modifying a file already changed by a prior todo**:
- Before implementing: re-read the file's CURRENT state (not from memory)
- After implementing: re-run ALL verification steps for ALL prior todos
  that touched this file
- Record: "File X touched by todos #A, #B — re-verified #A after #B"

**After modifying any file**:
- Who consumes/imports/calls/reads this file?
- Did my change affect any of those consumers?
- For scripts/configs: who runs this? What do they expect?

**Before marking a todo complete**:
- Did you verify the change works (typecheck/build), or are you assuming?
- Re-read the code one more time

**After fixing a bug or inconsistency**:
- Grep for the old (buggy) pattern — if it exists in other files, those are the same bug
- Check parallel implementations: if you fixed IDE A's path, verify IDEs B-N have the same fix

**After writing or modifying tests**:
- Read what the assertion actually checks, not just its name
- If both sides of a comparison are empty/null/missing, the assertion is a false positive
- Keyword checks must verify the keyword exists in at least one file — otherwise the check is vacuous

**When something feels wrong**:
- If implementation feels harder than the plan suggested, pause
- Check whether the plan missed something rather than forcing a solution

## Red Flags — STOP

| Thought | Reality |
|---------|---------|
| "Let me also fix this nearby code while I'm here" | Only modify files listed in the plan. Propose additions first. |
| "This small change doesn't need to be in the plan" | If it's not in the plan, update the plan and wait for confirmation. |
| "I'll mark this done and verify later" | Verify BEFORE marking complete. No exceptions. |
| "The plan said X but Y is clearly better" | Stop. Update plan.md. Wait for human confirmation. |
| "Same approach failed but let me try one more time" | 3 failures → MUST stop and report to human. |
| "I fixed this one spot, the others are probably fine" | Grep for the same pattern. If it exists elsewhere, it's the same bug. |
| "These generated files don't count" | No global exemption. If derived artifacts were not explicitly expected, stop and update the plan. |

## Common Rationalizations

| Excuse | Why It Fails |
|--------|-------------|
| "It's just a refactor, not a new feature" | Refactors not in the plan can break callers. Propose first. |
| "The test passes, so it must be correct" | Tests prove behavior, not design intent. Re-read the plan. |
| "I'll update the plan after I finish" | Unauthorized changes compound. Stop early, update plan. |
| "This dependency was obvious, didn't need to be in the plan" | If it was obvious, it would be in the plan. Update it. |

## Unexpected Discoveries

These WILL happen. Handle them by severity:

- **Small addition** (new utility function, extra test case):
  Update plan.md with explanation, wait for human confirmation

- **Derived artifact changed** (lockfile, generated types, snapshot):
  If it was explicitly expected in the todo item, verify it and record it in the
  Retrospective. If it was NOT explicitly expected, stop, update plan.md, wait for
  human confirmation

- **Design direction change** (wrong assumption, better approach found):
  Stop. Inform human. Human removes BATON:GO to roll back to annotation cycle.

- **Stopping mid-implementation** (end of session, blocked):
  Append `## Lessons Learned` to plan.md — what worked, what didn't, what to try next

## Action Boundaries Reminder

These rules are enforced by hooks and cannot be bypassed:

1. Source code writes require `<!-- BATON:GO -->` in plan.md (write-lock.sh)
2. Only modify files listed in the plan
3. Same approach fails 3x → MUST stop and report
4. Discover omission → MUST stop, update plan, wait for confirmation
5. Derived artifacts are allowed only when explicitly listed in the approved plan/todo
6. Markdown is always writable (research.md, plan.md updates are never blocked)
