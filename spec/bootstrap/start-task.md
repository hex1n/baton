# Start A Harness Task

## Goal

Initialize a new active harness task in a repo that already has `.harness/`
bootstrapped.

This step does three things:

1. appends a new task row to `module-status.md`
2. resets active task artifacts from the current templates
3. archives the previous task's active artifacts into `.harness/history/` when needed

It does not manage normal in-task state transitions. After initialization, the
current owner agent updates `module-status.md` directly at each handoff or
blocker.

## v1 Assumption

Portable harness v1 assumes:

- one non-complete active task per workspace
- parallel work should use another worktree or clone

`start-task` enforces that assumption by refusing to create a new task row while
an existing row is not yet `complete`.

## PowerShell

```powershell
pwsh ./spec/bootstrap/start-task.ps1 -RepoRoot . -TaskId challenge-export-fix
```

Useful options:

- `-Owner scoped-explorer`
- `-State exploring`
- `-Notes "user-approved pilot task"`
- `-Language auto|en|zh`
- `-DryRun`

## Bash

```bash
./spec/bootstrap/start-task.sh --repo-root . --task-id challenge-export-fix
```

Useful options:

- `--owner scoped-explorer`
- `--state exploring`
- `--notes "user-approved pilot task"`
- `--language auto|en|zh`
- `--dry-run`

## What Gets Reset

The active task surfaces are reset from templates:

- `scoped-map.md`
- `requirements.md`
- `architecture.md`
- `verification-path.md`
- `retrospective.md`

This keeps the top-level `.harness/` focused on the current task.

Language selection for these human-facing artifacts resolves in this order:

1. explicit `--language` / `-Language`
2. `.harness/profile.local.yaml` → `documentation.artifact_language`
3. Chinese default

If the selected policy is `auto`, the bootstrap script resolves the artifact
language from the local environment locale. `module-status.md` is not localized.

Template resolution order:

1. `repo/.harness/overrides/templates/`
2. vendored `spec/templates/`

## What Gets Archived

If the active artifact files differ from the templates, `start-task` copies them
to:

```text
.harness/history/<timestamp>-<previous-scope>/
```

This is a lightweight history mechanism, not a full scheduler.

## Expected Flow

1. run `init-harness`
2. review `profile.local.yaml`
3. run `Repo Explorer` once
4. run `start-task`
5. fill `scoped-map.md`
6. after architecture approval, sync `requirements.md` to any approved
   architecture decisions that change requirements-level truth
7. run `spec/bootstrap/check-consistency.sh` before or during `verification_check`
8. let the current owner agent move the task through the remaining states in `module-status.md`

## Failure Conditions

`start-task` should stop instead of guessing when:

- `.harness/` is missing
- `module-status.md` is missing
- the task id already exists
- another task row is not yet `complete`
