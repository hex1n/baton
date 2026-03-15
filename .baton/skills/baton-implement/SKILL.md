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
STOP ON UNEXPECTED DISCOVERIES — UPDATE PLAN FIRST
VERIFY = VISIBLE OUTPUT. "I checked" is not evidence.
FIRST PRINCIPLES BEFORE FRAMING.
```

Approved write set = files listed in plan/todo + A/B-level additions.

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
| "I can skip the review dispatch, the changes are small" | Review dispatch is mandatory at completion. No exceptions |

## When to Use

- Plan has `<!-- BATON:GO -->` and user says to implement or generate todolist
- Resuming: BATON:GO present + unchecked todos or `## Lessons Learned` exists

**When NOT to use**: No plan, no BATON:GO, or during research/planning.

## The Process

### Step 1: Generate Todolist

If `## Todo` doesn't exist and human said "generate todolist":

- Read the plan carefully
- Generate items per baton-plan schema (Change, Files, Verify, Deps, Artifacts)
- Order by dependencies; independent items can be parallelized

**After generating, dispatch review subagent** via Agent tool with only the
todolist + plan text. Process findings before presenting.

### Step 2: Execute Each Todo Item

**CONTINUOUS EXECUTION: Once the user says "implement", execute ALL todo items
to completion without pausing between items. Only stop for: blocking errors,
C/D unexpected discoveries, or 3-failure limit. Do not stop to show progress
or ask for confirmation between items — the approved plan IS the confirmation.**

For each item:
1. **Understand intent** — re-read the plan section this todo implements
2. **Implement** — make the change
3. **Self-check** — re-read modified code (not from memory). Match plan intent?
4. **Verify** — run the verification method specified
5. **Mark complete** — only after 3 + 4 pass

### Step 3: Handle Dependencies

- Dependent items: sequential. Independent items: parallel if write sets don't overlap.
- Before subagents: assign explicit file ownership. Overlapping files = sequential.
- 3+ independent items with non-overlapping write sets → invoke baton-subagent.

### Self-Checks (3 essential)

1. **Re-read code, not from memory** — after every edit
2. **Grep for same bug elsewhere** — after fixing any bug
3. **Run tests before marking done** — no exceptions

### Step 4: Unexpected Discoveries

**A. Local completion aid** (private helper, test fixture) → continue, record in notes.
**B. Adjacent integration** (barrel export, route registration) → continue, append to write set.
**C. Scope extension** → STOP. Update plan. Wait for human.
**D. Design change** → STOP. Human removes BATON:GO.

### Step 5: Completion

After ALL items verified:
1. **Implementation review** — dispatch review subagent via Agent tool with the
   diff (`git diff` of all changes). Review criteria: does each change match plan
   intent? Unintended side effects? Missed edge cases? Fix findings before proceeding.
2. **Retrospective** — append `## Retrospective` to plan (≥3 lines: wrong predictions,
   surprises, research improvements)
3. **Mark complete** — add `<!-- BATON:COMPLETE -->` on its own line in the plan file
4. **Full test suite** — run the project's complete suite, not just per-item tests
5. **Branch disposition** — present options (merge/PR/keep/discard), wait for human

**NO MERGE WITHOUT FULL TEST SUITE PASS.**

### Session Handoff

When stopping mid-work: append `## Lessons Learned` to plan — what worked,
what didn't, what to try next.
