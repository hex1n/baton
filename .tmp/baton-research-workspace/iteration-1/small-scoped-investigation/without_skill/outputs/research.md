# Bash-Guard Hook: Blocking Logic Research

## Summary

`bash-guard.sh` (v3.3) is a **PreToolUse** hook that intercepts every Bash tool invocation. It decides whether to **allow** (exit 0) or **block** (exit 2) commands based on two factors: (1) whether the plan gate is open, and (2) whether the command matches a known write pattern.

## Decision Flow

### Step 1: Gate Check (lines 20-31)

The hook first checks if the plan gate is open:

1. Calls `resolve_plan_name` and `find_plan` (from `lib/common.sh` -> `lib/plan-parser.sh`) to locate the active plan file by walking up from the working directory.
2. If a plan is found AND `<!-- BATON:GO -->` is present in it -> **exit 0 (allow everything)**.
3. Special case: if multiple plan files exist and `BATON_PLAN` env var is not set, the gate is treated as **closed** even if one plan has `BATON:GO`.
4. If no plan exists, or the plan lacks `BATON:GO` -> gate is closed, proceed to command inspection.

### Step 2: Command Extraction (lines 33-51)

The command string is extracted from stdin JSON (`tool_input.command` field) using `jq` or an `awk` fallback. If no command is found (empty stdin or missing field), the hook allows (exit 0).

### Step 3: Quote Stripping (lines 54-86)

Before pattern matching, the `strip_quoted_segments()` function removes all content inside single and double quotes from the command. This prevents false positives where write-related words appear only inside quoted strings (e.g., `echo 'cp src dst'` is allowed because `cp src dst` is inside quotes and gets stripped).

The stripped version is stored in `_SCAN_CMD`, and pattern matching runs against this stripped version (except for `python -c` write detection, which checks the raw `CMD`).

### Step 4: Blocked Patterns (lines 100-152)

These patterns cause **exit 2 (block)**:

| Category | Pattern / Detection | Reason String |
|---|---|---|
| **Heredoc + redirect** | `<<[-]?...>file` regex on `_SCAN_CMD` | `heredoc with redirect` |
| **Output redirection** | `[012]?>>[?] file` regex (the `has_output_redirection` function) | `output redirection` |
| **tee** | `tee` as a command token (standalone or after `;`, `&`, `\|`, `(`) | `tee (write sink)` |
| **sed -i** | Substring match on `_SCAN_CMD` | `sed -i (in-place edit)` |
| **perl -pi** | Substring match on `_SCAN_CMD` | `perl -pi (in-place edit)` |
| **python -c with write** | `python[3] -c` on stripped + `open(... 'w'` or `'a'` on raw `CMD` | `python -c with file write` |
| **cp** | Command token check via `_is_cmd_token` | `cp (file copy)` |
| **mv** | Command token check | `mv (file move)` |
| **install** | Command token check | `install (file install)` |
| **truncate** | Command token check | `truncate` |
| **patch** | Command token check | `patch (in-place diff application)` |

### Step 5: Warn-Only Patterns (lines 154-162)

These emit a stderr warning but **still allow** (exit 0):

- `rm` as a command token
- `touch ` as a substring of `_SCAN_CMD`

## Key Helper: `_is_cmd_token` (lines 96-98)

This function checks if a word appears as a command (not just a substring). It uses:

```
grep -qE "(^|[;&|(]\s*)(/[^ ]*/)?$1(\s|$)"
```

This matches the token:
- At the start of the command, OR after `;`, `&`, `|`, or `(`
- Optionally preceded by a path prefix like `/bin/` or `/usr/bin/`
- Followed by whitespace or end-of-string

## Common False Positive Scenarios

Based on the logic, likely false positive triggers:

1. **Output redirection in non-write contexts**: The `has_output_redirection` regex `(^|[^<])([012]?>>?|>>?)[[:space:]]*[^&[:space:]]` is broad. Commands like `cmd 2>&1` should NOT match (the `[^&[:space:]]` excludes `&`), but edge cases with unusual spacing or fd numbers could trigger it.

2. **`cp`, `mv`, `install` used for read-only inspection**: e.g., `cp --help`, `mv --help`, `install --help` would all be blocked because `_is_cmd_token` only checks that the command name is present, not what arguments follow.

3. **`tee` used without file output**: `tee /dev/stderr` or `tee` with no arguments would still be blocked.

4. **`patch --dry-run`**: Would be blocked even though it doesn't modify files.

5. **`sed -i` appearing as a substring in other contexts**: The check is a simple substring match (`*"sed -i"*`), so a command like `grep "sed -i" docs.txt` would be blocked because after quote stripping, `sed -i` might still appear depending on quote type.

6. **`install` as part of `npm install`, `pip install`, etc.**: The `_is_cmd_token` regex checks for the word at command position. `npm install` should NOT match because `install` comes after `npm` (not at start or after `;|&(`). But `pip install` or other tools where `install` appears as a subcommand might match if preceded by a pipe or semicolon.

## Fail-Open Behavior

- If `lib/common.sh` is missing -> exit 0 (allow)
- If stdin is empty or command extraction fails -> exit 0 (allow)
- If an unexpected error occurs -> trap catches it and exits 0 (allow)

## Files Referenced

- `.baton/hooks/bash-guard.sh` (main hook, 164 lines)
- `.baton/hooks/lib/common.sh` (shared functions, sources plan-parser.sh)
- `.baton/hooks/lib/plan-parser.sh` (plan discovery + `parser_has_go`)
- `.baton/hooks/manifest.conf` (maps `PreToolUse:Bash` -> `bash-guard`)
- `tests/test-bash-guard.sh` (23 test groups, covers all patterns)
