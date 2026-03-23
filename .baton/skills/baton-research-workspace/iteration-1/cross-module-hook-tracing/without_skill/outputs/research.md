# Write-Lock Mechanism Across IDE Adapters

## Research Question

How does the write-lock mechanism work across the different IDE adapters (Claude Code, Cursor, Codex)? Does it actually fire in all IDEs? What are the behavioral differences? What is the common contract for adding a new IDE adapter?

---

## Architecture Overview

The write-lock system uses a **layered architecture** with one core script and thin adapter layers:

```
write-lock.sh (core, exit 0/2)
    |
    +-- Claude Code / Factory AI: dispatched via dispatch.sh (native support)
    |
    +-- Cursor: adapter-cursor.sh translates exit codes to JSON protocol
    |
    +-- Codex: NO write-lock (advisory-only hooks, no PreToolUse event)
```

**Core script**: `.baton/hooks/write-lock.sh` (v3.1)
**Dispatch layer**: `.baton/hooks/dispatch.sh` routes events via `manifest.conf`
**Platform shim**: `.baton/hooks/run-hook.cmd` (polyglot cmd/bash wrapper for Windows)

---

## Per-IDE Analysis

### Claude Code / Factory AI — Full Protection

**Does write-lock fire?** Yes. Hard block via `PreToolUse` hook.

**Configuration** (`.claude/settings.json`):
- Hook event: `PreToolUse` with matcher `Edit|Write|MultiEdit|CreateFile|NotebookEdit`
- Invocation: `run-hook.cmd PreToolUse` -> `dispatch.sh PreToolUse` -> `write-lock.sh`

**Signal flow**:
1. Claude Code sends JSON on stdin with `tool_name` and `tool_input.file_path`
2. `dispatch.sh` buffers stdin as `BATON_STDIN`, extracts `tool_name`, matches against `manifest.conf`
3. `write-lock.sh` reads `BATON_TARGET` env or parses `tool_input.file_path` from stdin JSON
4. Exit code 0 = allow, exit code 2 = block (hard gate)
5. On allow with BATON:GO, emits `hookSpecificOutput` JSON with `additionalContext` on stdout

**Evidence**: Settings at `.claude/settings.json` lines 9-28 configure the PreToolUse matcher. Test suite `tests/test-write-lock.sh` (530 lines, ~45 assertions) exercises all code paths. Manifest at `.baton/hooks/manifest.conf` line 4 maps `PreToolUse:Write,Edit,MultiEdit,CreateFile,NotebookEdit:write-lock`.

**Behavioral details**:
- Markdown files (`.md`, `.MD`, `.markdown`, `.mdx`) always allowed but checked for governance marker injection (BATON:GO/BATON:OVERRIDE written by AI is blocked)
- `baton-tasks/` markdown files exempt from governance marker check
- Files outside the Baton project root always allowed
- No plan file found -> block with research phase guidance
- Multiple plan files without `BATON_PLAN` set -> fail-closed (ambiguous)
- Plan exists but no `<!-- BATON:GO -->` -> block with annotation cycle guidance
- Plan has GO -> check write-set enforcement (target must be in `Files:` field of `## Todo` items)
- `BATON_BYPASS=1` env -> immediate allow with warning
- No target determinable -> fail-open with warning
- Unexpected errors (trap) -> fail-open with warning
- jq preferred for JSON parsing; awk fallback available

### Cursor — Core Protection (via Adapter)

**Does write-lock fire?** Yes. Hard block via `preToolUse` hook, translated by adapter.

**Adapter**: `.baton/adapters/cursor/adapter.sh` (37 lines)

**Signal flow**:
1. Cursor sends JSON on stdin with `tool_input.file_path`
2. `adapter-cursor.sh` invokes `write-lock.sh` directly (not through dispatch.sh)
3. Captures combined stdout+stderr output and exit code
4. Translates to Cursor JSON protocol:
   - Exit 0 -> `{"decision":"allow"}` (with optional `context` field containing `additionalContext`)
   - Exit 2 -> `{"decision":"deny","reason":"..."}` (reason = escaped stderr output)
5. Capability tier statement prepended: `[Baton capability: reduced enforcement (Cursor)]`

**Alternative path**: `.baton/adapters/cursor/dispatch.sh` (34 lines) provides a dispatch-based path that:
- Maps Cursor camelCase event names to PascalCase (e.g., `preToolUse` -> `PreToolUse`)
- Routes through `dispatch.sh` for full manifest-based routing
- Translates exit code 2 -> `{"decision":"block","reason":"..."}`

**Note**: The adapter and dispatch files use slightly different deny key names: `adapter.sh` uses `"deny"` while `dispatch.sh` uses `"block"`. Both patterns work with Cursor.

**Behavioral differences from Claude Code**:
- Missing hooks: `post-write-tracker` (no write-set drift warning), `stop-guard` (no session-end reminders), `completion-check`, `failure-tracker`, `retrospective enforcement`
- Available hooks: `write-lock` (hard block), `phase-guide`, `bash-guard`, `subagent-context`, `pre-compact`
- Adapter adds capability tier labeling so the AI knows enforcement level

**Evidence**: Adapter code at `.baton/adapters/cursor/adapter.sh`. Test suite `tests/test-adapters.sh` tests 1-3 verify allow/deny JSON output. Test suite `tests/test-adapters-v2.sh` tests 1-4 verify JSON protocol including capability tier statement and write-gate context.

### Codex — Rules Guidance Only (No Write-Lock)

**Does write-lock fire?** No. Codex has no `PreToolUse` hook event.

**Adapter**: `.baton/adapters/codex/adapter.sh` (63 lines), `.baton/adapters/codex/dispatch.sh` (35 lines)

**What IS available**:
- `SessionStart` (experimental): `phase-guide.sh` runs, output redirected from stderr to stdout (Codex reads stdout as DeveloperInstructions)
- `Stop` (experimental): `stop-guard.sh` runs off-channel, message saved to `.codex/stop-hook.message.txt`, valid JSON `{"continue":false}` emitted
- Capability tier header prepended: `[Baton capability: rules + guidance only (Codex)] Hard gates (write-lock, bash-guard) are not available.`

**Key limitation**: The adapter explicitly comments that write-lock and bash-guard are "not available on Codex" (adapter.sh line 8-11). Codex's sandbox and human approval controls provide separate safety layers outside Baton's scope.

**Evidence**: Adapter code at `.baton/adapters/codex/adapter.sh` lines 7-11 explicitly document the unavailability. IDE capability matrix at `docs/ide-capability-matrix.md` line 11 confirms "None" for write-lock.

---

## Write-Lock Decision Logic (Common Core)

The core `write-lock.sh` implements this decision tree regardless of IDE:

```
1. BATON_BYPASS=1?              -> ALLOW (with warning)
2. Can't determine target?      -> ALLOW (fail-open, with warning)
3. Target is markdown?          -> Check governance markers, then ALLOW
4. Target outside project root? -> ALLOW
5. No plan file found?          -> BLOCK ("complete research first")
6. Multiple plans, no BATON_PLAN? -> BLOCK ("ambiguous")
7. Plan has <!-- BATON:GO -->?  -> Check write-set, then ALLOW
8. Plan exists, no GO?          -> BLOCK ("annotation cycle in progress")
```

Write-set enforcement (step 7 detail):
- If plan `## Todo` items have `Files:` fields, target must appear in that set
- If no write set defined, all files allowed when GO is present

---

## Common Contract for a New Adapter

Based on the existing adapters, a new IDE adapter must handle these concerns:

### 1. Protocol Translation

The core contract is:
- **Input**: write-lock.sh receives target file path via `BATON_TARGET` env var or JSON on stdin (`tool_input.file_path`)
- **Output**: exit code 0 = allow, exit code 2 = block, stderr = human-readable messages, stdout = hookSpecificOutput JSON (on allow)

An adapter must translate between the IDE's native protocol and this contract:

| IDE Protocol | Adapter Responsibility |
|---|---|
| Exit code (Claude Code, Windsurf, Augment, Kiro) | None needed; core script works directly |
| JSON response (Cursor) | Translate exit code to `{"decision":"allow/deny"}` |
| JSON response (Cline) | Translate exit code to `{"cancel":true/false}` |
| JSON response (GitHub Copilot) | Translate exit code to `{"permissionDecision":"allow/deny"}` |

### 2. Event Name Mapping

Different IDEs use different casing and naming:
- Claude Code: `PreToolUse` (PascalCase)
- Cursor: `preToolUse` (camelCase)
- Windsurf: `pre_write_code` (snake_case)

The Cursor dispatch adapter (`dispatch-cursor.sh`) shows the mapping pattern (lines 12-21).

### 3. Stdin Handling

Some IDEs may not send EOF on stdin, causing `cat` to hang. The Codex adapter handles this by closing stdin: `</dev/null`. The dispatch.sh already buffers stdin as `BATON_STDIN` to avoid this issue.

### 4. Capability Tier Labeling

Each adapter should include a capability tier statement so the AI knows its enforcement level. Pattern:
```
[Baton capability: <tier> (<IDE name>)] <description of limitations>
```

Existing tiers:
- **Full protection**: Claude Code, Factory (no statement needed; this is the default)
- **Reduced enforcement**: Cursor (missing some hooks)
- **Rules + guidance only**: Codex (no hard gates)

### 5. Two Adapter Styles

The codebase shows two architectural patterns:

**Style A — Direct adapter** (e.g., `cursor/adapter.sh`):
- Calls `write-lock.sh` directly
- Simple, handles only write-lock
- Used when only write-lock needs translation

**Style B — Dispatch adapter** (e.g., `codex/dispatch.sh`, `cursor/dispatch.sh`):
- Routes through `dispatch.sh` which reads `manifest.conf`
- Handles all events, not just write-lock
- More complete but requires event name mapping
- Preferred for IDEs that support multiple hook events

### 6. Test Requirements

Based on existing test patterns (`test-adapters.sh`, `test-adapters-v2.sh`):
- Test allow case (plan with BATON:GO -> IDE-native allow response)
- Test block case (plan without BATON:GO -> IDE-native deny response)
- Test no-plan case (no plan.md -> IDE-native deny response)
- Test capability tier statement presence in responses
- Test context/reason field inclusion

---

## Behavioral Difference Summary

| Behavior | Claude Code | Cursor | Codex |
|---|---|---|---|
| Write-lock fires? | Yes (hard block) | Yes (hard block via adapter) | No |
| Write-set enforcement? | Yes | Yes (through write-lock.sh) | No |
| Governance marker protection? | Yes | Yes (through write-lock.sh) | No |
| Hook invocation path | settings.json -> run-hook.cmd -> dispatch.sh -> write-lock.sh | hooks.json -> adapter.sh -> write-lock.sh | N/A |
| Block signal format | exit code 2 | `{"decision":"deny","reason":"..."}` | N/A |
| Allow signal format | exit code 0 + hookSpecificOutput JSON | `{"decision":"allow","context":"..."}` | N/A |
| Additional hooks available | 9/9 | 5/9 | 2/9 (advisory only) |
| Capability tier | Full protection | Reduced enforcement | Rules + guidance only |

---

## Gaps and Considerations for a New Adapter

1. **Cursor has two adapter files** (`adapter.sh` and `dispatch.sh`) with slightly different `deny`/`block` key names. When adding a new adapter, choose one pattern and be consistent.

2. **The IDE capability matrix** (`docs/ide-capability-matrix.md`) must be updated when adding a new IDE. This is a documented maintenance rule.

3. **Research doc** (`docs/research-ide-hooks.md`) contains detailed protocol information for 12 IDEs. 8 of them support PreToolUse hard blocking. The exit-code-2 protocol (Class A) covers 5 IDEs directly; JSON-response IDEs (Class B) need thin adapters of ~10-35 lines.

4. **Windows support**: The `run-hook.cmd` polyglot wrapper handles Windows by finding Git Bash. A new adapter should consider whether it needs its own Windows shim or can rely on the existing one.

5. **Fail-open vs fail-closed**: The core write-lock.sh fails open on unexpected errors (trap handler) but fails closed on ambiguous inputs (multiple plans). This behavior is inherited by all adapters.

---

## Key Files

| File | Role |
|---|---|
| `.baton/hooks/write-lock.sh` | Core write-lock logic (172 lines) |
| `.baton/hooks/dispatch.sh` | Event-based hook dispatcher (65 lines) |
| `.baton/hooks/manifest.conf` | Event-to-script mapping (10 entries) |
| `.baton/hooks/run-hook.cmd` | Windows/Unix polyglot shim (46 lines) |
| `.baton/hooks/lib/common.sh` | Shared functions, legacy wrappers (64 lines) |
| `.baton/hooks/lib/plan-parser.sh` | Plan discovery + section parsing (442 lines) |
| `.baton/adapters/cursor/adapter.sh` | Cursor write-lock adapter (37 lines) |
| `.baton/adapters/cursor/dispatch.sh` | Cursor full dispatch adapter (34 lines) |
| `.baton/adapters/codex/adapter.sh` | Codex hook adapter (63 lines) |
| `.baton/adapters/codex/dispatch.sh` | Codex dispatch adapter (35 lines) |
| `.claude/settings.json` | Claude Code hook configuration |
| `docs/ide-capability-matrix.md` | IDE capability comparison table |
| `docs/research-ide-hooks.md` | Detailed IDE hook research (12 tools) |
| `docs/stable-surface.md` | Enforcement layer documentation |
| `tests/test-write-lock.sh` | Write-lock unit tests (~45 assertions) |
| `tests/test-adapters.sh` | Cursor + Codex adapter tests (10 assertions) |
| `tests/test-adapters-v2.sh` | Cursor adapter v2 tests (5 assertions) |
