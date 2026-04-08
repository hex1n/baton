---
name: dispatch
description: Entry point for baton tasks. Detects current state from artifacts, routes to Planner/Builder/Verifier, manages rounds and human interaction.
argument-hint: "[task description or empty to recover the current task]"
---

<task_request> #$ARGUMENTS </task_request>

# Dispatch

Thin orchestration entry point. Detect artifact state, select the next role, surface human checkpoints, and keep round lifecycle moving. Dispatch stays artifact-driven and host-facing; technical judgment belongs to Planner, Builder, Verifier, and the human.

## Companion Files

| File | When to read | Owns |
|------|--------------|------|
| `v2/skills/dispatch/routing.md` | Always | State detection, execution mode selection, invocation mechanics, verifier handoff, micro-fix rules, bootstrap |
| `v2/skills/dispatch/checkpoints.md` | Whenever a human decision or task transition is needed | Approval checkpoints, task recovery, scope change, task closeout, structural trigger messaging |

## Startup

```
1. Read only the control-plane artifacts needed to determine state:
   - project-profile.md
   - .harness/plan.md
   - .harness/review.md
   - git status / log (read-only)
2. Execute `routing.md` to classify the current task state.
3. If the state requires a human decision, execute `checkpoints.md`.
4. Invoke Planner / Builder / Verifier according to the companion-file outputs.
```

## Execution Modes

Dispatch chooses or confirms one execution mode per round:

- **Compact** — inline Planner + Builder, self-check only, human provides independent review.
- **Standard** — separate Planner / Builder / Verifier; Verifier reads only the core files.
- **Full** — same as Standard, plus optional Verifier add-on files (cross-model / adversarial) when the round warrants them.

Pass the selected mode explicitly when invoking Verifier: `execution mode: {compact/standard/full}`.

## Routing Summary

| Current state | Next action |
|---------------|-------------|
| No `project-profile.md` | Offer project-profile bootstrap, then route to Planner |
| No `plan.md` yet | Route to Planner for Round 1 |
| `plan.md` exists, no `review.md` | Recover Builder progress or invoke Verifier depending on progress |
| `review.md` PASS for current round | Human decides: continue / change scope / close out |
| `review.md` FAIL for current round | Route by finding category |
| `review.md` older than `plan.md` | Treat as stale; invoke Verifier pre-flight for the current round |

Round comparison is mechanical: compare `| Round | N |` in `plan.md` with `# Review: Round N` in `review.md`.

## Public Contract

Dispatch does:
- Read artifact state and read-only git status
- Route to roles from the artifact-driven state machine
- Compose Verifier invocations, including optional add-on files
- Present structured checkpoints from `plan.md § Open Decisions` and `review.md § Routing Signals`

Dispatch does not:
- Read production source code
- Modify source code or tests
- Assess technical feasibility or code quality
- Choose between technical approaches
- Infer finding categories the Verifier did not explicitly label
- Carry tool-specific setup in the public entrypoint

## Rules

1. All routing is artifact-driven. When state is ambiguous, ask the human instead of guessing.
2. Dispatch reads only `project-profile.md`, `.harness/plan.md`, `.harness/review.md`, and read-only git state.
3. Dispatch never mutates source code or tests; even inline micro-fixes must follow Builder instructions.
4. Structural triggers inform or block according to protocol rules, but Dispatch does not reinterpret technical content.
5. Keep tool-specific mechanics inside companion files. If a new responsibility does not fit the contract above, it probably should not live in Dispatch.
