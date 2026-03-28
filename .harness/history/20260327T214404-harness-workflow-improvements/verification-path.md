# Verification Path: harness-workflow-improvements

**Owner**: `verification-explorer`
**Status**: `complete`

## 1. Intended Checks

- Build:
  - not applicable; this task is protocol/docs/scripts work rather than an application binary build
- Tests:
  - `check-consistency.sh` must still pass after the protocol and script changes
  - `start-task.sh --dry-run` must remain executable with canonical owner/state token loading
- Static checks:
  - `start-task.ps1` should remain structurally aligned with the Bash implementation
  - protocol docs and role skills must agree on Gate 2 sync and isolation responsibilities
- Runtime/manual checks:
  - `sync-skills.sh` must base its decision on actual file state
  - final mirrored skill copies must match canonical `skills/`

## 2. Exact Commands

```text
bash spec/bootstrap/check-consistency.sh
bash spec/bootstrap/start-task.sh --repo-root . --task-id verify-workflow --owner scoped-explorer --state exploring --notes "verification probe" --dry-run
bash spec/bootstrap/start-task.sh --repo-root . --task-id verify-workflow --owner scoped-explorer --state invalid-state --notes "verification probe" --dry-run
pwsh ./spec/bootstrap/start-task.ps1 -RepoRoot . -TaskId verify-workflow -Owner scoped-explorer -State exploring -Notes "verification probe" -DryRun
bash spec/bootstrap/sync-skills.sh
rg -n "spawn_agent|wait_agent|fork_context" README.md spec/adapters/codex.md skills/harness-verifier.md skills/harness-evaluator.md
rg -n 'Happy path|Repair loops|Verifier BLOCKED|Generator BLOCKED|Evaluator BLOCKED|re-run review|blocked -> architecting|blocked -> generating|blocked -> verification_check' README.md spec/README.md spec/protocol/state-machine.md
```

## 3. Prerequisites

- Toolchain:
  - `bash`
  - standard Unix utilities used by bootstrap scripts
  - `pwsh` for PowerShell runtime verification if available
- Services:
  - none
- Fixtures:
  - existing Baton repo layout with `skills/`, `.claude/skills/`, `.agents/`, and `.harness/`
- Environment variables:
  - none required for the listed commands

## 4. Dry-Run Result

- Command: `bash spec/bootstrap/check-consistency.sh`
  - Result: pass
  - Notes: final run passed all four invariants, including the new `states.txt` canonical-source check, after the Codex example additions
- Command: `bash spec/bootstrap/start-task.sh --repo-root . --task-id verify-workflow --owner scoped-explorer --state exploring --notes "verification probe" --dry-run`
  - Result: executable; exited with expected open-task guard
  - Notes: `Cannot start a new task while non-complete task rows exist: harness-workflow-improvements:verification_check`
- Command: `bash spec/bootstrap/start-task.sh --repo-root . --task-id verify-workflow --owner scoped-explorer --state invalid-state --notes "verification probe" --dry-run`
  - Result: executable; rejected invalid state token before task-row checks
  - Notes: script returned `Unsupported state: invalid-state`
- Command: `pwsh ./spec/bootstrap/start-task.ps1 -RepoRoot . -TaskId verify-workflow -Owner scoped-explorer -State exploring -Notes "verification probe" -DryRun`
  - Result: unavailable in current environment
  - Notes: shell reported `pwsh: command not found`
- Command: `bash spec/bootstrap/sync-skills.sh`
  - Result: executable; detected actual copy-mode workspace and performed sync
  - Notes: script reported `.link-mode` declared `symlink`, actual workspace was `copy`, then synced `.claude/skills/` and `.agents/`
- Command: `rg -n "spawn_agent|wait_agent|fork_context" README.md spec/adapters/codex.md skills/harness-verifier.md skills/harness-evaluator.md`
  - Result: pass
  - Notes: examples now exist in `spec/adapters/codex.md`; README points Codex users to them; Verifier/Evaluator skills contain concise execution notes
- Command: `rg -n 'Happy path|Repair loops|Verifier BLOCKED|Generator BLOCKED|Evaluator BLOCKED|re-run review|blocked -> architecting|blocked -> generating|blocked -> verification_check' README.md spec/README.md spec/protocol/state-machine.md`
  - Result: pass
  - Notes: README, spec README, and state-machine now all show the linear happy path separately from repair loops

## 5. Blockers

- No blocker for implementation.
- Environment gap: `pwsh` is unavailable locally, so PowerShell validation must use fallback review rather than live execution.

## 6. Fallbacks

- If the primary path fails:
  - use `git diff --check` plus `check-consistency.sh` output to distinguish syntax / formatting issues from protocol drift
- If the test module is unavailable:
  - not applicable; the validation path is script- and doc-based
- If the repo build is already broken:
  - not applicable; no application build is required for this task
- If `pwsh` is unavailable:
  - perform a line-by-line parity review between `start-task.sh` and `start-task.ps1`, focusing on token loading and validation flow, and record residual risk explicitly
- If current workspace link mode does not reproduce the sync bug:
  - inspect actual file relationships with `test -L` / inode comparison or create a temporary copy-mode fixture to prove `sync-skills.sh` takes the sync path
