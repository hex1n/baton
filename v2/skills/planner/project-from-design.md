# Planner Guide: Project `plan.md` from `design.md`

> Use this file after drafting or revising `.harness/design.md`. `design.md` is the primary planning narrative; `plan.md` is the Baton control-plane projection.

## Input Contract

Read:

```text
- .harness/design.md
- .harness/plan.md (if this is not Round 1)
- project-profile.md
```

`design.md` may use the planning engine's native structure. Baton only requires that these semantic blocks are recognizable:

- `Problem` / `Problem Definition`
- `Goals`
- `Non-goals` / `Out of Scope`
- `Recommended Approach` / `Recommendation`
- `Implementation Plan` / `Implementation Slices`
- `Risks`
- `Self-Check` / `Failure Modes`

Conditionally required when applicable:

- `Alternatives`
- `Need Confirmation` / `Open Questions`
- `Semantic Invariants`
- `Compatibility / Caller Impact`
- `Rollout / Rollback`
- `Data / API / Schema Changes`

## Projection Rules

Project only the control-plane subset into `.harness/plan.md`. Do not paste the full design narrative into the plan.

### 1. `§ Plan Quality`

Project:

- `Problem` -> `Problem Statement`
- design assumptions / invariants / compatibility concerns -> `Load-Bearing Assumptions`
- true constraints vs inherited conventions -> `Constraints vs Conventions`
- `Alternatives` or single-path justification -> `Alternatives Considered`
- `Self-Check` / `Failure Modes` -> `Failure Mode`
- your chosen confidence call -> `Recommendation Confidence`
- why that confidence is justified -> `Confidence Basis`

### 2. `§ Open Decisions`

Project:

- `Need Confirmation` / `Open Questions` that require human input

Rules:

- only load-bearing human choices belong here
- each open decision must become one row with `Status` and `Blocking`
- if design says no human choice remains, record a resolved `None.` row

### 3. `§ Round Contract`

Project:

- `Goals` + `Recommended Approach` -> `Scope In`
- `Non-goals` / explicit deferrals -> `Scope Out`
- load-bearing entry points named in the design -> `Key Entry Points`
- observable design outcome -> `Done Criteria`
- how Verifier should prove the outcome -> `Verification Plan`
- any rollout safety or overload rationale -> `Budget Note`
- completion threshold -> `Exit Threshold`
- deferred follow-up items -> `Deferred Items`

### 4. `§ Implementation Slices`

Project:

- `Implementation Plan` / `Implementation Slices`

Rules:

- keep file groupings explicit
- keep checks explicit
- slice descriptions should match the approved round scope, not the whole design

### 5. `§ Risks`

Project:

- design risks
- rollout / rollback concerns
- compatibility hazards that Builder or Verifier must watch

## Guardrails

1. `plan.md` stays concise. It is a Baton control-plane document, not a second design document.
2. If a design detail matters for routing, approval, or Builder execution, it must be projected into `plan.md`.
3. If `design.md` and `plan.md` disagree, fix `design.md` first, then re-project `plan.md`.
4. Dispatcher never routes from `design.md`, so missing projection is a protocol bug.
