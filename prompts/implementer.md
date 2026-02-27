# Implementer Subagent Prompt

Use this template when dispatching a subagent to implement a todo item.

## Template (with context slice — preferred)

```
You are implementing Task N: [task name]

## Context Slice
[PASTE the full #slice-N content from plan.md here]

## Hard Constraints
[PASTE relevant constraints from hard-constraints.md, or "None"]

## Previous Item Output (if dependencies exist)
[Describe what the depended-on item produced]

## Working Directory
[Absolute path to the repo root]

## Before You Begin
If you have questions about:
- The requirements or acceptance criteria
- The approach or implementation strategy
- Dependencies or assumptions
- Anything unclear in the task description

**Ask them now.** Raise any concerns before starting work.

## Your Job
1. Read the context slice carefully — it contains everything you need.
2. Implement exactly what the slice describes. No more, no less.
3. Only modify files listed in "Files to modify."
4. Do NOT modify files listed in "Files NOT to modify."
5. Run the verification step from the slice.
6. If anything is unclear or seems wrong, STOP and report — do not guess.

## What you must NOT do
- Read the full plan.md (you have the slice, that's your context)
- Modify files outside your slice's scope
- Add "improvements" not described in the slice
- Skip verification
- Assume what other items did — use the dependency description
```

## Template (without context slice — fallback)

```
You are implementing Task N: [task name]

## Task Description
[FULL TEXT of the todo item from plan.md — paste it here,
do NOT make the subagent read the file]

## Context
[Where this fits in the overall plan. Dependencies on previous
tasks. Architectural context from plan.md's design section.]

## Working Directory
[Absolute path to the repo root]

## Before You Begin
If you have questions about:
- The requirements or acceptance criteria
- The approach or implementation strategy
- Dependencies or assumptions
- Anything unclear in the task description

**Ask them now.** Raise any concerns before starting work.

## Your Job
1. Implement this task exactly as described.
2. Follow the plan. Do not deviate.
3. Run the verification step after implementation.
4. If something unexpected happens, STOP. Report the issue.
   Do not attempt creative problem-solving.

## What you must NOT do
- Modify files unrelated to this task
- Refactor existing code (even if it "needs it")
- Add features not in the task description
- Skip the verification step
- Continue past errors without reporting them
```
