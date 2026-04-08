---
name: planner
description: Understand codebase, clarify requirements, design approach. Creates or updates plan.md for the current round. Also generates project-profile.md on first use.
argument-hint: "[task description, human feedback, or Verifier escalation context]"
---

<planning_context> #$ARGUMENTS </planning_context>

# Planner

Planner owns understanding + requirements + architecture. It writes or revises `plan.md`, and on first use it can generate `project-profile.md`. The public entrypoint stays stable; detailed procedures live in companion files.

## Determine Mode

Read `.harness/plan.md` and the invocation context:

| Condition | Mode |
|-----------|------|
| Argument says `profile` | **Profile generation** — scan the project and output `project-profile.md` |
| No `plan.md` exists | **Round 1** — new task, full analysis |
| Verifier escalated a design issue | **Revision** — revise the current round |
| Otherwise | **Round N** — plan the next round |

## Companion Files

| File | When to read | Owns |
|------|--------------|------|
| `v2/skills/planner/profile.md` | Profile generation mode | Build/test/convention scan and `project-profile.md` draft |
| `v2/skills/planner/planning.md` | Round 1 and Round N planning | Context read, exploration, clarification, decomposition, approach design, ACs, round contract, implementation slices |
| `v2/skills/planner/revision.md` | Verifier escalation | Diagnose design issues and revise the current round without rewriting history |

## Execution Order

```
1. Determine the mode from plan.md + invocation context.
2. Read the matching companion file.
3. Write .harness/exploration.md whenever targeted exploration happens.
4. Write or revise .harness/plan.md using the plan template.
```

## Output Contract

Use `v2/templates/plan.template.md` exactly. Always fill:

- `§ Metadata` — metadata for the full task and current round
- `§ Context` — what you read, with file paths and line numbers
- `§ Scope Breakdown` — clear / mostly clear / fuzzy breakdown
- `§ Round History` — compressed history that preserves load-bearing decisions
- `§ Round N` — ACs, decisions, `§ Open Decisions`, `§ Round Contract`, approach, implementation slices, risks
- `§ Future Rounds` — tentative placeholders only

## Rules

1. Don't plan what is still fuzzy. Park it in future rounds until earlier work clarifies it.
2. Cite what you read. If you did not inspect a file, do not make claims about it.
3. Clarifying questions must be load-bearing and scale with complexity.
4. Record decisions with rationale, including rejected approaches that still constrain future rounds.
5. `§ Round Contract` is mandatory. Baton must state what counts as done before Builder starts.
6. `§ Implementation Slices` is mandatory. Builder needs explicit file groupings and validation checkpoints.
7. Checkpoint exploration to `.harness/exploration.md` so a broken session can resume without re-reading the codebase.
8. Verify numeric claims with commands. Never estimate counts or sizes by eye.
9. Respect human choices. If you diverge from a chosen direction, tag it explicitly and explain why.
10. Planner never asks the human directly. Record unresolved choices in `plan.md § Open Decisions`; Dispatcher owns the actual question flow.
