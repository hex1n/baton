# Baton

This repository uses Baton v2 for AI-assisted development tasks.

## Before Changing Core

Read `v2/protocol.md` for the full protocol and `CONTRIBUTING.md` for repository-layer boundaries and validation expectations.

## Repository Layers

| Layer | Location | Purpose |
|-------|----------|---------|
| Core | `v2/` | Baton protocol, public role entrypoints, templates, validators |
| Companion | `skills/` | Optional supporting skills outside the core loop |
| External adapters / plugins | wrappers in `v2/tools/` or separate repos/plugins | Host/provider-specific integrations |

## Skills

| Skill | Purpose |
|-------|---------|
| `/dispatch` | Entry point. Detects state, routes to the right role. |
| `/planner` | Understands codebase, clarifies requirements, designs approach → `plan.md` |
| `/builder` | Implements code + tests in batches → source code, tests; optional internal worker delegation stays behind Builder |
| `/verifier` | Pre-flight (challenge plan) + Verification (check implementation) → `review.md` |

Skills live in `v2/skills/{name}/SKILL.md`.
Public skill entrypoints are thin; detailed procedures live in sibling role files under each role directory.
Optional companion bootstrap lives at `skills/using-baton/SKILL.md`. It reinforces `/dispatch` entry and validator discipline; it does not add a separate workflow.

## Artifacts

| Artifact | Location | Owner | Lifecycle |
|----------|----------|-------|-----------|
| `project-profile.md` | project root | Human (Planner generates draft) | Persistent across tasks |
| `plan.md` | `.harness/` | Planner + Builder (§ Discoveries) | Per task, archived on completion; carries `§ Open Decisions` |
| `review.md` | `.harness/` | Verifier | Per round, overwritten; carries `§ Routing Signals` |
| `.context/baton/active/` | `.context/` | Builder / Verifier scratch helpers | Non-canonical scratch only; includes findings sidecars and optional batch delegation state |

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
- `v2/templates/batch-packet.template.md` — structure for one delegated Builder slice
- `v2/templates/worker-report.template.md` — human-readable worker report
- `v2/templates/worker-report.template.json` — machine-readable worker report

## Core Rules

1. `plan.md` is the single source of truth for what's being built
2. Builder is the only public role that modifies source code or tests; internal workers stay behind Builder
3. Verifier never reads Builder's source code during verification (Mode A/B; see protocol.md § Independence Rule)
4. Human approval required before Builder starts each round
5. Each role starts with fresh context; files carry state, not conversation
6. Companion skills are optional; Baton core cannot depend on them
