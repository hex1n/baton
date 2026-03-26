# Scoped Map: add-version-flag

**Requirement**: Add `--version` flag to bootstrap scripts
**Domain**: spec/bootstrap
**Owner**: `scoped-explorer`
**Status**: `complete`

## 1. Scope

- In scope: `spec/bootstrap/init-harness.sh`, `spec/bootstrap/start-task.sh`
- Out of scope: PowerShell equivalents (`.ps1`), protocol docs
- Expected write boundary: 2 existing files + possibly 1 new version file

## 2. Entry Point

- `init-harness.sh:121-161` — argument parsing loop (`while [[ $# -gt 0 ]]; case "$1" in`)
- `start-task.sh:49-85` — same pattern
- Both use `--help|-h` → `usage()` → `exit 0` as the existing model for info-only flags

## 3. Call Chain

```text
user runs script with --version → case match → print version → exit 0
```

No deeper chain. Same pattern as `--help`.

## 4. Existing Behavior

- `init-harness.sh` handles 8 flags: `--repo-root`, `--profile`, `--adapter`, `--task-id`, `--dry-run`, `--detect-only`, `--force`, `--help`
- `start-task.sh` handles 6 flags: `--repo-root`, `--task-id`, `--owner`, `--state`, `--notes`, `--dry-run`, `--help`
- Neither has `--version` or any version string
- Both scripts: `set -euo pipefail`, shared pattern of `usage()` + arg loop + validation

## 5. Existing Tests

- No tests exist for bootstrap scripts (old test suite deleted in restructure)
- Verification: manual execution only (`bash script.sh --version`)

## 6. Dependency / Risk Scan

- No integration/infra touch
- No migrations
- No cross-domain risk
- Only risk: version string DRY — if hardcoded in each script, could drift

## 7. Change Shape

- Additive: new case branch in existing arg parser pattern
- Estimated file count: 2-3
- Trivial sizing (visual inspection sufficient for verification)

## 8. Open Questions

- Where does the version string live? (per-script hardcode vs shared file)

## 9. Recommendation

- Proceed — straightforward additive change
- Specifier should define output format and version source location
