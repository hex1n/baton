---
name: harness-status
description: >
  Report the current task state, owner, next recommended action, and repair
  round. Trigger when the user asks "what's the status", "where are we",
  "what's next", or "show harness status". Readable at any point in a task.
user-invocable: true
---

# Harness Status

## Execution Steps

1. Check that `.harness/module-status.md` exists. If not, prompt the user
   to run `init-harness` first and stop.

2. Read `.harness/module-status.md`.

3. Report:
   - **Task ID** and description (from the task row)
   - **Current state** and **owner**
   - **Next action** — derived from the state machine below
   - **Eval round** — if in the repair loop, show `round N / 3`
   - **Blockers** — if state is `blocked`, show the blocker category and
     what is needed to unblock

## State → Next Action Mapping

| State | Next Action |
|-------|-------------|
| `exploring` | Run `/harness-explorer` to produce `scoped-map.md` |
| `specifying` | Run `/harness-specifier` to produce `requirements.md` |
| `architecting` | Run `/harness-architect` to produce `architecture.md` |
| `awaiting_human_arch` | Human reviews and approves `architecture.md` |
| `verification_check` | Run `/harness-verifier` to produce `verification-path.md` |
| `generating` | Run `/harness-generator` to implement the changes |
| `reviewing` | Run `/harness-evaluator` to evaluate the implementation |
| `ready_for_human_close` | Human reviews findings and confirms task complete |
| `complete` | Task closed — run `/harness-retrospective` if not yet done |
| `blocked` | See blocker details; route to exit per blocked-exit table |

## Blocked Exit Table

| Blocker Category | Exit State | Next Owner |
|-----------------|-----------|-----------|
| `verification_blocker` | `verification_check` | verifier |
| `design_blocker` (architecture wrong) | `architecting` | architect |
| `design_blocker` (requirements ambiguous) | `architecting` + specifier | architect + human |
| `environment_blocker` | `generating` (after fix) | generator |
| 3 repair rounds exhausted | human decision | human |
