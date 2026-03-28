# Plan: Fix bash-guard false positive for `patch --dry-run`

**Sizing**: Small (single-step verification — run test suite + manual check)

## Problem

`bash-guard.sh` blocks the `patch` command unconditionally at line 144-145. The `patch --dry-run` flag only simulates applying a patch without modifying any files, so it should be allowed when the plan gate is closed. This is a false positive.

## Root Cause

The `patch` rule in the file mutation commands block (line 144) uses `_is_cmd_token 'patch'` with no flag-awareness. Unlike `sed -i` which is checked via pattern match on the `-i` flag, `patch` has no exemption for its read-only flags.

## Fix

**File**: `.baton/hooks/bash-guard.sh` (single file change)

**Approach**: Replace the unconditional `patch` block with a conditional that checks for `--dry-run` and `--check` flags (the two standard read-only flags for `patch`). If either flag is present in the command, allow it. Otherwise, block.

### Implementation Detail

Change lines 144-145 from:

```bash
elif [ -z "$_blocked" ] && _is_cmd_token 'patch'; then
    _blocked="patch (in-place diff application)"
```

To:

```bash
elif [ -z "$_blocked" ] && _is_cmd_token 'patch'; then
    case "$_SCAN_CMD" in
        *--dry-run*|*--check*) ;;  # read-only flags — allow
        *) _blocked="patch (in-place diff application)" ;;
    esac
```

**Why `case` on `$_SCAN_CMD`**: This follows the existing pattern used for `sed -i` and `perl -pi` checks (lines 115-121) — matching against the quote-stripped command string. The `case` glob match is sufficient here because `--dry-run` and `--check` are unambiguous long flags.

**Why these two flags**:
- `--dry-run`: Prints what would happen without applying. Standard read-only usage.
- `--check`: Alias for `--dry-run` in GNU patch. Same behavior.

No short-form alias exists for `--dry-run` in GNU patch, so we only need long-form matches.

## Test Changes

**File**: `tests/test-bash-guard.sh`

Add a new test section (Test 24) for patch flag-awareness:

```bash
echo "=== Test 24: patch --dry-run → allowed (read-only flag) ==="
d="$tmp/t24" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_allowed "$d" "patch --dry-run < fix.patch"
assert_allowed "$d" "patch --check < fix.patch"
assert_allowed "$d" "patch -p1 --dry-run < fix.patch"
assert_blocked "$d" "patch < fix.patch"
assert_blocked "$d" "patch -p1 < fix.patch"
```

This covers:
- `--dry-run` alone and with other flags (`-p1`)
- `--check` (alias)
- Bare `patch` without dry-run still blocked
- `patch` with other flags but no dry-run still blocked

## Write Set

| File | Change |
|------|--------|
| `.baton/hooks/bash-guard.sh` | Add `--dry-run`/`--check` exemption to patch rule (lines 144-145) |
| `tests/test-bash-guard.sh` | Add Test 24 for patch flag-awareness |

## Verification

1. Run `tests/test-bash-guard.sh` — all existing tests must pass, new Test 24 must pass.
2. Manual spot-check: `patch --dry-run < some.patch` returns exit 0 (allowed) with gate closed.

## Risks

- **Low**: A command containing `--dry-run` as a *filename argument* (e.g., `patch --dry-run`) could theoretically be a file named `--dry-run`, but this is an extreme edge case and the same pattern is used for other flag checks in the codebase.
- No behavioral change when gate is open (all commands allowed regardless).

## Batch notes

Total: 2 files, ~8 lines changed, ~8 lines added. Straightforward single-hypothesis fix.

## 批注区
