# Hook Dispatch Protocol Compatibility: Baton vs Claude Code

> Depth: Standard -- cross-module comparison (baton dispatch + 9 hook scripts) against external specification (Claude Code docs).
> Sources: dispatch.sh, manifest.conf, all hook scripts under `.baton/hooks/`, settings.json, and https://code.claude.com/docs/en/hooks (fetched 2026-03-23).

## Overview

Baton's hook dispatch protocol is **largely compatible** with Claude Code's current hook specification, with two concrete mismatches and one latent risk. The architecture works correctly today because baton runs as a `type: "command"` hook in settings.json, meaning Claude Code handles stdin delivery and exit code interpretation -- baton's dispatch.sh is an internal routing layer, not a direct protocol participant.

```
Claude Code                        Baton
  |                                  |
  |-- stdin JSON ------------------>|  settings.json registers run-hook.cmd
  |                                  |  run-hook.cmd -> dispatch.sh
  |                                  |  dispatch.sh buffers stdin as BATON_STDIN
  |                                  |  dispatch.sh routes to hook script(s) via manifest.conf
  |                                  |  hook script reads BATON_STDIN, writes stderr/stdout
  |<-- exit code + stdout + stderr --|  dispatch.sh propagates exit code
```

---

## Finding 1: Stdin JSON Format

### What Claude Code sends (per official docs)

Every hook receives these common fields on stdin:

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/directory",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse"
}
```

Event-specific fields for events baton uses:

| Event | Additional fields |
|-------|------------------|
| **PreToolUse** | `tool_name`, `tool_input` (tool-specific object), `tool_use_id` |
| **PostToolUse** | `tool_name`, `tool_input`, `tool_response`, `tool_use_id` |
| **PostToolUseFailure** | `tool_name`, `tool_input`, `tool_use_id`, `error`, `is_interrupt` |
| **SessionStart** | `source` (startup\|resume\|clear\|compact), `model`, `agent_type` |
| **SubagentStart** | `agent_id`, `agent_type` |
| **Stop** | `stop_hook_active`, `last_assistant_message` |
| **TaskCompleted** | `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name` |
| **PreCompact** | `trigger` (manual\|auto), `custom_instructions` |

### What baton reads from stdin

dispatch.sh buffers the full stdin into `BATON_STDIN` (line 20) and extracts `tool_name` for matcher filtering (lines 25-31).

| Hook script | Fields read | Method | Compatible? |
|-------------|------------|--------|-------------|
| write-lock.sh | `tool_input.file_path`, `cwd`, `tool_input.new_string`, `tool_input.content` | jq with awk fallback | **Yes** |
| bash-guard.sh | `tool_input.command` | jq with awk fallback | **Yes** |
| post-write-tracker.sh | `tool_input.file_path`, `cwd`, `session_id` | jq with awk fallback | **Yes** |
| failure-tracker.sh | `session_id`, `tool_name` | jq with awk fallback | **Yes** |
| phase-guide.sh | (does not read stdin fields) | N/A | **Yes** |
| subagent-context.sh | (does not read stdin fields) | N/A | **Yes** |
| stop-guard.sh | (does not read stdin fields) | N/A | **Yes** |
| completion-check.sh | (does not read stdin fields) | N/A | **Yes** |
| pre-compact.sh | (does not read stdin fields) | N/A | **Yes** |
| quality-gate.sh | (does not read stdin fields, uses `BATON_TARGET` env) | N/A | **Yes** |

**Verdict: Fully compatible.** All field names baton reads (`tool_name`, `tool_input.file_path`, `tool_input.command`, `tool_input.new_string`, `tool_input.content`, `cwd`, `session_id`) match the official specification exactly. (verified: read all hook scripts + compared against fetched docs)

### Unused fields

Baton does not read several fields that Claude Code provides: `transcript_path`, `permission_mode`, `tool_use_id`, `hook_event_name` (from stdin -- baton gets the event name from the command-line argument instead), `stop_hook_active`, `last_assistant_message`, `model`, `source`. These are available if baton wants them in the future but their absence causes no issue.

---

## Finding 2: Exit Code Semantics

### Claude Code specification

| Exit code | Meaning | JSON parsed? | Effect |
|-----------|---------|-------------|--------|
| 0 | Success | Yes | Proceed; stdout JSON may modify behavior |
| 2 | Block | No | Block the action; stderr fed to Claude |
| Other (1, 3, ...) | Non-blocking error | No | stderr shown in verbose mode; execution continues |

**Blocking capability by event** (relevant to baton):

| Event | Exit 2 blocks? |
|-------|---------------|
| PreToolUse | **Yes** -- prevents tool execution |
| PostToolUse | **No** -- "blocks tool result" (stderr shown to Claude, but tool already ran) |
| PostToolUseFailure | **No** -- observability only |
| SessionStart | **No** -- non-blocking |
| SubagentStart | **No** -- non-blocking |
| Stop | **Yes** -- prevents Claude from stopping |
| TaskCompleted | **Yes** -- prevents task from being marked complete |
| PreCompact | **No** -- non-blocking |

### What baton does

dispatch.sh (lines 52-61):

```bash
_rc=0
( . "$_dir/$_script.sh" ) || _rc=$?
if [ "$_rc" -eq 2 ] && [ "$_exit_code" -ne 2 ]; then
    _exit_code=2
fi
if [ "$_rc" -ne 0 ] && [ "$_rc" -ne 2 ]; then
    echo "... unexpected code $_rc ..." >&2
fi
```

- Exit 0: allow (pass through)
- Exit 2: block (first exit 2 wins, propagated to Claude Code)
- Other: warning to stderr, does not propagate

| Baton hook | Exit codes used | Matches spec? |
|------------|----------------|---------------|
| write-lock.sh (PreToolUse) | 0=allow, 2=block | **Yes** |
| bash-guard.sh (PreToolUse) | 0=allow, 2=block | **Yes** |
| completion-check.sh (TaskCompleted) | 0=allow, 2=block | **Yes** |
| stop-guard.sh (Stop) | always 0 | **Yes** (deliberately advisory-only) |
| post-write-tracker.sh (PostToolUse) | always 0 | **Yes** (PostToolUse can't block anyway) |
| subagent-context.sh (SubagentStart) | always 0 | **Yes** (SubagentStart can't block anyway) |
| failure-tracker.sh (PostToolUseFailure) | always 0 | **Yes** |
| phase-guide.sh (SessionStart) | always 0 | **Yes** (SessionStart can't block anyway) |
| pre-compact.sh (PreCompact) | always 0 | **Yes** (PreCompact can't block) |
| quality-gate.sh (PostToolUse) | always 0 | **Yes** |

**Verdict: Fully compatible.** Baton's exit code usage matches the spec precisely. The dispatch.sh "first exit 2 wins" logic is consistent with Claude Code running the registered command and interpreting its exit code. (verified: read dispatch.sh:52-61 + all hook scripts)

**One nuance worth noting:** dispatch.sh swallows non-0/non-2 exit codes (treats them as warnings). Claude Code's spec says "other exit codes = non-blocking error, stderr shown in verbose mode." Since dispatch.sh converts these to exit 0 while emitting a warning to stderr, the net effect is slightly different (Claude Code wouldn't see the non-zero exit), but this is defensive-by-design and doesn't cause functional problems.

---

## Finding 3: Stdout JSON Output Format

This is where the two concrete mismatches live.

### Claude Code specification

For **exit 0**, Claude Code parses stdout as JSON. The expected structure depends on the event:

**PreToolUse** (most important for baton):
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask",
    "permissionDecisionReason": "...",
    "updatedInput": { ... },
    "additionalContext": "Context for Claude"
  }
}
```

**SessionStart**:
```json
{
  "additionalContext": "Context added to Claude's memory"
}
```
Or wrapped in hookSpecificOutput:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "..."
  }
}
```

**PostToolUse** / **PostToolUseFailure** / **SubagentStart** / **Stop** / **PreCompact**:
All support `hookSpecificOutput.additionalContext` for injecting context.

### What baton outputs to stdout

| Hook | Stdout output | Matches spec? |
|------|--------------|---------------|
| **write-lock.sh** (exit 0, gate open) | `{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"Baton: write-set approved..."}}` | **Yes** |
| **write-lock.sh** (exit 2, blocked) | Nothing on stdout (messages go to stderr) | **Yes** (spec says JSON ignored on exit 2) |
| **bash-guard.sh** | No stdout output (stderr only) | **Yes** (no JSON = no modification) |
| **phase-guide.sh** (with `CLAUDE_PLUGIN_ROOT`) | `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}` | **Yes** |
| **phase-guide.sh** (without `CLAUDE_PLUGIN_ROOT`) | `{"additional_context":"..."}` | **MISMATCH** |
| **stop-guard.sh** | No stdout output (stderr only) | **Yes** |
| **completion-check.sh** | No stdout output (stderr only) | **Yes** |
| **post-write-tracker.sh** | No stdout output (stderr only) | **Yes** |
| **subagent-context.sh** | No stdout output (stderr only) | **Yes** |
| **failure-tracker.sh** | No stdout output (stderr only) | **Yes** |
| **pre-compact.sh** | No stdout output (stderr only) | **Yes** |
| **quality-gate.sh** | No stdout output (stderr only) | **Yes** |

### Mismatch 1: phase-guide.sh `additional_context` vs `additionalContext`

**Location:** phase-guide.sh lines 35-39

```bash
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    printf '... "hookSpecificOutput": { "hookEventName": "SessionStart", "additionalContext": "%s" } ...'
else
    printf '... "additional_context": "%s" ...'
fi
```

When `CLAUDE_PLUGIN_ROOT` is **not** set (which is the case for standard project installations -- it's only set when baton runs as a Claude Code plugin), the output uses snake_case `additional_context` instead of camelCase `additionalContext`. The official docs specify `additionalContext` (camelCase) as the field name.

**Impact assessment:** The docs show `additionalContext` at the top level for SessionStart (`{"additionalContext": "..."}`). Baton's non-plugin path outputs `{"additional_context": "..."}`. Claude Code may silently ignore unrecognized fields, meaning the governance context injection could be **silently dropped** when not running as a plugin.

**Confidence:** The field name mismatch is verified (read phase-guide.sh:35-39 + fetched docs). The runtime impact is unverified -- I cannot confirm whether Claude Code's parser accepts snake_case variants or silently drops them. If Claude Code accepts both, this is harmless. If it only accepts camelCase, governance context is lost in non-plugin mode.

### Mismatch 2: stop-guard.sh misses the `decision: "block"` opportunity

This is a **design choice**, not a bug. stop-guard.sh outputs to stderr only (advisory messages) and always exits 0. The Claude Code spec supports `{"decision": "block", "reason": "..."}` on stdout for Stop hooks, which would cause Claude to continue working.

Baton intentionally chose not to use this -- stop-guard.sh is advisory-only (line 6: "Always exit 0 -- never block the stop action"). The spec capability is available but unused.

**Impact:** None -- this is intentional. Mentioning for completeness of the field-by-field comparison.

---

## Summary: Field-by-Field Compatibility Matrix

| Protocol aspect | Baton behavior | Claude Code spec | Compatible? |
|----------------|---------------|-----------------|-------------|
| **Stdin: common fields** | Reads `session_id`, `cwd` | Provides `session_id`, `cwd`, `transcript_path`, `permission_mode`, `hook_event_name` | Yes (reads subset) |
| **Stdin: tool_name** | Extracted via jq/sed from JSON | Provided as `tool_name` in PreToolUse/PostToolUse | Yes |
| **Stdin: tool_input** | Reads `.tool_input.file_path`, `.tool_input.command`, `.tool_input.new_string`, `.tool_input.content` | Tool-specific nested object under `tool_input` | Yes |
| **Stdin: delivery** | dispatch.sh buffers to `BATON_STDIN` env var | Piped to stdin of command | Yes (buffering is transparent) |
| **Exit 0** | Allow / proceed | Allow, parse stdout JSON | Yes |
| **Exit 2** | Block (first wins in dispatch) | Block action, stderr fed to Claude | Yes |
| **Exit other** | Swallowed by dispatch, warning on stderr | Non-blocking error, stderr in verbose mode | Minor difference (swallowed vs passed through) |
| **Stdout: PreToolUse allow** | `hookSpecificOutput.additionalContext` | `hookSpecificOutput` with optional `permissionDecision`, `additionalContext`, `updatedInput` | Yes |
| **Stdout: PreToolUse block** | No stdout (stderr only) | Stdout ignored on exit 2 | Yes |
| **Stdout: SessionStart (plugin mode)** | `hookSpecificOutput.additionalContext` | `additionalContext` or `hookSpecificOutput.additionalContext` | Yes |
| **Stdout: SessionStart (non-plugin)** | `additional_context` (snake_case) | `additionalContext` (camelCase) | **No** |
| **Stdout: all other hooks** | No stdout (stderr only) | Various hookSpecificOutput options available | Yes (unused but valid) |
| **Stderr: exit 0** | Used for advisory messages | Shown in verbose mode | Yes |
| **Stderr: exit 2** | Used for block reason messages | Fed to Claude as error context | Yes |
| **Settings.json registration** | `type: "command"`, `command: ".baton/hooks/run-hook.cmd PreToolUse"` | Supports `type: "command"`, `command: "..."` | Yes |
| **Matcher syntax** | `Edit\|Write\|MultiEdit\|CreateFile\|NotebookEdit` | Supports tool names, pipe-separated regex | Yes |

---

## Open Questions

1. **Does Claude Code accept `additional_context` (snake_case)?** The non-plugin code path in phase-guide.sh uses this field name. If Claude Code silently drops it, governance context injection is lost for non-plugin installations. This could be verified by adding a temporary debug log and checking whether the context appears in Claude's responses. Priority: medium-high -- this affects whether Claude sees baton's governance rules at session start.

2. **Is `CLAUDE_PLUGIN_ROOT` ever set for non-plugin installations?** If baton is always installed as a plugin, the mismatch in question 1 is moot. But the code explicitly handles the non-plugin case, suggesting it's a real scenario. (verified: the if/else branch exists at phase-guide.sh:35-39, meaning the developer anticipated both paths)

3. **Does dispatch.sh's exit-code swallowing matter in practice?** When a hook script exits with code 1 (unexpected error), dispatch.sh converts it to exit 0 + stderr warning. Claude Code would have treated code 1 as "non-blocking error" anyway, but the distinction is that Claude Code never sees the non-zero exit. If Claude Code logs non-zero exits differently in verbose mode, baton's swallowing hides this diagnostic information.

4. **SessionStart: plain text stdout behavior.** The docs mention that "Exit 0 + plain text stdout: text added as context" for SessionStart. Baton's phase-guide.sh outputs phase guidance to **stderr** (not stdout), meaning Claude shows it in verbose mode but may not inject it as context. The governance JSON goes to stdout. The phase guidance messages (e.g., "IMPLEMENT phase -- load /baton-implement") are advisory-to-the-user, not context-for-Claude, so stderr is the correct channel. But this means Claude may not be aware of the current phase from these messages -- only from the governance context injection.

## Batch Annotation

