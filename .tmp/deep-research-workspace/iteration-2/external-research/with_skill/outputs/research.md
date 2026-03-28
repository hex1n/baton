# Claude Code Hook Events: Full Reference (as of March 2026)

**Depth**: Standard -- external docs question spanning 3 dimensions (event list, blocking, handler types), structured findings warranted.

## Overview

Claude Code supports **22 hook events** across 7 lifecycle phases, **4 handler types** (command, HTTP, prompt, agent), and a structured exit code / JSON output system for controlling behavior. Of the 22 events, **12 support blocking** via exit code 2 or JSON decision output.

Source: official docs at [code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks) (verified: WebFetch 2026-03-23; redirected from docs.anthropic.com/en/docs/claude-code/hooks).

## Findings

### Complete Event List (22 events)

| # | Event | Lifecycle Phase | Blocking? | Matcher Target |
|---|-------|----------------|-----------|----------------|
| 1 | `SessionStart` | Session Setup | No | Start source (`startup`, `resume`, `clear`, `compact`) |
| 2 | `InstructionsLoaded` | Session Setup | No | Load reason (`session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact`) |
| 3 | `UserPromptSubmit` | User Input | **Yes** | No matcher (always fires) |
| 4 | `PreToolUse` | Agentic Loop | **Yes** | Tool name regex (`Bash`, `Edit\|Write`, `mcp__.*`) |
| 5 | `PermissionRequest` | Agentic Loop | **Yes** | No matcher (always fires) |
| 6 | `PostToolUse` | Agentic Loop | No | Tool name regex |
| 7 | `PostToolUseFailure` | Agentic Loop | No | Tool name regex |
| 8 | `Notification` | Agentic Loop | No | Type (`permission_prompt`, `idle_prompt`, `auth_success`) |
| 9 | `SubagentStart` | Agentic Loop | No | Agent type (`Bash`, `Explore`, `Plan`, custom) |
| 10 | `SubagentStop` | Agentic Loop | **Yes** | Agent type |
| 11 | `Stop` | Session End | **Yes** | No matcher (always fires) |
| 12 | `StopFailure` | Session End | No | Error type (`rate_limit`, `authentication_failed`, `billing_error`, `server_error`) |
| 13 | `TeammateIdle` | Agent Teams | **Yes** | No matcher (always fires) |
| 14 | `TaskCompleted` | Agent Teams | **Yes** | No matcher (always fires) |
| 15 | `ConfigChange` | Configuration | **Yes** | Source (`user_settings`, `project_settings`, `policy_settings`, `skills`) |
| 16 | `WorktreeCreate` | Version Control | **Yes** | No matcher (always fires) |
| 17 | `WorktreeRemove` | Version Control | No | No matcher (always fires) |
| 18 | `PreCompact` | Context Management | No | Trigger (`manual`, `auto`) |
| 19 | `PostCompact` | Context Management | No | Trigger |
| 20 | `Elicitation` | MCP Interaction | **Yes** | MCP server name |
| 21 | `ElicitationResult` | MCP Interaction | **Yes** | MCP server name |
| 22 | `SessionEnd` | Session Cleanup | No | Exit reason (`clear`, `resume`, `logout`, `other`) |

### Events That Support Blocking (12 of 22)

Exit code 2 or JSON `decision: "block"` / `permissionDecision: "deny"` blocks the action. The specific effect per event:

| Event | Exit 2 Effect |
|-------|--------------|
| `PreToolUse` | Tool call prevented; stderr shown to Claude |
| `PermissionRequest` | Permission denied |
| `UserPromptSubmit` | Prompt rejected and erased |
| `Stop` | Claude forced to continue instead of stopping |
| `SubagentStop` | Subagent forced to continue |
| `TeammateIdle` | Teammate continues working |
| `TaskCompleted` | Task not marked complete |
| `ConfigChange` | Config change blocked (exception: `policy_settings` cannot be blocked) |
| `Elicitation` | MCP elicitation denied |
| `ElicitationResult` | User response blocked, becomes decline |
| `WorktreeCreate` | Worktree creation fails |

**Non-blocking events** (exit 2 has no blocking effect): `SessionStart`, `InstructionsLoaded`, `SessionEnd`, `PostToolUse`, `PostToolUseFailure`, `Notification`, `SubagentStart`, `PreCompact`, `PostCompact`, `WorktreeRemove`, `StopFailure`.

Note: `PostToolUse` with exit 2 shows stderr to Claude but cannot undo the tool execution -- the tool already ran. `StopFailure` ignores output and exit code entirely. `InstructionsLoaded` ignores exit code entirely.

### Handler Types (4)

| Type | Key | Use Case | Blocking Capable? | Async Support? |
|------|-----|----------|-------------------|----------------|
| **Command** | `"type": "command"` | Shell scripts, any executable | Yes (exit code 2 or JSON) | Yes (`"async": true`) |
| **HTTP** | `"type": "http"` | Remote endpoints, webhooks | Yes (2xx + JSON with `decision: "block"`) | No (non-2xx = non-blocking error) |
| **Prompt** | `"type": "prompt"` | Single-turn LLM yes/no evaluation | Yes (returns decision JSON) | No |
| **Agent** | `"type": "agent"` | Multi-step verification with tools (Read, Grep, Glob) | Yes (returns decision JSON) | No |

#### Command handler config
```json
{
  "type": "command",
  "command": "/path/to/script.sh",
  "async": false,
  "timeout": 600,
  "statusMessage": "Checking..."
}
```
Receives event JSON on stdin. Returns decisions via exit codes and stdout JSON.

#### HTTP handler config
```json
{
  "type": "http",
  "url": "http://localhost:8080/hooks/pre-tool-use",
  "timeout": 30,
  "headers": { "Authorization": "Bearer $TOKEN" },
  "allowedEnvVars": ["TOKEN"]
}
```
POST with JSON body. Non-2xx and connection failures are non-blocking errors (execution continues).

#### Prompt handler config
```json
{
  "type": "prompt",
  "prompt": "Should this tool call be allowed? $ARGUMENTS",
  "model": "fast-model",
  "timeout": 30
}
```
`$ARGUMENTS` placeholder is replaced with the hook input JSON.

#### Agent handler config
```json
{
  "type": "agent",
  "prompt": "Verify that this deployment is safe. $ARGUMENTS",
  "timeout": 60
}
```
Spawns a subagent with access to Read, Grep, Glob tools for multi-step validation.

### Exit Code Summary

| Exit Code | Meaning | Stdout Parsed? | Effect |
|-----------|---------|---------------|--------|
| 0 | Success | Yes (JSON parsed) | Continues; JSON may contain decisions |
| 2 | Blocking error | No (ignored) | Blocks action on blocking-capable events; stderr fed to Claude |
| Other | Non-blocking error | No (ignored) | Continues; stderr shown in verbose mode only |

### JSON Decision Control

On exit 0, hooks can return structured JSON to stdout. Two main decision patterns:

**Top-level decision** (used by `UserPromptSubmit`, `Stop`, `SubagentStop`, `PostToolUse`, `ConfigChange`):
```json
{ "decision": "block", "reason": "Explanation" }
```

**hookSpecificOutput with permissionDecision** (used by `PreToolUse`):
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask",
    "permissionDecisionReason": "...",
    "updatedInput": { "field": "new_value" }
  }
}
```
The `permissionDecision` field offers three-way control: `allow` (skip permission prompt), `deny` (block), `ask` (prompt user).

**Universal fields** (all events):
```json
{
  "continue": true,
  "stopReason": "...",
  "suppressOutput": false,
  "systemMessage": "..."
}
```
Setting `"continue": false` stops Claude entirely, regardless of event type.

### Async Execution

- Only command hooks support `"async": true` -- runs in background, cannot block.
- Four events run asynchronously by default: `InstructionsLoaded`, `Notification`, `WorktreeRemove`, `SessionEnd`.
- `SessionEnd` has a default timeout of 1.5 seconds, configurable via `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS`.

### Configuration Locations

| Location | Scope |
|----------|-------|
| `~/.claude/settings.json` | All projects (local machine) |
| `.claude/settings.json` | Single project (committable) |
| `.claude/settings.local.json` | Single project (gitignored) |
| Managed policy settings | Organization-wide (admin-controlled) |
| Plugin `hooks/hooks.json` | When plugin enabled |
| Skill/agent frontmatter | While component active |

### Special Behaviors Worth Noting

- **`PreToolUse` can modify tool input** via `updatedInput` in JSON output -- the only event that can alter what the tool receives.
- **`SessionStart` can set environment variables** via `$CLAUDE_ENV_FILE` -- write `export VAR=value` lines to that file.
- **`UserPromptSubmit` and `SessionStart`** are the only events where stdout text (non-JSON) is added as context Claude can see. All other events show stdout only in verbose mode.
- **`PostToolUse` can replace MCP tool output** via `updatedMCPToolOutput` in hookSpecificOutput.
- **`PermissionRequest` can update permissions** via `updatedPermissions` array in decision object.
- **Managed hooks** (`policy_settings` source) cannot be disabled at user/project level.

## Open Questions

1. **Event count discrepancy**: Some third-party sources reference "12 events" or "21 events" rather than the 22 found in official docs. This likely reflects documentation from different Claude Code versions. The 22-event list above is from the current official docs page. (verified: WebFetch of code.claude.com/docs/en/hooks, 2026-03-23)

2. **Prompt and Agent hook decision format**: The official docs describe these handler types but the exact JSON response schema they produce (vs. command hooks) is not explicitly differentiated. It is likely they use the same JSON decision fields, but this is inferred, not directly documented. (unverified: inferred from docs structure)

3. **Version history**: The docs do not state when each event was added. Events like `Elicitation`, `ElicitationResult`, `StopFailure`, `InstructionsLoaded`, `PostCompact` appear to be newer additions. The Anthropic changelog at docs.anthropic.com/en/release-notes/claude-code would have version-specific details. (unverified: not fetched)

I didn't check the changelog for when specific events were added, which could matter if targeting a specific Claude Code version rather than the latest.

## Sources

- [Claude Code Hooks Reference (Official)](https://code.claude.com/docs/en/hooks) -- primary source, fetched 2026-03-23
- [Anthropic Docs Redirect](https://docs.anthropic.com/en/docs/claude-code/hooks) -- redirects to code.claude.com as of 2026-03-23
