# Builder Guide: Internal Workers

Use this file when Builder delegates a packet to an internal worker.

## Worker Contract

Internal workers are part of Builder. They are not Baton roles and do not own canonical state.

Worker inputs:

- One batch packet from `.context/baton/active/batches/.../packet.md`
- The source files or snippets named in the packet
- The exact commands Builder chose from `project-profile.md`

Worker outputs belong under the same batch scratch directory, for example:

```text
.context/baton/active/batches/round-{N}/batch-{M}/report.md
.context/baton/active/batches/round-{N}/batch-{M}/report.json
.context/baton/active/batches/round-{N}/batch-{M}/patch.diff
```

Start reports from:

```text
v2/templates/worker-report.template.json
v2/templates/worker-report.template.md
```

The normal helpers are:

```text
bash v2/tools/builder-worker.sh run-worker --round {N} --batch {M} --worker-label {name}
bash v2/tools/builder-worker.sh collect-report --round {N} --batch {M} --status {status} --summary "{summary}"
bash v2/tools/builder-worker.sh show-status --round {N} --batch {M}
```

## Allowed Actions

Workers may:

- Implement the requested slice inside the packet scope
- Run the packet's compile or test commands
- Produce a patch, implementation notes, and test results
- Flag uncertainty or blockers explicitly

Workers may not:

- Update `.harness/plan.md` or `.harness/review.md`
- Ask the human directly
- Invoke Verifier or `external-review.sh`
- Expand the packet scope on their own
- Treat scratch outputs as accepted without Builder review

## Status Contract

Workers report one of four statuses:

- `complete` — requested slice is implemented and validated as far as the packet allows
- `complete_with_concerns` — work is done, but the worker has specific doubts or caveats
- `needs_context` — required context or constraints were missing from the packet
- `blocked` — the worker cannot proceed without a design, environment, or scope change

## Builder Handling

Handle statuses like this:

- `complete`
  Builder reviews the result, re-runs project validation, and applies canonical updates.
- `complete_with_concerns`
  Builder reads the concerns before integrating. If concerns are load-bearing, escalate instead of hand-waving them away.
- `needs_context`
  Builder fixes the packet and re-dispatches. Do not force the worker to guess.
- `blocked`
  Builder decides whether the blocker is missing context, wrong delegation mode, or a real Planner/Human escalation.

## Rules

1. Builder remains responsible for correctness, validation, and canonical writes.
2. Worker reports are evidence for Builder, not truth for Dispatcher.
3. If a worker exposes a discovery that changes the plan, Builder records it in `plan.md § Discoveries`.
4. Never hide uncertainty. `complete_with_concerns` is better than a silent bad merge.
5. Use the report templates directly so Builder can read reports mechanically.
