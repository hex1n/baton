**Question**: How does baton's hook system work — architecture, dispatch mechanism, hook lifecycle, and IDE integration?
**Depth**: Standard
**Key finding**: Baton uses a centralized `dispatch.sh` dispatcher that reads a `manifest.conf` routing table to fan out IDE events to individual hook scripts, with IDE-specific adapters translating between each IDE's native protocol and the shared internal convention.
**Open questions**: 2 — see end of document

---

## Overview

Baton's hook system is an event-driven interception layer that enforces a plan-first governance workflow across multiple AI coding IDEs. It intercepts tool calls (writes, bash commands, session lifecycle events) and routes them to specialized hook scripts that can block, advise, or inject context.

```
IDE (Claude Code / Cursor / Codex / Factory)
  │
  ├─ Claude Code/Factory ─→ .claude/settings.json ─→ run-hook.cmd ─→ dispatch.sh
  ├─ Cursor ──────────────→ .cursor/hooks.json ───→ adapters/cursor/dispatch.sh ─→ dispatch.sh
  └─ Codex ───────────────→ .codex/hooks.json ────→ adapters/codex/dispatch.sh ──→ dispatch.sh
                                                                                       │
                                                                            manifest.conf (routing table)
                                                                                       │
                                            ┌──────────┬──────────┬──────────┬──────────┤
                                            │          │          │          │          │
                                        write-lock  bash-guard  phase-guide  stop-guard  ... (10 hooks total)
                                            │
                                       lib/common.sh ─→ lib/plan-parser.sh
                                                        lib/junction.sh
```

## Findings

### 1. The Dispatch Layer

**`dispatch.sh`** is the central event router. (verified: read `.baton/hooks/dispatch.sh`)

**Mechanism:**
1. Receives the event name as `$1` (e.g., `PreToolUse`, `SessionStart`).
2. Buffers stdin into `BATON_STDIN` env var so multiple hooks can read the same JSON payload.
3. Extracts `tool_name` from the JSON payload (using jq with awk fallback) for matcher filtering.
4. Iterates `manifest.conf` line by line — each line maps `event:matcher:script`.
5. For each matching line, runs the hook script in a subshell (`( . "$_dir/$_script.sh" )`) to isolate exit codes and variable state.
6. For `PreToolUse` events: exit code 2 from any hook = block the tool call. First block wins; all hooks still run.
7. Unexpected exit codes (not 0 or 2) produce a warning to stderr but don't block.

**Design choice — subshell isolation**: Each hook runs via `. "$_dir/$_script.sh"` inside `( )`, meaning it's sourced (so it can access dispatch's env vars like `BATON_STDIN`) but isolated in a subshell (so its exit code and variable mutations don't affect other hooks). (verified: `dispatch.sh:52`)

### 2. The Manifest

**`manifest.conf`** is a simple `event:matcher:script` text file. (verified: read `.baton/hooks/manifest.conf`)

Current routing table (10 entries, 10 hook scripts):

| Event | Matcher | Script | Behavior |
|-------|---------|--------|----------|
| `SessionStart` | (all) | `phase-guide` | Detect phase, inject guidance + governance context |
| `PreToolUse` | `Write,Edit,MultiEdit,CreateFile,NotebookEdit` | `write-lock` | **Hard block** writes without `BATON:GO` |
| `PreToolUse` | `Bash` | `bash-guard` | **Hard block** shell write patterns without `BATON:GO` |
| `PostToolUse` | `Write,Edit,MultiEdit,CreateFile,NotebookEdit` | `post-write-tracker` | Advisory: warn if modified file not in write set |
| `PostToolUse` | `Write,Edit,MultiEdit,CreateFile,NotebookEdit` | `quality-gate` | Advisory: check for self-challenge section in plan/research |
| `SubagentStart` | (all) | `subagent-context` | Inject Todo progress + write set into subagent context |
| `Stop` | (all) | `stop-guard` | Advisory: remind about incomplete tasks |
| `TaskCompleted` | (all) | `completion-check` | **Hard block** completion without retrospective |
| `PostToolUseFailure` | (all) | `failure-tracker` | Advisory: cumulative failure count with threshold alerts |
| `PreCompact` | (all) | `pre-compact` | Preserve plan progress context before compression |

Matcher semantics: empty matcher = match all events of that type. Comma-separated values = match if `tool_name` is in the list. (verified: `dispatch.sh:41-48`)

### 3. Exit Code Protocol

The system uses a simple exit code convention shared across all hooks:

| Exit Code | Meaning | Effect |
|-----------|---------|--------|
| `0` | Allow | Operation proceeds |
| `2` | Block | Operation denied (only meaningful for `PreToolUse` and `TaskCompleted`) |
| Other | Error | Warning emitted to stderr, treated as allow (fail-open) |

All hooks have `trap 'exit 0' HUP INT TERM` for fail-open behavior on unexpected errors. This is a deliberate design choice — hooks should never cause undefined behavior. (verified: pattern present in all hook scripts)

### 4. The Hook Scripts

#### Hard Gates (can block operations)

**`write-lock.sh`** (v3.1) — The core enforcement mechanism. (verified: read `.baton/hooks/write-lock.sh`)
- Resolves target file path from `BATON_TARGET` env or stdin JSON `.tool_input.file_path`.
- Always allows markdown files (`*.md`, `*.mdx`) — but blocks AI from writing governance markers (`BATON:GO`, `BATON:OVERRIDE`) into markdown.
- Blocks if: no plan exists, plan exists but no `BATON:GO`, or target file is outside the plan's write set.
- **Write-set enforcement**: When `BATON:GO` is present and the plan has `Files:` fields in `## Todo`, only listed files can be written. Out-of-set writes are blocked with the list of approved files shown.
- Emergency bypass: `BATON_BYPASS=1` env var.

**`bash-guard.sh`** (v3.3) — Blocks shell write patterns when the plan gate is closed. (verified: read `.baton/hooks/bash-guard.sh`)
- When `BATON:GO` is present: allows everything.
- When closed: strips quoted segments from the command, then checks for: output redirection (`>`/`>>`), heredoc redirects, `tee`, `sed -i`, `perl -pi`, `python -c` with file write, `cp`, `mv`, `install`, `truncate`, `patch`.
- Warns (but allows) `rm` and `touch`.

**`completion-check.sh`** (v1.2) — Blocks `TaskCompleted` without a proper retrospective. (verified: read `.baton/hooks/completion-check.sh`)
- Only fires when all Todo items are done.
- Requires `## Retrospective` section with >= 3 non-empty content lines.
- Advisory checks: unresolved `?` markers, test suite not run.

#### Advisory Hooks (always exit 0)

**`phase-guide.sh`** (v7.1) — The most complex hook. (verified: read `.baton/hooks/phase-guide.sh`)
- Runs on `SessionStart`. Detects the current workflow phase via a state machine:
  - `FINISH` — plan + GO + all todos done
  - `AWAITING_TODO` — plan + GO but no `## Todo` items
  - `IMPLEMENT` — plan + GO + todos exist
  - `ANNOTATION` — plan exists, no GO
  - `PLAN` — research exists, no plan
  - `RESEARCH` — nothing exists
- Dynamically scans installed skills across `.baton/skills`, `.claude/skills`, `.cursor/skills`, `.agents/skills` and suggests relevant skills per phase.
- **Governance context injection**: On exit, reads `.baton/skills/using-baton/SKILL.md` and outputs it as `additionalContext` JSON on stdout, effectively injecting the governance layer into the AI's system prompt at session start.
- **Auto-junction**: Creates NTFS junctions for `baton-*` skills into all detected IDE skill directories.

**`stop-guard.sh`** (v3.0) — Reminds about incomplete work when stopping. (verified: read `.baton/hooks/stop-guard.sh`)

**`post-write-tracker.sh`** (v1.1) — Warns when modified files aren't in the plan's write set. (verified: read `.baton/hooks/post-write-tracker.sh`)
- Tracks repeat violations per session via temp files in `/tmp/`.

**`quality-gate.sh`** (v1.0) — Checks plan/research files for `## Self-Challenge` section depth. (verified: read `.baton/hooks/quality-gate.sh`)

**`failure-tracker.sh`** (v1.1) — Counts cumulative tool failures per session. Alerts at 3 and 5 failures. (verified: read `.baton/hooks/failure-tracker.sh`)
- Uses `/tmp/baton-failures-{session_id}` for persistence.
- Cannot track per-hypothesis failures (that's an AI-layer concern); this is a session-total proxy.

**`subagent-context.sh`** (v1.2) — Injects plan Todo items and authorized write set into subagent context. (verified: read `.baton/hooks/subagent-context.sh`)

**`pre-compact.sh`** (v1.2) — Preserves plan progress, write set, and recent Annotation Log entries before context window compression. (verified: read `.baton/hooks/pre-compact.sh`)

### 5. Shared Libraries

**`lib/common.sh`** — Entry point for shared functions. Sources `plan-parser.sh`. Provides legacy wrappers (`resolve_plan_name`, `find_plan`, `has_skill`) and `baton_resolve_test_cmd()` for auto-detecting test commands. (verified: read `.baton/hooks/lib/common.sh`)

**`lib/plan-parser.sh`** (v1.3) — The parser/discovery engine. (verified: read `.baton/hooks/lib/plan-parser.sh`)
- **1A primitives**: `parser_find_plan` (walk-up discovery with multi-plan disambiguation), `parser_find_research`, `parser_has_go`, `parser_has_skill`, `parser_project_root`.
- **1B primitives**: `parser_todo_range`, `parser_todo_counts`, `parser_todo_items`, `parser_todo_remaining_items`, `parser_retro_range`, `parser_retro_valid`.
- **1C primitives**: `parser_writeset_normalize`, `parser_writeset_extract`, `parser_writeset_contains`.
- Plan discovery uses walk-up (starting from CWD, checking each ancestor). Multi-plan disambiguation: Layer 1 = unique `BATON:GO` presence, Layer 2 = `BATON_TARGET` context matching, Layer 3 = mtime ordering with warning.

**`lib/junction.sh`** — `atomic_junction()` function: tries NTFS junction first (Windows), then symlink (Unix), then falls back to `cp -r`. (verified: read `.baton/hooks/lib/junction.sh`)

### 6. Cross-Platform Entry: `run-hook.cmd`

A polyglot file that works as both a Windows batch script and a Unix shell script. (verified: read `.baton/hooks/run-hook.cmd`)

- **Windows path** (cmd.exe interprets the batch portion): Searches for `bash.exe` at standard Git for Windows locations, then falls back to `bash` on PATH. Calls `dispatch.sh` via that bash.
- **Unix path** (shell interprets it): The batch portion is hidden behind `: << 'CMDBLOCK'` (a no-op heredoc in bash). Directly execs `dispatch.sh`.
- If no bash is found on Windows, exits silently (hooks are advisory, not blocking) — though this is a degraded state since the write-lock would not fire.

### 7. IDE Adapters

Adapters sit between IDE-specific hook protocols and the shared `dispatch.sh`.

**Cursor adapter** (`adapters/cursor/dispatch.sh`) — (verified: read file)
- Maps Cursor's camelCase event names to baton's PascalCase (`preToolUse` -> `PreToolUse`, etc.).
- Calls `dispatch.sh`, captures combined stdout+stderr.
- Translates exit code 2 to `{"decision":"block","reason":"..."}` JSON.
- Exit 0 becomes `{"decision":"allow"}`.

**Cursor write-lock adapter** (`adapters/cursor/adapter.sh`) — (verified: read file)
- A simpler adapter that calls `write-lock.sh` directly (not through dispatch).
- Translates to Cursor's `{"decision":"allow"|"deny"}` protocol.
- Annotates all output with `[Baton capability: reduced enforcement (Cursor)]`.

**Codex adapter** (`adapters/codex/dispatch.sh`) — (verified: read file)
- Codex has no `PreToolUse` hard gates — only `SessionStart` and `Stop`.
- SessionStart: prepends a capability tier header, then runs dispatch with stdin closed (Codex may not send EOF).
- Stop: runs dispatch off-channel, saves reminder text to `.codex/stop-hook.message.txt`, emits `{"continue":false}`.
- All output annotated with `[Baton capability: rules + guidance only (Codex)]`.

**Codex individual adapter** (`adapters/codex/adapter.sh`) — (verified: read file)
- Routes to individual hook scripts (`phase-guide`, `stop-guard`) rather than through dispatch.
- Redirects stderr to stdout (Codex reads stdout; baton hooks output to stderr).

### 8. Hook Registration (Installation)

`setup.sh` (v4.0) handles installation per IDE. (verified: read `setup.sh`)

| IDE | Hook Config File | Entry Point | Protocol |
|-----|-----------------|-------------|----------|
| Claude Code / Factory | `.claude/settings.json` | `run-hook.cmd <Event>` | exit 0/2, JSON stdout for context |
| Cursor | `.cursor/hooks.json` | `bash .baton/adapters/cursor/dispatch.sh <event>` | JSON `{"decision":"allow"|"block"}` |
| Codex | `.codex/hooks.json` | `bash .baton/adapters/codex/dispatch.sh <Event>` | text stdout (SessionStart), JSON (Stop) |

Claude Code/Factory register all 8 event types. Cursor registers 6 (no `TaskCompleted`, no `PostToolUseFailure`). Codex registers only `SessionStart` and `Stop` (no hard gates available).

### 9. Defense Model

The hook system implements a layered defense strategy (verified: `constitution.md` "Defense Model" section):

1. **Hooks enforce structure** — write-lock and bash-guard prevent unauthorized code modifications.
2. **Review enforces quality** — quality-gate and post-write-tracker flag drift.
3. **Neither is sufficient alone** — hooks can be bypassed (`BATON_BYPASS=1`); review catches what hooks miss.

The three layers are:
- **Self-challenge** (quality-gate hook + self-challenge section requirements)
- **Context-isolated review** (separate review step, not hook-enforced)
- **Human annotation cycle** (plan approval via `BATON:GO` marker)

### 10. Testing

The hook system has extensive test coverage (verified: glob `tests/test-*.sh`):
- `test-dispatch.sh` — 17 assertions for the dispatch system
- `test-write-lock.sh` — write-lock behavior
- `test-bash-guard.sh` — shell command blocking
- `test-phase-guide.sh` — 58 assertions for phase detection and guidance
- `test-stop-guard.sh` — stop behavior
- `test-plan-parser.sh` — parser primitives
- `test-junction.sh` — 6 assertions for junction utility
- `test-adapters.sh` / `test-adapters-v2.sh` — adapter protocol translation
- `test-new-hooks.sh` — newer hooks (failure-tracker, pre-compact, etc.)
- `test-setup.sh` — installation
- `test-multi-ide.sh` — multi-IDE installation

## Open Questions

1. **Session ID reliability across IDEs**: `failure-tracker.sh` and `post-write-tracker.sh` use session ID from JSON or `PPID` as a fallback for temp file naming. It's unclear whether all IDEs consistently provide `session_id` in their JSON payloads, or whether `PPID` remains stable for the duration of a session across all platforms. (would need runtime testing to verify)

2. **Cursor `sessionStart` blocking**: The prior research notes (`docs/research-ide-hooks.md`) flag that Cursor community reports indicate `continue: false` on `sessionStart` may be ignored in some versions. If `phase-guide.sh` ever needed to block at session start (it currently doesn't — always exits 0), this could be a limitation. (unverified: based on community reports, not tested)
