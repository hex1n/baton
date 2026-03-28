# Requirements: add-version-flag

**Topic**: Bootstrap script version reporting
**Status**: `complete`
**Sizing**: `Trivial`

## 1. Problem

Bootstrap scripts have no way to report which version of the harness protocol they implement. Users cannot verify script/protocol version alignment.

## 2. Scope

### 2.1 In Scope

- `spec/bootstrap/init-harness.sh` — add `--version` flag
- `spec/bootstrap/start-task.sh` — add `--version` flag

### 2.2 Out of Scope

- PowerShell equivalents (`.ps1`)
- Version bumping automation
- Semantic versioning policy

## 3. Functional Requirements

### FR-1 Version flag

- Both scripts accept `--version` as an argument
- On `--version`, print the protocol version and exit 0
- No other output (no usage text, no banners)

### FR-2 Single version source

- Version string is defined in exactly one place
- Both scripts read from the same source (no hardcoded duplicates)

## 4. Non-Goals

- Version checking against remote/upstream
- Automatic version increment on release
- Adding version to `.ps1` scripts

## 5. Acceptance Criteria

- [ ] `bash spec/bootstrap/init-harness.sh --version` prints a version string and exits 0
- [ ] `bash spec/bootstrap/start-task.sh --version` prints the same version string and exits 0
- [ ] Version string is defined in exactly one file (not duplicated)
- [ ] Existing flags (`--help`, `--dry-run`, etc.) still work unchanged

## 6. Constraints

- Must follow existing argument parsing pattern (`case "$1" in`)
- Must not change behavior of any existing flag

## 7. Validation Intent

- Run each script with `--version`, verify output and exit code
- Run each script with `--help`, verify existing behavior unchanged
