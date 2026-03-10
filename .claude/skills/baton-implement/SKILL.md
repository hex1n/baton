---
normative-status: This skill is the authoritative specification for the IMPLEMENT phase. workflow.md provides the overview; this file is the definitive reference for implementation execution.
name: baton-implement
description: >
  This skill MUST be used when plan.md contains BATON:GO and the user says
  "implement", "generate todolist", "start building", "实施", "开始实施",
  or "开始开发". Also use when resuming implementation mid-session. Without
  this skill, source code changes will be blocked by the write-lock hook.
user-invocable: true
---

## Iron Law

```
NO CODE CHANGES WITHOUT BATON:GO IN PLAN.MD
ONLY MODIFY FILES IN THE APPROVED WRITE SET (SEE UNEXPECTED DISCOVERIES FOR SCOPE)
STOP ON UNEXPECTED DISCOVERIES — UPDATE PLAN FIRST
```

**Section hierarchy**: Iron Law = hard gates (violation = stop) · Process = execution
protocol · Self-Check = drift detection · Red Flags = pattern recognition (if you
think this, stop).

Approved write set = files listed in the plan/todo + A/B-level additions recorded
during implementation (see Unexpected Discoveries).

The plan is the contract. Every change must trace back to a todo item. The write-lock
hook enforces BATON:GO at the filesystem level — this is not just a guideline.

## When to Use

- When plan.md has `<!-- BATON:GO -->` and the user says to implement
- When the user says "generate todolist" (after BATON:GO is present)
- After the annotation cycle is complete and the human has approved
- **Resuming**: when plan.md contains BATON:GO and any of:
  - unchecked todo items exist (`- [ ]`)
  - `## Lessons Learned` indicates a prior session stopped mid-work
  - the user explicitly asks to continue implementation

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
5. **Mark complete** — only after steps 3 and 4 pass.
   For Medium/Large tasks, record a completion note per item:
   `Files: ... | Verified: <command> → <result> | Deviations: none or <what changed>`

### Step 3: Handle Dependencies

- Items with dependencies MUST execute sequentially
- Independent items can run in parallel (subagent) only when their write sets do
  not overlap
- Before launching subagents, assign explicit file ownership. If two items may touch
  the same implementation file, generated file, or test suite, run them sequentially
- Long todolists (10+) should be batched

### Step 4: Completion

After ALL items are done:

1. Run tiered verification and record results in plan.md:
   - **Required**: all todo-specified verifications + tests for affected files
   - **If available**: package/module-level test suite
   - **If runnable**: full project test suite
   - **If not runnable**: record why and list uncovered risk areas
2. Append `## Retrospective`:
   - What did the plan get wrong? (predictions vs reality)
   - What surprised you during implementation?
   - What would you research differently next time?
3. Remind the human to archive (per workflow.md: `mkdir -p plans && mv <plan-file> plans/plan-<date>-<topic>.md`)

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
| "Let me also fix this nearby code while I'm here" | Only modify files in the approved write set (see Unexpected Discoveries for scope). Propose additions first. |
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

Levels A and B are pre-authorized exceptions to Iron Law #2. Levels C and D require
stopping. This is the approved write set scope definition.

These WILL happen. Handle them by impact level:

**A. Local completion aid** — e.g. private helper function, small test fixture.
Condition: does not change public contract, does not add cross-module dependencies.
→ If within an already-approved file: continue, record in todo completion notes.
→ If requires a new file: continue only when the file is narrowly scoped to the approved change, does not create a new public entrypoint or public contract, and does not introduce cross-module dependencies beyond this todo. Append the file to the todo’s write set and note the reason.

**B. Adjacent integration change** — e.g. barrel export, route registration, fixture index update.
Condition: required to complete the planned change, not a new feature.
→ Continue. Append the file to the todo's write set and note the reason.

**C. Scope extension** — e.g. fixing a related bug, covering an adjacent module.
Condition: goes beyond what the plan approved.
→ Stop. Update plan.md with the proposed addition. Wait for human confirmation.

**D. Design change** — e.g. wrong assumption discovered, approach fundamentally flawed.
→ Stop. Inform human. Human removes BATON:GO to roll back to annotation cycle.

### Session Handoff

When stopping mid-implementation (end of session, blocked, or waiting on human):
Append `## Lessons Learned` to plan.md — what worked, what didn't, what to try next.

## Action Boundaries Reminder

These rules have different enforcement levels:

1. **Hook-enforced**: Source code writes require `<!-- BATON:GO -->` in plan.md (write-lock.sh blocks without GO)
2. **Advisory**: Only modify files in the approved write set — post-write-tracker warns on plan-unlisted writes but cannot block (host hook model limitation)
3. **Skill-disciplined**: Same approach fails 3x → MUST stop and report. Same root cause = same chain; only a fundamentally different strategy counts as new.
4. **Skill-disciplined**: Discover scope omission beyond A/B → MUST stop, update plan, wait for confirmation
5. **Hook-enforced**: Markdown is always writable (research.md, plan.md updates are never blocked)
