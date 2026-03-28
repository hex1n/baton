**Question**: How does baton's hooks system work? How are all hooks triggered, and what are the failure modes?
**Depth**: Deep
**Key finding**: Baton uses a manifest-driven event dispatcher (`dispatch.sh`) that routes 9 Claude Code lifecycle events to 10 hook scripts, split into blocking (exit 2) and advisory (exit 0) categories, with fail-open as the default safety posture and multiple concrete failure modes around plan discovery, JSON parsing, and cross-platform adaptation.
**Open questions**: 3 -- see end of document

---

## Architecture Overview

```
Claude Code Runtime
    |
    v
~/.claude/settings.json       <-- user-level hook registration (setup.sh writes this)
    |                               maps events to: run-hook.cmd <EventName>
    v
hooks/run-hook.cmd             <-- cross-platform polyglot entry point
    |                               (batch + bash in one file)
    v
hooks/dispatch.sh              <-- central event router
    |                               reads manifest.conf, buffers stdin, runs hooks in subshells
    |
    +-- hooks/manifest.conf    <-- declarative event:matcher:script routing table
    |
    +-- hooks/lib/common.sh    <-- shared functions (plan discovery, test cmd resolution)
    |       +-- lib/plan-parser.sh  <-- plan discovery, section parsing, write-set primitives
    |
    +-- [10 hook scripts]      <-- individual hooks, sourced by dispatch.sh
```

For non-Claude-Code IDEs, adapter layers translate between the IDE's protocol and dispatch.sh:
- **Codex**: `.baton/adapters/codex/dispatch.sh` -- maps SessionStart/Stop only; hard gates unavailable
- **Cursor**: `.baton/adapters/cursor/dispatch.sh` -- maps camelCase events to PascalCase; translates exit codes to JSON `{"decision":"allow"|"block"}`

(verified: `hooks/dispatch.sh`, `hooks/manifest.conf`, `.baton/adapters/codex/dispatch.sh`, `.baton/adapters/cursor/dispatch.sh`)

---

## How Hooks Are Registered

### Installation Path

`install.sh` clones the repo to `~/.baton/`, then calls `setup.sh`, which:

1. Creates skill symlinks in `~/.claude/skills/` (verified: `setup.sh:39-53`)
2. Merges hook entries into `~/.claude/settings.json` via jq (verified: `setup.sh:66-128`)
3. Injects constitution reference into `~/.claude/CLAUDE.md` (verified: `setup.sh:147-160`)

The hook registration builds 9 entries, each pointing to:
```
<path-to-baton>/hooks/run-hook.cmd <EventName>
```

The registered entries (verified: `setup.sh:69-79`):

| Event | Matcher | Dispatches To |
|-------|---------|---------------|
| `PreToolUse` | `Edit\|Write\|MultiEdit\|CreateFile\|NotebookEdit` | write-lock, (via manifest) |
| `PreToolUse` | `Bash` | bash-guard (via manifest) |
| `PostToolUse` | `Edit\|Write\|MultiEdit\|CreateFile\|NotebookEdit` | post-write-tracker, quality-gate |
| `SessionStart` | (all) | phase-guide |
| `Stop` | (all) | stop-guard |
| `PreCompact` | (all) | pre-compact |
| `SubagentStart` | (all) | subagent-context |
| `TaskCompleted` | (all) | completion-check |
| `PostToolUseFailure` | (all) | failure-tracker |

**Important note on matcher handling**: The `settings.json` registration uses matchers at the Claude Code level (e.g., `"matcher": "Edit|Write|MultiEdit|CreateFile|NotebookEdit"`). The manifest.conf uses a *separate* matcher system within dispatch.sh. Both layers filter, creating a double-filter architecture. (verified: `setup.sh:69-79`, `manifest.conf:1-12`, `dispatch.sh:40-48`)

### For Codex

`.codex/hooks.json` registers only `SessionStart` and `Stop`, both routing through the Codex adapter dispatch. Hard gates (PreToolUse blocking) are explicitly unavailable. (verified: `.codex/hooks.json`)

---

## The Dispatch Mechanism

`dispatch.sh` is the central router (verified: `hooks/dispatch.sh:1-64`):

1. **Receives event name** as `$1` argument
2. **Sets `BATON_PROJECT_DIR`** to the current working directory
3. **Buffers stdin** into `BATON_STDIN` env var (Claude Code passes tool name + input as JSON)
4. **Extracts `tool_name`** from the JSON payload using jq (with sed fallback)
5. **Iterates `manifest.conf`** line by line: `event:matcher:script`
   - Skips comments (`#`) and blank lines
   - Matches event name exactly
   - If matcher is non-empty, checks if `tool_name` is in the comma-separated matcher list
   - If matcher is empty, matches all tools
6. **Runs each matched hook** in a subshell: `( . "$_dir/$_script.sh" )`
   - Subshell isolation means hooks cannot affect each other's variables or exit codes
   - All matched hooks run even if an earlier one exits 2 (blocking)
7. **Exit code logic**:
   - Exit 0 = allow (default)
   - Exit 2 = block (for PreToolUse hooks)
   - Any other exit code = warning logged to stderr, does not block
   - First exit 2 wins; subsequent hooks still execute but cannot override the block

### manifest.conf Format

```
# event:matcher:script
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

(verified: `hooks/manifest.conf:1-12`)

---

## Individual Hooks: Blocking vs Advisory

### Blocking Hooks (exit 2 = prevent the tool use)

| Hook | Event | Trigger | What It Blocks |
|------|-------|---------|----------------|
| **write-lock.sh** | PreToolUse (Write/Edit/...) | Every file write attempt | Blocks source code writes when: (a) no plan exists, (b) plan has no `<!-- BATON:GO -->`, (c) multi-plan ambiguity, (d) target file not in approved write-set, (e) AI attempts to add governance markers |
| **bash-guard.sh** | PreToolUse (Bash) | Every Bash command | Blocks explicit shell write patterns (redirect, tee, sed -i, cp, mv, etc.) when plan gate is closed |
| **completion-check.sh** | TaskCompleted | When AI marks task complete | Blocks completion when all Todos are done but no `## Retrospective` with >= 3 content lines |

### Advisory Hooks (always exit 0, output warnings to stderr)

| Hook | Event | Purpose |
|------|-------|---------|
| **phase-guide.sh** | SessionStart | Detects current workflow phase (RESEARCH/PLAN/ANNOTATION/AWAITING_TODO/IMPLEMENT/FINISH), outputs guidance and skill suggestions. Also injects `using-baton` SKILL.md as governance context via JSON stdout. |
| **post-write-tracker.sh** | PostToolUse (Write/Edit/...) | Warns when modified files aren't in the plan's write-set. Tracks repeat violations per session in `/tmp/baton-writeset-violations-<session>`. |
| **quality-gate.sh** | PostToolUse (Write/Edit/...) | Checks plan/research files for `## Self-Challenge` section with >= 3 content lines. |
| **stop-guard.sh** | Stop | Reminds about incomplete tasks. In IMPLEMENT phase: shows progress. In FINISH phase: prompts for retrospective, test suite, BATON:COMPLETE. |
| **subagent-context.sh** | SubagentStart | Injects plan Todo items and authorized write-set into subagent context. |
| **failure-tracker.sh** | PostToolUseFailure | Counts cumulative tool failures per session (temp file). Alerts at 3 and 5 failures. |
| **pre-compact.sh** | PreCompact | Outputs plan progress summary (phase, todo counts, write-set, annotation log) before context compression. |

---

## Shared Library Layer

### lib/common.sh (verified: `hooks/lib/common.sh:1-63`)

- Sources `plan-parser.sh`
- Provides legacy wrappers: `resolve_plan_name()`, `find_plan()`, `has_skill()`
- Provides `baton_resolve_test_cmd()` -- auto-detects test command from package.json/Makefile/pytest.ini/tests/

### lib/plan-parser.sh (verified: `hooks/lib/plan-parser.sh:1-445`)

Three tiers of primitives:

**1A - Discovery**: `parser_find_plan`, `parser_find_research`, `parser_has_go`, `parser_has_skill`, `parser_project_root`

**1B - Section parsing**: `parser_todo_range`, `parser_todo_counts`, `parser_todo_items`, `parser_todo_remaining_items`, `parser_retro_range`, `parser_retro_valid`

**1C - Write-set**: `parser_writeset_normalize`, `parser_writeset_extract`, `parser_writeset_contains`

Key behaviors of `parser_find_plan`:
- Walks up directories from `JSON_CWD` (or cwd) looking for `plan.md`, `plan-*.md`, `baton-tasks/*/plan.md`
- Filters out COMPLETE-marked plans (`<!-- BATON:COMPLETE -->`)
- Disambiguates multiple plans via: (1) BATON:GO uniqueness, (2) BATON_TARGET context, (3) most recent mtime
- Sets `MULTI_PLAN_COUNT` to signal ambiguity

---

## Cross-Platform and Adapter Differences

### run-hook.cmd (verified: `hooks/run-hook.cmd:1-45`)

A polyglot file: Windows batch script at the top (wrapped in a bash heredoc no-op), Unix bash at the bottom. On Windows, it searches for `bash.exe` in standard Git for Windows locations, then PATH. If no bash is found, it exits silently (fail-open).

### Codex Adapter (verified: `.baton/adapters/codex/adapter.sh:1-62`, `.baton/adapters/codex/dispatch.sh:1-34`)

- Only `SessionStart` and `Stop` are wired
- Hard gates (write-lock, bash-guard) are **not available** -- Codex has no PreToolUse hook support
- Closes stdin (`</dev/null`) to prevent hangs from Codex not sending EOF
- Stop hook saves message to `.codex/stop-hook.message.txt` (file-based, since Codex stdout is a JSON protocol channel)
- Prepends capability tier header: "[Baton capability: rules + guidance only (Codex)]"

### Cursor Adapter (verified: `.baton/adapters/cursor/dispatch.sh:1-33`, `.baton/adapters/cursor/adapter.sh:1-36`)

- Maps camelCase events (Cursor) to PascalCase (baton): `sessionStart` -> `SessionStart`, etc.
- Translates exit codes to JSON: exit 0 -> `{"decision":"allow"}`, exit 2 -> `{"decision":"block","reason":"..."}`
- The `adapter.sh` (legacy) wraps only write-lock and outputs `{"decision":"deny"}` format
- Reduced enforcement: no post-write-tracker, stop-guard, completion-check, failure-tracker, or retrospective enforcement

---

## Failure Modes

### 1. Plan Discovery Failures

**No plan found** (verified: `write-lock.sh:135-139`):
- write-lock blocks with: "no plan.md found"
- Guides to "Complete research first"
- This is *intentional* blocking, not a bug -- it enforces the research-first workflow

**Multi-plan ambiguity** (verified: `write-lock.sh:141-146`, `plan-parser.sh:80-131`):
- When multiple active plan files exist and `BATON_PLAN` is not set
- write-lock blocks with: "X plan files found -- ambiguous"
- completion-check also blocks in this case
- Disambiguation layers (BATON:GO uniqueness, BATON_TARGET context) reduce but don't eliminate this

**Plan walk-up reaches filesystem root** (verified: `plan-parser.sh:136`):
- Falls back to `PLAN_NAME="plan.md"` with empty `PLAN`
- write-lock then blocks (no plan found)

### 2. JSON Parsing Failures

**No jq available** (verified: `write-lock.sh:38-44`, `dispatch.sh:28-30`, `bash-guard.sh:42-48`):
- Falls back to sed/awk parsing for tool_name extraction
- Falls back to awk parsing for file_path extraction
- The awk fallback is fragile: `awk -F'"' '{for(i=1;i<=NF;i++) if($i=="file_path") print $(i+2)}'`
- If JSON has unexpected formatting (whitespace, nested quotes), awk fallback may silently fail
- write-lock warns: "Install jq for reliable path parsing"
- **Concrete risk**: If both jq and awk fail to extract file_path, write-lock fails open with a warning

**Empty/missing stdin** (verified: `dispatch.sh:20-21`):
- `cat 2>/dev/null || true` handles this gracefully
- No tool_name extracted -> matcher hooks with tool filter are skipped (correct behavior)
- Empty-matcher hooks still fire

### 3. Fail-Open vs Fail-Closed Decisions

**Fail-open cases** (the hook allows the operation despite an error):
- write-lock: unexpected errors (trap on line 14), missing common.sh, no target path determinable, files outside project root
- bash-guard: unexpected errors, missing common.sh
- post-write-tracker: all errors (trap `exit 0`)
- pre-compact, subagent-context: all errors
- run-hook.cmd on Windows: no bash found

**Fail-closed cases** (the hook blocks):
- write-lock: no plan, no BATON:GO, multi-plan ambiguity, file not in write-set, AI writing governance markers
- bash-guard: shell write patterns detected while gate is closed
- completion-check: multi-plan ambiguity, missing/shallow retrospective
- dispatch.sh: if manifest.conf is missing, exits 0 (fail-open, but no hooks run)

### 4. Subshell Isolation Side Effects

Each hook runs in a subshell: `( . "$_dir/$_script.sh" )` (verified: `dispatch.sh:52`). This means:
- Hooks cannot set environment variables visible to later hooks
- All matched hooks run regardless of earlier hook exit codes
- A hook crash (unexpected exit) doesn't kill the dispatcher
- **But**: hooks that depend on shared state (e.g., BATON_STDIN) work because it's exported before the loop

### 5. Session Tracking Fragility

**failure-tracker.sh** (verified: `hooks/failure-tracker.sh:39-49`):
- Uses `SESSION_ID` from JSON or falls back to `PPID`
- PPID is "stable within a Claude Code session" but this is an assumption -- if the process tree changes (e.g., wrapper scripts), PPID would differ
- Count file at `/tmp/baton-failures-<SESSION_ID>` persists across session restarts (tmp not cleaned per-session)
- **Concrete risk**: Stale count files from previous sessions could cause premature alerts in a new session

**post-write-tracker.sh** (verified: `hooks/post-write-tracker.sh:85-91`):
- Similar session tracking with `/tmp/baton-writeset-violations-<session>`
- Same PPID fragility applies

### 6. Write-Set Enforcement Gap

**Pre vs Post asymmetry** (verified: `write-lock.sh:150-161`, `post-write-tracker.sh:78-114`):
- write-lock (PreToolUse) enforces the write-set as a hard block
- post-write-tracker (PostToolUse) only warns about out-of-set writes
- But if write-lock allows (e.g., fail-open path), the write happens and post-write-tracker catches it after the fact
- **Concrete gap**: The awk fallback path in write-lock could fail to extract the target path, causing fail-open, and the write would succeed without write-set validation

### 7. Governance Marker Protection Limits

write-lock checks for `BATON:GO` and `BATON:OVERRIDE` in new content (verified: `write-lock.sh:65-75`):
- Only checks when jq is available (`command -v jq`)
- Only checks `.tool_input.new_string` and `.tool_input.content`
- Does not check Bash tool (bash-guard doesn't check for governance markers)
- **Concrete gap**: AI could write governance markers via `echo "<!-- BATON:GO -->" >> plan.md` through Bash, since bash-guard only checks for file-write *patterns*, not content

### 8. Phase-Guide Context Injection

phase-guide.sh has a complex EXIT trap (verified: `hooks/phase-guide.sh:27-40`):
- On every exit, it reads `using-baton/SKILL.md` and outputs it as `additionalContext` JSON
- If `CLAUDE_PLUGIN_ROOT` is set, uses `hookSpecificOutput.hookEventName: "SessionStart"` format
- Otherwise uses `additional_context` format
- **Failure mode**: if `using-baton/SKILL.md` doesn't exist (e.g., skill symlink broken), the governance context is silently not injected -- no warning

### 9. CRLF Compatibility

dispatch.sh strips `\r` from manifest.conf fields (verified: `dispatch.sh:37`):
```bash
_evt="${_evt%$'\r'}"; _matcher="${_matcher%$'\r'}"; _script="${_script%$'\r'}"
```
- Handles Windows CRLF (`core.autocrlf=true`)
- But individual hook scripts do NOT strip CRLF from their own inputs
- **Risk**: If hook scripts read files with CRLF line endings (e.g., plan.md checked out on Windows), string comparisons like `grep -q '<!-- BATON:GO -->'` might fail

### 10. Timeout and Hanging

- setup.sh does not set timeouts on hooks (verified: `setup.sh:69-79` -- no `timeout` field in entries)
- `.codex/hooks.json` sets `"timeout": 30` (verified: `.codex/hooks.json`)
- Claude Code may impose its own default timeout
- dispatch.sh's `cat` to buffer stdin could hang if the caller doesn't close stdin and doesn't send EOF
  - Codex adapter mitigates this with `</dev/null` (verified: `.baton/adapters/codex/dispatch.sh:19`)
  - Claude Code should close stdin, but if it doesn't, the hook process hangs indefinitely

---

## Contradictions and Tensions

### Defense Model vs Failure Boundary

The constitution states: "Hooks enforce structure. Review enforces quality. Neither is sufficient alone." (verified: `constitution.md:163`). Yet failure-tracker.sh explicitly notes it's a "session-total proxy" because "hooks cannot track hypothesis identity; per-hypothesis enforcement is AI-layer" (verified: `failure-tracker.sh:9-11`). This is an honest acknowledgment that hooks can only approximate the constitution's per-hypothesis failure boundary.

### Fail-Open Philosophy vs Security Goals

Most hooks default to fail-open (allow operation on error), which prioritizes developer experience over enforcement. This creates a tension: the hooks system is designed to *prevent* unauthorized writes, but any unexpected error in the hook chain (jq missing, JSON malformed, symlink broken) silently allows the write through. The constitution acknowledges this indirectly: "Adding more structural checks (hooks) does not solve quality problems -- it incentivizes mechanical compliance."

### Double Matcher Filtering

Claude Code settings.json has matchers (`"matcher": "Edit|Write|..."`) AND manifest.conf has matchers (`PreToolUse:Write,Edit,...:write-lock`). Both filter. If they disagree (e.g., setup.sh registers `NotebookEdit` but manifest.conf omits it from a hook), the hook won't fire for that tool. Currently they're consistent, but this is a maintenance burden -- changes must be synchronized in two places.

---

## Challenge

**Weakest conclusion**: My analysis of the governance marker protection gap (failure mode 7 -- AI could use Bash to write BATON:GO) is based on reading the code, but I haven't verified this by running the actual hooks against a Bash command that echoes a governance marker. The bash-guard pattern matching is sophisticated and might catch this through the `has_output_redirection` check -- but the check is on the *pattern*, not the *content*.

**Most important thing I didn't check**: Whether Claude Code actually passes stdin in the format dispatch.sh expects for all event types. I verified the code handles the JSON format, but different event types may have different stdin schemas. If an event type sends a different JSON structure (or no JSON), the tool_name extraction would silently fail and matcher-based hooks would be skipped.

---

## Open Questions

1. **Timeout behavior**: What is Claude Code's default timeout for hooks when none is specified in settings.json? If hooks hang (e.g., stdin not closed), how long does the user wait? (reason: no runtime access to test)
2. **CRLF in plan files on Windows**: Does `grep -q '<!-- BATON:GO -->'` match correctly when the plan file has CRLF line endings? The `<!-- BATON:GO -->` pattern has no `$` anchor, so it might match even with trailing `\r`, but this is unverified. (reason: no Windows test environment)
3. **Session ID stability across Claude Code restarts**: failure-tracker and post-write-tracker use PPID as session proxy fallback. If Claude Code restarts but reuses the same terminal PID hierarchy, stale temp files could cause incorrect failure counts. (reason: no runtime access to verify PPID behavior)
