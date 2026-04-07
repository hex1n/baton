# Baton v2

This project uses the baton v2 harness for AI-assisted development tasks.

## Protocol

Read `v2/protocol.md` for the full protocol: roles, artifacts, round lifecycle, feedback paths, and rules.

## Skills

| Skill | Purpose |
|-------|---------|
| `/dispatch` | Entry point. Detects state, routes to the right role. |
| `/planner` | Understands codebase, clarifies requirements, designs approach → `brief.md` |
| `/builder` | Implements code + tests in batches → source code, tests |
| `/verifier` | Pre-flight (challenge plan) + Verification (check implementation) → `eval.md` |

Skills live in `v2/skills/{name}/SKILL.md`.

## Artifacts

| Artifact | Location | Owner | Lifecycle |
|----------|----------|-------|-----------|
| `project-profile.md` | project root | Human (Planner generates draft) | Persistent across tasks |
| `brief.md` | `.harness/` | Planner + Builder (§ Discoveries) | Per task, archived on completion |
| `eval.md` | `.harness/` | Verifier | Per round, overwritten |

## Quick Start

1. `/dispatch` — starts a new task or resumes an existing one
2. First time? Dispatch invokes Planner to generate `project-profile.md`
3. Describe your task → Planner creates `brief.md` Round 1
4. Verifier pre-flight → you approve → Builder implements → Verifier verifies
5. Repeat rounds until done

## Templates

- `v2/templates/project-profile.template.md` — structure for project profile
- `v2/templates/brief.template.md` — structure for task brief

## Core Rules

1. `brief.md` is the single source of truth for what's being built
2. Verifier never reads Builder's source code during verification (Mode A/B; see protocol.md § Independence Rule)
3. Human approval required before Builder starts each round
4. Max 3 Builder-Verifier iterations per round before escalation
5. Each role starts with fresh context; files carry state, not conversation
6. Round scope lock: after approval, ACs are frozen; new requirements go to next round
