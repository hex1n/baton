# Baton — Stable Surface

What Baton guarantees, organized by enforcement strength.

## Layer 1 — Hard Gate

Technical block. Hook returns non-zero → operation prevented by the host.

| Capability | Hook | What it does |
|------------|------|--------------|
| GO gate | write-lock.sh | Source writes blocked until `<!-- BATON:GO -->` in plan. Markdown always allowed. |

This is the only capability Baton can technically guarantee. Everything below depends on AI cooperation.

## Layer 2 — Soft Guard

Advisory. Hook always exits 0 but emits guidance to stderr. Guides AI behavior but cannot prevent violations.

| Capability | Hook | What it does |
|------------|------|--------------|
| Phase detection | phase-guide.sh | 6-state machine (RESEARCH → PLAN → ANNOTATION → AWAITING_TODO → IMPLEMENT → ARCHIVE). Routes to skills when available, falls back to hardcoded guidance. |
| Write-set drift warning | post-write-tracker.sh | Warns when modified file basename not mentioned in plan. |
| Todolist gate | phase-guide.sh | Detects AWAITING_TODO state (GO set, no `## Todo`). Reminds to generate todolist before implementing. |
| Retrospective enforcement | completion-check.sh | Soft-blocks task completion until `## Retrospective` exists when all todos are done. |
| Risky bash detection | bash-guard.sh | Warns on file-writing bash patterns (`>>`, `sed -i`, `cp`, `mv`) when plan is locked. |
| Subagent context | subagent-context.sh | Injects plan progress into subagent sessions. |
| Session-end reminders | stop-guard.sh | Reminds about incomplete todos and suggests Lessons Learned on session stop. |
| Pre-compact summary | pre-compact.sh | Outputs progress summary before context compression. |

## Layer 3 — Protocol Discipline

No hook enforcement. Relies on skill Iron Laws + human review.

| Capability | Where defined | What it does |
|------------|---------------|--------------|
| A/B write-set additions | baton-implement skill | Narrowly scoped file additions without replanning. Requires todolist to append to; does not apply when todolist is skipped. |
| 3-failure stop | workflow.md rule 5 | Same approach fails 3× → must stop and report. Same root cause = same chain. |
| C/D discovery stop | workflow.md rule 6 | Scope extension or design change discovered → must stop, update plan, wait for confirmation. |
| Fallback conservatism | workflow.md Enforcement Boundaries | Fallback guidance is intentionally more conservative than skill-guided execution. Without phase-specific skill discipline, stricter defaults are safer. |

## Design Principles

- **Safe-side defaults**: When in doubt, block rather than allow. Write-lock fails open only on unexpected errors (trap handler), not on ambiguous inputs.
- **Layered degradation**: Without skills, soft guards still fire. Without hooks (Codex), only protocol text remains. Each layer lost reduces enforcement but never silently changes rules.
- **Advisory over blocking**: Most hooks are advisory because the host hook model (Claude Code) cannot block PostToolUse events. Only PreToolUse can return non-zero to prevent an action.
