**Question**: How does baton's hook system work end-to-end — dispatch mechanism, hook lifecycle, IDE integration, and extension points?
**Depth**: Standard
**Key finding**: Baton's hook system is a pure-bash, event-driven dispatch architecture where a single `dispatch.sh` reads a `manifest.conf` routing table to fan out IDE events to isolated hook scripts, with per-IDE adapters translating between the core exit-code protocol and IDE-specific JSON response formats.
**Open questions**: 2 — see end of document

## Overview

```
IDE (Claude Code / Cursor / Codex / Factory)
  │
  │  settings.json / hooks.json registers events
  │
  ▼
run-hook.cmd  (polyglot: batch on Windows, bash on Unix)
  │
  ▼
dispatch.sh   (reads manifest.conf, buffers stdin, fans out to hooks)
  │
  ├──→ write-lock.sh        (PreToolUse: Write/Edit — hard block)
  ├──→ bash-guard.sh         (PreToolUse: Bash — hard block)
  ├──→ phase-guide.sh        (SessionStart — guidance injection)
  ├──→ post-write-tracker.sh (PostToolUse: Write/Edit — advisory)
  ├──→ quality-gate.sh       (PostToolUse: Write/Edit — advisory)
  ├──→ stop-guard.sh         (Stop — advisory)
  ├──→ subagent-context.sh   (SubagentStart — advisory)
  ├──→ completion-check.sh   (TaskCompleted — hard block)
  ├──→ failure-tracker.sh    (PostToolUseFailure — advisory)
  └──→ pre-compact.sh        (PreCompact — advisory)

Shared library:
  lib/common.sh    → legacy wrappers, test-cmd resolver
  lib/plan-parser.sh → plan discovery, section parsing, write-set
  lib/junction.sh  → NTFS junction / symlink / copy utility

IDE adapters (for non-Claude-Code IDEs):
  adapters/cursor/dispatch.sh  → event name mapping + JSON response
  adapters/cursor/adapter.sh   → direct write-lock → Cursor JSON
  adapters/codex/dispatch.sh   → stdin handling + guidance-only tier
  adapters/codex/adapter.sh    → stderr→stdout redirect for Codex
```

## Findings

### 1. The Dispatch Mechanism

The central dispatcher is `.baton/hooks/dispatch.sh` (verified: `dispatch.sh:1-64`).

**Input**: Event name as `$1`, tool payload on stdin (JSON with `tool_name`, `tool_input`, `cwd` fields).

**Routing table**: `manifest.conf` uses a `event:matcher:script` format (verified: `manifest.conf:1-12`). Each line maps an event + optional tool matcher to a script name (without `.sh` extension). The matcher is comma-separated tool names; empty matcher matches all tools.

**Current routing (10 hooks across 7 events)**:

| Event | Matcher | Script | Can Block? |
|-------|---------|--------|------------|
| SessionStart | (all) | phase-guide | No |
| PreToolUse | Write,Edit,MultiEdit,CreateFile,NotebookEdit | write-lock | Yes (exit 2) |
| PreToolUse | Bash | bash-guard | Yes (exit 2) |
| PostToolUse | Write,Edit,MultiEdit,CreateFile,NotebookEdit | post-write-tracker | No |
| PostToolUse | Write,Edit,MultiEdit,CreateFile,NotebookEdit | quality-gate | No |
| SubagentStart | (all) | subagent-context | No |
| Stop | (all) | stop-guard | No |
| TaskCompleted | (all) | completion-check | Yes (exit 2) |
| PostToolUseFailure | (all) | failure-tracker | No |
| PreCompact | (all) | pre-compact | No |

**Dispatch mechanics**:

1. **Stdin buffering**: Stdin is read once into `BATON_STDIN` and exported. This allows multiple hooks to access the same payload without re-reading (verified: `dispatch.sh:17-20`).

2. **Tool extraction**: Tool name extracted from JSON `tool_name` field using jq (with awk fallback for jq-less environments) (verified: `dispatch.sh:24-31`).

3. **Matcher filtering**: For each manifest line, if a matcher is specified, the tool name must appear in the comma-separated matcher list. Empty matcher = match all. No tool name available + matcher specified = skip (verified: `dispatch.sh:41-48`).

4. **Subshell isolation**: Each hook runs in a subshell via `. "$_dir/$_script.sh"`, isolating exit codes and variable state (verified: `dispatch.sh:51-52`).

5. **Exit code protocol**: Exit 0 = allow, exit 2 = block (PreToolUse only), anything else = warning logged to stderr. For PreToolUse events, the first exit 2 wins — the dispatcher accumulates the blocking code (verified: `dispatch.sh:54-61`).

6. **CRLF handling**: Manifest lines are explicitly stripped of `\r` for Windows compatibility with `core.autocrlf=true` (verified: `dispatch.sh:37`).

### 2. The Hook Scripts — Two Categories

**Hard gates (can block tool execution)**:

- **write-lock.sh** (v3.1): The core enforcement hook. Blocks source code writes unless `plan.md` contains `<!-- BATON:GO -->`. Logic: markdown files always allowed (but governance markers like BATON:GO/BATON:OVERRIDE are blocked from AI insertion). Files outside the project root are always allowed. When BATON:GO is present, write-set enforcement checks that the target file appears in the plan's `## Todo` section `Files:` fields. Emergency bypass via `BATON_BYPASS=1`. Fail-open on unexpected errors (verified: `write-lock.sh:1-172`).

- **bash-guard.sh** (v3.3): Blocks shell-based file writes when the plan gate is closed. Detects patterns: output redirection, heredocs with redirect, `tee`, `sed -i`, `perl -pi`, `python -c` with file writes, `cp`, `mv`, `install`, `truncate`, `patch`. Has a quote-stripping parser to avoid false positives on quoted strings. Warns (but does not block) on `rm` and `touch` (verified: `bash-guard.sh:1-164`).

- **completion-check.sh** (v1.2): Blocks task completion (TaskCompleted event) unless `## Retrospective` section exists with at least 3 content lines. Also advisory-warns about unresolved `❓` markers and test suite execution (verified: `completion-check.sh:1-77`).

**Advisory hooks (observe and inform, never block)**:

- **phase-guide.sh** (v7.1): SessionStart hook. Detects project phase (RESEARCH → PLAN → ANNOTATION → AWAITING_TODO → IMPLEMENT → FINISH) by inspecting plan existence, BATON:GO marker, and todo progress. Outputs phase-specific guidance to stderr. Auto-creates skill junctions at session start. Injects `using-baton` skill content as `additionalContext` JSON via an EXIT trap (verified: `phase-guide.sh:1-264`).

- **post-write-tracker.sh** (v1.1): Tracks whether modified files appear in the plan's write set. Warns on first violation, escalates on repeat violations within a session (tracks via temp file keyed on session ID) (verified: `post-write-tracker.sh:1-117`).

- **quality-gate.sh** (v1.0): After writes to plan/research files, checks for `## Self-Challenge` section with at least 3 content lines (verified: `quality-gate.sh:1-46`).

- **stop-guard.sh** (v3.0): When stopping during implement phase, reminds about incomplete todos or guides through finish workflow (retrospective, tests, BATON:COMPLETE, branch disposition) (verified: `stop-guard.sh:1-53`).

- **subagent-context.sh** (v1.2): Injects plan context (todo progress, write set) into subagent sessions so spawned agents know the plan scope (verified: `subagent-context.sh:1-51`).

- **failure-tracker.sh** (v1.1): Counts tool failures per session. Alerts at 3 and 5 cumulative failures, reminding about the constitution's per-hypothesis failure boundary. Explicitly notes that per-hypothesis tracking is an AI-layer responsibility — hooks can only track session totals (verified: `failure-tracker.sh:1-64`).

- **pre-compact.sh** (v1.2): Before context window compression, outputs plan progress summary and recent Annotation Log entries to ensure critical context survives (verified: `pre-compact.sh:1-70`).

### 3. The Shared Library

All hooks source `lib/common.sh`, which in turn sources `lib/plan-parser.sh`.

**plan-parser.sh** (v1.3) provides three layers of primitives:

- **1A Discovery**: `parser_find_plan` (walk-up directory search, multi-plan disambiguation via BATON:GO uniqueness and BATON_TARGET context), `parser_find_research` (paired research file discovery), `parser_has_go`, `parser_has_skill`, `parser_project_root` (marker-based walk-up: `.baton`, `.git`, `.claude`, `.cursor`, `.codex`, `AGENTS.md`, `CLAUDE.md`).

- **1B Section**: `parser_todo_range`, `parser_todo_counts`, `parser_todo_items`, `parser_todo_remaining_items`, `parser_retro_range`, `parser_retro_valid` — all use awk to parse markdown sections.

- **1C Write-set**: `parser_writeset_normalize` (strips `./`, converts absolute to project-relative, handles Windows drive letters via cygpath), `parser_writeset_extract` (parses `Files:` fields from `## Todo` items), `parser_writeset_contains`.

**junction.sh** provides `atomic_junction`: tries NTFS junction first (Windows, no Developer Mode needed), then symlink, then falls back to copy. This is the core distribution mechanism — `~/.baton/` is the single source, and projects reference it via junctions (verified: `junction.sh:1-37`).

### 4. IDE Integration — Three Tiers

**Tier A: Full enforcement (Claude Code / Factory AI)**

IDE registers all 8 event types in `.claude/settings.json`. Each points to `run-hook.cmd <EventName>`, which finds bash and delegates to `dispatch.sh`. The dispatch reads `manifest.conf` and runs the appropriate hooks. Exit code 2 on PreToolUse is a hard block; stderr messages are shown to the AI (verified: `.claude/settings.json:1-107`).

The `run-hook.cmd` file is a polyglot — the first section is a batch script (for Windows cmd.exe) that locates Git Bash in standard paths; the second section is a bash script (for Unix) that delegates directly to `dispatch.sh` (verified: `run-hook.cmd:1-46`).

**Tier B: Reduced enforcement (Cursor)**

Cursor uses camelCase event names and expects JSON responses. Two adapter files handle this:

- `adapters/cursor/dispatch.sh`: Maps camelCase → PascalCase, runs `dispatch.sh`, translates exit code 2 to `{"decision":"block","reason":"..."}` and exit 0 to `{"decision":"allow"}` (verified: `adapters/cursor/dispatch.sh:1-34`).

- `adapters/cursor/adapter.sh`: Direct write-lock adapter for legacy/specific registration. Wraps write-lock.sh output in Cursor's JSON format. Explicitly labels output as "reduced enforcement" since Cursor lacks some hook events (verified: `adapters/cursor/adapter.sh:1-37`).

Hook registration goes into `.cursor/hooks.json` with Cursor's schema (version 1, timeout per hook). Setup also creates `.cursor/rules/baton.mdc` with the constitution content (verified: `setup.sh:284-361`).

**Tier C: Rules + guidance only (Codex)**

Codex has no PreToolUse hard gates. Two adapter files:

- `adapters/codex/dispatch.sh`: Closes stdin (Codex may not send EOF), prepends a tier header so Codex always sees its enforcement level. Stop event writes stderr to a file and emits `{"continue":false}` JSON (verified: `adapters/codex/dispatch.sh:1-35`).

- `adapters/codex/adapter.sh`: Redirects stderr→stdout (Codex reads stdout as developer instructions). Labels all output with "rules + guidance only" tier statement (verified: `adapters/codex/adapter.sh:1-63`).

Setup injects constitution into `AGENTS.md`, creates `.codex/hooks.json` (SessionStart + Stop only), enables `codex_hooks` feature flag in `.codex/config.toml`, and configures project trust in `~/.codex/config.toml` (verified: `setup.sh:364-478`).

### 5. Installation and Distribution

`setup.sh` (v4.0) handles installation with a junction-based distribution model (verified: `setup.sh:1-684`):

1. Ensures `~/.baton` exists (clones from GitHub if needed, pulls if already present)
2. Detects self-install (running inside baton's own source repo)
3. Auto-detects IDEs from project directory markers (`.claude/`, `.cursor/`, `AGENTS.md`, etc.)
4. Creates `.baton/` junction pointing to `~/.baton/.baton/` (the source of truth)
5. Creates skill junctions into each IDE's skills directory (`.claude/skills/`, `.cursor/skills/`, `.agents/skills/`)
6. Generates/merges IDE-specific config files (preserves existing user hooks during merge)
7. Updates `.gitignore` to exclude junctions

The junction model means updates propagate automatically — updating `~/.baton` (via `git pull`) updates all projects simultaneously.

### 6. Extension Points — Adding a New Hook

To add a new hook, you need:

1. **Script**: Create `.baton/hooks/<name>.sh` following the pattern: fail-open trap, source `lib/common.sh`, read `BATON_STDIN`, implement logic, exit 0 (allow) or exit 2 (block for PreToolUse/TaskCompleted events).

2. **Manifest line**: Add `Event:Matcher:name` to `manifest.conf`. The dispatcher will automatically route matching events to your script.

3. **IDE registration**: For Claude Code/Factory, add the event to `.claude/settings.json` hooks (if it's a new event type not already registered). For Cursor/Codex, update the adapter dispatch files.

4. **Tests**: Create `tests/test-<name>.sh` following the existing assertion pattern.

### 7. Design Philosophy

The system has several notable design choices:

- **Fail-open by default**: Every hook has a `trap 'exit 0' HUP INT TERM` at the top. If anything goes wrong, the operation is allowed rather than blocked. This prevents hook bugs from breaking the development workflow (verified: every hook script's first non-comment line).

- **jq optional, awk fallback**: All JSON parsing has a fallback path for environments without jq. This keeps the "zero compiled dependencies" promise (verified: `dispatch.sh:26-30`, `write-lock.sh:35-45`).

- **Layered defense model**: Self-challenge (AI self-check) + context-isolated review + human annotation. The constitution explicitly states "adding more structural checks (hooks) does not solve quality problems — it incentivizes mechanical compliance" (verified: `constitution.md`, Defense Model section).

- **Capability tiering**: Each IDE adapter self-labels its enforcement level so the AI knows what's enforced vs. advisory. Codex explicitly says "hard gates not available, relies on rules and guidance" (verified: `adapters/codex/adapter.sh:7-11`).

## Self-Challenge

The weakest part of this investigation is the **runtime behavior under concurrent hooks**. I verified the dispatch code statically, but did not run tests to confirm that multiple hooks on the same event (e.g., both `write-lock` and `post-write-tracker` on Write tools, or both `post-write-tracker` and `quality-gate` on PostToolUse) execute correctly in sequence with proper stdin sharing. The `BATON_STDIN` export mechanism should handle this (since each hook reads from the exported variable, not from stdin directly), but I did not verify this at runtime.

I also did not trace what happens when `run-hook.cmd` is invoked on a system where Git Bash is not installed — the code silently exits 0 (verified in code: `run-hook.cmd:40`), but whether this fail-open is actually desired for all event types is a judgment call not tested here.

## Open Questions

1. **Adapter completeness for Cursor**: The Cursor dispatch adapter (`adapters/cursor/dispatch.sh`) routes all events through `dispatch.sh`, but the manifest includes `TaskCompleted` and `PostToolUseFailure` events. Cursor's documented event types do not include these exact names — does Cursor actually fire events that would trigger `completion-check.sh` and `failure-tracker.sh`?

2. **Session ID reliability**: `failure-tracker.sh` and `post-write-tracker.sh` use session-based temp files (`/tmp/baton-failures-*`, `/tmp/baton-writeset-violations-*`). They fall back to `PPID` when no session ID is available. On Windows (Git Bash spawned by cmd.exe), PPID behavior may differ from Unix — are these counters actually reliable across the full hook lifecycle on Windows?
