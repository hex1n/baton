# Plan: Skip-todolist advisory test + full baseline

**Complexity**: Trivial

## Changes

1. Add 1 test to `tests/test-new-hooks.sh`: GO + no ## Todo + plan-unlisted file → post-write-tracker still warns
2. Run full test suite to establish clean baseline after shell contract + path resolution fixes

**Files**: `tests/test-new-hooks.sh`
**Verify**: `bash tests/test-new-hooks.sh` passes, then all test suites pass

## 批注区

<!-- BATON:GO 后直接实现 -->
<!-- BATON:GO -->