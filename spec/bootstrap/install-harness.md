# Install Harness Into A Target Repo

## Goal

Install the current baton checkout into another repository as a self-contained,
versioned harness payload.

This command is the recommended external-repo adoption path. It replaces
manual skill copying as the primary workflow.

## What It Writes

```text
target-repo/
  .vendor/
    baton-harness/
      README.md
      spec/
      skills/
  .harness/
    harness.lock.yaml
    overrides/
      skills/
      templates/
  .claude/
    skills/
  .agents/
```

## Bash

```bash
./spec/bootstrap/install-harness.sh --repo-root /path/to/repo
```

Useful options:

- `--source-root /path/to/baton`
- `--dry-run`
- `--force`

## Windows

Use the same shell entrypoint from Git Bash, or invoke it from PowerShell:

```powershell
bash ./spec/bootstrap/install-harness.sh --repo-root C:/path/to/repo
```

Useful options:

- `--source-root C:/path/to/baton`
- `--dry-run`
- `--force`

## Effective Skill Resolution

Runtime skill entrypoints in `.claude/skills/` and `.agents/` are materialized
from these sources in order:

1. `.harness/overrides/skills/`
2. `.vendor/baton-harness/skills/`

The materialization strategy is local to the target repo:

1. symlink
2. hardlink
3. copy

When symlinks are used, their targets are written as repo-relative paths.
This means the repo stays self-contained even when symlinks are used.

## Next Step

After install, bootstrap the target repo from its own vendored payload:

```bash
/path/to/repo/.vendor/baton-harness/spec/bootstrap/init-harness.sh --repo-root /path/to/repo --profile auto --adapter codex
```
