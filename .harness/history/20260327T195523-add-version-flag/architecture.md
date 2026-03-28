# Architecture: add-version-flag

**Topic**: Bootstrap script version reporting
**Status**: `proposed`
**Sizing**: `Trivial`

## 1. Problem

Need a `--version` flag in both bootstrap scripts that reads from a single version source.

## 2. First-Principles

### 2.1 Problem Statement

Two scripts need to report the same version string without duplication.

### 2.2 Constraints

- Scripts use `bash` with `set -euo pipefail`
- Scripts already use `script_dir` / `spec_root` to locate sibling files
- Argument parsing follows `case "$1" in` pattern

### 2.3 Solution Categories

- **A: Shared VERSION file** — `spec/VERSION` contains one line (e.g., `1.0.0`). Both scripts read it via `cat "$spec_root/VERSION"`.
- **B: Shared shell variable file** — `spec/version.sh` exports `HARNESS_VERSION=1.0.0`. Both scripts `source` it.
- **C: Hardcode in each script** — each script has `version="1.0.0"` at the top.

### 2.4 Evaluation

- **A wins**: simplest, language-agnostic (works for `.ps1` too later), one plain text file, `cat` is all you need. Other tools/scripts can also read it.
- **B rejected**: overkill — sourcing a shell file for one variable adds complexity with no benefit.
- **C rejected**: violates FR-2 (single source). Version will drift.

## 3. Recommended Architecture

- Create `spec/VERSION` containing `1.0.0` (one line, no newline decoration)
- Both scripts: add `--version` case before `--help`, read and print `"$spec_root/VERSION"` content, exit 0
- Version output format: `harness-spec v<version>` (e.g., `harness-spec v1.0.0`)

Key change points:
- `spec/VERSION` — new file (1 line)
- `spec/bootstrap/init-harness.sh:121-161` — add `--version` case
- `spec/bootstrap/start-task.sh:49-85` — add `--version` case

## 4. Surface Scan

| File | Level | Disposition | Reason |
|---|---|---|---|
| `spec/VERSION` | L1 | add | new version source file |
| `spec/bootstrap/init-harness.sh` | L1 | modify | add --version case in arg parser |
| `spec/bootstrap/start-task.sh` | L1 | modify | add --version case in arg parser |

## 5. Validation Strategy

- `bash spec/bootstrap/init-harness.sh --version` → `harness-spec v1.0.0`, exit 0
- `bash spec/bootstrap/start-task.sh --version` → `harness-spec v1.0.0`, exit 0
- `bash spec/bootstrap/init-harness.sh --help` → existing usage output (unchanged)

## 6. Risks

- None significant. Change is additive and isolated.

## 7. Self-Challenge

1. Is a separate VERSION file overkill for one string? No — it's simpler than any alternative and enables future use by other tools.
2. Unverified assumptions: none. The `spec_root` variable already exists in both scripts.
3. A skeptic would ask: "why not just hardcode?" Answer: FR-2 requires single source, and the cost of a file is negligible.
