# Harness Governance

This project uses the portable harness protocol defined in `spec/`.
Role skills in `.claude/skills/harness-*.md` implement the protocol for Claude Code.

## State Machine

Tasks progress through these states in order:

```
exploring → specifying → architecting → awaiting_human_arch
  → verification_check → generating → reviewing
  → ready_for_human_close → complete
```

- Any state can transition to `blocked` (must state reason and next decision needed)
- `blocked` exits to: `verification_check`, `architecting`, or `generating`
- One active task per workspace. Parallel work uses worktrees.
- `complete` requires human confirmation.

## Gates

| # | Gate | Required Before | Key Criteria |
|---|------|----------------|-------------|
| 1 | Scoped Exploration Complete | Specifier | Entry points, write surface, test landing points, risks identified |
| 2 | Architecture Approved | Verification Check | Requirements ↔ architecture consistent, human approved |
| 3 | Verification Path Check | Generator | Validation commands executable, fallback defined |
| 4 | Independent Review | Human Close | Findings explicit, blockers resolved or accepted |
| 5 | Human Close | Complete | Human accepts residual risk, confirms objective met |

## Artifacts

Tasks produce artifacts in `.harness/`:

| Artifact | Purpose |
|----------|---------|
| `scoped-map.md` | Task-local understanding |
| `requirements.md` | Implementation contract |
| `architecture.md` | Change design |
| `verification-path.md` | Validation proof |
| `module-status.md` | Control plane (state tracking) |
| `retrospective.md` | Process lessons |

## Principles

1. **Verification before generation** — prove you can validate before writing code
2. **File-based communication** — artifacts are the source of truth, not conversation history
3. **Explicit blockers** — blocked states must name the reason and next decision
4. **Human gates** — architecture approval and task close require human confirmation
5. **Context isolation** — each role operates from artifacts, not prior role's reasoning
