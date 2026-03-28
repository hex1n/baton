# Baton Hook System

## Calibration

**Depth**: Standard
**Decision boundary**: This investigation determines **what the baton hook system is, how it's structured, and what it enforces**, so that a developer can understand the hook architecture and know where to look when modifying or debugging hooks.

The prompt "研究一下 baton 的 hook 系统" is vague. I narrowed it to architecture comprehension rather than attempting to cover everything (testing, history, design rationale, edge cases, etc.).

---

## Answer

Baton's hook system is an **event-driven enforcement and guidance layer** that intercepts AI tool usage at defined lifecycle points. It consists of three tiers:

1. **Dispatch engine** (`hooks/dispatch.sh`) — reads a manifest, matches events+tools, runs hook scripts in subshells
2. **Individual hook scripts** (11 scripts in `hooks/`) — each enforces or advises on a specific invariant
3. **IDE adapters** (`.baton/adapters/{codex,cursor}/`) — translate dispatch exit codes and output into each IDE's protocol

### Architecture Overview

```
IDE (Claude Code / Cursor / Codex)
  |
  v
[IDE-specific hook config]  -- e.g., ~/.claude/settings.json "hooks" section
  |
  v
run-hook.cmd                -- cross-platform polyglot entry point (bash/cmd)
  |
  v
dispatch.sh                 -- reads manifest.conf, buffers stdin, matches event+tool, runs hooks
  |
  v
manifest.conf               -- event:matcher:script routing table
  |
  v
individual hook scripts     -- sourced in subshells; exit 0 = allow, exit 2 = block
  |
  v
hooks/lib/common.sh         -- shared functions (plan discovery, legacy wrappers)
hooks/lib/plan-parser.sh    -- plan discovery, section parsing, write-set extraction
```

---

## Key Components

### 1. Dispatch Engine (`hooks/dispatch.sh`) ✅ read hooks/dispatch.sh

The central router. Receives an event name as `$1`, reads `manifest.conf` line by line, and for each matching entry, runs the hook script in a subshell (`( . "$_dir/$_script.sh" )`).

Key mechanics:
- **Stdin buffering**: Reads all stdin into `BATON_STDIN` env var once, so multiple hooks can access the same JSON payload ✅ dispatch.sh:17-20
- **Tool name extraction**: Parses `tool_name` from stdin JSON (jq with sed fallback) for matcher filtering ✅ dispatch.sh:24-31
- **Exit code semantics**: `exit 0` = allow, `exit 2` = block (PreToolUse only), anything else = warning logged ✅ dispatch.sh:54-61
- **Isolation**: Each hook runs in a subshell, so variable state and exit codes don't leak between hooks ✅ dispatch.sh:50-52

### 2. Manifest (`hooks/manifest.conf`) ✅ read hooks/manifest.conf

A simple `event:matcher:script` routing table with 10 entries:

| Event | Matcher (tools) | Script | Behavior |
|-------|-----------------|--------|----------|
| SessionStart | (all) | phase-guide | Detects phase, outputs guidance |
| PreToolUse | Write,Edit,MultiEdit,CreateFile,NotebookEdit | write-lock | **Blocks** writes without BATON:GO |
| PreToolUse | Bash | bash-guard | **Blocks** shell write patterns without BATON:GO |
| PostToolUse | Write,Edit,MultiEdit,CreateFile,NotebookEdit | post-write-tracker | Warns on out-of-write-set files |
| PostToolUse | Write,Edit,MultiEdit,CreateFile,NotebookEdit | quality-gate | Checks for Self-Challenge section |
| SubagentStart | (all) | subagent-context | Injects plan context into subagents |
| Stop | (all) | stop-guard | Reminds about incomplete tasks |
| TaskCompleted | (all) | completion-check | **Blocks** completion without retrospective |
| PostToolUseFailure | (all) | failure-tracker | Counts failures, alerts at 3 and 5 |
| PreCompact | (all) | pre-compact | Preserves plan context before compression |

### 3. Individual Hooks

#### Hard gates (can block via exit 2):

**write-lock.sh** ✅ read hooks/write-lock.sh
- Blocks source code writes until plan contains `<!-- BATON:GO -->`
- Always allows markdown files (but blocks AI from writing governance markers like BATON:GO/BATON:OVERRIDE) ✅ write-lock.sh:65-77
- Enforces write-set: if plan defines a `Files:` list in `## Todo`, target must be in it ✅ write-lock.sh:150-161
- Fail-open design: unexpected errors allow the operation ✅ write-lock.sh:14
- Emergency bypass: `BATON_BYPASS=1` ✅ write-lock.sh:17-20

**bash-guard.sh** ✅ read hooks/bash-guard.sh
- Blocks explicit shell write patterns (redirections, heredocs, tee, sed -i, cp, mv, etc.) when gate is closed ✅ bash-guard.sh:100-146
- Quote-stripping: removes content inside quotes before scanning, so string literals in echo/printf don't trigger false positives ✅ bash-guard.sh:54-86
- Warn-only for ambiguous patterns (rm, touch) ✅ bash-guard.sh:155-162

**completion-check.sh** ✅ read hooks/completion-check.sh
- Blocks task completion if all Todo items done but no `## Retrospective` with >=3 content lines ✅ completion-check.sh:44-62
- Warns about unresolved evidence markers and test suite ✅ completion-check.sh:64-74

#### Advisory hooks (always exit 0):

**phase-guide.sh** ✅ read hooks/phase-guide.sh
- Detects current phase from plan state: RESEARCH -> PLAN -> ANNOTATION -> AWAITING_TODO -> IMPLEMENT -> FINISH ✅ phase-guide.sh:7
- Outputs phase-specific guidance to stderr
- Injects `using-baton` SKILL.md as governance context via `additionalContext` JSON on stdout ✅ phase-guide.sh:27-39
- Dynamically scans for installed skills and suggests relevant ones per phase ✅ phase-guide.sh:53-83

**post-write-tracker.sh** ✅ read hooks/post-write-tracker.sh
- Warns when modified files aren't in the plan's write set ✅ post-write-tracker.sh:79-113
- Tracks repeat violations per session via temp files, escalates on repeats ✅ post-write-tracker.sh:85-99

**stop-guard.sh** ✅ read hooks/stop-guard.sh
- Reminds about incomplete tasks when session stops
- Shows progress (N/M Todo items) and finish workflow steps ✅ stop-guard.sh:32-50

**failure-tracker.sh** ✅ read hooks/failure-tracker.sh
- Counts tool failures per session via `/tmp/baton-failures-<session>` ✅ failure-tracker.sh:49-52
- Alerts at 3 and 5 failures; references constitution's per-hypothesis failure boundary ✅ failure-tracker.sh:57-61

**quality-gate.sh** ✅ read hooks/quality-gate.sh
- Checks plan/research files for `## Self-Challenge` section with >=3 content lines ✅ quality-gate.sh:25-43

**subagent-context.sh** ✅ read hooks/subagent-context.sh
- Injects Todo items and write set into subagent context ✅ subagent-context.sh:35-48

**pre-compact.sh** ✅ read hooks/pre-compact.sh
- Outputs plan progress, write set, and annotation log before context compression ✅ pre-compact.sh:29-67

### 4. Shared Libraries (`hooks/lib/`)

**plan-parser.sh** ✅ read hooks/lib/plan-parser.sh
- **1A Discovery**: `parser_find_plan` (walk-up plan discovery with multi-plan disambiguation), `parser_find_research`, `parser_has_go`, `parser_has_skill`, `parser_project_root`
- **1B Section parsing**: `parser_todo_range`, `parser_todo_counts`, `parser_todo_items`, `parser_retro_range`, `parser_retro_valid`
- **1C Write-set**: `parser_writeset_normalize`, `parser_writeset_extract`, `parser_writeset_contains`
- Double-source guard via `_BATON_PARSER_LOADED` ✅ plan-parser.sh:28-29

**common.sh** ✅ read hooks/lib/common.sh
- Sources plan-parser.sh, provides legacy wrapper functions (`resolve_plan_name`, `find_plan`, `has_skill`)
- `baton_resolve_test_cmd` — auto-detects test command from project structure ✅ common.sh:46-63

### 5. IDE Adapters

**Claude Code** (primary): Hooks registered in `~/.claude/settings.json` via `setup.sh`. The `run-hook.cmd` polyglot entry point calls `dispatch.sh` directly. Exit 2 = block, stderr = displayed to AI as context. ✅ read setup.sh:66-128

**Cursor** (`.baton/adapters/cursor/`): Two files:
- `adapter.sh`: Translates write-lock exit codes to Cursor JSON protocol (`{"decision":"allow"}` / `{"decision":"deny","reason":"..."}`) ✅ read cursor/adapter.sh
- `dispatch.sh`: Full dispatch adapter mapping camelCase events to PascalCase ✅ read cursor/dispatch.sh

**Codex** (`.baton/adapters/codex/`): Two files:
- `adapter.sh`: Wraps phase-guide and stop-guard only (no hard gates on Codex) ✅ read codex/adapter.sh
- `dispatch.sh`: Full dispatch adapter; SessionStart outputs on stdout for Codex DeveloperInstructions; Stop writes to file ✅ read codex/dispatch.sh

### 6. Installation (`setup.sh`) ✅ read setup.sh

- Skills: symlinked from `~/.baton/skills/*` to `~/.claude/skills/*`
- Hooks: merged into `~/.claude/settings.json` with jq (removes old baton entries, adds new)
- Constitution: referenced in `~/.claude/CLAUDE.md`
- Migration: `--migrate` removes v4 project-local artifacts

---

## How Hooks Relate to Constitution

The constitution defines the "why"; hooks enforce the "how":

| Constitution Invariant | Hook Enforcement |
|------------------------|------------------|
| "No execution beyond authorization" (Inv. 4) | write-lock.sh blocks writes without BATON:GO |
| "No stale authorization" (Inv. 5) | write-lock.sh enforces write-set boundaries |
| "No completion by implication" (Inv. 6) | completion-check.sh requires retrospective |
| Failure boundary (Permissions) | failure-tracker.sh counts and alerts |
| Governance markers (Permissions) | write-lock.sh blocks AI from writing BATON:GO/OVERRIDE |
| Defense Model ("Hooks enforce structure") | All hooks collectively |

The constitution explicitly notes: "Hooks enforce structure. Review enforces quality. Neither is sufficient alone." ✅ read constitution.md (Defense Model section)

---

## Self-Challenge

1. **Coverage gap**: The hook system is entirely bash-based. If `jq` is unavailable, multiple hooks fall back to `awk`/`sed` parsing which is acknowledged as less reliable (write-lock.sh:51-53). The fail-open design means parsing failures silently allow operations.

2. **Session identity**: failure-tracker.sh and post-write-tracker.sh track state via `/tmp/` files keyed by session ID, falling back to `$PPID`. This is a "session-total proxy" for the constitution's per-hypothesis failure boundary -- the hooks themselves cannot track hypothesis identity. ✅ failure-tracker.sh:9-11

3. **Adapter parity**: Codex adapter explicitly documents it has **no hard gates** (no write-lock, no bash-guard). Cursor adapter only wraps write-lock directly in `adapter.sh`, while `dispatch.sh` provides full event routing. The enforcement level varies significantly by IDE. ✅ codex/adapter.sh:6-11

---

## Key Files

| Path | Role |
|------|------|
| `hooks/dispatch.sh` | Event router, subshell isolation, stdin buffering |
| `hooks/manifest.conf` | Event:matcher:script routing table |
| `hooks/run-hook.cmd` | Cross-platform entry point (bash+cmd polyglot) |
| `hooks/lib/plan-parser.sh` | Plan discovery, section parsing, write-set |
| `hooks/lib/common.sh` | Shared functions, legacy wrappers |
| `hooks/write-lock.sh` | Hard gate: blocks writes without BATON:GO |
| `hooks/bash-guard.sh` | Hard gate: blocks shell writes without BATON:GO |
| `hooks/phase-guide.sh` | Phase detection + guidance injection |
| `hooks/completion-check.sh` | Hard gate: blocks completion without retrospective |
| `hooks/post-write-tracker.sh` | Advisory: write-set drift detection |
| `hooks/quality-gate.sh` | Advisory: Self-Challenge section check |
| `hooks/stop-guard.sh` | Advisory: session-end reminders |
| `hooks/failure-tracker.sh` | Advisory: cumulative failure counting |
| `hooks/subagent-context.sh` | Advisory: plan context for subagents |
| `hooks/pre-compact.sh` | Advisory: context preservation before compression |
| `.baton/adapters/codex/` | Codex IDE adapter (rules+guidance only) |
| `.baton/adapters/cursor/` | Cursor IDE adapter (reduced enforcement) |
| `setup.sh` | User-level installation (hooks, skills, constitution) |

## 批注区
