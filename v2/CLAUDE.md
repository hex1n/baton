# Baton v2

This project uses the baton v2 harness for AI-assisted development tasks.

## Protocol

Read `v2/protocol.md` for the full protocol: roles, artifacts, round lifecycle, feedback paths, and rules.

## Skills

| Skill | Purpose |
|-------|---------|
| `/dispatch` | Entry point. Detects state, routes to the right role. |
| `/planner` | Understands codebase, clarifies requirements, designs approach → `plan.md` |
| `/builder` | Implements code + tests in batches → source code, tests |
| `/verifier` | Pre-flight (challenge plan) + Verification (check implementation) → `review.md` |

Skills live in `v2/skills/{name}/SKILL.md`.
Public skill entrypoints are thin; detailed procedures live in sibling role files under each role directory.

## Artifacts

| Artifact | Location | Owner | Lifecycle |
|----------|----------|-------|-----------|
| `project-profile.md` | project root | Human (Planner generates draft) | Persistent across tasks |
| `plan.md` | `.harness/` | Planner + Builder (§ Discoveries) | Per task, archived on completion; carries `§ Open Decisions` for Dispatcher |
| `review.md` | `.harness/` | Verifier | Per round, overwritten; carries `§ Routing Signals` for Dispatcher |

## Quick Start

1. `/dispatch` — starts a new task or recovers an existing one
2. First time? Dispatcher invokes Planner to generate `project-profile.md`
3. Describe your task → Planner creates `plan.md` Round 1
4. Verifier pre-flight → you approve → Builder implements → Verifier verifies
5. Repeat rounds until closeout

## Templates

- `v2/templates/project-profile.template.md` — structure for project profile
- `v2/templates/plan.template.md` — structure for the task plan
- `v2/templates/review.template.md` — structure for per-round review output

## Core Rules

1. `plan.md` is the single source of truth for what's being built
2. Verifier never reads Builder's source code during verification (Mode A/B; see protocol.md § Independence Rule)
3. Human approval required before Builder starts each round
4. Max 3 Builder-Verifier iterations per round before escalation
5. Each role starts with fresh context; files carry state, not conversation
6. Round scope lock: after approval, ACs are frozen; new requirements go to next round
