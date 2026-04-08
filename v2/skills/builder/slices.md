# Builder Guide: Slice Packets

Use this file when Builder delegates one approved implementation slice or fix slice to an internal worker.

## Purpose

A slice packet narrows the worker's scope so the worker does not need to infer intent from the whole round. The packet is scratch state, not canonical state.

Write packets under:

```text
.context/baton/active/slices/round-{N}/slice-{M}/packet.md
```

Start from:

```text
v2/templates/slice-packet.template.md
```

The normal helper is:

```text
bash v2/tools/builder-slice.sh init-slice --round {N} --slice {M} --mode {advisory|isolated}
```

## When to Create a Packet

Create a packet only when all of these are true:

- The scope is already approved in `plan.md`
- The work fits one implementation slice or one fix slice
- The worker can stay inside a small, explicit file set
- Delegation reduces context load more than it adds coordination overhead

Do not create a packet when:

- The round is in Compact mode
- The work is tightly coupled across many moving pieces
- The plan is still ambiguous
- The right next step is design escalation, not implementation

## Packet Content

Each packet should contain:

- `Objective` — one sentence describing the slice being implemented
- `Scope Slice` — exact ACs or Verifier findings this packet covers
- `Allowed Files` — explicit file paths the worker may touch
- `Forbidden Actions` — especially: no `.harness/*`, no human questions, no external review
- `Acceptance Checks` — the observable outcomes that must be true for this slice
- `Test Commands` — exact commands from `project-profile.md`
- `Context Snippets` — only the source excerpts or notes the worker actually needs
- `Start SHA` — current baseline before the slice starts
- `Delegation Mode` — `advisory` or `isolated`

## Construction Rules

1. **Copy, do not reinterpret.** Pull ACs and constraints from `plan.md` exactly.
2. **Narrow the slice.** A packet should reduce the worker's search space, not restate the whole round.
3. **Declare file boundaries.** If Builder already knows the touched files, list them.
4. **Keep context minimal.** Include only the snippets or notes needed for this slice.
5. **Record the trigger.** If the packet is for Verifier feedback, say which finding(s) it addresses.
6. **Use the template directly.** Fill `v2/templates/slice-packet.template.md` instead of inventing ad-hoc headings.

## Packet Rules

1. The packet is a Builder aid, not a control-plane artifact.
2. If a worker needs information the packet does not provide, it should return `needs_context` instead of guessing.
3. If the slice turns out to require broader design changes, stop and escalate through Builder.
4. Packet contents may summarize `plan.md`, but `plan.md` remains the source of truth.
