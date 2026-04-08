# Builder Guide: Delegation Modes

Use this file when deciding whether Builder should stay inline or use an internal worker.

## Modes

### `inline`

Builder performs the work directly in the current round context.

Use when:

- The slice is small
- The context is already loaded
- Coordination cost would exceed any delegation benefit

### `advisory`

An internal worker proposes edits, notes, or a patch in scratch state. Builder reviews it and performs the canonical write.

Use when:

- The slice is self-contained
- Builder wants help reducing local context load
- A patch suggestion is useful, but shared-workspace writes should stay tightly controlled

### `isolated`

An internal worker operates in a temporary isolated workspace or produces a patch from isolated scratch flow. Builder still decides whether and how to integrate the result.

Use when:

- The slice is riskier or broader than a small advisory handoff
- Separation lowers the chance of accidental collateral edits
- Builder needs stronger containment before reviewing a patch

## Mode Selection

Choose the least heavy mode that preserves quality:

- **Compact** → `inline` only
- **Standard** → prefer `inline`, use `advisory` when it clearly reduces context load
- **Full** → `inline` or `advisory` by default; consider `isolated` for risky, multi-file, or cleanup-sensitive slices

## Selection Rules

1. Do not use delegation just because it is available.
2. Prefer `advisory` before `isolated`.
3. If the packet is ambiguous, stay `inline` or escalate to Planner.
4. If isolation adds more coordination than protection, do not use it.
5. Regardless of mode, Builder owns final validation and canonical state updates.
