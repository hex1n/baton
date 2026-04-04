# Harness Governance

This repository uses the portable harness protocol defined in `spec/`.

This content is the shared root governance source for host-specific entrypoints:

- `CLAUDE.md` for Claude Code style environments
- `AGENTS.md` for Codex and Cursor style environments

Do not hand-edit those files directly. Update this template and then run:

```bash
bash spec/bootstrap/sync-entrypoints.sh --repo-root . --force
```

## State Machine

Tasks progress through these states in order:

```text
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
| 3 | Verification Path Check | Generator | Validation commands executable, isolation mode/context explicit, fallback defined |
| 4 | Independent Review | Human Close | Findings explicit, `evaluation.md` present, blockers resolved or accepted |
| 5 | Human Close | Complete | Human accepts residual risk, confirms objective met |

## Artifacts

Tasks produce artifacts in `.harness/`:

| Artifact | Purpose |
|----------|---------|
| `exploration.md` | Task-local understanding |
| `requirements.md` | Implementation contract |
| `architecture.md` | Change design |
| `verification.md` | Validation proof |
| `evaluation.md` | Independent review verdict and isolation provenance |
| `task-status.md` | Control plane (state tracking) |
| `retrospective.md` | Process lessons |

## Principles

1. **Verification before generation** — prove you can validate before writing code
2. **File-based communication** — artifacts are the source of truth, not conversation history
3. **Explicit blockers** — blocked states must name the reason and next decision
4. **Human gates** — architecture approval and task close require human confirmation
5. **Context isolation** — `Verification Explorer` and `Evaluator` must use isolated judgment in `strict`; `compat` fallback must be explicit in artifacts

## Multi-Host Root Entry Rules

- Keep root governance synchronized through `spec/templates/root-governance.template.md`
- Materialize host entrypoints with `bash spec/bootstrap/sync-entrypoints.sh --repo-root . --force`
- `CLAUDE.md` remains the root entrypoint for Claude Code style hosts
- `AGENTS.md` is the shared root entrypoint for Codex and Cursor style hosts
- If you change root governance rules, update the template first and let the sync script rewrite the host files
