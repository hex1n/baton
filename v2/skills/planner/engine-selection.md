# Planner Guide: Engine Selection

> Use this file at the start of every planning round, before drafting `.harness/design.md`.

## Goal

Choose the planning engine that should produce the round's `design.md`.

Baton keeps the public `planner` role stable, but the internal planning engine is task-shaped:

- feature / design / change / migration work -> Superpowers planning engine
- bug / incident / regression work -> Superpowers debugging engine

## Engine Mapping

### 1. Feature / design / change / migration rounds

Default engine:

```text
brainstorming -> writing-plans
```

What this means:

- clarify the real problem, not just the requested solution
- surface meaningful alternatives when they exist
- write a detailed human-readable design into `.harness/design.md`
- only then project the Baton control-plane subset into `.harness/plan.md`

Use this path by default for:

- new features
- protocol / architecture changes
- migrations or replace flows
- multi-module refactors
- scoped design tasks

### 2. Bug / incident / regression rounds

Default engine:

```text
systematic-debugging
```

What this means:

- prove the failure mode first
- isolate root cause before proposing the fix
- write the debugging narrative and chosen fix path into `.harness/design.md`
- then project the approved control-plane subset into `.harness/plan.md`

Use this path by default for:

- bug fixes
- incidents
- regressions
- "why is this broken?" tasks

## Companion Boundary

The engine policy is part of Baton core. The actual Superpowers adapter skills live in root `skills/` as optional companions.

Rules:

1. If the companion adapters are available, use them as the default engine entrypoints.
2. If the companion adapters are unavailable, Planner must still emulate the same workflow and output contract.
3. Baton core must never require a host-specific plugin or installation detail in order to keep working.
4. Record any fallback in `.harness/design.md` so humans can see whether the round used the intended engine or a Baton-native fallback.

## Human Override

If the human explicitly asks for a different planning engine:

- follow that direction
- keep `design.md` / `plan.md` contracts unchanged
- note the override in `plan.md § Decisions` if it materially changes planning depth or search quality
