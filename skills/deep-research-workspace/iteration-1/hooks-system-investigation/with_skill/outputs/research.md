**Question**: How does the baton hooks system work? How are all hooks triggered, and what are the failure modes?
**Depth**: Deep
**Key finding**: Baton uses a manifest-driven, event-dispatched shell hook system that enforces a plan-first governance workflow across multiple AI coding IDEs, with 11 individual hooks covering 9 event types, a fail-open design for most hooks, and adapter layers for non-Claude-Code IDEs.
**Open questions**: 3 -- see end of document

---

## Overview

Baton's hooks system is the enforcement mechanism for its plan-first governance model. The system intercepts AI tool use events (writes, bash commands, session lifecycle) and enforces that code modifications follow the prescribed workflow: research -> plan -> annotation -> approval -> implementation -> completion.

### Architecture Diagram

```
                         IDE Event
                             |
                 +-----------+-----------+
                 |           |           |
            Claude Code    Cursor      Codex
                 |           |           |
     ~/.claude/      .cursor/      .codex/
     settings.json   hooks.json    hooks.json
                 |           |           |
                 v           v           v
            run-hook.cmd  dispatch-    dispatch-
            (polyglot)    cursor.sh    codex.sh
                 |           |           |
                 v           v           |
            dispatch.sh <----+           |
                 |                       |
            manifest.conf                |
            (routing table)              |
                 |                       |
         +-------+-------+     +--------+--------+
         |       |       |     |                  |
     phase-  write-  bash-  adapter-          adapter-
     guide   lock    guard  cursor.sh         codex.sh
       |       |       |   (translate         (stderr->
     stop-  post-   quality JSON protocol)     stdout)
     guard  write-    gate
       |   tracker     |
    comple-   |    subagent-
    tion-  failure-  context
    check  tracker     |
       |       |    pre-
       |       |   compact
       v       v       v
    stderr output -> AI sees messages
    exit code -> 0=allow, 2=block
```

## Findings

### 1. Entry Points: How the IDE Triggers Hooks

There are three distinct entry paths depending on the IDE:

**Path A: Claude Code / Factory AI (full enforcement)**
- Hooks are registered in `~/.claude/settings.json` at the user level (verified: `setup.sh:66-128`)
- Each event type maps to a command that invokes `run-hook.cmd <EventName>` (verified: `setup.sh:69-79`)
- `run-hook.cmd` is a polyglot file (verified: `hooks/run-hook.cmd:1-46`) -- cmd.exe runs the batch portion on Windows, bash runs the shell portion on Unix
- On Unix: `exec bash "${SCRIPT_DIR}/dispatch.sh" "$@"` (verified: `run-hook.cmd:44-45`)
- On Windows: searches for Git Bash in standard locations, falls back to PATH, exits silently (exit 0) if no bash found (verified: `run-hook.cmd:17-40`)

**Path B: Cursor (reduced enforcement)**
- Hooks are registered in `.cursor/hooks.json` at project level
- Uses adapter `dispatch-cursor.sh` which maps camelCase event names to PascalCase and wraps dispatch.sh output into Cursor's `{"decision":"allow"|"block"}` JSON protocol (verified: `.baton/adapters/cursor/dispatch.sh:10-21`)
- Also has a standalone `adapter.sh` that calls write-lock directly (verified: `.baton/adapters/cursor/adapter.sh:12`)
- Reduced capabilities documented in adapter.sh:8-11: missing post-write-tracker, stop-guard, completion-check, failure-tracker, retrospective enforcement

**Path C: Codex (guidance only)**
- Hooks registered in `.codex/hooks.json` with only SessionStart and Stop events (verified: `.codex/hooks.json:1-26`)
- Uses `dispatch-codex.sh` which closes stdin (Codex may not send EOF, causing `cat` to hang) and redirects stderr to stdout (verified: `.baton/adapters/codex/dispatch.sh:16-17`)
- No hard gates available: write-lock and bash-guard cannot run because Codex has no PreToolUse event (verified: `adapter-codex.sh:7-11`)
- Stop hook writes message to file instead of stdout (Codex Stop stdout is a JSON protocol channel) (verified: `adapter-codex.sh:38-48`)

### 2. The Dispatcher: `dispatch.sh`

The dispatcher (`hooks/dispatch.sh`) is the central routing component.

**Input processing** (verified: `dispatch.sh:17-31`):
1. Receives event name as `$1`
2. Buffers stdin into `BATON_STDIN` (so multiple hooks can access the same payload)
3. Extracts `tool_name` from stdin JSON using jq, falling back to sed if jq is unavailable
4. Exports `BATON_PROJECT_DIR` as the current working directory

**Manifest routing** (verified: `dispatch.sh:35-62` and `manifest.conf:1-12`):
- Reads `manifest.conf` line by line, format: `event:matcher:script`
- Skips comments and blank lines
- Matches event name exactly
- If a matcher is specified but no tool_name was extracted, the hook is skipped
- Matcher check: comma-separated list, matched via `case ",$_matcher," in *",$_tool,"*)`

**Exit code semantics** (verified: `dispatch.sh:50-64`):
- `exit 0` = allow
- `exit 2` = block (only meaningful for PreToolUse)
- Any other exit code logs a warning to stderr but does NOT block
- All hooks run in subshells: `( . "$_dir/$_script.sh" )` -- isolates exit codes and variable state
- First `exit 2` wins as the overall exit code, but **all hooks still run** even after a block

### 3. The Manifest: `manifest.conf`

Complete manifest (verified: `hooks/manifest.conf:1-12`):

| Event | Matcher | Script | Purpose |
|-------|---------|--------|---------|
| `SessionStart` | (none) | `phase-guide` | Detect current phase, inject governance context |
| `PreToolUse` | `Write,Edit,MultiEdit,CreateFile,NotebookEdit` | `write-lock` | Block source writes without BATON:GO |
| `PreToolUse` | `Bash` | `bash-guard` | Block shell writes without BATON:GO |
| `PostToolUse` | `Write,Edit,MultiEdit,CreateFile,NotebookEdit` | `post-write-tracker` | Warn when modified files not in plan write-set |
| `PostToolUse` | `Write,Edit,MultiEdit,CreateFile,NotebookEdit` | `quality-gate` | Check for Self-Challenge in plan/research files |
| `SubagentStart` | (none) | `subagent-context` | Inject plan context into subagents |
| `Stop` | (none) | `stop-guard` | Remind about incomplete tasks on session end |
| `TaskCompleted` | (none) | `completion-check` | Block completion without retrospective |
| `PostToolUseFailure` | (none) | `failure-tracker` | Count failures, alert at thresholds |
| `PreCompact` | (none) | `pre-compact` | Preserve key context before compression |

### 4. Individual Hook Behaviors

#### 4.1 `write-lock.sh` (PreToolUse -- blocking)

The most critical hook. Prevents source code modification without plan approval.

**Decision tree** (verified: `write-lock.sh:1-172`):
1. `BATON_BYPASS=1` -> allow (emergency bypass)
2. Cannot determine target path -> allow with warning (fail-open)
3. Target is `.md/.mdx` -> allow, UNLESS it tries to write governance markers (BATON:GO/BATON:OVERRIDE) -> block
4. Target in `baton-tasks/` -> allow (governance docs, skip marker check)
5. Target outside project root -> allow
6. No plan file found -> **block** with research phase guidance
7. Multiple plan files found and no `BATON_PLAN` set -> **block** (ambiguous)
8. Plan exists + `BATON:GO` present:
   - If write-set defined in plan and target not in it -> **block**
   - Otherwise -> allow (with self-check context injection)
9. Plan exists + no `BATON:GO` -> **block** with annotation phase guidance

**Path resolution** (verified: `write-lock.sh:31-55`):
- Target from `BATON_TARGET` env or from stdin JSON `.tool_input.file_path`
- CWD from stdin JSON `.cwd` field
- Uses jq with awk fallback
- Canonicalization via `realpath -m` or `readlink -f` (verified: `write-lock.sh:94-122`)

#### 4.2 `bash-guard.sh` (PreToolUse -- blocking)

Blocks shell commands that write files when the plan gate is closed.

**Decision tree** (verified: `bash-guard.sh:1-164`):
1. Gate open (BATON:GO present) -> allow everything
2. Multi-plan ambiguity -> treat as gate-closed
3. Cannot extract command from stdin -> allow
4. Quote-stripped command checked against block patterns:
   - Heredoc with redirect
   - Output redirection (`>`, `>>`)
   - `tee` (write sink)
   - `sed -i`, `perl -pi` (in-place edit)
   - `python -c` with file write patterns (`open(... 'w')`)
   - `cp`, `mv`, `install`, `truncate`, `patch`
5. Warn-only patterns: `rm`, `touch`

**Quote stripping** (verified: `bash-guard.sh:54-86`): Character-by-character state machine that removes content inside single and double quotes. This prevents false positives from strings that contain write-like patterns (e.g., `echo "redirect > here"` should not block).

#### 4.3 `phase-guide.sh` (SessionStart -- advisory)

The longest hook (256 lines). Detects the current workflow phase and outputs guidance.

**State detection priority** (verified: `phase-guide.sh:93-253`):
1. FINISH: plan + GO + all todos done
2. AWAITING_TODO: plan + GO + no Todo section/items
3. IMPLEMENT: plan + GO + todos exist
4. ANNOTATION: plan exists, no GO
5. PLAN: research exists, no plan
5b. Research multi-match fallback
6. RESEARCH: nothing exists

**Governance context injection** (verified: `phase-guide.sh:16-41`): On every exit (via trap EXIT), reads `using-baton/SKILL.md` and outputs it as `additionalContext` JSON to stdout. This is how the `using-baton` governance layer gets injected into every Claude Code session. Uses `hookSpecificOutput` for Claude Code, `additional_context` for other IDEs.

**Skill discovery** (verified: `phase-guide.sh:53-83`): Dynamically scans installed skills across `.claude/skills/`, `.cursor/skills/`, `.agents/skills/`, and `~/.claude/skills/`. Then filters by keyword (research, plan, implement, debug, review) to suggest relevant skills for the current phase.

#### 4.4 `post-write-tracker.sh` (PostToolUse -- advisory)

Warns when modified files are not in the plan's write-set. Always exits 0.

**Write-set checking** (verified: `post-write-tracker.sh:78-114`):
- Extracts `Files:` fields from `## Todo` section using `parser_writeset_extract`
- Normalizes paths (strip `./`, convert absolute to project-relative)
- If write-set exists and file not in it: warns with expected file list
- Tracks repeat violations per session in `/tmp/baton-writeset-violations-{session_id}`
- Escalated warning on repeat violations: "REPEAT write-set violation" with scope drift alert

#### 4.5 `quality-gate.sh` (PostToolUse -- advisory)

Checks plan/research files for `## Self-Challenge` section. Always exits 0.

- Only fires on files named `plan*.md` or `research*.md` (verified: `quality-gate.sh:16-19`)
- Checks for section header and minimum 3 content lines (verified: `quality-gate.sh:25-43`)

#### 4.6 `stop-guard.sh` (Stop -- advisory)

Reminds about incomplete tasks when the session ends. Always exits 0.

- Only active during implement phase (plan + GO) (verified: `stop-guard.sh:26-27`)
- All todos done: finish workflow reminder (retrospective, test suite, BATON:COMPLETE)
- Remaining todos: progress summary + resume hint

#### 4.7 `completion-check.sh` (TaskCompleted -- blocking)

Blocks task completion until retrospective is written.

- Blocks (exit 2) if: all todos done + no `## Retrospective` or < 3 content lines (verified: `completion-check.sh:44-62`)
- Multi-plan ambiguity: blocks with disambiguation guidance (verified: `completion-check.sh:28-32`)
- Advisory checks: unresolved `?` markers and test suite execution reminder

#### 4.8 `failure-tracker.sh` (PostToolUseFailure -- advisory)

Counts tool failures per session and alerts at thresholds.

- Counter file: `/tmp/baton-failures-{session_id}` (verified: `failure-tracker.sh:49`)
- Alerts at exactly 3 and 5 failures (verified: `failure-tracker.sh:57-61`)
- Session ID from JSON `session_id`/`sessionId`, fallback to PPID (verified: `failure-tracker.sh:22-46`)
- Cannot track per-hypothesis failures; that is the AI layer's responsibility (noted in `failure-tracker.sh:9-11`)

#### 4.9 `subagent-context.sh` (SubagentStart -- advisory)

Injects plan context into subagents.

- Without BATON:GO: reports "ANNOTATION phase" only (verified: `subagent-context.sh:29-32`)
- With BATON:GO: outputs todo progress + authorized write set (verified: `subagent-context.sh:35-48`)

#### 4.10 `pre-compact.sh` (PreCompact -- advisory)

Preserves key context before context window compression.

- Outputs phase, progress, write-set, and recent Annotation Log (verified: `pre-compact.sh:29-67`)
- Critical for maintaining baton awareness across context compaction events

### 5. Shared Infrastructure: `lib/plan-parser.sh`

The parser module (445 lines) provides all plan discovery and parsing primitives.

**Discovery** (verified: `plan-parser.sh:35-140`):
- `parser_find_plan`: walks up from CWD looking for `plan.md`, `plan-*.md`, or `baton-tasks/*/plan.md`
- Filters out COMPLETE-marked plans (verified: `plan-parser.sh:63-69`)
- Multi-plan disambiguation: (1) unique BATON:GO holder wins, (2) target context matching, (3) mtime-based selection with warning

**Section parsing** (verified: `plan-parser.sh:263-366`):
- `parser_todo_range/counts/items`: scoped to `## Todo` section only (not stray `- [ ]` elsewhere)
- `parser_retro_range/valid`: `## Retrospective` with exact header match and >= 3 content lines
- Uses awk for line-range extraction

**Write-set** (verified: `plan-parser.sh:376-444`):
- `parser_writeset_extract`: parses `Files:` fields from `## Todo` items, handles backtick wrapping, comma separation, `(new)` annotations, `|` metadata
- `parser_writeset_normalize`: strips `./`, converts absolute paths to project-relative, handles Windows cygpath

### 6. Fail-Open Design and Safety Nets

The hooks system follows a **fail-open design** for unexpected errors (verified by trap statements in every hook):

| Hook | Error trap | Rationale |
|------|-----------|-----------|
| write-lock | `trap 'exit 0' HUP INT TERM` | Unexpected error -> allow operation |
| bash-guard | `trap 'exit 0' HUP INT TERM` | Same |
| phase-guide | `trap 'exit 0' HUP INT TERM` | Unexpected error -> skip guidance |
| post-write-tracker | `trap 'exit 0' HUP INT TERM` | Advisory, always exits 0 |
| quality-gate | `trap 'exit 0' HUP INT TERM` | Advisory, always exits 0 |
| stop-guard | `trap 'exit 0' HUP INT TERM` | Advisory, never blocks stop |
| completion-check | `trap 'exit 0' HUP INT TERM` | Unexpected error -> allow |
| failure-tracker | (no trap) | Simple counter, unlikely to fail |
| subagent-context | `trap 'exit 0' HUP INT TERM` | Advisory, always exits 0 |
| pre-compact | `trap 'exit 0' HUP INT TERM` | Advisory, always exits 0 |

The dispatch layer itself (`dispatch.sh:58-61`) surfaces unexpected exit codes (not 0 or 2) to stderr but does not block on them.

### 7. Failure Modes

#### 7.1 Environmental Failures

**No jq installed** (medium risk):
- write-lock: falls back to awk for path extraction, then warns about jq (verified: `write-lock.sh:39-44`)
- bash-guard: falls back to awk for command extraction (verified: `bash-guard.sh:42-48`)
- dispatch: falls back to sed for tool_name extraction (verified: `dispatch.sh:28-30`)
- Risk: awk/sed fallbacks are less robust for edge-case JSON structures. Nested JSON, escaped quotes, or multiline values may cause incorrect parsing.

**No bash on Windows** (low risk):
- `run-hook.cmd:40`: exits 0 silently -- all hooks become no-ops
- Comment documents this as intentional: "hooks are advisory, not blocking"
- Risk: on Windows without Git Bash, there is zero governance enforcement

**Stdin not closed by IDE** (known Codex issue):
- dispatch.sh line 20: `BATON_STDIN="$(cat 2>/dev/null || true)"` will hang if stdin never gets EOF
- Codex adapter mitigates by closing stdin: `bash "$HOOK_SCRIPT" </dev/null` (verified: `adapter-codex.sh:53`)
- Risk: any new IDE integration that does not close stdin could cause hook timeouts

#### 7.2 Path Resolution Failures

**Relative vs absolute path mismatch** (medium risk):
- Target path may be relative (from JSON `.tool_input.file_path`) or absolute
- `_canonicalize_path` in write-lock.sh attempts resolution via `realpath -m` -> `readlink -f` -> manual parent-directory walk (verified: `write-lock.sh:94-122`)
- Risk: If the file does not exist yet (CreateFile), parent directory may not exist, and canonicalization may fail. The `realpath -m` flag handles nonexistent paths, but not all systems support `-m`.

**CWD vs JSON_CWD divergence** (low-medium risk):
- `dispatch.sh` exports `BATON_PROJECT_DIR` as `$(pwd)` before any processing
- Individual hooks use `JSON_CWD` from stdin if available
- Risk: if the IDE's reported CWD differs from the actual shell CWD, plan discovery may look in the wrong directory

#### 7.3 Plan Discovery Failures

**Multi-plan ambiguity** (medium risk):
- When multiple active plan files exist and `BATON_PLAN` is not set, hooks attempt disambiguation via (1) unique BATON:GO, (2) target context, (3) mtime ordering (verified: `plan-parser.sh:81-132`)
- If disambiguation fails, write-lock and completion-check **block** (fail-closed)
- Other hooks warn but continue
- Risk: In a monorepo with multiple concurrent tasks in `baton-tasks/*/`, users may hit unexpected blocks

**COMPLETE-marked plan not filtered** (low risk):
- Plan discovery filters out plans containing `<!-- BATON:COMPLETE -->` on its own line (verified: `plan-parser.sh:65-66`)
- If the marker is embedded in prose or malformed, the plan may not be filtered
- Risk: stale completed plans could interfere with discovery

**Plan walks up to filesystem root** (low risk):
- Both `parser_find_plan` and `parser_project_root` walk up until `dirname "$_d" == "$_d"` (filesystem root)
- Risk: if run outside any project, could find unrelated plan files in parent directories. Mitigated by `parser_project_root` checking for `.baton`, `.git`, `.claude` markers.

#### 7.4 Write-Lock Bypass Mechanisms

These are **intentional**, not bugs, but worth documenting as failure modes from a security perspective:

1. **`BATON_BYPASS=1`**: explicit env var bypass (verified: `write-lock.sh:17-19`)
2. **Markdown files always allowed**: any `.md` write passes (verified: `write-lock.sh:58-78`), though governance marker injection is blocked
3. **Files outside project root allowed**: write-lock checks project boundary (verified: `write-lock.sh:124-132`)
4. **NotebookEdit may not be covered by Cursor adapter**: the adapter only wraps write-lock directly, not the full dispatch (verified: `adapter-cursor.sh:12` -- only calls write-lock.sh, not dispatch.sh for the full matcher set)
5. **bash-guard pattern list is incomplete**: only covers known write patterns. Novel write mechanisms (e.g., `dd`, `rsync`, custom scripts) are not caught (verified: `bash-guard.sh:100-146`)

#### 7.5 Race Conditions

**Session counter files** (low risk):
- `failure-tracker.sh` and `post-write-tracker.sh` use files in `/tmp/` keyed by session ID
- No file locking -- concurrent tool use could cause count inconsistencies
- Risk: negligible in practice since AI tool use is sequential, but worth noting

#### 7.6 Adapter-Specific Failures

**Cursor reduced enforcement** (documented, medium impact):
- Cursor adapter explicitly notes missing: post-write-tracker, stop-guard, completion-check, failure-tracker (verified: `adapter-cursor.sh:6-11`)
- The Cursor `dispatch.sh` adapter does map all event types (verified: `dispatch-cursor.sh:11-21`), but whether Cursor sends all these events is IDE-dependent

**Codex guidance-only mode** (documented, high impact):
- No write-lock, no bash-guard: all hard gates are unavailable
- Only advisory guidance at SessionStart and Stop (verified: `adapter-codex.sh:7-11`)
- Relies entirely on Codex's own sandbox and human approval for safety

**Stop hook JSON protocol conflict on Codex** (resolved):
- Codex Stop expects JSON on stdout but baton hooks output human-readable text
- Resolved by saving reminder text to a file and emitting `{"continue":false}` (verified: `dispatch-codex.sh:22-28`)

#### 7.7 Parser Edge Cases

**Todo counting false positives** (prevented):
- Parser scopes to `## Todo` section only using awk (verified: `plan-parser.sh:291-301`)
- Checklist items outside `## Todo` are ignored, preventing `## Approach` or `## Notes` items from inflating counts
- Tests verify this behavior (verified: `tests/test-new-hooks.sh:316-329`)

**Write-set extraction limitations** (low risk):
- Only parses `Files:` fields indented under Todo items (verified: `plan-parser.sh:417`)
- Files mentioned in prose, headers, or other sections are not extracted
- Backtick wrapping is expected but not required (the awk strips backticks via `gsub`)

### 8. Hook Installation and Registration

**User-level install** (v5 architecture, verified: `setup.sh:66-128`):
- `setup.sh` merges baton hook entries into `~/.claude/settings.json`
- Uses jq to:
  1. Remove existing baton entries (matching `run-hook.cmd`, `dispatch.sh`, or `.baton/hooks/`)
  2. Add new entries for all 9 event types
- Falls back to error message if jq is unavailable
- Creates backup at `settings.json.baton-backup`

**v5 flat install** (verified: `setup.sh:1-8`, `install.sh:1-49`):
- Baton installs to `~/.baton/` (git clone)
- Hooks reference `~/.baton/hooks/run-hook.cmd` by absolute path in settings.json
- Skills symlinked into `~/.claude/skills/`
- Constitution referenced from `~/.claude/CLAUDE.md` via `@../.baton/constitution.md`
- This means hooks are user-global, not per-project -- `.baton/hooks` in a project root is a symlink to `../hooks` (verified: `ls -la .baton/`)

**Health check** (verified: `bin/baton:12-105`):
- `baton doctor` verifies: source installation, dispatch.sh presence, manifest.conf, 7 expected skills, hooks in settings.json, constitution reference

## Contradictions and Tensions

### 1. Fail-Open vs. Security

The system is designed fail-open for reliability (unexpected errors never block the developer), but this means:
- Any environmental issue (no jq, path resolution failure, missing common.sh) silently disables protection
- The `trap 'exit 0' ...` pattern in every blocking hook means a bug in the hook itself becomes a silent bypass

This is a conscious design choice (documented at `write-lock.sh:13`, `bash-guard.sh:11`) but creates tension with the constitution's "no execution beyond authorization" invariant.

### 2. Advisory vs. Blocking

Only 3 hooks can actually block (write-lock, bash-guard, completion-check). The other 8 are advisory-only. This means:
- Post-write-tracker detects write-set violations but cannot prevent them
- Failure-tracker detects repeated failures but cannot stop the AI
- The AI must cooperate with advisory hooks for governance to work

This is explicitly acknowledged in the constitution's defense model: "Hooks enforce structure. Review enforces quality. Neither is sufficient alone." (verified: `constitution.md` Defense Model section)

### 3. Cursor dispatch.sh vs adapter.sh

Two Cursor integration paths exist:
- `dispatch-cursor.sh`: wraps dispatch.sh, maps all event types (verified: `.baton/adapters/cursor/dispatch.sh`)
- `adapter.sh`: wraps write-lock.sh directly, only for PreToolUse (verified: `.baton/adapters/cursor/adapter.sh:12`)

It is unclear which one is currently active in a real Cursor installation -- the `.cursor/hooks.json` file does not exist at the project root. This may mean Cursor support is configured per-project or is inactive.

## Challenge

**Weakest conclusion**: The bash-guard pattern matching is inherently incomplete. The quote-stripping state machine and pattern list cover common write mechanisms, but any novel approach to writing files from bash (e.g., using less common tools like `rsync`, `dd`, piping to a script that writes, or using language-specific file write APIs beyond python) would bypass the guard. This is acknowledged by the hook being Phase-1 only, but the gap between "blocks obvious writes" and "prevents unauthorized writes" is significant.

**Most important unchecked item**: I did not verify the actual `~/.claude/settings.json` on this machine to confirm hooks are registered. The project-level `.claude/settings.json` does not contain hooks (verified: only has env vars), which is correct for v5 (user-level install). The actual enforcement depends on the user-level file existing with correct entries.

**Assumption**: This analysis assumes Claude Code's hook event protocol matches what the hooks expect (JSON stdin with `tool_name` and `tool_input` fields). I verified the hook code's expectations but could not verify the actual JSON payloads sent by Claude Code at runtime.

## Open Questions

1. **Is Cursor integration active?** No `.cursor/hooks.json` exists at the project root. The adapter code exists but may not be registered anywhere. Need to check if Cursor reads hooks from a user-level config or if this requires per-project setup.

2. **What happens when `realpath -m` is unavailable?** The write-lock path canonicalization chain is `realpath -m` -> `readlink -f` -> manual resolution. On some minimal Linux containers or older macOS, neither may support the `-m` flag. The fallback chain exists but its correctness for nonexistent paths is unverified.

3. **How does the system behave with concurrent subagents?** Multiple subagents may trigger hooks simultaneously. The dispatch and hooks use no locking, so counter files (failure-tracker, write-set violations) could have race conditions. In practice, this may be a non-issue if tool use is serialized, but the architecture does not enforce this assumption.

## 批注区
