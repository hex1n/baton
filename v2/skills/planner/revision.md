# Planner Guide: Revision

> Use this file when Verifier escalates a design issue that cannot be handled as a Builder-only code bug.

## Revision Flow

### Step 1: Read `review.md`

Understand what Verifier flagged as a design issue and why it no longer fits the current plan.

### Step 2: Read `plan.md`

Understand the current approach, decisions, and what has already been completed.

### Step 2b: Read `design.md`

Treat `.harness/design.md` as the primary planning narrative. If `design.md` and `plan.md` disagree, revise `design.md` first and then re-project the affected control-plane fields into `plan.md`.

### Step 3: Diagnose

Decide whether the issue is:
- a small design adjustment inside the current approach, or
- a fundamental rethink of the round's approach

### Step 4: Revise `plan.md`

```
- Revise .harness/design.md first when the design issue changes the reasoning, alternatives, or implementation structure
- Update § Approach with the revised design
- Note what changed and why in § Decisions
- Add or update § Open Decisions if human judgment is still required
- Update `Scope Class`, `Risk Class`, or round forecasts if the revision changes the round shape
- Update `§ Round Contract → Key Entry Points` if the revision changes which entry points must remain in scope
- Update ACs if the design change requires it
- Preserve round history; do not rewrite it
```

If the design issue exposes a requirement gap instead of a design problem, surface it back to Dispatcher for a human checkpoint instead of silently deciding it.

If Dispatcher or Verifier asks for a deepen pass, keep the task and AC direction stable unless the deeper search proves the framing itself is wrong. In that case, update `§ Plan Quality`, then revise the affected approach / ACs explicitly instead of silently swapping plans.

If Verifier flags confidence-calibration drift, refresh `§ Plan Quality → Recommendation Confidence` and `Confidence Basis` explicitly instead of leaving the old claim in place.

After revising the design, re-run the projection so `.harness/plan.md` stays aligned with `.harness/design.md`.

If the revision changes the task from "design/change" work to "bug/root-cause" work or vice versa, re-run `engine-selection.md` and switch planning engines explicitly instead of silently continuing on the wrong path.
