# Baton Hook System: Architecture and Mechanics

## Calibration

**Depth**: Standard
**Decision boundary**: This investigation determines **what hooks exist, how they are triggered, and what they enforce** so that a developer can understand the hook system's mechanics and constraints.
**Scope**: Hook dispatch mechanism, individual hook behaviors, IDE adapter layer. Out of scope: phase skill internals, detailed review criteria, artifact format details.

## Investigation Plan

1. How does dispatch work? (manifest.conf + dispatch.sh + entry point)
2. What does each hook do? (blocking vs advisory, trigger events)
3. How do IDE adapters translate the hook protocol?
4. What shared infrastructure do hooks depend on? (lib/common.sh, plan-parser.sh)

---

## Finding 1: Dispatch Architecture

The hook system is event-driven. Entry point is `hooks/run-hook.cmd` -- a polyglot Bash/CMD script that delegates to `hooks/dispatch.sh`.

### Entry flow

```
IDE event -> run-hook.cmd -> dispatch.sh <event-name> -> individual hooks
```

`dispatch.sh` (✅ `hooks/dispatch.sh`) does the following:

1. Reads the event name from `$1`.
2. Buffers stdin into `BATON_STDIN` (Claude Code passes tool name + input as JSON).
3. Extracts `tool_name` from the JSON (via jq, with sed fallback).
4. Iterates `manifest.conf` line by line: `event:matcher:script`.
5. For each matching entry, runs the hook in a **subshell** (`( . "$_dir/$_script.sh" )`) to isolate exit codes and variable state.
6. Exit code semantics: `0` = allow, `2` = block (for PreToolUse), anything else = warning logged to stderr.
7. First blocking exit (code 2) wins; subsequent hooks still run but can't override.

### Manifest (✅ `hooks/manifest.conf`)

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

Format is `event:matcher:script`. Empty matcher = match all tools. Comma-separated matchers = match any listed tool.

---

## Finding 2: Individual Hooks -- Blocking vs Advisory

### Blocking hooks (exit 2 = prevent the tool call)

| Hook | Event | Matcher | Purpose |
|------|-------|---------|---------|
| **write-lock.sh** | PreToolUse | Write,Edit,MultiEdit,CreateFile,NotebookEdit | Blocks source writes until plan has `<!-- BATON:GO -->`. Also enforces write-set (files must be listed in plan's `## Todo` `Files:` fields). Always allows `.md` files but blocks AI from writing governance markers (`BATON:GO`, `BATON:OVERRIDE`). ✅ `hooks/write-lock.sh` |
| **bash-guard.sh** | PreToolUse | Bash | Blocks explicit shell write patterns (redirects, tee, sed -i, cp, mv, etc.) when gate is closed. Warns on ambiguous patterns (rm, touch). ✅ `hooks/bash-guard.sh` |
| **completion-check.sh** | TaskCompleted | (all) | Blocks task completion until `## Retrospective` exists with >= 3 content lines. Also warns about unresolved `?` markers and test suite. ✅ `hooks/completion-check.sh` |

### Advisory hooks (exit 0 always, output guidance to stderr)

| Hook | Event | Matcher | Purpose |
|------|-------|---------|---------|
| **phase-guide.sh** | SessionStart | (all) | Detects current phase (RESEARCH / PLAN / ANNOTATION / AWAITING_TODO / IMPLEMENT / FINISH) from artifact state and outputs phase-specific guidance + available skill suggestions. Also injects `using-baton` SKILL.md as governance context via JSON `additionalContext` on exit. ✅ `hooks/phase-guide.sh` |
| **post-write-tracker.sh** | PostToolUse | Write,Edit,etc. | After a write succeeds, checks if the modified file is in the plan's write set. Warns on first violation, escalates warning on repeat violations ("scope drift"). ✅ `hooks/post-write-tracker.sh` |
| **quality-gate.sh** | PostToolUse | Write,Edit,etc. | Checks plan/research files for `## Self-Challenge` section with >= 3 content lines. ✅ `hooks/quality-gate.sh` |
| **stop-guard.sh** | Stop | (all) | When stopping during implement phase, reminds about incomplete todo items or prompts finish workflow if all done. ✅ `hooks/stop-guard.sh` |
| **subagent-context.sh** | SubagentStart | (all) | Injects plan context (todo progress, authorized write set) into subagent sessions. ✅ `hooks/subagent-context.sh` |
| **failure-tracker.sh** | PostToolUseFailure | (all) | Counts cumulative tool failures per session (via `/tmp/baton-failures-{session}`). Alerts at 3 and 5 failures. Cannot track per-hypothesis; that's AI-layer responsibility. ✅ `hooks/failure-tracker.sh` |
| **pre-compact.sh** | PreCompact | (all) | Preserves plan progress, remaining todo items, write set, and annotation log before context compression. ✅ `hooks/pre-compact.sh` |

---

## Finding 3: Shared Infrastructure (lib/)

### plan-parser.sh (✅ `hooks/lib/plan-parser.sh`, Version 1.3)

The core parsing layer, organized in three primitive tiers:

- **1A Discovery**: `parser_find_plan` (walk-up plan discovery with multi-plan disambiguation via BATON:GO uniqueness and BATON_TARGET context), `parser_find_research` (paired research discovery), `parser_has_go`, `parser_has_skill`, `parser_project_root`.
- **1B Section**: `parser_todo_range`, `parser_todo_counts`, `parser_todo_items`, `parser_todo_remaining_items`, `parser_retro_range`, `parser_retro_valid` -- all scoped to `## Todo` or `## Retrospective` sections only.
- **1C Write-Set**: `parser_writeset_normalize` (path normalization including absolute-to-relative), `parser_writeset_extract` (extracts paths from `Files:` fields in `## Todo` items), `parser_writeset_contains`.

### common.sh (✅ `hooks/lib/common.sh`)

Thin wrapper that sources `plan-parser.sh` and provides legacy shims (`resolve_plan_name`, `find_plan`, `has_skill`) plus `baton_resolve_test_cmd` (auto-detects npm/make/pytest/bash test commands).

---

## Finding 4: IDE Adapter Layer

Baton hooks target Claude Code natively (stderr for messages, JSON on stdout for `additionalContext`, exit codes for blocking). Other IDEs need translation.

### Claude Code (native)

`setup.sh` registers hooks in `~/.claude/settings.json` (✅ `setup.sh:66-128`). Each event maps to `run-hook.cmd <EventName>`. The install is user-level (v5 "flat install"), not project-local.

### Cursor adapter (✅ `.baton/adapters/cursor/dispatch.sh`)

- Maps camelCase event names to PascalCase (`preToolUse` -> `PreToolUse`).
- Translates exit codes to Cursor JSON: `{"decision":"allow"}` or `{"decision":"block","reason":"..."}`.
- Separate `adapter.sh` exists as a legacy single-hook adapter (write-lock only).
- **Reduced capability**: labeled as "reduced enforcement (Cursor)".

### Codex adapter (✅ `.baton/adapters/codex/dispatch.sh`, `.baton/adapters/codex/adapter.sh`)

- Only SessionStart and Stop events are wired (✅ `.codex/hooks.json`).
- Hard gates (write-lock, bash-guard) are **not available** on Codex.
- Labeled "rules + guidance only (Codex)" -- enforcement relies on rules and guidance, not tool-call blocking.
- Closes stdin to prevent Codex EOF hang.
- Stop hook writes reminder text to `.codex/stop-hook.message.txt` instead of stdout (stdout is a JSON protocol channel).

### Capability tiers (derived from adapter comments)

| IDE | Hard gates (block) | Advisory hooks | Governance injection |
|-----|-------------------|----------------|---------------------|
| Claude Code | Full (write-lock, bash-guard, completion-check) | Full (all 7 advisory hooks) | SessionStart additionalContext |
| Cursor | Partial (write-lock via adapter, bash-guard) | Reduced (no post-write-tracker, stop-guard, completion-check, failure-tracker) | PreToolUse context field |
| Codex | None | SessionStart + Stop only | Text on stdout |

---

## Finding 5: Safety Design Patterns

1. **Fail-open with visibility**: Every hook has `trap '... exit 0' HUP INT TERM`. If a hook crashes, the tool call is allowed but a warning is emitted. The philosophy is: hooks should never silently break the developer's workflow.

2. **Emergency bypass**: `BATON_BYPASS=1` env var skips enforcement (✅ `write-lock.sh:17`, `post-write-tracker.sh:14`, `completion-check.sh:15`, `subagent-context.sh:14`, `pre-compact.sh:14`).

3. **Subshell isolation**: dispatch.sh runs each hook in `( . "$_dir/$_script.sh" )`, preventing one hook from polluting another's variables or exit status.

4. **Governance marker protection**: write-lock.sh blocks the AI from writing `<!-- BATON:GO -->` or `<!-- BATON:OVERRIDE -->` into non-baton-tasks markdown files (✅ `write-lock.sh:66-77`). This enforces the constitution's rule that only humans place governance markers.

5. **Multi-plan disambiguation**: When multiple active plan files exist, `parser_find_plan` uses a two-layer disambiguation strategy: (1) unique BATON:GO, (2) BATON_TARGET context matching. Falls back to mtime-sorted with warning.

---

## Self-Challenge

- **Weakest conclusion**: The capability tier table for Cursor is inferred partly from adapter comments (✅ `adapter.sh:5-11`) rather than from testing the actual Cursor integration end-to-end. The comment-based evidence is reliable for what's wired, but I cannot verify runtime behavior. **? no runtime access to Cursor**
- **Assumption to verify**: I assumed the manifest.conf shown is the complete and current hook registration. If hooks can be registered outside manifest.conf (e.g., dynamically), this analysis would be incomplete. However, `dispatch.sh` reads only from `manifest.conf` (✅ `dispatch.sh:11`), making this assumption well-founded.
- **What a skeptic would challenge**: The "fail-open" design means a broken hook silently allows operations. This is an intentional safety tradeoff (don't block developer work), but it means hook enforcement can degrade silently if, e.g., `jq` is missing or `plan-parser.sh` has a bug.

---

## Final Conclusions

Baton's hook system is an **event-driven, manifest-routed dispatcher** with 10 hooks covering 8 event types. Three hooks can block (write-lock, bash-guard, completion-check); the rest are advisory. All hooks share a common plan-discovery and write-set-checking infrastructure in `lib/plan-parser.sh`.

The system is designed with a **fail-open safety model**: crashes allow the operation with a visible warning, and `BATON_BYPASS=1` provides an emergency escape hatch. IDE differences are handled by an adapter layer that translates between Baton's stderr/exit-code protocol and each IDE's native hook protocol (Cursor JSON, Codex stdout text).

The constitution (✅ `constitution.md`) describes hooks as one layer of defense: "Hooks enforce structure. Review enforces quality. Neither is sufficient alone." This accurately reflects the implementation -- hooks enforce structural gates (plan exists, GO marker present, file in write set) but cannot enforce quality judgments (those are the AI's responsibility at the skill layer).

## 批注区
