# How does the write-lock mechanism work across IDE adapters?

## Overview

```
                          write-lock.sh (core engine)
                          exit 0 = allow, exit 2 = block
                                    |
            +-------------------------+-------------------------+
            |                         |                         |
      Claude Code / Factory       Cursor                     Codex
      (direct invocation)       (adapter translates)       (NO write-lock)
            |                         |                         |
    dispatch.sh routes          dispatch-cursor.sh         dispatch-codex.sh
    PreToolUse -> write-lock    maps camelCase events      SessionStart/Stop only
    exit 2 = hard block         exit 2 -> JSON deny        advisory guidance
    stderr shown to AI          stdout JSON to IDE         no PreToolUse at all
```

**Short answer:** Write-lock fires as a hard block in Claude Code and Cursor, but does NOT fire in Codex at all. Codex has no PreToolUse hook support, so write-lock enforcement is entirely absent there. The common contract for a new adapter is: (1) invoke `dispatch.sh` with the correct PascalCase event name, (2) translate exit code 2 into the IDE's native block signal, and (3) pass stdin JSON containing `tool_input.file_path` and optionally `cwd`.

## Findings

### The core write-lock engine

`write-lock.sh` (`verified: .baton/hooks/write-lock.sh`) is IDE-agnostic. It:

1. Reads the target file path from `BATON_TARGET` env var, or from stdin JSON field `.tool_input.file_path`
2. Always allows markdown files (`*.md`, `*.mdx`) — but blocks governance marker injection (`BATON:GO`, `BATON:OVERRIDE`) in markdown
3. Always allows files outside the Baton project root
4. Walks up the directory tree to find a plan file (`plan.md` or `plan-*.md`)
5. Checks for `<!-- BATON:GO -->` marker in the plan
6. If GO is present, enforces write-set (files listed in plan's `## Todo` section)
7. Exit 0 = allow, exit 2 = block. On unexpected errors, it fails open (exit 0 + warning)

Key design decisions:
- **Fail-open** on unexpected errors and missing targets (`verified: write-lock.sh:13-14, :49-54`)
- **Fail-closed** on multi-plan ambiguity (`verified: write-lock.sh:142-146`)
- **jq with awk fallback** for JSON parsing (`verified: write-lock.sh:35-45`)
- **Emergency bypass** via `BATON_BYPASS=1` (`verified: write-lock.sh:17-20`)

### IDE adapter comparison

| Dimension | Claude Code / Factory | Cursor | Codex |
|-----------|----------------------|--------|-------|
| **Write-lock fires?** | Yes - hard block | Yes - hard block (via adapter) | **No** |
| **Hook event** | `PreToolUse` (PascalCase) | `preToolUse` (camelCase) | N/A - no PreToolUse support |
| **Config file** | `.claude/settings.json` | `.cursor/hooks.json` | `.codex/hooks.json` |
| **Invocation path** | `run-hook.cmd` -> `dispatch.sh` -> `write-lock.sh` | `dispatch-cursor.sh` -> `dispatch.sh` -> `write-lock.sh` | `dispatch-codex.sh` -> `dispatch.sh` (SessionStart/Stop only) |
| **Block signal format** | exit code 2, stderr shown to AI | JSON: `{"decision":"block","reason":"..."}` on stdout | N/A |
| **Allow signal format** | exit code 0, stdout JSON `hookSpecificOutput` | JSON: `{"decision":"allow"}` on stdout | N/A |
| **Hooks available** | 9/9 (all events) | 6/9 (reduced) | 2/9 (SessionStart + Stop only) |
| **Capability tier** | Full protection | Core protection (reduced enforcement) | Rules + guidance only |
| **Write-set enforcement** | Yes (via write-lock.sh) | Yes (same engine) | No |
| **Governance marker guard** | Yes | Yes | No |

### How each adapter invokes write-lock

**Claude Code** (`verified: .claude/settings.json`):
- Settings.json registers hooks with `run-hook.cmd` polyglot wrapper
- `run-hook.cmd` calls `dispatch.sh` with the event name
- `dispatch.sh` reads `manifest.conf` to find `write-lock` for `PreToolUse:Write,Edit,MultiEdit,CreateFile,NotebookEdit`
- Sources `write-lock.sh` in a subshell
- Exit code propagates directly to Claude Code (exit 2 = block)
- Stdin JSON is buffered once by dispatch.sh into `BATON_STDIN` env var so all hooks can read it

**Cursor** (`verified: .baton/adapters/cursor/dispatch.sh`):
- `.cursor/hooks.json` registers `bash .baton/adapters/cursor/dispatch.sh preToolUse` with matcher `Write`/`Edit`/`Bash`
- `dispatch-cursor.sh` maps camelCase -> PascalCase: `preToolUse` -> `PreToolUse`
- Calls `dispatch.sh` which runs `write-lock.sh`
- Translates exit code: exit 2 -> `{"decision":"block","reason":"..."}`, exit 0 -> `{"decision":"allow"}`
- There is also an **older** `adapter.sh` that calls write-lock.sh directly (not through dispatch.sh) — the current setup.sh generates configs using `dispatch.sh` (`verified: setup.sh:287-288`)

**Codex** (`verified: .baton/adapters/codex/adapter.sh:6-9, dispatch.sh`):
- `.codex/hooks.json` only registers `SessionStart` and `Stop` events
- `dispatch-codex.sh` routes these to `dispatch.sh` with stdin closed (`</dev/null`) to prevent hangs
- **Write-lock is explicitly not available** — adapter.sh comments state: "Hard gates (write-lock, bash-guard) are not available on Codex"
- Prepends a tier header: `[Baton capability: rules + guidance only (Codex)]`
- Codex relies on its own sandbox and human approval controls instead

### The common adapter contract

For a new IDE adapter, based on the patterns in Cursor and Codex adapters:

1. **Event name mapping**: Map IDE's native event names to dispatch.sh PascalCase names (`SessionStart`, `PreToolUse`, `PostToolUse`, etc.)
2. **Invoke dispatch.sh**: Call `bash .baton/hooks/dispatch.sh <PascalCase-event>` with stdin piped through (or closed if the IDE doesn't send EOF)
3. **Translate exit codes**: Map exit 0 -> IDE's "allow" signal, exit 2 -> IDE's "block" signal
4. **Pass stdin JSON**: The JSON must contain at minimum `tool_input.file_path` for write-lock to resolve the target. Optional: `cwd` for plan discovery, `tool_name` for dispatch matcher filtering.
5. **Declare capability tier**: Prefix output with a tier statement (e.g., `[Baton capability: ...]`) so the AI knows enforcement level
6. **Handle EOF/stdin**: Some IDEs don't send EOF on stdin — use `</dev/null` if needed (`verified: codex/dispatch.sh:16,19`)
7. **Register in setup.sh**: Add a `generate_<ide>_hooks()` function and a case in the main loop

**Stdin JSON shape expected by write-lock.sh:**
```json
{
  "tool_name": "Write",          // used by dispatch.sh for matcher filtering
  "tool_input": {
    "file_path": "src/app.ts",   // REQUIRED for write-lock target resolution
    "content": "..."             // checked for governance markers on .md files
  },
  "cwd": "/path/to/project/src"  // optional: used for plan discovery walk-up
}
```

**Exit code protocol:**
```
0  = allow (operation proceeds)
2  = block (operation denied, stderr contains reason)
other = warning (write-lock fails open, dispatch.sh logs warning)
```

### Behavioral differences that matter

1. **Cursor's older adapter.sh vs dispatch.sh**: The `adapter.sh` file at `.baton/adapters/cursor/adapter.sh` calls write-lock.sh directly, while `dispatch.sh` routes through the dispatch system. Setup.sh generates configs pointing to `dispatch.sh` (`verified: setup.sh:287`). The older adapter.sh appears to be a legacy path.

2. **Cursor uses "deny" in adapter.sh but "block" in dispatch.sh**: The legacy `adapter.sh` outputs `{"decision":"deny"}` (`verified: adapter.sh:34`), while the current `dispatch.sh` outputs `{"decision":"block"}` (`verified: cursor/dispatch.sh:30`). This could be a Cursor protocol version difference or a bug.

3. **Codex stdin hang risk**: Codex may not send EOF on stdin, so both Codex adapter files explicitly close stdin with `</dev/null` (`verified: codex/dispatch.sh:16,19`). A new adapter should consider whether the IDE sends EOF.

4. **Write-set enforcement happens inside write-lock.sh**: It is not adapter-specific. If write-lock fires (i.e., the IDE supports PreToolUse), write-set enforcement is automatic. No adapter action needed.

5. **Governance marker protection**: Equally IDE-agnostic — write-lock.sh checks markdown writes for `BATON:GO`/`BATON:OVERRIDE` content regardless of adapter.

## Self-Challenge

**Weakest conclusion:** The claim that "block" vs "deny" in the two Cursor adapter files is a potential issue. I verified the string values in both files, but I did not verify which one Cursor actually reads in production — it could be that Cursor accepts both, or that only `dispatch.sh` is wired in practice. The test suite (`test-adapters-v2.sh`) tests the older `adapter.sh` and checks for `"deny"`, not `"block"`, suggesting the test suite may be stale relative to the current dispatch.sh path.

**What I skipped:** I did not trace `run-hook.cmd` (the polyglot Windows/bash wrapper) to confirm it delegates correctly to `dispatch.sh` on all platforms. I also did not verify the actual Cursor hook protocol documentation to confirm whether "deny" or "block" is the correct value.

**What would disprove the main conclusion:** If Cursor's `preToolUse` hook doesn't actually receive write tool invocations with `file_path` in the stdin JSON, write-lock would fail to resolve the target and fail-open silently — meaning Cursor's "hard block" would be weaker than claimed.

## Open Questions

1. **"deny" vs "block" in Cursor adapter**: Which is the correct Cursor protocol value? The legacy adapter.sh uses `"deny"`, the new dispatch.sh uses `"block"`. Does Cursor accept both? This should be verified against Cursor's current documentation.
2. **run-hook.cmd behavior**: How does the polyglot wrapper work on non-Windows systems? Is it tested?
3. **Cursor hook coverage gap**: `setup.sh` registers Cursor hooks for `Write`, `Edit`, and `Bash` tools but NOT for `MultiEdit`, `CreateFile`, or `NotebookEdit`. Claude Code covers all five write tools. Is this intentional (Cursor doesn't have those tools?) or a gap?
4. **New adapter minimum viable**: For a new IDE that supports PreToolUse-equivalent hooks, the minimum adapter is ~15 lines: event name mapping + dispatch.sh invocation + exit code translation. For an IDE without PreToolUse, the adapter can only provide SessionStart/Stop guidance (like Codex).
