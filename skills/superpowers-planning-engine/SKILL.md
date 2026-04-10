---
name: superpowers-planning-engine
description: >
  Companion adapter for using Superpowers-style planning as Baton's default
  planning engine for feature, design, change, refactor, and migration rounds.
  Runs the semantics of brainstorming first, then writing-plans, and produces
  `.harness/design.md` for the Baton planner to project into `.harness/plan.md`.
user-invocable: true
allowed-tools: Read Grep Glob Bash Write
---

# Superpowers Planning Engine

This is a Baton companion adapter. It is not a new public Baton role.

Use it when Baton's Planner needs the default feature/design planning path:

```text
brainstorming -> writing-plans -> design.md -> plan.md projection
```

## What It Must Produce

Write `.harness/design.md` with a structure that is natural for the planning engine, but preserves Baton's minimum compatible sections:

- `Problem`
- `Goals`
- `Non-goals`
- `Recommended Approach`
- `Implementation Plan` or `Implementation Slices`
- `Risks`
- `Self-Check`

Add these when applicable:

- `Alternatives`
- `Need Confirmation`
- `Semantic Invariants`
- `Compatibility / Caller Impact`
- `Rollout / Rollback`
- `Data / API / Schema Changes`

## Workflow

1. Start with brainstorming semantics:
   - clarify the real problem
   - separate solution from problem
   - surface hidden decisions
   - compare meaningful alternatives
2. Continue with writing-plans semantics:
   - turn the chosen direction into a detailed design and implementation plan
   - make slices concrete and file-oriented where possible
3. Write `.harness/design.md`
4. Hand off to Baton's Planner projection guide:
   - `v2/skills/planner/project-from-design.md`

## Guardrails

- Do not bypass Baton artifacts
- Do not write directly to `review.md`
- Do not let Dispatcher route from `design.md`
- Do not collapse back to a single-document plan
