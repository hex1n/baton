# Harness Governance

This repo uses the baton harness. Protocol lives in `spec/`, task artifacts in `.harness/`. Full state machine, gates, and artifact definitions: see `spec/`.

Root entrypoints (`CLAUDE.md`, `AGENTS.md`) are generated from `spec/templates/root-governance.template.md` via `bash spec/bootstrap/sync-entrypoints.sh --repo-root . --force`. Do not hand-edit them.

## Principles

1. **Verification before generation** — prove you can validate before writing code
2. **File-based communication** — `.harness/` artifacts are the source of truth, not conversation
3. **Explicit blockers** — blocked states must name reason and next decision
4. **Human gates** — architecture approval and task close require human confirmation
5. **Context isolation** — Verification Explorer and Evaluator use isolated judgment in `strict`; `compat` fallback must be explicit in artifacts
