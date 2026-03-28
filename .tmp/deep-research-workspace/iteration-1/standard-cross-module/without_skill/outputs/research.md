# Write-Lock Mechanism Across IDE Adapters: Research Report

## Question

How does the write-lock mechanism work across the different IDE adapters (Claude Code, Cursor, Codex)? Does it actually fire in all IDEs? What are the behavioral differences? What is the common contract for adding a new IDE adapter?

## Architecture Overview

The write-lock is a **three-layer architecture**: a single core script, a dispatch system, and per-IDE adapters that translate between the core's exit-code protocol and each IDE's native hook protocol.

```
IDE native hook system
  --> IDE adapter (protocol translation)
    --> dispatch.sh (event routing + stdin buffering)
      --> write-lock.sh (core logic, exit 0 or 2)
```

## Core: write-lock.sh

**Location**: `.baton/hooks/write-lock.sh` (v3.1)

**Trigger**: PreToolUse event, matched to `Write|Edit|MultiEdit|CreateFile|NotebookEdit` tools.

**Contract (exit codes)**:
- `exit 0` = allow the write
- `exit 2` = block the write (hard gate)
- Other exit codes = unexpected error, treated as warning by dispatch.sh

**Decision logic** (in order):
1. `BATON_BYPASS=1` env var --> allow immediately (emergency bypass)
2. Read target path from `BATON_TARGET` env or stdin JSON `.tool_input.file_path`
3. No target determinable --> fail-open (exit 0 with warning)
4. Target is `*.md|*.MD|*.markdown|*.mdx` --> allow (but check for governance marker injection -- blocks AI from writing `BATON:GO` or `BATON:OVERRIDE`)
5. Target is outside project root --> allow
6. No plan file found --> block (exit 2), with guidance to complete research first
7. Multiple plan files without `BATON_PLAN` set --> block (exit 2), ambiguity error
8. Plan found but no `<!-- BATON:GO -->` marker --> block (exit 2), annotation cycle guidance
9. Plan has `BATON:GO` --> check write-set enforcement:
   - If plan defines `Files:` fields in `## Todo`, target must be in the write set
   - If target not in write set --> block (exit 2)
   - If in write set or no write set defined --> allow (exit 0) with `additionalContext` JSON on stdout

**Key design decisions**:
- **Fail-open on unexpected errors**: The trap handler catches HUP/INT/TERM and exits 0 with a warning, not 2.
- **Fail-open when target is unknown**: If path cannot be extracted, it allows the write rather than blocking blindly.
- **Fail-closed on ambiguity**: Multiple plan files without explicit selection blocks.

## Dispatch Layer: dispatch.sh

**Location**: `.baton/hooks/dispatch.sh`

**Role**: Event router. Reads `manifest.conf`, filters by event name and tool matcher, runs matching hooks in subshells.

**Key behaviors**:
- Buffers stdin into `BATON_STDIN` env var so multiple hooks can read the same payload
- Extracts `tool_name` from JSON for matcher filtering
- For PreToolUse: first `exit 2` wins (blocks the operation)
- Unexpected exit codes (not 0 or 2) are surfaced as warnings

**manifest.conf** maps write-lock to:
```
PreToolUse:Write,Edit,MultiEdit,CreateFile,NotebookEdit:write-lock
```

## IDE Adapter Analysis

### Claude Code (Full Protection)

**Configuration**: `.claude/settings.json` with hooks pointing to `.baton/hooks/run-hook.cmd PreToolUse`

**Write-lock fires?**: YES -- hard block.

**Protocol**: Native. Claude Code invented the exit-code protocol that write-lock.sh uses directly:
- JSON on stdin (with `tool_name`, `tool_input.file_path`, `cwd`)
- Exit 0 = allow
- Exit 2 = block
- stderr displayed to AI as context
- stdout with `hookSpecificOutput.additionalContext` JSON injected into AI context

**No adapter needed**: dispatch.sh runs write-lock.sh directly. The `run-hook.cmd` polyglot wrapper just invokes `bash dispatch.sh <event>`.

**Hooks registered** (9/9):
PreToolUse, PostToolUse, SessionStart, Stop, PreCompact, SubagentStart, TaskCompleted, PostToolUseFailure -- all via dispatch.sh.

**Behavioral notes**:
- Write-lock outputs `additionalContext` JSON when a write is approved, which Claude Code injects as a reminder ("Self-check: confirm scope matches plan before writing")
- stderr messages from blocked writes are shown directly to the AI

---

### Cursor (Core Protection -- via adapter)

**Configuration**: `.cursor/hooks.json` with hooks pointing to `bash .baton/adapters/cursor/dispatch.sh <event>`

**Write-lock fires?**: YES -- hard block via adapter translation.

**Protocol**: Cursor uses camelCase events and a JSON response protocol:
- Input: JSON on stdin (same fields as Claude Code)
- Output: `{"decision":"allow"}` or `{"decision":"block","reason":"..."}`
- Exit code 2 also means block

**Adapter chain**:
1. Cursor calls `dispatch-cursor.sh preToolUse`
2. `dispatch-cursor.sh` maps camelCase to PascalCase (`preToolUse` --> `PreToolUse`)
3. Runs `dispatch.sh PreToolUse`, captures both stdout and stderr (`2>&1`)
4. If dispatch exits 2: emits `{"decision":"block","reason":"<combined output>"}`
5. If dispatch exits 0: emits `{"decision":"allow"}`

**Two adapter files exist** (important distinction):
- `.baton/adapters/cursor/dispatch.sh` -- **current, used by setup.sh**. Full dispatch integration. Maps all events (sessionStart, preToolUse, postToolUse, subagentStart, preCompact, stop).
- `.baton/adapters/cursor/adapter.sh` -- **legacy/standalone**. Calls write-lock.sh directly (not via dispatch). Used by older tests. Includes capability tier label `[Baton capability: reduced enforcement (Cursor)]`.

**Hooks registered** (6 event types): sessionStart, preToolUse (Write, Edit, Bash), postToolUse (Write, Edit), stop, subagentStart, preCompact.

**Behavioral differences from Claude Code**:
1. **Fewer hooks**: No TaskCompleted, PostToolUseFailure -- so no completion-check or failure-tracker.
2. **No post-write-tracker**: PostToolUse is registered but `post-write-tracker.sh` output goes to JSON protocol, not stderr. Write-set drift warnings may not surface correctly.
3. **additionalContext lost**: `dispatch-cursor.sh` captures stderr+stdout combined and only uses it for the deny reason. When allowing, it outputs `{"decision":"allow"}` with no context injection. The approved-write self-check reminder from write-lock.sh is dropped.
4. **Capability tier label**: The legacy adapter.sh adds `[Baton capability: reduced enforcement (Cursor)]` to responses. The current dispatch.sh does NOT add this label -- a potential gap.
5. **Event name mapping**: Cursor uses camelCase (`preToolUse`), dispatch.sh uses PascalCase (`PreToolUse`). The adapter handles this translation.

---

### Codex (Rules + Guidance Only)

**Configuration**: `.codex/hooks.json` with SessionStart and Stop only. `.codex/config.toml` enables `codex_hooks` feature flag.

**Write-lock fires?**: NO. Codex has no PreToolUse hook capability.

**What fires instead**: Only SessionStart (phase-guide) and Stop (stop-guard) -- both advisory.

**Adapter**: `.baton/adapters/codex/dispatch.sh`:
1. For SessionStart: prepends tier header, runs `dispatch.sh SessionStart` with stdin closed (`</dev/null` -- Codex may not send EOF)
2. For Stop: runs dispatch off-channel, saves message to `.codex/stop-hook.message.txt`, emits `{"continue":false}` JSON
3. All other events: runs dispatch with stderr redirected to stdout (`2>&1`)

Also: `.baton/adapters/codex/adapter.sh` (standalone, calls individual hooks directly, not used by current setup.sh).

**Behavioral differences from Claude Code**:
1. **No write-lock at all**: This is the fundamental gap. Codex cannot block writes. Enforcement relies entirely on AGENTS.md rules (constitution.md) and human approval controls.
2. **Tier header injected**: Every response includes `[Baton capability: rules + guidance only (Codex)] Hard gates (write-lock, bash-guard) are not available.`
3. **stdin closed**: Codex adapters use `</dev/null` because Codex may not send EOF, which would cause dispatch.sh's `cat` to hang.
4. **Stop protocol differs**: Codex Stop expects JSON (`{"continue":false}`), not plain text. The adapter saves human-readable text to a file instead.

## Capability Matrix Summary

| Aspect | Claude Code | Cursor | Codex |
|--------|-------------|--------|-------|
| Write-lock fires | Yes (hard block) | Yes (hard block via adapter) | No |
| Protocol | exit code + JSON stdout | JSON `decision` response | N/A |
| Needs adapter | No (native) | Yes (dispatch-cursor.sh) | N/A |
| additionalContext | Yes (injected by host) | Lost in translation | N/A |
| Hooks registered | 9/9 | 6/9 | 2/9 |
| Write-set enforcement | Yes | Yes (via write-lock.sh) | No |
| Governance marker check | Yes | Yes (via write-lock.sh) | No |
| Capability tier label | Not needed | Missing in dispatch.sh | Yes |
| Fail-open behavior | stderr shown to AI | Reason in JSON deny | N/A |

## Common Contract for a New IDE Adapter

Based on the existing patterns, a new IDE adapter must implement:

### Required

1. **Event name translation**: Map the IDE's native event names to dispatch.sh's PascalCase events (SessionStart, PreToolUse, PostToolUse, Stop, etc.).

2. **Protocol translation for PreToolUse**:
   - Call `dispatch.sh PreToolUse` (or write-lock.sh directly for minimal adapters)
   - Translate exit code 2 into the IDE's native "deny/block" response format
   - Translate exit code 0 into the IDE's native "allow" response format
   - Include the block reason (from stderr/stdout) in the deny response

3. **Stdin handling**:
   - Pass through the IDE's stdin JSON to dispatch.sh, OR
   - Close stdin (`</dev/null`) if the IDE might not send EOF
   - Ensure `tool_input.file_path` is accessible via jq (or the awk fallback)

4. **Capability tier declaration**: Include a `[Baton capability: <tier> (<IDE name>)]` label in responses so the AI knows the enforcement level.

### Optional but Recommended

5. **additionalContext forwarding**: When write-lock approves a write, it emits `hookSpecificOutput` JSON on stdout. If the IDE supports context injection, forward this. Currently only Claude Code does this; Cursor drops it.

6. **Stop event handling**: If the IDE has a Stop/session-end hook, call `dispatch.sh Stop` and translate output to the IDE's expected format (some expect JSON, some expect plain text).

7. **SessionStart forwarding**: Forward to `dispatch.sh SessionStart` for phase-guide context injection.

### Files to Create/Modify

For a new IDE adapter "newide":

1. **`.baton/adapters/newide/dispatch.sh`** -- Main adapter script. Pattern: see `cursor/dispatch.sh` (22 lines) as the minimal template.

2. **`setup.sh`** -- Add a `generate_newide_hooks()` function that creates the IDE's config file (e.g., `.newide/hooks.json`). Add the IDE name to `SUPPORTED_IDES`. Add a case in the main install loop.

3. **`docs/ide-capability-matrix.md`** -- Document which hooks fire and the protection tier.

4. **`tests/test-adapters.sh`** or new test file -- Test that the adapter correctly translates allow/deny/block responses.

### Protocol Classification

From the research in `docs/research-ide-hooks.md`:

- **Type A (exit code 2)**: Claude Code, Factory, Cursor, Windsurf, Augment, Amazon Q/Kiro -- write-lock.sh works directly or with minimal wrapping.
- **Type B (JSON response)**: Cline (`{"cancel":true}`), GitHub Copilot (`{"permissionDecision":"deny"}`) -- need thin adapter to translate output format.
- **Type C (no PreToolUse)**: Codex, Zed, Roo Code -- no write-lock possible, rules-only tier.

## Open Issues and Gaps

1. **Cursor dispatch.sh drops additionalContext**: When write-lock approves a write and emits `additionalContext`, `dispatch-cursor.sh` discards it by only outputting `{"decision":"allow"}`. This means the "self-check: confirm scope matches plan" reminder never reaches the AI in Cursor.

2. **Cursor dispatch.sh missing capability tier label**: The legacy `adapter.sh` includes `[Baton capability: reduced enforcement (Cursor)]` but the current `dispatch.sh` does not. The AI in Cursor may not know its enforcement tier.

3. **Two Cursor adapter files**: Both `adapter.sh` (legacy, calls write-lock directly) and `dispatch.sh` (current, calls dispatch.sh) exist. Tests reference both. This could cause confusion for contributors.

4. **Codex stdin hanging risk**: Both Codex adapters close stdin explicitly because Codex may not send EOF. This is a documented workaround but could mask legitimate stdin payloads.

5. **No Factory-specific adapter**: Factory AI uses the same settings.json as Claude Code. This works because Factory implements the same protocol, but there is no separate adapter or test coverage to verify Factory-specific behavior.
