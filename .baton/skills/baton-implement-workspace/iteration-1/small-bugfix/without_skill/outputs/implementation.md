# Implementation Output: --dry-run exception for patch rule in bash-guard.sh

**Task size**: Small
**State**: EXECUTING (simulated)
**Write set**: bash-guard.sh, test-bash-guard.sh

---

## Step 1: Understand the bug

In `bash-guard.sh` lines 144-145, the `patch` command is unconditionally blocked when the plan gate is closed:

```bash
elif [ -z "$_blocked" ] && _is_cmd_token 'patch'; then
    _blocked="patch (in-place diff application)"
```

This blocks `patch --dry-run`, which is a read-only operation (it only checks whether a patch would apply cleanly without modifying any files). This is a false positive — `--dry-run` should be allowed.

## Step 2: Implement the fix in bash-guard.sh

**File**: `.baton/hooks/bash-guard.sh`
**Lines affected**: 144-145

**Before** (lines 144-145):
```bash
elif [ -z "$_blocked" ] && _is_cmd_token 'patch'; then
    _blocked="patch (in-place diff application)"
```

**After**:
```bash
elif [ -z "$_blocked" ] && _is_cmd_token 'patch'; then
    case "$_SCAN_CMD" in
        *--dry-run*) ;; # read-only check, allow
        *) _blocked="patch (in-place diff application)" ;;
    esac
```

**Rationale**: This uses a `case` statement to inspect the quote-stripped command (`$_SCAN_CMD`) for the `--dry-run` flag. If present, the match falls through without setting `_blocked`, so the command is allowed. Otherwise, it blocks as before. This follows the existing pattern in the file where `case` statements are used for sub-pattern matching (e.g., lines 115-121 for sed/perl, lines 125-133 for python).

Using `$_SCAN_CMD` (quote-stripped) is correct here because `--dry-run` would appear outside of quotes in normal usage. If someone quoted it (`patch '--dry-run'`), the flag would be stripped and not matched — but that's an edge case that doesn't represent real usage, and erring on the side of blocking is safer.

## Step 3: Add tests in test-bash-guard.sh

**File**: `tests/test-bash-guard.sh`
**Location**: After Test 23 (line 365), before the results summary (line 368).

**New test section to insert**:

```bash
# ============================================================
echo ""
echo "=== Test 24: patch --dry-run → allowed (read-only check) ==="
d="$tmp/t24" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_allowed "$d" "patch --dry-run < fix.patch"
assert_allowed "$d" "patch --dry-run -p1 < fix.patch"
assert_allowed "$d" "patch -p1 --dry-run < fix.patch"
assert_blocked "$d" "patch < fix.patch"
assert_blocked "$d" "patch -p1 < fix.patch"
```

**Rationale**: Tests cover:
1. `patch --dry-run` with input redirection — should be allowed
2. `patch --dry-run` with other flags — should be allowed
3. `--dry-run` appearing after other flags — should be allowed
4. `patch` without `--dry-run` — should still be blocked (regression check)
5. `patch -p1` without `--dry-run` — should still be blocked (regression check)

Note: cases 4 and 5 use `< fix.patch` which contains input redirection (`<`). The existing `has_output_redirection` regex on line 89 uses `[^<]` to avoid matching `<` (input redirection), so `patch < fix.patch` will not be blocked by the redirection rule — it will correctly reach the `patch` command check. ✅ Verified by reading the regex pattern at line 89.

## Step 4: Verification plan

1. Run the existing test suite to confirm no regressions: `bash tests/test-bash-guard.sh`
2. The new Test 24 assertions validate both the positive case (--dry-run allowed) and negative case (plain patch still blocked)
3. Expected result: all tests pass, total count increases by 5

## Summary of changes

| File | Change | Lines |
|------|--------|-------|
| `.baton/hooks/bash-guard.sh` | Replace unconditional `patch` block with case statement checking for `--dry-run` | ~4 lines changed (net +2) |
| `tests/test-bash-guard.sh` | Add Test 24 with 5 assertions for patch --dry-run behavior | ~10 lines added |

## 批注区
