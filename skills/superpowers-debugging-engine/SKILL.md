---
name: superpowers-debugging-engine
description: >
  Companion adapter for using systematic-debugging as Baton's default planner
  engine for bug, incident, and regression rounds. Produces `.harness/design.md`
  as the debugging narrative and fix plan before the Baton planner projects the
  control plane into `.harness/plan.md`.
user-invocable: true
allowed-tools: Read Grep Glob Bash Write
---

# Superpowers Debugging Engine

This is a Baton companion adapter. It is not a new public Baton role.

Use it when Baton's Planner is handling:

- bug fixes
- regressions
- incidents
- failure investigation rounds

## Workflow

1. Prove the failure mode or reproduce the observed breakage when possible
2. Narrow the root cause before proposing the fix
3. Write `.harness/design.md` with:
   - the problem
   - evidence or reproduction notes
   - root-cause hypothesis
   - rejected hypotheses if they matter
   - recommended fix path
   - implementation slices
   - risks and self-check
4. Hand off to Baton's Planner projection guide:
   - `v2/skills/planner/project-from-design.md`

## Minimum Baton-Compatible Sections

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
- `Compatibility / Caller Impact`
- `Rollout / Rollback`

## Guardrails

- Root cause comes before fix path
- Do not skip projection into `.harness/plan.md`
- Do not let debugging notes replace Baton control-plane fields
- Do not bypass Verifier pre-flight
