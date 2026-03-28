# Baton Hooks System: Complete Investigation

## 1. Architecture Overview

The baton hooks system is a **shell-based, event-driven hook dispatcher** that enforces a plan-first workflow for AI coding assistants. It intercepts IDE tool calls (file writes, bash commands, session events) to enforce governance rules defined in the baton constitution.

### Core Design Principles

- **Fail-open**: Every hook uses `trap 'exit 0' HUP INT TERM` so that unexpected errors never block the developer. The only intentional blocks use `exit 2`.
- **Subshell isolation**: Each hook runs in a subshell `( . "$_dir/$_script.sh" )` so one hook's exit/variable state cannot affect another.
- **Stdin buffering**: The dispatcher reads stdin once into `BATON_STDIN` so multiple hooks can access the same JSON payload.
- **Cross-platform**: `run-hook.cmd` is a polyglot file (batch + bash) that works on both Windows and Unix.

### File Layout

```
hooks/
  dispatch.sh          -- Central event router (reads manifest, runs matching hooks)
  run-hook.cmd         -- Cross-platform entry point (polyglot batch/bash)
  manifest.conf        -- Event-to-hook routing table
  lib/
    common.sh          -- Shared functions (legacy wrappers + test suite detection)
    plan-parser.sh     -- Plan/research file discovery, section parsing, write-set extraction
  write-lock.sh        -- [PreToolUse] Hard-blocks source writes without BATON:GO
  bash-guard.sh        -- [PreToolUse] Blocks shell write patterns without BATON:GO
  phase-guide.sh       -- [SessionStart] Detects phase and outputs guidance
  post-write-tracker.sh-- [PostToolUse] Warns about writes to files not in the plan
  quality-gate.sh      -- [PostToolUse] Checks for Self-Challenge section in plans
  stop-guard.sh        -- [Stop] Reminds about incomplete tasks when session ends
  completion-check.sh  -- [TaskCompleted] Blocks completion without retrospective
  failure-tracker.sh   -- [PostToolUseFailure] Counts failures, alerts at thresholds
  pre-compact.sh       -- [PreCompact] Preserves context before context compression
  subagent-context.sh  -- [SubagentStart] Injects plan context into subagents
```

---

## 2. How Hooks Are Triggered

### 2.1 Registration Path

Hooks are registered in the IDE's settings via `setup.sh`. For Claude Code (the primary target), the installer writes hook entries into `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|CreateFile|NotebookEdit",
        "hooks": [{"type": "command", "command": "/path/to/run-hook.cmd PreToolUse"}]
      },
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "/path/to/run-hook.cmd PreToolUse"}]
      }
    ],
    "PostToolUse": [...],
    "SessionStart": [...],
    "Stop": [...],
    ...
  }
}
```

When the IDE is about to execute a tool (e.g., `Write`), it invokes the registered command with the event name, passing a JSON payload on stdin containing `tool_name`, `tool_input`, `cwd`, etc.

### 2.2 Dispatch Flow

```
IDE event (e.g., PreToolUse with tool=Write)
  --> run-hook.cmd PreToolUse
    --> dispatch.sh PreToolUse
      1. Buffers stdin into BATON_STDIN
      2. Extracts tool_name from JSON (jq with awk fallback)
      3. Reads manifest.conf line by line
      4. For each matching entry (event + tool matcher):
         - Runs hook script in subshell
         - Tracks exit codes (exit 2 = block)
      5. Returns exit 2 if any hook blocked, else exit 0
```

### 2.3 The Manifest (`manifest.conf`)

The manifest is a simple text file with the format `event:matcher:script`:

```
SessionStart::phase-guide
PreToolUse:Write,Edit,MultiEdit,CreateFile,NotebookEdit:write-lock
PreToolUse:Bash:bash-guard
PostToolUse:Write,Edit,MultiEdit,CreateFile,NotebookEdit:post-write-tracker
PostToolUse:Write,Edit,MultiEdit,CreateFile,NotebookEdit:quality-gate
SubagentStart::subagent-context
Stop::stop-guard
TaskCompleted::completion-check
PostToolUseFailure::failure-tracker
PreCompact::pre-compact
```

- Empty matcher (e.g., `SessionStart::phase-guide`) matches all tool names.
- Comma-separated matcher (e.g., `Write,Edit`) matches any listed tool.
- Comments (`#`) and blank lines are skipped.

### 2.4 Matcher Filtering

The dispatcher extracts `tool_name` from the JSON stdin. If a manifest entry has a non-empty matcher, the dispatcher checks if `tool_name` appears in the comma-separated list. If the matcher is specified but no tool name is available (e.g., no stdin), the hook is skipped.

### 2.5 IDE Adapter System

Not all IDEs use the same hook protocol. Baton has an adapter layer in `.baton/adapters/`:

| IDE | Adapter | Protocol Translation |
|-----|---------|---------------------|
| Claude Code / Factory AI | Direct (dispatch.sh) | Exit codes (0=allow, 2=block) |
| Cursor | `adapters/cursor/dispatch.sh` | Translates exit code 2 to `{"decision":"deny","reason":"..."}` |
| Codex | `adapters/codex/dispatch.sh` | Advisory only (no PreToolUse), SessionStart/Stop with JSON protocol |

The Cursor adapter maps camelCase event names (e.g., `preToolUse`) to PascalCase (`PreToolUse`) before calling dispatch.sh, and wraps the exit code in JSON.

The Codex adapter is limited because Codex has no `PreToolUse` hook -- it can only provide advisory guidance at `SessionStart` and `Stop`.

---

## 3. Individual Hook Behaviors

### 3.1 write-lock.sh (PreToolUse -- HARD BLOCK)

**Purpose**: Block source code writes until the plan contains `<!-- BATON:GO -->`.

**Decision logic**:
1. `BATON_BYPASS=1` --> allow immediately
2. No target path determinable --> fail-open with warning
3. Target is `.md`/`.mdx` --> allow (but check for governance marker injection)
4. Target is outside project root --> allow
5. No plan found --> **BLOCK** (exit 2)
6. Multiple plans, no `BATON_PLAN` set --> **BLOCK** (ambiguous)
7. Plan exists, no `BATON:GO` --> **BLOCK**
8. Plan has `BATON:GO`:
   - If write-set defined in plan's `## Todo` section: check if target is in the write set
   - Target not in write set --> **BLOCK**
   - Target in write set or no write set defined --> **ALLOW** (with additionalContext JSON on stdout)

**Governance marker protection**: Even for allowed `.md` files, the hook checks if the AI is trying to write `<!-- BATON:GO -->` or `<!-- BATON:OVERRIDE -->` and blocks it -- only humans may add these markers.

**Exit codes**: 0 = allow, 2 = block.

### 3.2 bash-guard.sh (PreToolUse -- HARD BLOCK)

**Purpose**: Block explicit shell write patterns when the plan gate is closed.

**Decision logic**:
1. Plan exists and has `BATON:GO` --> allow everything
2. Multi-plan ambiguity without `BATON_PLAN` --> treat as gate-closed
3. No command in stdin --> allow (nothing to check)
4. Quote-strip the command, then check against blocklist:
   - Output redirection (`>`, `>>`, `1>`, `2>`)
   - Heredoc with redirect (`cat <<EOF > file`)
   - `tee` (standalone or piped)
   - In-place editors (`sed -i`, `perl -pi`)
   - `python -c` with file write patterns (`open(..., 'w')`)
   - File mutation commands (`cp`, `mv`, `install`, `truncate`, `patch`)
5. Matched --> **BLOCK** (exit 2)
6. Warn-only patterns: `rm`, `touch` --> exit 0 with warning

**Key technique**: The `strip_quoted_segments()` function removes content inside single/double quotes before pattern matching, so `echo 'cp src dst'` is not falsely blocked.

### 3.3 phase-guide.sh (SessionStart -- ADVISORY)

**Purpose**: Detect the current workflow phase and output contextual guidance.

**State machine** (priority order):
1. **FINISH** -- Plan + GO + all Todo items done
2. **AWAITING_TODO** -- Plan + GO + no `## Todo` section or zero items
3. **IMPLEMENT** -- Plan + GO + some Todo items remain
4. **ANNOTATION** -- Plan exists, no GO
5. **PLAN** -- Research exists, no plan
6. **RESEARCH** -- Nothing exists

**Skill detection**: Scans `.claude/skills/`, `.cursor/skills/`, `.agents/skills/`, and `~/.claude/skills/` for installed skills. If relevant skills exist (e.g., `baton-research`, `baton-plan`, `baton-implement`), it prompts the AI to load them. Otherwise, it provides hardcoded fallback guidance.

**Governance context injection**: On exit (via `trap ... EXIT`), it reads `skills/using-baton/SKILL.md` and outputs it as `additionalContext` JSON on stdout, ensuring the AI always receives baton's orchestration rules.

### 3.4 post-write-tracker.sh (PostToolUse -- ADVISORY)

**Purpose**: Warn when a modified file is not in the plan's approved write set.

**Behavior**:
- Only runs when plan exists and has `BATON:GO`
- Markdown files always pass silently
- Extracts write set from `Files:` fields in the plan's `## Todo` section
- If file is not in write set --> warning to stderr
- Tracks repeat violations per session in `/tmp/baton-writeset-violations-{session_id}`
- Repeat violations get escalated warnings about scope drift

**Always exits 0** -- PostToolUse hooks cannot block.

### 3.5 quality-gate.sh (PostToolUse -- ADVISORY)

**Purpose**: Check that plan/research files contain a `## Self-Challenge` section with sufficient depth (>=3 content lines).

**Behavior**: Only triggers on files matching `plan*.md` or `research*.md`. Warns if the section is missing or too shallow. Always exits 0.

### 3.6 stop-guard.sh (Stop -- ADVISORY)

**Purpose**: Remind about incomplete tasks when the session ends.

**Behavior**:
- Only runs during implement phase (plan + GO)
- All done --> FINISH phase reminder (retrospective, test suite, BATON:COMPLETE, branch disposition)
- Items remaining --> progress summary ("3/5 done, 2 remaining")
- Always exits 0 (never blocks stopping)

### 3.7 completion-check.sh (TaskCompleted -- SOFT BLOCK)

**Purpose**: Block task completion until a valid retrospective is written.

**Decision logic**:
1. Multi-plan ambiguity --> **BLOCK** (exit 2)
2. No plan or no GO --> allow (nothing to enforce)
3. Not all Todo items done --> allow
4. All Todo items done, no `## Retrospective` --> **BLOCK** (exit 2)
5. Retrospective exists but <3 non-empty lines --> **BLOCK** (exit 2)
6. Valid retrospective --> allow (advisory warnings for unresolved markers and test suite)

### 3.8 failure-tracker.sh (PostToolUseFailure -- ADVISORY)

**Purpose**: Count cumulative tool failures per session and alert at thresholds.

**Behavior**:
- Appends each failure to `/tmp/baton-failures-{session_id}`
- Alerts at exactly 3 failures: "check if any two share the same root-cause hypothesis"
- Alerts at exactly 5 failures: "failure boundary very likely applies"
- Uses session_id from JSON, falls back to PPID
- Always exits 0

**Limitation**: The constitution's failure boundary is per-hypothesis (>=2 under same causal claim), but hooks cannot track hypothesis identity. Per-hypothesis enforcement must happen at the AI layer.

### 3.9 pre-compact.sh (PreCompact -- ADVISORY)

**Purpose**: Preserve key context before the IDE compresses the context window.

**Output includes**:
- Current phase (IMPLEMENT/FINISH/PLAN-ANNOTATION/AWAITING_TODO)
- Todo progress (done/total)
- Remaining Todo items (up to 5)
- Authorized write set (up to 10 files)
- Recent Annotation Log entries (last 10 lines)
- Always exits 0

### 3.10 subagent-context.sh (SubagentStart -- ADVISORY)

**Purpose**: Inject plan context when a subagent (e.g., Claude Code's parallel worker) starts.

**Output includes**:
- Todo progress and items (up to 20 lines)
- Authorized write set
- Phase context if no GO
- Always exits 0

---

## 4. Shared Infrastructure

### 4.1 plan-parser.sh

The backbone library providing all plan/research file discovery and section parsing:

**1A Discovery primitives**:
- `parser_find_plan()` -- Walk-up directory search for `plan.md` or `plan-*.md` (also searches `baton-tasks/*/`). Filters out COMPLETE-marked plans. Disambiguates multiple plans via BATON:GO uniqueness and BATON_TARGET context.
- `parser_find_research()` -- Find paired research file by deriving name from plan (e.g., `plan-hooks.md` -> `research-hooks.md`). Falls back to glob search.
- `parser_has_go()` -- Check for `<!-- BATON:GO -->` marker.
- `parser_has_skill()` -- Walk-up skill directory search.
- `parser_project_root()` -- Infer project root by walking up to find `.baton/`, `.git/`, `.claude/`, etc.

**1B Section primitives**:
- `parser_todo_range()` -- Find `## Todo` section line range.
- `parser_todo_counts()` -- Count `- [x]` vs `- [ ]` items scoped to `## Todo` only.
- `parser_retro_range()` / `parser_retro_valid()` -- Find and validate `## Retrospective`.

**1C Write-set primitives**:
- `parser_writeset_normalize()` -- Strip `./`, convert absolute paths to project-relative.
- `parser_writeset_extract()` -- Parse `Files:` fields from `## Todo` items (backtick-wrapped, comma-separated).
- `parser_writeset_contains()` -- Check if a path is in the write set.

### 4.2 common.sh

Thin wrapper that sources plan-parser.sh and provides:
- Legacy function wrappers (`resolve_plan_name`, `find_plan`, `has_skill`)
- `baton_resolve_test_cmd()` -- Auto-detect project test command (npm test, make test, pytest, etc.)

---

## 5. Failure Modes

### 5.1 Designed Fail-Open Cases

These are **intentional** -- the hook allows the operation when it cannot determine the correct action:

| Condition | Hook | Behavior |
|-----------|------|----------|
| Cannot determine target file path | write-lock | Allow with warning on stderr |
| `common.sh` or `plan-parser.sh` not found | All hooks | Allow silently (exit 0) |
| `jq` not installed | write-lock, bash-guard, etc. | Fall back to `awk`/`sed` parsing |
| `manifest.conf` missing | dispatch.sh | Exit 0 (no hooks to run) |
| No stdin (no JSON payload) | bash-guard | Allow (no command to check) |
| Unexpected error (trap fires) | All hooks | Exit 0 with warning to stderr |
| File outside project root | write-lock | Allow (not baton's scope) |
| `BATON_BYPASS=1` | write-lock, post-write-tracker, completion-check, pre-compact, subagent-context | Skip all checks |

### 5.2 Designed Fail-Closed Cases

These cause **intentional blocking** (exit 2):

| Condition | Hook | Exit Code |
|-----------|------|-----------|
| No plan file found | write-lock | 2 |
| Plan exists, no BATON:GO | write-lock | 2 |
| Multiple plans, no BATON_PLAN | write-lock, completion-check | 2 |
| File not in approved write set | write-lock | 2 |
| AI writing governance markers (BATON:GO, BATON:OVERRIDE) | write-lock | 2 |
| Shell write pattern with gate closed | bash-guard | 2 |
| All todos done, no valid retrospective | completion-check | 2 |

### 5.3 Potential Undesigned Failure Modes

#### 5.3.1 Parser Failures

- **awk fallback for jq**: The `awk` and `sed` fallbacks for JSON parsing are fragile. If the JSON payload contains escaped quotes, multi-line content, or unusual formatting, the awk parser may extract the wrong field value or nothing at all. This would cause write-lock to fail-open (no target path found).
- **realpath/readlink unavailability**: Path canonicalization in `_canonicalize_path()` falls back through `realpath -m`, `readlink -f`, and manual `cd + pwd`. On minimal systems (e.g., Alpine containers), all may be unavailable, causing path comparison to fail. The write-set check could incorrectly block or allow.

#### 5.3.2 Multi-Plan Disambiguation Edge Cases

- **mtime-based selection**: When multiple plans exist without BATON_PLAN, the parser selects by mtime (`ls -t`). If file timestamps are reset (git clone, CI artifact), the wrong plan may be selected.
- **Disambiguation Layer 1 (GO uniqueness)**: If exactly one plan has BATON:GO, it is selected. But if two plans both have GO, it falls through to mtime selection, which may pick the wrong one. The warning on stderr is easy to miss.
- **Disambiguation Layer 2 (BATON_TARGET context)**: Only applies when the target path is in a `baton-tasks/<topic>/` subdirectory. For files at the project root, this layer provides no help.

#### 5.3.3 Write-Set Enforcement Gaps

- **No write-set defined**: If the plan's `## Todo` section does not use `Files:` fields, write-set enforcement is entirely skipped. The post-write-tracker falls back to simple basename grep against the plan text, which is unreliable (e.g., `utils.ts` would match any mention of "utils.ts" in any context).
- **Path normalization asymmetry**: The write-set uses project-relative paths, but the target path comes from the IDE's JSON payload which may be absolute. While `parser_writeset_normalize()` handles this, edge cases with symlinks, mount points, or case-insensitive filesystems could cause false blocks or false allows.
- **New file creation**: `CreateFile` tool is in the write-lock matcher, but newly created files are by definition not yet in the write set. This requires the plan to list new files with `(new)` annotation, which may be omitted.

#### 5.3.4 Bash Guard Evasion

The bash-guard uses pattern matching on the shell command string after stripping quoted segments. Known bypass vectors:

- **Obfuscated commands**: `eval "$(echo 'cp a b')"` -- the actual `cp` is inside an eval, not visible to pattern matching.
- **Variable expansion**: `$CMD` where CMD=cp -- the variable is not expanded by the pattern matcher.
- **Aliases or functions**: A function named `mycp` that calls `cp` internally would not be caught.
- **Binary execution**: Running a compiled binary that writes files (e.g., `./my-tool --output file.txt`) is not caught.
- **dd command**: `dd if=input of=output` is not in the blocklist.
- **xargs with write commands**: `echo 'content' | xargs -I{} cp {} file.txt` -- `xargs` is not blocked.

The bash-guard is documented as "advisory" -- it catches obvious patterns but cannot provide complete coverage.

#### 5.3.5 Race Conditions

- **Plan modification during hook execution**: If the plan file is modified (e.g., BATON:GO removed) between when write-lock reads it and when the write actually occurs, the hook's decision is stale. However, since hooks run synchronously before the tool executes, this is only a concern if another process modifies the plan concurrently.
- **Temp file accumulation**: `failure-tracker.sh` and `post-write-tracker.sh` write to `/tmp/baton-failures-{session}` and `/tmp/baton-writeset-violations-{session}`. These files are never cleaned up within a session and accumulate across sessions if session IDs are reused.

#### 5.3.6 Governance Context Injection (phase-guide.sh)

- **Large SKILL.md content**: The governance context injection reads `using-baton/SKILL.md` and escapes it for JSON output. Extremely large SKILL.md files could cause shell performance issues (the escaping is done character-by-character in bash). Tests verify this works up to 3KB.
- **JSON escaping edge cases**: The `_escape_for_json()` function handles `\`, `"`, `\n`, `\r`, `\t`. Other special characters (e.g., null bytes, unicode) could produce invalid JSON. This would cause the IDE to silently ignore the governance context.

#### 5.3.7 Adapter-Specific Issues

- **Codex stdin hang**: The Codex adapter explicitly closes stdin (`</dev/null`) because "Codex may not send EOF, causing dispatch.sh's `cat` to hang." If this workaround is not applied in a future adapter, the dispatcher will hang indefinitely on the `BATON_STDIN="$(cat)"` line.
- **Cursor JSON escaping**: The Cursor adapter escapes output for JSON using `sed 's/\\/\\\\/g; s/"/\\"/g'` and `tr '\n' ' '`. Multi-line stderr output with special characters could produce malformed JSON, causing Cursor to misinterpret the response.

#### 5.3.8 Section-Scoping Fragility

All section parsing (Todo, Retrospective, Self-Challenge) relies on exact header matching:
- `## Todo` must be followed by optional spaces only (regex: `/^## Todo[[:space:]]*$/`)
- `## Retrospective` must be an exact match
- `## Retrospective Notes` (note the extra word) does NOT match -- this is tested and intentional but could confuse users

If a user writes `## TODO` (all caps) or `## To-do` (hyphenated), the section would not be found, and hooks would behave as if it does not exist. Write-lock would still allow writes (no write-set to enforce), but completion-check would block (no retrospective found).

---

## 6. Exit Code Protocol Summary

| Exit Code | Meaning | Used By |
|-----------|---------|---------|
| 0 | Allow / advisory output only | All hooks |
| 2 | Block (PreToolUse/TaskCompleted) | write-lock, bash-guard, completion-check |
| Other | Unexpected error -- surfaced as warning by dispatch.sh | Not intentionally used |

The dispatcher aggregates exit codes: "first blocking exit (exit 2) wins," but all hooks still run even after one blocks. Non-0, non-2 exit codes trigger a warning on stderr.

---

## 7. Testing Infrastructure

The hooks system has extensive test coverage in `/tests/`:

| Test File | Hook(s) Tested | Test Count (approx) |
|-----------|---------------|---------------------|
| test-dispatch.sh | dispatch.sh (routing, matchers, isolation, stdin buffering) | ~15 |
| test-write-lock.sh | write-lock.sh (all block/allow scenarios, JSON parsing, walk-up, multi-plan, write-set) | ~40 |
| test-bash-guard.sh | bash-guard.sh (all block/allow patterns, quote stripping, path-qualified commands) | ~45 |
| test-stop-guard.sh | stop-guard.sh (all phases, walk-up, section-aware counting) | ~25 |
| test-phase-guide.sh | phase-guide.sh (all 6 states, skill detection, governance context) | ~50 |
| test-new-hooks.sh | post-write-tracker, subagent-context, completion-check, pre-compact, failure-tracker | ~40 |

Optional benchmark test: `BATON_RUN_BENCH=1` runs 100 write-lock invocations and asserts <200ms average latency.

---

## 8. Summary Table: Hook Trigger Matrix

| Event | Tools Matched | Hook | Can Block? | Hard/Soft |
|-------|--------------|------|-----------|-----------|
| SessionStart | (all) | phase-guide.sh | No | Advisory |
| PreToolUse | Write, Edit, MultiEdit, CreateFile, NotebookEdit | write-lock.sh | Yes | Hard (exit 2) |
| PreToolUse | Bash | bash-guard.sh | Yes | Hard (exit 2) |
| PostToolUse | Write, Edit, MultiEdit, CreateFile, NotebookEdit | post-write-tracker.sh | No | Advisory |
| PostToolUse | Write, Edit, MultiEdit, CreateFile, NotebookEdit | quality-gate.sh | No | Advisory |
| SubagentStart | (all) | subagent-context.sh | No | Advisory |
| Stop | (all) | stop-guard.sh | No | Advisory |
| TaskCompleted | (all) | completion-check.sh | Yes | Soft (exit 2) |
| PostToolUseFailure | (all) | failure-tracker.sh | No | Advisory |
| PreCompact | (all) | pre-compact.sh | No | Advisory |
