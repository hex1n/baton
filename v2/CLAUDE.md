# Baton v2

This project uses the baton v2 harness for AI-assisted development tasks.

## Protocol

Read `v2/protocol.md` for the full protocol: roles, artifacts, round lifecycle, feedback paths, and rules.
Read `CONTRIBUTING.md` before changing core behavior.

## Repository Layers

| Layer | Location | Purpose |
|-------|----------|---------|
| Core | `v2/` | Baton protocol, public role entrypoints, templates, validators |
| Companion | `skills/` | Optional supporting skills outside the core Baton loop |
| External adapters / plugins | wrappers in `v2/tools/` or separate repos/plugins | Host/provider-specific integrations |

## Skills

| Skill | Purpose |
|-------|---------|
| `/dispatch` | Entry point. Detects state, routes to the right role. |
| `/planner` | Understands codebase, clarifies requirements, designs approach → `design.md` + `plan.md` |
| `/builder` | Implements code + tests in slices → source code, tests; optional internal worker delegation stays behind Builder |
| `/verifier` | Pre-flight (challenge plan) + Verification (check implementation) → `review.md` |

Skills live in `v2/skills/{name}/SKILL.md`.
Public skill entrypoints are thin; detailed procedures live in sibling role files under each role directory.
Optional companion bootstrap lives at `skills/using-baton/SKILL.md`. It keeps `/dispatch` as the default entry point and preserves the artifact-first control plane.

## Artifacts

| Artifact | Location | Owner | Lifecycle |
|----------|----------|-------|-----------|
| `project-profile.md` | project root | Human (Planner generates draft) | Persistent across tasks |
| `design.md` | `.harness/` | Planner | Per task, archived on completion; primary human-readable planning artifact with a minimum Baton-compatible section contract |
| `plan.md` | `.harness/` | Planner + Builder (§ Discoveries) | Per task, archived on completion; Baton control-plane projection of `design.md`, carrying round classification, forecasts, `§ Plan Quality`, `§ Open Decisions`, `§ Round Contract`, and `§ Implementation Slices` for Dispatcher |
| `review.md` | `.harness/` | Verifier | Per round, overwritten; carries `§ Routing Signals`, design-review add-on selection, pre-flight triage, verify-pass add-on selection, plan-quality assessment, confidence calibration, and round-load assessment for Dispatcher |
| `.context/baton/active/` | `.context/` | Builder / Verifier scratch helpers | Non-canonical scratch only; includes findings sidecars and optional slice delegation state |

## Task Classification

- `Scope Class` / `Risk Class` classify the current round in `plan.md § Metadata`.
- `Expected Rounds` / `Expected Slices This Round` are forecasts; they can still feed the round-load guard.
- `Verifier Mode` captures evidence capability.
- `Execution Mode` is the orchestration choice Dispatcher confirms from the classification.
- Complex rounds may set `Planning Depth = deepen` in `plan.md § Plan Quality`, which lets Dispatcher route a deepen pass before Builder starts.
- Every round should declare `Recommendation Confidence`; Verifier records whether that confidence is calibrated before Builder starts.
- Planner default engine policy: feature/design/change rounds use `brainstorming + writing-plans`; bug/incident/regression rounds use `systematic-debugging`.
- In `full` mode, Verifier pre-flight may run design-stage review add-ons before human approval; `review.md § Routing Signals` records whether Baton should auto-revise or stop for a human checkpoint.

## Quick Start

1. `/dispatch` — starts a new task or recovers an existing one
2. First time? Dispatcher invokes Planner to generate `project-profile.md`
3. Describe your task → Planner creates `design.md`, then projects `plan.md` Round 1
4. Verifier pre-flight → you approve → Builder implements → Verifier verifies
5. Repeat rounds until closeout

## Templates

- `v2/templates/project-profile.template.md` — structure for project profile
- `v2/templates/plan.template.md` — structure for the task plan
- `v2/templates/review.template.md` — structure for per-round review output
- `v2/templates/slice-packet.template.md` — structure for one delegated Builder slice
- `v2/templates/worker-report.template.md` — human-readable worker report
- `v2/templates/worker-report.template.json` — machine-readable worker report

## Core Rules

1. `plan.md` is the single source of truth for Baton execution and routing in the active task
2. Verifier never reads Builder's source code during verification (Mode A/B; see protocol.md § Independence Rule)
3. Human approval required before Builder starts each round
4. Max 3 Builder-Verifier iterations per round before escalation
5. Each role starts with fresh context; files carry state, not conversation
6. Round scope lock: after approval, ACs are frozen; new requirements go to next round
7. Companion skills remain optional; Baton core cannot require them
