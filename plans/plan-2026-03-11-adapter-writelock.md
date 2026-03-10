# Plan: Fix adapter shell contract + write-lock path resolution

**Complexity**: Small (upgraded from Trivial — C-level discovery during implementation)
**Source**: Previous plan's Surface Scan miss + implementation debugging

## Requirements

1. [CODE] `adapter-cursor.sh:5` uses `sh` to invoke `#!/usr/bin/env bash` write-lock.sh — same shell contract bug as 6 test files just fixed
2. [CODE] `write-lock.sh:64-67` path resolution fails on macOS: when target's parent dir doesn't exist, `realpath -m` and `readlink -f` both fail, manual fallback produces `/app.ts` instead of `$PROJECT_DIR/src/app.ts`, causing "outside project" false positive → all blocking bypassed

## Root Cause Analysis

On macOS, write-lock.sh line 64-67:
```sh
TARGET_REAL="$(realpath -m "$TARGET" 2>/dev/null || readlink -f "$TARGET" 2>/dev/null)" || true
if [ -z "$TARGET_REAL" ]; then
    TARGET_REAL="$(cd "$(dirname "$TARGET")" 2>/dev/null && pwd)/$(basename "$TARGET")" 2>/dev/null || TARGET_REAL="$TARGET"
fi
```

1. `realpath -m src/app.ts` → fails (macOS realpath lacks `-m`)
2. `readlink -f src/app.ts` → fails (macOS readlink lacks `-f`)
3. TARGET_REAL="" → enters fallback
4. `cd "$(dirname "src/app.ts")"` = `cd src` → fails (dir doesn't exist), silenced by `2>/dev/null`
5. `&& pwd` never runs → `$(cd ... && pwd)` = empty string
6. TARGET_REAL = `"/$(basename "src/app.ts")"` = `"/app.ts"`
7. `"/app.ts"` is absolute, doesn't start with PROJECT_DIR → "outside project" → exit 0

This is the root cause of all 10 pre-existing test-write-lock.sh failures and all 4 pre-existing test-adapters failures.

## Changes

### Change 1: adapter-cursor.sh shell contract (done)

`adapter-cursor.sh:5` — `sh` → `bash`. Already applied.

### Change 2: write-lock.sh path resolution fix

Replace the fallback at `write-lock.sh:64-68` with logic that handles non-existent parent dirs:

When `realpath` and `readlink` both fail and the parent dir doesn't exist, resolve relative to PROJECT_DIR instead of trying to `cd` into a non-existent directory.

```sh
TARGET_REAL="$(realpath -m "$TARGET" 2>/dev/null || readlink -f "$TARGET" 2>/dev/null)" || true
if [ -z "$TARGET_REAL" ]; then
    _parent="$(dirname "$TARGET")"
    if [ -d "$_parent" ]; then
        TARGET_REAL="$(cd "$_parent" 2>/dev/null && pwd)/$(basename "$TARGET")"
    else
        # Parent doesn't exist — resolve relative to project dir
        TARGET_REAL="${PROJECT_DIR}/${TARGET}"
    fi
fi
```

**Files**: `.baton/hooks/write-lock.sh`
**Verify**: `bash tests/test-write-lock.sh && bash tests/test-adapters.sh && bash tests/test-adapters-v2.sh`

## Self-Review

### Internal Consistency
- Change 1 addresses requirement 1 ✅
- Change 2 addresses requirement 2 ✅
- The fix is minimal: only changes the fallback path when parent dir doesn't exist

### External Risks
- **Biggest risk**: The fix might change behavior for edge cases where the parent dir exists but the file doesn't. Mitigation: the `if [ -d "$_parent" ]` guard preserves existing behavior when parent exists.
- **What could make this wrong**: If some caller intentionally passes absolute-looking relative paths. No evidence of this.

<!-- BATON:GO -->

## Retrospective

**What the plan got wrong:** Original Trivial plan assumed adapter sh→bash was the root cause of test failures. It wasn't — the real root cause was write-lock.sh path resolution on macOS. Good that the skill discipline forced a stop + plan update instead of continuing to guess.

**What surprised me:** A single 5-line path resolution bug caused 14 test failures across 3 test suites. The bug had been there since write-lock.sh v3 but only manifests when the target file's parent directory doesn't exist — which is exactly the case in temp-dir-based tests.

**What to research differently next time:** When investigating pre-existing test failures, run `bash -x` on the failing script early instead of assuming the root cause from the symptom pattern.

## 批注区

