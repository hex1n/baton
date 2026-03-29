# Update Vendored Harness

## Goal

Refresh a target repository's vendored baton harness payload from the current
baton checkout while preserving local overrides.

## Bash

```bash
./spec/bootstrap/update-harness.sh --repo-root /path/to/repo
```

## Windows

Use the same shell entrypoint from Git Bash, or invoke it from PowerShell:

```powershell
bash ./spec/bootstrap/update-harness.sh --repo-root C:/path/to/repo
```

## Behavior

`update-harness`:

1. refreshes `.vendor/baton-harness/`
2. rewrites `.harness/harness.lock.yaml`
3. re-materializes `.claude/skills/` and `.agents/`
4. keeps local override files under `.harness/overrides/`

Override precedence does not change during update:

1. `.harness/overrides/skills/`
2. `.vendor/baton-harness/skills/`

For templates used by vendored bootstrap scripts:

1. `.harness/overrides/templates/`
2. `.vendor/baton-harness/spec/templates/`

## Constraint

v1 updates from a local baton checkout via `--source-root` or the current
script location. It does not fetch from a remote registry or Git URL.
