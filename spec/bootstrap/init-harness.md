# Init Harness In A New Repo

## Goal

Adopt the portable harness in a new repository with the smallest workable setup.

This checklist is designed for:

- any repository
- any agent CLI or editor agent
- first-time harness adoption

## Step 1: Choose A Repo Profile

Pick the closest base profile from `profiles/`:

- `java-maven.yaml`
- `node-monorepo.yaml`
- `python-service.yaml`

If none match exactly, pick the nearest one and override locally.

## Step 2: Choose An Adapter

Pick the closest execution adapter from `adapters/`:

- `codex.md`
- `claude-code.md`
- `cursor.md`

If your tool is different, start from [cli-adapter-interface.md](../adapters/cli-adapter-interface.md).

You can also use the draft bootstrap scripts:

- `bootstrap/init-harness.ps1`
- `bootstrap/init-harness.sh`
- `bootstrap/start-task.ps1`
- `bootstrap/start-task.sh`

## Step 3: Create `.harness/`

Copy these templates into the target repo:

```text
.harness/
  scoped-map.md
  requirements.md
  architecture.md
  verification-path.md
  module-status.md
  retrospective.md
  profile.local.yaml
```

The last file should be created from `templates/profile.local.template.yaml`.
In this reference implementation, bootstrap also creates shared root governance
entrypoints:

```text
CLAUDE.md
AGENTS.md
```

If the repo adopted baton through `install-harness`, prefer running the
vendored script inside the target repo:

```bash
/path/to/repo/.vendor/baton-harness/spec/bootstrap/init-harness.sh --repo-root /path/to/repo --profile auto --adapter codex
```

If you want a generated starting point instead of manual copying:

```powershell
pwsh ./spec/bootstrap/init-harness.ps1 -RepoRoot . -Profile auto -Adapter codex -TaskId pilot-task -Language zh
```

```bash
./spec/bootstrap/init-harness.sh --repo-root . --profile auto --adapter codex --task-id pilot-task --language zh
```

Those commands also materialize `CLAUDE.md` and `AGENTS.md` from the shared
governance template when the files are missing. Pass `--force` if you want to
refresh them from the template.

Useful options:

- `-Profile auto` / `--profile auto`
- `-Language auto|en|zh` / `--language auto|en|zh`
- `-DryRun` / `--dry-run`
- `-DetectOnly` / `--detect-only`
- `-TaskId <id>` / `--task-id <id>`
- `-Force` / `--force`

If you only want to identify the repo profile without writing files:

```powershell
pwsh ./spec/bootstrap/init-harness.ps1 -RepoRoot . -Profile auto -Adapter codex -DetectOnly
```

```bash
./spec/bootstrap/init-harness.sh --repo-root . --profile auto --adapter codex --detect-only
```

## Step 4: Fill `profile.local.yaml`

At minimum, set:

- repo name
- base profile
- artifact language policy
- build command
- test command
- worktree policy
- high-risk paths
- review isolation strategy

Do not leave validation commands implicit.

Language policy rules:

- `documentation.artifact_language: zh` writes human-facing artifacts in Chinese
- `documentation.artifact_language: en` writes them in English
- `documentation.artifact_language: auto` makes bootstrap scripts resolve from
  locale, while writing skills follow the current user request language
- if you omit the flag in this repo, the bootstrap default is `zh`
- `module-status.md` stays English as the stable control-plane file

Template resolution order:

1. `repo/.harness/overrides/templates/`
2. vendored `spec/templates/`

Root governance resolution order is simpler:

1. shared template `spec/templates/root-governance.template.md`
2. host entrypoints `CLAUDE.md` and `AGENTS.md` generated from it

## Step 5: Define Worktree Policy

For medium-plus tasks, decide now:

- whether worktrees are required
- naming convention for branches
- where worktrees live
- whether `.harness/` stays in the primary workspace

Recommended default:

- `.harness/` stays in the primary repo
- code generation happens in a dedicated worktree

## Step 6: Run Repo Explorer Once

Before the first real task:

1. map module or package layout
2. identify high-risk directories
3. identify default test/build entry points
4. identify unstable or environment-heavy surfaces

Optional output:

- `repo-map.md`

## Step 7: Dry-Run Verification Path

Before implementation on the first task, run the intended validation path once.

You are not checking the feature yet. You are checking whether validation itself is reachable.

Record in `verification-path.md`:

- the commands
- the prerequisites
- whether they run
- whether the repo already has blocking build/test issues

If this step fails, do not pretend the task is ready for generator.

## Step 8: Start With A Pilot Task

The first harness task in a repo should be:

- medium size
- local to one business area
- testable without cross-environment deployment
- not blocked on schema or infrastructure migration

Avoid starting with:

- huge refactors
- infra-wide changes
- migration-heavy tasks
- tasks with unclear verification ownership

After `Repo Explorer`, initialize the first concrete task:

```powershell
pwsh ./spec/bootstrap/start-task.ps1 -RepoRoot . -TaskId pilot-task
```

```bash
./spec/bootstrap/start-task.sh --repo-root . --task-id pilot-task
```

## Step 9: Keep `module-status.md` Live

Create the task row at the start of the task, not at the end.

After `start-task`, the current owner agent should update it at every major transition:

- `exploring`
- `specifying`
- `architecting`
- `verification_check`
- `generating`
- `reviewing`
- `blocked`
- `ready_for_human_close`
- `complete`

Do not require a separate state-transition script as part of the core protocol.
If a local repo adds one, treat it as a convenience wrapper around direct file updates.

Before a task enters `verification_check`, ensure `requirements.md` reflects
any approved architecture decisions that change requirements-level truth.
Run `spec/bootstrap/check-consistency.sh` before or during that verification stage.

## Step 10: Close With A Retrospective

After the task ends:

1. capture what worked
2. capture what blocked progress
3. update the local profile or bootstrap policy if needed

The first two or three tasks should always produce a retrospective.

## Suggested First-Day Minimum

If you want the shortest viable adoption path, do only this:

1. choose a profile
2. choose an adapter
3. create `.harness/`
4. create `profile.local.yaml`
5. run `Repo Explorer`
6. run `start-task`
7. run `Verification Path Check`
8. do one pilot task

That is enough to prove whether the harness is portable in the target repo.
