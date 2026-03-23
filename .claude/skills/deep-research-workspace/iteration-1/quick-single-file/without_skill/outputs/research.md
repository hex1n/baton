# Research: How bash-guard.sh Decides What to Block

## Summary

`bash-guard.sh` is a PreToolUse hook (v3.3) that intercepts Bash tool invocations and blocks explicit file-write patterns when the "plan gate" is closed (no `<!-- BATON:GO -->` marker in the plan). When the gate is open, all commands pass through.

The `patch --dry-run` false positive occurs because `patch` is unconditionally listed in the block list at line 144-145 with no flag-awareness -- any command where `patch` appears as a command token is blocked, regardless of whether `--dry-run` makes it read-only.

## Gate Logic (lines 23-31)

1. If a plan file is found AND contains `BATON:GO` --> gate open --> `exit 0` (allow everything).
2. If multiple plan files exist and `BATON_PLAN` env var is not set --> gate treated as closed (ambiguity).
3. If no plan or no `BATON:GO` --> gate closed --> proceed to command inspection.

## Command Extraction (lines 33-51)

The command string is extracted from stdin JSON at `tool_input.command` (using `jq` if available, otherwise `awk`). If no command is found, `exit 0` (allow).

## Quote Stripping (lines 54-86)

Before pattern matching, `strip_quoted_segments()` removes content inside single and double quotes from the command string. This prevents false positives from commands like `echo 'cp a b'` -- the `cp` inside quotes is stripped, so it is not detected as a command token. All pattern matching below operates on `_SCAN_CMD` (the quote-stripped version), except for the `python -c` write check which also inspects the raw `CMD`.

## Blocking Rules (Phase-1 Block List, lines 100-146)

These patterns cause `exit 2` (block):

| Rule | Detection Method | Line(s) |
|------|-----------------|---------|
| **Heredoc with redirect** | Regex: `<<[-]?[space]*[^>]*>[space]*[^&space]` | 102-103 |
| **Output redirection** | Regex via `has_output_redirection()`: `([012]?>>?\|>>?)[space]*[^&space]` | 104-105 |
| **tee** (standalone or piped) | `_is_cmd_token 'tee'` | 109-111 |
| **sed -i** | Substring match on `_SCAN_CMD` | 116-117 |
| **perl -pi** | Substring match on `_SCAN_CMD` | 118-119 |
| **python -c with file write** | `_SCAN_CMD` contains `python -c` or `python3 -c`, AND raw `CMD` contains `open(` with `'w'`/`'a'` mode | 124-133 |
| **cp** | `_is_cmd_token 'cp'` | 136-137 |
| **mv** | `_is_cmd_token 'mv'` | 138-139 |
| **install** | `_is_cmd_token 'install'` | 140-141 |
| **truncate** | `_is_cmd_token 'truncate'` | 142-143 |
| **patch** | `_is_cmd_token 'patch'` | 144-145 |

### How `_is_cmd_token` works (lines 96-98)

```bash
_is_cmd_token() {
    printf '%s\n' "$_SCAN_CMD" | grep -qE "(^|[;&|(]\s*)(/[^ ]*/)?$1(\s|$)"
}
```

It checks whether the given name appears as a "command position" token -- at the start of the line, or after `;`, `&`, `|`, or `(`. It also matches path-qualified variants like `/usr/bin/patch`. It does NOT examine any flags or arguments after the command name.

## Warn-Only Rules (lines 154-162)

These emit a warning to stderr but allow the command (`exit 0`):

- **rm** -- "destructive -- verify intent"
- **touch** -- "allowed, but verify intent"

## The `patch --dry-run` False Positive

**Root cause**: Line 144-145 blocks `patch` unconditionally via `_is_cmd_token 'patch'`. The guard does not inspect flags at all. `patch --dry-run` (or `patch --check`) performs no file modification -- it only tests whether a patch applies cleanly -- but the guard blocks it anyway.

### Fix Approaches

**Approach A -- Flag whitelist**: After matching `patch` as a command token, check whether `--dry-run` or `--check` is present in the arguments. If so, allow. This is analogous to how `python -c` has a secondary content check before blocking.

```bash
# Replace lines 144-145 with:
elif [ -z "$_blocked" ] && _is_cmd_token 'patch'; then
    case "$_SCAN_CMD" in
        *"--dry-run"*|*"--check"*) ;;  # read-only modes → allow
        *) _blocked="patch (in-place diff application)" ;;
    esac
fi
```

**Approach B -- Broader read-only flag recognition**: Define a helper that checks for well-known dry-run/check flags across multiple commands. More future-proof but higher scope.

**Recommendation**: Approach A is minimal and directly addresses the false positive. The flag check should operate on `_SCAN_CMD` (quote-stripped) so that `--dry-run` inside a quoted string does not cause a false negative.

## Key Files

- `.baton/hooks/bash-guard.sh` -- the guard script (165 lines)
- `.baton/hooks/lib/common.sh` -- shared functions (sources plan-parser.sh)
- `tests/test-bash-guard.sh` -- 23 test groups, no existing test for `patch`

## 批注区
