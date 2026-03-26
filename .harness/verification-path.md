# Verification Path: add-version-flag

**Owner**: `verifier`
**Status**: `pass`

## 1. Intended Checks

- Build: N/A (bash scripts, no compilation)
- Tests: N/A (no test suite)
- Runtime/manual checks: run scripts with `--version` and `--help`

## 2. Exact Commands

```bash
bash spec/bootstrap/init-harness.sh --version
bash spec/bootstrap/start-task.sh --version
bash spec/bootstrap/init-harness.sh --help
bash spec/bootstrap/start-task.sh --help
```

## 3. Prerequisites

- Toolchain: bash (available via Git Bash on Windows)
- No other prerequisites

## 4. Dry-Run Result

- `bash spec/bootstrap/init-harness.sh --help` → exits 0, prints usage ✅
- `bash spec/bootstrap/start-task.sh --help` → exits 0, prints usage ✅
- Both scripts are executable in current environment

## 5. Blockers

- none

## 6. Fallbacks

- Not needed — primary path works
