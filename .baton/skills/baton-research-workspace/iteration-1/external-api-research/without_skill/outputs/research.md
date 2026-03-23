# Hook Events Across Claude Code, Cursor, and Codex CLI

## Research Question

What hook events are available across Claude Code, Cursor, and Codex CLI? Which events can baton rely on for core governance?

## Sources

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) — official docs
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide) — official guide
- [Cursor Hooks Docs](https://cursor.com/docs/hooks) — official docs
- [Cursor Third Party Hooks](https://cursor.com/docs/reference/third-party-hooks) — Claude Code compatibility
- [Codex CLI Features](https://developers.openai.com/codex/cli/features) — official docs
- [Codex CLI Changelog](https://developers.openai.com/codex/changelog) — release history
- [Deep Dive into Cursor Hooks (GitButler)](https://blog.gitbutler.com/cursor-hooks-deep-dive) — third-party deep dive
- [Codex hooks PR #11067](https://github.com/openai/codex/pull/11067) — comprehensive hook system PR
- [hatayama/codex-hooks](https://github.com/hatayama/codex-hooks) — community project reusing Claude Code hooks format for Codex

---

## Event Inventory

### Claude Code (as of March 2026 — 21 events)

Claude Code has the most mature hooks system. Events fall into two categories based on handler support.

**Events supporting command + prompt/agent handlers:**

| Event | Matcher | Can Block? | Key Capability |
|---|---|---|---|
| PreToolUse | tool name regex | Yes (exit 2 / `"decision":"block"`) | Block tool calls, modify tool input, enforce write-locks |
| PostToolUse | tool name regex | No | Inject additionalContext into tool result |
| PostToolUseFailure | tool name regex | No | React to failed tool calls, track failure patterns |
| PermissionRequest | tool name regex | Yes | Intercept permission prompts |
| Stop | — | No | Inject reminders before response completes |
| SubagentStop | — | No | Post-processing after subagent finishes |
| TaskCompleted | — | No | Completion verification, cleanup |
| UserPromptSubmit | — | Yes | Block or augment user prompts before processing |
| StopFailure | — | No | React when stop hooks fail |

**Events supporting command handlers only:**

| Event | Matcher | Can Block? | Key Capability |
|---|---|---|---|
| SessionStart | — | No | Context injection, environment setup |
| SessionEnd | — | No | Cleanup, logging |
| SubagentStart | — | No | Inject context into spawned subagents |
| PreCompact | — | No | Preserve critical context before compaction |
| PostCompact | — | No | Post-compaction actions |
| Notification | — | No | React to permission prompts, idle, auth events |
| Elicitation | — | No | React to elicitation dialogs |
| ElicitationResult | — | No | React to elicitation responses |
| InstructionsLoaded | — | No | React after CLAUDE.md loaded |
| ConfigChange | — | No | React to settings changes |
| TeammateIdle | — | No | Coordinate multi-agent workflows |
| WorktreeCreate | — | No (but replaces default) | Custom worktree creation |
| WorktreeRemove | — | No | Custom worktree cleanup |

**Hook handler types:** command (shell), HTTP, prompt, agent.

**Matcher:** Regex on tool name for tool-related events. `"*"` or omit for match-all.

**Output protocol:** JSON on stdout. Key fields: `decision` (allow/deny/block), `additionalContext`, `updatedInput`, `suppressOutput`.

---

### Cursor (as of March 2026 — 6 events, beta)

Cursor's hook system is newer and has fewer events. It uses a different naming convention (camelCase) and a different JSON response protocol.

| Event | Equivalent Claude Code Event | Can Block? | Key Capability |
|---|---|---|---|
| beforeShellExecution | PreToolUse (Bash only) | Yes | Block shell commands, modify command |
| beforeMCPExecution | PreToolUse (MCP tools) | Yes | Block MCP tool calls |
| beforeReadFile | PreToolUse (Read) | No (but can rewrite content) | Redact secrets, filter file content before LLM sees it |
| afterFileEdit | PostToolUse (Write/Edit) | No | Auto-format, auto-stage, lint |
| stop | Stop | No | Commit, cleanup, notification |
| beforeSubmitPrompt | UserPromptSubmit | Yes | Block or augment prompts |

**Handler types:** command (shell) only.

**Output protocol:** JSON on stdout: `{"continue": bool, "permission": "allow"|"deny"|"ask", "userMessage": "...", "agentMessage": "..."}`.

**Key differences from Claude Code:**
- No SessionStart event -- no way to inject context at session initialization
- No SubagentStart/SubagentStop -- no subagent lifecycle hooks
- No PreCompact/PostCompact -- no compaction awareness
- No TaskCompleted -- no completion-phase hook
- No PostToolUseFailure -- no failure tracking hook
- Tool events are split by tool type (shell vs MCP vs file) rather than unified with matchers
- beforeReadFile has no Claude Code equivalent -- it intercepts file content before it reaches the model

**Third-party hooks compatibility:** Cursor supports loading Claude Code hooks via `.claude/settings.json` format, translating events automatically. This is documented at [cursor.com/docs/reference/third-party-hooks](https://cursor.com/docs/reference/third-party-hooks).

---

### Codex CLI (as of March 2026 — experimental, evolving)

Codex CLI's hook system is the newest and still experimental. It was introduced in v0.115.0 (March 11, 2026) with SessionStart and Stop, and v0.116.0 (March 20, 2026) added UserPromptSubmit.

**Confirmed stable events (shipped in releases):**

| Event | Can Block? | Key Capability |
|---|---|---|
| SessionStart | No | Context injection at session start |
| Stop | No | End-of-turn actions |
| UserPromptSubmit | Yes | Block or augment prompts before execution |

**Events in PR/development (not confirmed stable):**

Based on open PRs (#11067, #9796) and community forks, additional events are under development:

| Event | Status | Notes |
|---|---|---|
| PreToolUse | In PR | Block/modify tool calls |
| PostToolUse | In PR | React to tool results |
| PostToolUseFailure | In PR | React to failed tool calls |
| AfterAgent | In PR | Post-agent completion |
| Notification | In PR | React to notifications |
| SubagentStart | In PR | Subagent lifecycle |
| SubagentStop | In PR | Subagent lifecycle |
| TaskCompleted | In PR | Completion hooks |

**Hook configuration:** `.codex/hooks.json` with similar structure to Claude Code.

**Output protocol:** JSON on stdout. Hooks can proceed, block (with message), or modify (substitute input).

**Key limitation:** Codex CLI's sandbox model means hooks cannot enforce hard gates the same way Claude Code can -- the tool operates with a different permission model (full-auto vs approval-based). Baton's existing Codex adapter already acknowledges this: `"[Baton capability: rules + guidance only (Codex)] Hard gates (write-lock, bash-guard) are not available."` (from `.baton/adapters/codex/dispatch.sh`).

---

## Cross-Platform Comparison Matrix

| Event Category | Claude Code | Cursor | Codex CLI |
|---|---|---|---|
| **Session lifecycle** | SessionStart, SessionEnd | -- | SessionStart |
| **Tool pre-execution (blocking)** | PreToolUse (all tools, matcher) | beforeShellExecution, beforeMCPExecution | UserPromptSubmit; PreToolUse (in PR) |
| **Tool post-execution** | PostToolUse, PostToolUseFailure | afterFileEdit | Stop; PostToolUse (in PR) |
| **Prompt gating** | UserPromptSubmit | beforeSubmitPrompt | UserPromptSubmit |
| **Stop/completion** | Stop, TaskCompleted, StopFailure | stop | Stop |
| **Subagent lifecycle** | SubagentStart, SubagentStop | -- | In PR |
| **Memory/compaction** | PreCompact, PostCompact | -- | -- |
| **File content filtering** | -- | beforeReadFile | -- |
| **Permission intercept** | PermissionRequest | -- | -- |
| **Multi-agent coordination** | TeammateIdle | -- | -- |
| **Worktree management** | WorktreeCreate, WorktreeRemove | -- | -- |
| **Configuration** | ConfigChange, InstructionsLoaded | -- | -- |
| **Elicitation** | Elicitation, ElicitationResult | -- | -- |

---

## Analysis for Baton Governance

### What baton currently uses (from manifest.conf)

1. **SessionStart** -- phase detection, context injection (phase-guide.sh)
2. **PreToolUse** (Write/Edit/etc.) -- write-lock enforcement
3. **PreToolUse** (Bash) -- bash command guarding
4. **PostToolUse** (Write/Edit/etc.) -- write tracking, quality gate
5. **Stop** -- stop-guard (completion reminders)
6. **TaskCompleted** -- completion-check
7. **PostToolUseFailure** -- failure tracking
8. **PreCompact** -- context preservation before compaction
9. **SubagentStart** -- subagent context injection

### Cross-platform availability of baton's current hooks

| Baton Hook | Claude Code | Cursor | Codex CLI |
|---|---|---|---|
| SessionStart (phase-guide) | Yes | **No** | Yes |
| PreToolUse write-lock | Yes (blocking) | Partial (afterFileEdit is post-only; beforeShellExecution for shell) | **No** (rules only) |
| PreToolUse bash-guard | Yes (blocking) | Yes (beforeShellExecution) | **No** (rules only) |
| PostToolUse write-tracker | Yes | Partial (afterFileEdit) | **No** |
| PostToolUse quality-gate | Yes | Partial (afterFileEdit) | **No** |
| Stop (stop-guard) | Yes | Yes (stop) | Yes |
| TaskCompleted | Yes | **No** | **No** |
| PostToolUseFailure | Yes | **No** | **No** |
| PreCompact | Yes | **No** | **No** |
| SubagentStart | Yes | **No** | **No** |

### Tier Classification

Based on availability, baton's hooks fall into three tiers:

**Tier 1 — Universal (available everywhere):**
- Stop — all three platforms support this

**Tier 2 — Mostly available (2 of 3):**
- SessionStart — Claude Code + Codex CLI (not Cursor)
- PreToolUse/bash-guard — Claude Code + Cursor's beforeShellExecution (not Codex stable)
- UserPromptSubmit — all three (but baton doesn't use it yet)

**Tier 3 — Claude Code only:**
- PreToolUse write-lock (blocking file writes)
- PostToolUse (unified, with matcher)
- TaskCompleted
- PostToolUseFailure
- PreCompact
- SubagentStart

### Recommendations for Baton's Core Governance

1. **Hard-gate hooks (PreToolUse write-lock, bash-guard) are Claude Code-specific in practice.** Cursor's beforeShellExecution partially covers bash-guard but not write-lock. Codex has no blocking capability at all. Baton should continue treating these as "Tier 1 enforcement" on Claude Code and "rules + guidance" elsewhere, as the Codex adapter already does.

2. **SessionStart is the safest foundation for context injection.** It works on Claude Code and Codex CLI. For Cursor, baton could fall back to rules/CLAUDE.md-based injection since Cursor loads those files. The lack of SessionStart in Cursor is the biggest gap -- consider using Cursor's third-party hooks compatibility (loading `.claude/settings.json`) as a bridge.

3. **Stop is the only truly universal event.** If baton needs one event that works everywhere for governance reminders, Stop is it.

4. **UserPromptSubmit is available on all three platforms** and baton does not currently use it. This could be valuable for prompt-level governance (e.g., blocking prompts that attempt to bypass BATON:GO).

5. **Baton's adapter pattern is sound.** The existing architecture (canonical hooks in `manifest.conf` + platform adapters in `adapters/cursor/` and `adapters/codex/`) correctly handles the impedance mismatch. The recommendation is to continue this pattern rather than reducing to lowest-common-denominator.

6. **Graceful degradation model:**
   - **Full enforcement** (Claude Code): All hooks, blocking gates, JSON protocol
   - **Partial enforcement** (Cursor): Shell/MCP blocking + post-edit hooks + stop + rules
   - **Guidance only** (Codex CLI): SessionStart context + Stop reminders + rules

7. **Events baton should NOT rely on for cross-platform governance:** TaskCompleted, PostToolUseFailure, PreCompact, SubagentStart. These are Claude Code luxuries. Governance logic depending on them must have fallback paths.

---

## Confidence Assessment

| Claim | Confidence |
|---|---|
| Claude Code has 21 hook events as listed | ✅ Verified via official docs at code.claude.com |
| Cursor has 6 hook events as listed | ✅ Verified via official docs at cursor.com/docs/hooks |
| Codex CLI has 3 stable events (SessionStart, Stop, UserPromptSubmit) | ✅ Verified via changelog at developers.openai.com |
| Codex CLI has PreToolUse/PostToolUse in development | ❓ Based on open PRs, not shipped releases |
| Cursor supports Claude Code hooks via third-party compatibility | ✅ Verified via cursor.com/docs/reference/third-party-hooks |
| Codex CLI cannot enforce hard gates | ✅ Verified via baton's own adapter code + Codex sandbox model |

## 批注区
