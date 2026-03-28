# How does bash-guard.sh decide what to block?

## Overview

```
                    Command arrives (stdin JSON)
                              |
                    +---------v----------+
                    | Gate open?         |
                    | (BATON:GO in plan) |
                    +----+----------+----+
                         |          |
                       YES          NO
                         |          |
                      exit 0    +---v-----------+
                     (allow)    | Strip quotes   |
                                | from command   |
                                +---+-----------+
                                    |
                          +---------v----------+
                          | Match block rules  |
                          | (Phase 1)          |
                          +----+----------+----+
                               |          |
                            MATCH       NO MATCH
                               |          |
                            exit 2    +---v----------+
                           (block)    | Match warns  |
                                      | (rm, touch)  |
                                      +---+----------+
                                          |
                                       exit 0
                                      (allow)
```

bash-guard.sh is a PreToolUse hook for Bash commands. It blocks explicit file-write shell patterns when the plan gate is closed (no `BATON:GO` marker). When the gate is open, everything is allowed.

## Findings

### Gate check (lines 24-31)

The guard first looks for a plan file and checks for `BATON:GO`. If the gate is open, it exits 0 immediately (all commands allowed). Special case: if multiple plans exist and `BATON_PLAN` env var is not set, it treats the gate as closed even if one plan has `BATON:GO`. (verified: read bash-guard.sh:24-31)

### Quote stripping (lines 54-86)

Before pattern matching, the guard strips content inside single and double quotes from the command string. This prevents false positives like `echo 'cp src dst'` from being blocked -- the `cp` is inside quotes, so it's removed before scanning. The stripped version is stored in `_SCAN_CMD`. (verified: read bash-guard.sh:54-86, test 22 confirms)

### Command token matching: `_is_cmd_token` (lines 96-98)

The helper `_is_cmd_token` checks if a token appears as an actual command -- at the start of the line or after `;`, `&`, `|`, or `(`. It also matches path-qualified variants like `/bin/cp` or `/usr/bin/tee`.

Pattern: `(^|[;&|(]\s*)(/[^ ]*/)?$1(\s|$)`

This means the token must be in "command position" (not an argument to another command). (verified: read bash-guard.sh:96-98)

### Block rules (Phase 1) -- the complete list

| Rule | Detection method | Line(s) | Example blocked |
|------|-----------------|---------|-----------------|
| Heredoc + redirect | Regex: `<<[-]?[[:space:]]*[^>]*>[[:space:]]*[^&[:space:]]` | 102-103 | `cat <<EOF > file.txt` |
| Output redirection | `has_output_redirection` regex: `(^\|[^<])([012]?>>?\|>>?)[[:space:]]*[^&[:space:]]` | 104-105, 88-90 | `echo x > file`, `cmd 2>> log` |
| tee | `_is_cmd_token 'tee'` | 109-111 | `cat file \| tee out.txt` |
| sed -i | Substring match on `_SCAN_CMD` | 116-117 | `sed -i 's/a/b/' file` |
| perl -pi | Substring match on `_SCAN_CMD` | 118-119 | `perl -pi -e 's/x/y/' file` |
| python -c write | `python -c` or `python3 -c` + `open(` with `'w'` or `'a'` mode in raw `$CMD` | 124-133 | `python -c "open('f','w').write('x')"` |
| cp | `_is_cmd_token 'cp'` | 136-137 | `cp src dst` |
| mv | `_is_cmd_token 'mv'` | 138-139 | `mv old new` |
| install | `_is_cmd_token 'install'` | 140-141 | `install -m 644 src dst` |
| truncate | `_is_cmd_token 'truncate'` | 142-143 | `truncate -s 0 file` |
| **patch** | **`_is_cmd_token 'patch'`** | **144-145** | `patch file.c < diff.patch` |

Warn-only (exit 0 but stderr warning): `rm`, `touch`.

### The `patch --dry-run` false positive (the specific question)

The `patch` rule at line 144-145 uses `_is_cmd_token 'patch'`, which blocks **any** use of `patch` in command position -- regardless of flags. There is **no flag-aware logic** anywhere in the guard.

```bash
# Line 144-145:
elif [ -z "$_blocked" ] && _is_cmd_token 'patch'; then
    _blocked="patch (in-place diff application)"
fi
```

`patch --dry-run` (or `patch --check`) does **not** modify any files -- it only tests whether the patch would apply cleanly. But the guard treats it identically to `patch` without flags, blocking it unconditionally. (verified: read bash-guard.sh:144-145)

This is the same pattern used for `cp`, `mv`, `install`, and `truncate` -- none of these have flag-aware exceptions either. But `patch --dry-run` is a particularly common read-only usage that creates a real false positive, since it's a standard way to **verify** a patch before applying it.

### How to fix it

The fix would go between lines 144 and 145. Before declaring `_blocked="patch ..."`, check whether the command contains `--dry-run` or `--check` (the two standard read-only flags for `patch`). For example:

```bash
elif [ -z "$_blocked" ] && _is_cmd_token 'patch'; then
    case "$_SCAN_CMD" in
        *--dry-run*|*--check*)
            : # read-only patch invocation, allow
            ;;
        *)
            _blocked="patch (in-place diff application)"
            ;;
    esac
fi
```

Note: the check uses `_SCAN_CMD` (quote-stripped), so `--dry-run` inside a quoted string argument would be stripped and not matched -- but that's the correct behavior since `--dry-run` as a flag would not be inside quotes.

The test file (`tests/test-bash-guard.sh`) has **zero** test cases for `patch` -- neither blocked nor allowed. Any fix should add tests for both `patch file < diff` (blocked) and `patch --dry-run file < diff` (allowed). (verified: grep found no "patch" in test-bash-guard.sh)

## Open Questions

- Should `cp --no-clobber` or `cp -n` (which refuses to overwrite) also be exempted? The same flag-awareness pattern could apply to other commands, but the question only asks about `patch`.
- The `--dry-run` check via substring match (`*--dry-run*`) could theoretically match a filename containing `--dry-run`. This is unlikely enough to be acceptable, but a more precise regex through `_is_cmd_token`-style matching would be more robust.

I didn't check whether `patch` with `-p` flag (strip path prefix) alone should still be blocked -- it should, since `-p` doesn't prevent writes. Only `--dry-run` and `--check` are read-only modes.
