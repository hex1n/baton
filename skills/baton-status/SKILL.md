---
name: baton-status
description: >
  Report the current task state, owner, next recommended action, and repair
  round. Trigger when the user asks "what's the status", "where are we",
  "what's next", or "show harness status". Readable at any point in a task.
user-invocable: true
---

# Harness Status

## Response Language Policy

When reporting status to the user:

1. If `.harness/profile.local.yaml` sets `documentation.artifact_language` to
   `zh` or `en`, prefer that language for the response.
2. If it is `auto`, follow the current user request language.
3. If the setting is missing, default to Chinese.

Do not localize `module-status.md`. Keep the control-plane file, owner tokens,
state tokens, and blocker categories in stable English.

## Execution Steps

1. Check that `.harness/module-status.md` exists. If not, prompt the user
   to run `init-harness` first and stop.

2. Read `.harness/module-status.md`.
   Treat the **last task row in the table** as the current task row.

3. Report:
   - **Task ID** and description (from the current task row)
   - **Current state** and **owner** (from the current task row)
   - **Next action** — derived from the state machine below
   - **Eval round** — read the `Eval Round` column from the current task row.
     If state is `reviewing`, `generating` (repair), or `blocked` from evaluator,
     show `round N / 3`. If N ≥ 3, flag for human escalation.
   - **Blockers** — if state is `blocked`, show the blocker category and
     what is needed to unblock
   - If state is `ready_for_human_close` or `complete`, also show:
     - verifier isolation mode / execution context
     - evaluator isolation mode / execution context
     - evaluator verdict

## State → Next Action Mapping

| State | Next Action |
|-------|-------------|
| `exploring` | Run `/baton-explorer` to produce `scoped-map.md` |
| `specifying` | Run `/baton-specifier` to produce `requirements.md` |
| `architecting` | Run `/baton-architect` to produce `architecture.md` |
| `awaiting_human_arch` | Human reviews and approves `architecture.md` |
| `verification_check` | Run `/baton-verifier` to produce `verification-path.md` with isolation mode and execution context |
| `generating` | Run `/baton-generator` to implement the changes |
| `reviewing` | Run `/baton-evaluator` to produce `evaluation.md` and evaluate the implementation |
| `ready_for_human_close` | Human reviews `evaluation.md`, residual risks, and confirms task complete |
| `complete` | Task closed — run `/baton-retrospective` if not yet done |
| `blocked` | See blocker details; route to exit per blocked-exit table |

## Blocked Exit Table

| Blocker Category | Exit State | Next Owner |
|-----------------|-----------|-----------|
| `verification_blocker` | `verification_check` | verification-explorer |
| `design_blocker` (architecture wrong) | `architecting` | architect |
| `design_blocker` (requirements ambiguous) | `architecting` + specifier | architect + human |
| `environment_blocker` | `generating` (after fix) | generator |
| 3 repair rounds exhausted | human decision | human |
