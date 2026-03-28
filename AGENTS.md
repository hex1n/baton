# Harness Governance

This repository uses the portable harness protocol defined in `spec/`.

This content is the shared root governance source for host-specific entrypoints:

- `CLAUDE.md` for Claude Code style environments
- `AGENTS.md` for Codex and Cursor style environments

Do not hand-edit those files directly. Update this template and then run:

```bash
bash spec/bootstrap/sync-governance-entrypoints.sh --repo-root . --force
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

## Documentation Contribution Rules

- Root entry docs are maintained as a bilingual pair: `README.md` remains the official English entry, and `README.zh-CN.md` is the official Chinese companion
- Changes to root onboarding, install/update flow, vendor/override layout, or skill distribution guidance must update both README files in the same change
- Root entry-document tasks still use the harness workflow: scope the change, write requirements / architecture / verification artifacts, then verify
- After editing either root README, run `bash spec/bootstrap/check-root-readme-bilingual.sh`
- Other Chinese root-level docs are supplemental; they do not replace the official README pair

## Multi-Host Root Entry Rules

- Keep root governance synchronized through `spec/templates/root-governance.template.md`
- Materialize host entrypoints with `bash spec/bootstrap/sync-governance-entrypoints.sh --repo-root . --force`
- `CLAUDE.md` remains the root entrypoint for Claude Code style hosts
- `AGENTS.md` is the shared root entrypoint for Codex and Cursor style hosts
- If you change root governance rules, update the template first and let the sync script rewrite the host files
