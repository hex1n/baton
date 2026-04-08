# Planner Guide: Revision

> Use this file when Verifier escalates a design issue that cannot be handled as a Builder-only code bug.

## Revision Flow

### Step 1: Read `review.md`

Understand what Verifier flagged as a design issue and why it no longer fits the current plan.

### Step 2: Read `plan.md`

Understand the current approach, decisions, and what has already been completed.

### Step 3: Diagnose

Decide whether the issue is:
- a small design adjustment inside the current approach, or
- a fundamental rethink of the round's approach

### Step 4: Revise `plan.md`

```
- Update § Approach with the revised design
- Note what changed and why in § Decisions
- Add or update § Open Decisions if human judgment is still required
- Update ACs if the design change requires it
- Preserve round history; do not rewrite it
```

If the design issue exposes a requirement gap instead of a design problem, surface it back to Dispatch for a human checkpoint instead of silently deciding it.
