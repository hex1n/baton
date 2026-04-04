# Prepare Review Gate

## Goal

Run the local runtime-refresh and pre-review checks that should happen before
isolated verifier / evaluator handoff.

This command does not launch agents itself. It prepares the workspace so the
next isolated review steps are reproducible and less dependent on memory.

## Bash

```bash
./spec/bootstrap/prepare-review.sh --repo-root . --bootstrap-dir ./spec/bootstrap
```

## What It Does

1. re-runs `install-hooks.sh` for the target repo
2. runs `check-consistency.sh`
3. extracts a generated `SessionStart` hook command from local config and executes it once
4. prints the next isolated verifier / evaluator instructions

## Why It Exists

This closes two common failure modes:

- local `.codex/hooks.json` / `.claude/settings.json` drift after hook/runtime refactors
- relying on human memory for the steps required before isolated review

## Constraint

`prepare-review.sh` prepares the review gate, but the actual verifier /
evaluator must still be launched by the host as isolated agents such as
`spawn_agent({ fork_context: false })` in Codex.
