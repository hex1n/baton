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
| Phase detection | phase-guide.sh | 6-state machine (RESEARCH → PLAN → ANNOTATION → AWAITING_TODO → IMPLEMENT → FINISH). Routes to skills when available, falls back to hardcoded guidance. |
| Write-set drift warning | post-write-tracker.sh | Exact path matching against `Files:` fields in `## Todo` items; falls back to basename grep when no structured write set exists. |
| Todolist gate | phase-guide.sh | Detects AWAITING_TODO state (GO set, no `## Todo`). Reminds to generate todolist before implementing. |
| Retrospective enforcement | completion-check.sh | Soft-blocks task completion until `## Retrospective` with ≥3 content lines exists when all todos are done. Multi-plan without BATON_PLAN → fail-closed. |
| Failure tracking | failure-tracker.sh | Counts cumulative tool failures per session. Alerts at thresholds (3 and 5). |
| Shell write blocking | bash-guard.sh | Selectively blocks explicit file-write patterns (redirects, tee, sed -i, cp, mv, install, truncate) when plan gate is closed (exit 2). Read-only commands always pass. Quote-aware: commands inside quoted strings are not false-positived. |
| Subagent context | subagent-context.sh | Injects plan progress into subagent sessions. |
| Session-end reminders | stop-guard.sh | Reminds about incomplete todos and suggests Lessons Learned on session stop. |
| Pre-compact summary | pre-compact.sh | Outputs progress summary before context compression. |

## Layer 3 — Protocol Discipline

No hook enforcement. Relies on skill Iron Laws + human review.

| Capability | Where defined | What it does |
|------------|---------------|--------------|
| A/B write-set additions | baton-implement skill | Narrowly scoped file additions without replanning. Requires todolist to append to; does not apply when todolist is skipped. |
| Failure boundary | constitution.md §4.4 | Same approach fails repeatedly → must stop and report. Same underlying hypothesis = same approach. |
| Discovery protocol | constitution.md §4.3 | Q1/Q2 discovery (assumption change or plan change) → must stop, update plan, wait for renewed BATON:GO. |
| Fallback conservatism | constitution.md Enforcement Boundaries | Fallback guidance is intentionally more conservative than skill-guided execution. When skills are unavailable, hooks output hardcoded summaries as a safety net. |
| Adversarial review | baton-review skill | First-principles review of artifacts via subagent (`context: fork`). Dispatched before presenting research/plan/todolist to human. Skill-disciplined, not hook-enforced. |

## Design Principles

- **Safe-side defaults**: When in doubt, block rather than allow. Write-lock fails open only on unexpected errors (trap handler), not on ambiguous inputs.
- **Layered degradation**: Without skills, soft guards still fire. Without hooks (Codex), only protocol text remains. Each layer lost reduces enforcement but never silently changes rules.
- **Advisory over blocking**: Most hooks are advisory because the host hook model (Claude Code) cannot block PostToolUse events. Only PreToolUse can return non-zero to prevent an action.
