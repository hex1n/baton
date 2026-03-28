# Sync Root Governance Entrypoints

## Goal

Materialize the shared harness governance summary into the host-specific root
entrypoints used by local agent tools.

This reference implementation keeps one canonical source:

- `spec/templates/root-governance.template.md`

and syncs it into:

- `CLAUDE.md`
- `AGENTS.md`

## Bash

```bash
./spec/bootstrap/sync-governance-entrypoints.sh --repo-root .
```

Useful options:

- `--mode check`
- `--force`
- `--dry-run`

## When To Use It

- after editing `spec/templates/root-governance.template.md`
- when `check-consistency.sh` reports governance entrypoint drift
- during bootstrap, when you want to refresh root entrypoints in a target repo
