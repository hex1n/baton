# Plan: Fix bash-guard false positive on `patch --dry-run`

**Sizing**: Small

## Problem

The bash-guard hook blocks `patch` as a file-mutation command (line 144 of `bash-guard.sh`), but `patch --dry-run` does not modify any files -- it only tests whether the patch would apply cleanly. This is a false positive: users running `patch --dry-run` to inspect applicability are blocked unnecessarily when the plan gate is closed.

## Fix

Add flag-awareness to the `patch` rule in `bash-guard.sh`. Before blocking `patch`, check whether `--dry-run` is present in the command. If it is, skip the block.

The check must operate on the quote-stripped `$_SCAN_CMD` (same as the existing `_is_cmd_token` match), since `--dry-run` would appear outside of quotes in normal usage.

**Predicted diff** (lines 144-146 of `.baton/hooks/bash-guard.sh`):

Before:
```bash
elif [ -z "$_blocked" ] && _is_cmd_token 'patch'; then
    _blocked="patch (in-place diff application)"
fi
```

After:
```bash
elif [ -z "$_blocked" ] && _is_cmd_token 'patch'; then
    case "$_SCAN_CMD" in
        *--dry-run*) ;;  # patch --dry-run is read-only
        *) _blocked="patch (in-place diff application)" ;;
    esac
fi
```

The `case` pattern matches `--dry-run` anywhere in the command string (after quote stripping), which is safe because:
- `--dry-run` is unambiguous as a flag (not a filename or other token) in practice
- Quote stripping already removed any `--dry-run` that appears inside string literals (e.g., `echo '--dry-run'` would not match since it's stripped) -- ✅ verified by reading `strip_quoted_segments` at lines 54-86

## Alternatives

1. **Regex match in `_is_cmd_token` itself** (e.g., a second parameter for "safe flags"): Rejected because it over-engineers `_is_cmd_token` for a single use case. If more commands need flag-awareness later, this can be generalized then.
2. **Separate `_is_cmd_token_with_flag` helper**: Same over-engineering concern. A local `case` statement is simpler and clearer for one command.

## Write Set

| File | Change |
|------|--------|
| `.baton/hooks/bash-guard.sh` | Add `--dry-run` exemption inside the `patch` block (lines 144-146) |
| `tests/test-bash-guard.sh` | Add test assertions: `patch --dry-run` allowed, `patch` still blocked, `patch --dry-run` with path-qualified `/usr/bin/patch` allowed |

## Verify

1. Run `bash tests/test-bash-guard.sh` -- all existing tests pass (no regressions)
2. New test assertions confirm:
   - `patch file.patch` is still blocked (gate closed)
   - `patch --dry-run file.patch` is allowed
   - `/usr/bin/patch --dry-run file.patch` is allowed
   - `patch --dry-run < diff.patch` is allowed

## Risks

- **Low**: The `case` pattern `*--dry-run*` could theoretically match a filename containing `--dry-run` (e.g., `patch some--dry-run-file`). This is negligible in practice -- such filenames are pathological, and quote stripping would have already removed any quoted occurrence.

## 批注区

<!--
Processing rules:
- Read underlying evidence before responding
- Do not rewrite a challenge into a weaker one
- If accepted: update the relevant section
- If rejected: explain with evidence
- If unresolved: keep as ❓
- Impact = "blocks next phase" → document goes BLOCKED until resolved
-->

<!--
Per annotation, copy this block:

### [Annotation N]
- **Trigger / 触发点**:
- **Intent as understood / 理解后的意图**:
- **Response / 回应**:
- **Status**: ✅ / ❌ / ❓
- **Impact**: none / clarification only / affects conclusions / blocks next phase
-->
