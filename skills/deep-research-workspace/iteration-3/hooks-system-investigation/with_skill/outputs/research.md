**Question**: How does baton's hooks system work? How are all hooks triggered, and what are the failure modes?
**Depth**: Deep
**Key finding**: Baton hooks are shell scripts dispatched through a manifest-driven event router, triggered by IDE lifecycle events via adapter layers; the system is designed to fail-open on errors but has several structural failure modes around plan discovery, multi-plan ambiguity, and IDE capability gaps.
**Open questions**: 3 -- see end of document

---

# Baton Hooks System: Architecture, Trigger Mechanics, and Failure Modes

## Overview

Baton's hooks system is a layered enforcement mechanism that governs AI coding assistants across their lifecycle events (session start, tool use, session stop, etc.). It consists of:

1. **IDE hook registration** -- IDE-specific configuration that tells the IDE to call baton on certain events
2. **Adapter layer** -- translates between IDE-specific protocols and baton's internal protocol
3. **Dispatch layer** -- event router that reads a manifest and runs matching hook scripts in subshells
4. **Hook scripts** -- individual enforcement/advisory scripts
5. **Shared library** -- plan discovery, parsing, and write-set primitives

```
IDE (Claude Code / Cursor / Codex)
  │
  ├─ Claude Code: ~/.claude/settings.json → hooks → run-hook.cmd → dispatch.sh
  ├─ Cursor:      .cursor/hooks.json      → adapter-cursor dispatch.sh → dispatch.sh
  └─ Codex:       .codex/hooks.json       → adapter-codex dispatch.sh → dispatch.sh (limited)
                                                      │
                                                dispatch.sh
                                                      │
                                            manifest.conf (event:matcher:script)
                                                      │
                                    ┌─────────────────┼────────────────────┐
                                    ▼                 ▼                    ▼
                              hook-a.sh          hook-b.sh           hook-c.sh
                                    │                 │                    │
                                    └────── lib/common.sh ──── lib/plan-parser.sh
```

## 1. Hook Registration and Trigger Chain

### 1.1 Claude Code (Primary Path)

The setup script (`setup.sh`) writes hook registrations into `~/.claude/settings.json` at user level. The registration maps IDE events to the `run-hook.cmd` polyglot wrapper.

(verified: `setup.sh:66-128`)

The registered events are:

| IDE Event | Matcher | What fires |
|-----------|---------|-----------|
| `PreToolUse` | `Edit\|Write\|MultiEdit\|CreateFile\|NotebookEdit` | write-lock.sh |
| `PreToolUse` | `Bash` | bash-guard.sh |
| `PostToolUse` | `Edit\|Write\|MultiEdit\|CreateFile\|NotebookEdit` | post-write-tracker.sh, quality-gate.sh |
| `SessionStart` | (all) | phase-guide.sh |
| `Stop` | (all) | stop-guard.sh |
| `PreCompact` | (all) | pre-compact.sh |
| `SubagentStart` | (all) | subagent-context.sh |
| `TaskCompleted` | (all) | completion-check.sh |
| `PostToolUseFailure` | (all) | failure-tracker.sh |

When Claude Code fires an event, it calls:

```
run-hook.cmd <EventName>
  → dispatch.sh <EventName>   (stdin: JSON with tool_name, tool_input, cwd, session_id)
    → reads manifest.conf
    → for each matching line: source the hook script in a subshell
```

(verified: `run-hook.cmd:44-45`, `dispatch.sh:1-64`, `manifest.conf:1-12`)

### 1.2 Cursor (Adapter Path)

Cursor uses `.cursor/hooks.json` with camelCase event names and expects JSON responses (`{"decision":"allow"}` or `{"decision":"deny","reason":"..."}`).

The Cursor adapter at `.baton/adapters/cursor/dispatch.sh` translates camelCase to PascalCase and wraps dispatch.sh output into JSON. (verified: `adapters/cursor/dispatch.sh:10-33`)

The single-hook adapter at `.baton/adapters/cursor/adapter.sh` is a simpler path that only calls write-lock.sh directly (reduced enforcement). (verified: `adapters/cursor/adapter.sh:12-36`)

Important: Cursor has **reduced enforcement** -- the adapter comment explicitly states that post-write-tracker, stop-guard, completion-check, failure-tracker, and retrospective enforcement are reduced or missing. (verified: `adapters/cursor/adapter.sh:6-11`)

### 1.3 Codex (Rules + Guidance Only)

Codex only has `SessionStart` and `Stop` hooks via `.codex/hooks.json`. (verified: `.codex/hooks.json:1-26`)

The Codex adapter redirects stderr to stdout (since Codex reads stdout as context), closes stdin to prevent hangs, and prepends a tier header declaring "rules + guidance only." Hard gates (write-lock, bash-guard) are **not available** on Codex. (verified: `adapters/codex/adapter.sh:6-11`, `adapters/codex/dispatch.sh:12-34`)

For the Stop event, the Codex adapter writes the reminder text to `.codex/stop-hook.message.txt` as a file because Codex Stop stdout is a JSON protocol channel. (verified: `adapters/codex/dispatch.sh:22-28`)

## 2. The Dispatch Layer

### 2.1 dispatch.sh Mechanics

`dispatch.sh` is the central router. Its behavior:

1. Receives event name as `$1`
2. Exports `BATON_PROJECT_DIR` (set to `pwd`)
3. Buffers stdin into `BATON_STDIN` (so multiple hooks can read it)
4. Extracts `tool_name` from stdin JSON (using jq, falling back to sed)
5. Iterates through `manifest.conf` lines matching the event
6. For each match, runs the hook script in a **subshell** (`( . "$_dir/$_script.sh" )`)
7. Collects exit codes: exit 2 = block (for PreToolUse); other non-zero = warning to stderr

(verified: `dispatch.sh:1-64`)

Key design decisions:
- **Subshell isolation**: Each hook runs in `( . "$_dir/$_script.sh" )`, so exit codes and variable state don't leak between hooks. (verified: `dispatch.sh:52`)
- **All hooks run regardless of blocking**: Even after one hook exits 2, subsequent hooks for the same event still execute. The first exit 2 wins as the dispatch exit code. (verified: `dispatch.sh:54-57`, test at `test-dispatch.sh:150-157`)
- **Unexpected exit codes surface warnings**: Any exit code that isn't 0 or 2 produces a stderr warning, preventing silent hook crashes. (verified: `dispatch.sh:59-61`)

### 2.2 manifest.conf Format

Format: `event:matcher:script` (script name without `.sh` extension).

(verified: `manifest.conf:1-12`)

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

- Empty matcher = matches all tools for that event
- Comma-separated matcher = matches any of the listed tool names
- Matcher filtering requires a tool_name from stdin JSON; no tool_name + non-empty matcher = hook skipped

## 3. Individual Hooks

### 3.1 Hard-Blocking Hooks (exit 2 = block the tool use)

#### write-lock.sh (PreToolUse: Write/Edit/MultiEdit/CreateFile/NotebookEdit)

**Purpose**: Prevents source code writes until the plan file contains `<!-- BATON:GO -->`.

**Logic flow**:
1. If `BATON_BYPASS=1` -> allow
2. Parse target file path from `BATON_TARGET` env or stdin JSON `.tool_input.file_path`
3. If target is unknown -> fail-open with warning
4. If target is `.md` -> allow (but check for governance markers: AI must not write `BATON:GO` or `BATON:OVERRIDE`)
5. Find plan file via `parser_find_plan` (walk-up search)
6. If target is outside project root -> allow
7. No plan found -> block ("complete research first")
8. Multiple plans found, no `BATON_PLAN` set -> block ("ambiguous")
9. Plan found, `BATON:GO` present -> check write-set enforcement -> allow or block
10. Plan found, no `BATON:GO` -> block ("annotation cycle in progress")

**Write-set enforcement**: When the plan has `Files:` fields in `## Todo`, writes are restricted to those exact paths. Out-of-set writes are blocked with a list of approved files. (verified: `write-lock.sh:150-161`)

**Governance marker protection**: Even for `.md` files (normally allowed), the hook blocks writes that attempt to inject `<!-- BATON:GO -->` or `<!-- BATON:OVERRIDE -->` markers. This prevents AI from self-approving. (verified: `write-lock.sh:65-77`)

(verified: `write-lock.sh:1-172`)

#### bash-guard.sh (PreToolUse: Bash)

**Purpose**: Blocks shell commands that write files when the plan gate is closed.

**Logic flow**:
1. If plan + BATON:GO -> allow everything
2. If multi-plan ambiguity -> fall through to command check
3. Parse command from stdin JSON `.tool_input.command`
4. Strip quoted segments (to avoid false positives on string arguments)
5. Check for explicit write patterns:
   - Heredoc with redirect
   - Output redirection (`>`, `>>`)
   - `tee`
   - `sed -i`, `perl -pi`
   - `python -c` with `open(..., 'w')`
   - `cp`, `mv`, `install`, `truncate`, `patch`
6. Block if matched; warn-only for `rm` and `touch`

(verified: `bash-guard.sh:1-164`)

#### completion-check.sh (TaskCompleted)

**Purpose**: Blocks task completion until retrospective is written.

**Logic flow**:
1. Multi-plan ambiguity -> block
2. No plan or no BATON:GO -> allow (not in implement phase)
3. Not all todos done -> allow (not at completion yet)
4. All todos done, no `## Retrospective` section -> block
5. `## Retrospective` exists but < 3 content lines -> block
6. Advisory: warn about unresolved markers, remind about test suite

(verified: `completion-check.sh:1-77`)

### 3.2 Advisory Hooks (always exit 0)

#### phase-guide.sh (SessionStart)

**Purpose**: Detects workflow phase and outputs phase-specific guidance. Also injects the `using-baton` SKILL.md content as additional context.

**State machine** (priority high to low):
1. FINISH -- plan + GO + all todos done
2. AWAITING_TODO -- plan + GO + no `## Todo` items
3. IMPLEMENT -- plan + GO + todos exist
4. ANNOTATION -- plan exists, no GO
5. PLAN -- research exists, no plan
6. RESEARCH -- nothing exists

**Skill scanning**: Dynamically discovers available skills across `.claude/skills/`, `.cursor/skills/`, `.agents/skills/`, and `~/.claude/skills/`. Routes to appropriate skills per phase. (verified: `phase-guide.sh:53-83`)

**Governance context injection**: On exit, emits the full `using-baton/SKILL.md` as `additionalContext` JSON via an EXIT trap, so the IDE receives governance rules at every session start. (verified: `phase-guide.sh:17-41`)

(verified: `phase-guide.sh:1-256`)

#### post-write-tracker.sh (PostToolUse: Write/Edit/...)

**Purpose**: Warns when modified files aren't in the plan's write set.

**Key behavior**: Tracks repeat violations per session using `/tmp/baton-writeset-violations-{session_id}` files. First violation gets a full warning with expected files list; repeated violations get an escalated "REPEAT write-set violation" warning suggesting scope drift. (verified: `post-write-tracker.sh:85-105`)

(verified: `post-write-tracker.sh:1-117`)

#### quality-gate.sh (PostToolUse: Write/Edit/...)

**Purpose**: Checks that plan/research files contain `## Self-Challenge` with sufficient depth (3+ content lines). Only fires on files named `plan*.md` or `research*.md`.

(verified: `quality-gate.sh:1-46`)

#### stop-guard.sh (Stop)

**Purpose**: Reminds about incomplete tasks when stopping. Shows finish workflow when all todos are done; shows progress when some remain.

(verified: `stop-guard.sh:1-53`)

#### subagent-context.sh (SubagentStart)

**Purpose**: Injects plan context (todo progress, authorized write set) into subagent sessions.

(verified: `subagent-context.sh:1-51`)

#### pre-compact.sh (PreCompact)

**Purpose**: Preserves key context before context window compression -- outputs plan progress, write set, and recent annotation log entries.

(verified: `pre-compact.sh:1-70`)

#### failure-tracker.sh (PostToolUseFailure)

**Purpose**: Session-total failure counter with threshold alerts at exactly 3 and exactly 5 failures.

**Limitation**: This is a session-total proxy. The constitution's failure boundary is per-hypothesis (2+ failures under the same causal claim). Hooks cannot track hypothesis identity; per-hypothesis enforcement must be done at the AI layer. (verified: `failure-tracker.sh:9-11`)

(verified: `failure-tracker.sh:1-64`)

## 4. Shared Library Layer

### 4.1 lib/common.sh

Sources `plan-parser.sh` and provides legacy wrapper functions (`resolve_plan_name`, `find_plan`, `has_skill`). Also provides `baton_resolve_test_cmd()` for auto-detecting test suite commands. (verified: `lib/common.sh:1-64`)

### 4.2 lib/plan-parser.sh

The core discovery and parsing module. Key primitives:

**1A Discovery**:
- `parser_find_plan` -- walk-up search from cwd for `plan.md`, `plan-*.md`, `baton-tasks/*/plan.md`. Filters out COMPLETE-marked plans. Multi-plan disambiguation by BATON:GO uniqueness, then by BATON_TARGET context.
- `parser_find_research` -- paired research file discovery (derives name from plan filename)
- `parser_has_go` -- checks for `<!-- BATON:GO -->` in plan
- `parser_has_skill` -- walk-up skill directory search
- `parser_project_root` -- infers project root by scanning for `.baton`, `.git`, `.claude`, `.cursor`, `.codex`, `AGENTS.md`, `CLAUDE.md` markers

**1B Section Parsing**:
- `parser_todo_range` / `parser_todo_counts` / `parser_todo_items` -- all scoped to `## Todo` section only
- `parser_retro_range` / `parser_retro_valid` -- retrospective section with 3-line minimum

**1C Write-Set**:
- `parser_writeset_normalize` -- strips `./`, converts absolute to project-relative
- `parser_writeset_extract` -- parses backtick-wrapped, comma-separated paths from `Files:` fields in `## Todo`
- `parser_writeset_contains` -- membership check

(verified: `lib/plan-parser.sh:1-444`)

## 5. Failure Modes

### 5.1 Fail-Open by Design

Every hook has a trap that exits 0 on unexpected errors:

```bash
trap 'echo "... unexpected error, allowing operation (fail-open)" >&2; exit 0' HUP INT TERM
```

**Consequence**: If a hook crashes (missing dependency, file permission error, parse failure), the operation is allowed. This prevents hooks from blocking the user's workflow when something breaks, but it means enforcement silently degrades.

(verified: `write-lock.sh:14`, `bash-guard.sh:11`, `phase-guide.sh:10`, `post-write-tracker.sh:12`, `stop-guard.sh:13`, `completion-check.sh:14`, `subagent-context.sh:12`, `pre-compact.sh:12`)

### 5.2 No jq Available

Multiple hooks use jq for JSON parsing with an awk/sed fallback. The fallbacks are less robust:

- **write-lock.sh**: Uses awk to extract `file_path` and `cwd` from JSON. This can fail on nested JSON structures or unusual field ordering. If target path cannot be determined, it **fail-opens** with a warning. (verified: `write-lock.sh:39-44`, `write-lock.sh:48-55`)
- **dispatch.sh**: Falls back to sed for `tool_name` extraction. (verified: `dispatch.sh:28-30`)
- **bash-guard.sh**: Falls back to awk for command extraction. (verified: `bash-guard.sh:45-48`)
- **failure-tracker.sh**: Falls back to awk for session_id and tool_name. (verified: `failure-tracker.sh:30-35`)

### 5.3 Plan Discovery Failures

| Scenario | Behavior | Risk |
|----------|----------|------|
| No plan file anywhere in directory tree | write-lock blocks ("complete research first") | Correct |
| Multiple active plans, no BATON_PLAN env | write-lock blocks ("ambiguous") | Correct, but might confuse user |
| Multiple active plans, exactly one has BATON:GO | Auto-selects the GO plan | Reasonable disambiguation |
| Plan is in `baton-tasks/<topic>/` but cwd is project root | Walk-up search finds it via `ls baton-tasks/*/plan.md` | Correct but depends on shell globbing |
| `BATON:COMPLETE` plan + active plan in same directory | COMPLETE plans filtered out, active plan selected | Correct |
| Plan exists but common.sh / plan-parser.sh missing | write-lock fail-opens | **Silent enforcement loss** |

(verified: `lib/plan-parser.sh:35-140`, `write-lock.sh:82-87`, `write-lock.sh:134-146`)

### 5.4 Write-Set Bypass Vectors

The write-set enforcement in write-lock.sh has several structural limitations:

1. **Bash-guard incomplete coverage**: bash-guard blocks known write patterns (`>`, `tee`, `sed -i`, `cp`, etc.) but cannot catch all shell writes. Novel or creative shell write commands can bypass it. For example, `dd of=file`, custom binaries, or programs invoked by name that happen to write files. (verified: `bash-guard.sh:100-146`)

2. **Quote stripping limitations**: bash-guard strips single and double quotes to find write patterns, but complex quoting (heredocs within variables, `eval`, etc.) could evade detection. (verified: `bash-guard.sh:54-86`)

3. **`BATON_BYPASS=1`**: An explicit escape hatch. If set, write-lock allows everything. This is documented and intentional but means any process that can set environment variables can bypass enforcement. (verified: `write-lock.sh:17-20`)

4. **Markdown always allowed**: Any file ending in `.md`/`.mdx` bypasses the write lock (except for governance marker injection). This is intentional -- plan/research files must be writable during all phases. (verified: `write-lock.sh:58-78`)

5. **Files outside project root always allowed**: Writes to paths outside the detected project root are allowed without any checks. (verified: `write-lock.sh:129-132`)

### 5.5 IDE Capability Gaps

| IDE | Hard gates | Advisory hooks | Gap |
|-----|-----------|---------------|-----|
| Claude Code | All hooks available | All hooks available | None -- full enforcement |
| Cursor | write-lock (via adapter) | phase-guide, bash-guard | No post-write-tracker, stop-guard, completion-check, failure-tracker |
| Codex | None | phase-guide (SessionStart), stop-guard (Stop) | No hard gates at all -- relies entirely on rules + guidance |

(verified: `adapters/cursor/adapter.sh:6-11`, `adapters/codex/adapter.sh:6-11`, `.codex/hooks.json:1-26`)

### 5.6 Stdin Buffering and Codex Hang Risk

dispatch.sh reads stdin with `BATON_STDIN="$(cat 2>/dev/null || true)"`. If stdin never sends EOF, this `cat` call hangs. The Codex adapter explicitly closes stdin (`</dev/null`) to prevent this. Cursor's dispatch adapter also protects against this. But any direct invocation of dispatch.sh without proper stdin handling could hang.

(verified: `dispatch.sh:20-21`, `adapters/codex/adapter.sh:52-53`, `adapters/codex/dispatch.sh:16-19`)

### 5.7 Concurrency and Temp File Races

failure-tracker.sh and post-write-tracker.sh use `/tmp/baton-failures-{session_id}` and `/tmp/baton-writeset-violations-{session_id}` files respectively. If multiple sessions share the same PPID (unlikely but possible in certain process trees), or if session_id sanitization produces collisions, counts could be inaccurate.

(verified: `failure-tracker.sh:49-52`, `post-write-tracker.sh:91-96`)

### 5.8 Phase-Guide EXIT Trap Interaction

phase-guide.sh uses an EXIT trap to inject governance context (`_output_governance_context`). This trap runs on every exit path, including early returns. If the `using-baton/SKILL.md` file is missing or unreadable, the trap silently does nothing (returns 0). But if the file is large and JSON escaping fails, the output could be malformed JSON that the IDE ignores.

(verified: `phase-guide.sh:27-40`)

### 5.9 Self-Blocking During Hook Modifications

A known project-level concern (documented in user memory): plans that modify hooks must check whether those hooks' preconditions will block the implementation itself. For example, modifying `write-lock.sh` while the current plan's write-set doesn't include `write-lock.sh` would trigger the write-set enforcement and block the change.

(verified: user memory `feedback_hook_self_blocking.md`)

### 5.10 Governance Marker Protection Requires jq

The governance marker check (preventing AI from writing `BATON:GO` or `BATON:OVERRIDE` to markdown files) only runs when jq is available:

```bash
if [ -n "$STDIN" ] && command -v jq >/dev/null 2>&1; then
    _new_content="$(printf '%s' "$STDIN" | jq -r '.tool_input.new_string // .tool_input.content // empty' 2>/dev/null)"
```

Without jq, this entire check is skipped, and the AI could potentially inject governance markers into markdown files.

(verified: `write-lock.sh:65-76`)

## 6. Error Handling Patterns

All hooks follow a consistent error-handling pattern:

1. **Trap on HUP/INT/TERM** -> fail-open (exit 0)
2. **Missing dependencies** (common.sh, plan-parser.sh) -> fail-open (exit 0)
3. **BATON_BYPASS=1** -> skip all checks (exit 0)
4. **No plan** -> varies by hook (write-lock blocks; advisory hooks exit silently)
5. **Subshell isolation** in dispatch.sh prevents one hook's crash from affecting others

The overall philosophy is: **hooks should never prevent the user from working.** Enforcement degradation is preferred over false blocking. The tradeoff is that enforcement is only as reliable as the hook infrastructure (jq availability, plan file accessibility, correct cwd).

## 7. Contradictions and Tensions

### Constitution vs. Hook Capability

The constitution defines a "failure boundary" as "2+ failures under the same hypothesis." But failure-tracker.sh can only count session-total failures -- it explicitly cannot track hypotheses. The hook comments acknowledge this gap: "per-hypothesis enforcement is AI-layer." This means the constitution's requirement depends on the AI model's compliance, not hook enforcement. (verified: `failure-tracker.sh:9-11`, `constitution.md` Failure Boundary section)

### Defense Model Tension

The constitution states: "Hooks enforce structure. Review enforces quality. Neither is sufficient alone." and "Adding more structural checks (hooks) does not solve quality problems." This correctly identifies the limitation, but it means the hooks system is explicitly positioned as necessary-but-insufficient. The "sufficient" layer (cross-source review) is recommended but not enforced by hooks. (verified: `constitution.md` Defense Model section)

### Cursor Reduced Enforcement vs. Full Protocol

Cursor's adapter calls it "reduced enforcement" and explicitly lists missing capabilities. But the dispatch adapter (`dispatch.sh` in cursor adapter directory) supports all events via event name translation. There's a tension between the single-hook adapter (`adapter.sh`) and the full dispatch adapter (`dispatch.sh`) in the cursor adapter directory -- they provide different enforcement levels for the same IDE. Which one is actually used depends on the Cursor hooks configuration, which lives outside the baton repository.

(verified: `adapters/cursor/adapter.sh:6-11`, `adapters/cursor/dispatch.sh:1-33`)

## Challenge

**Weakest conclusion**: I described the bash-guard bypass vectors (section 5.4) based on reading the pattern matching code, but I did not actually test whether these bypass vectors work in practice. It's possible that Claude Code's own tool implementation limits what Bash commands the AI can construct in ways that make some theoretical bypasses practically impossible.

**Most important thing not checked**: The actual `~/.claude/settings.json` content (user-level) to verify that the hooks are currently registered as expected. I was denied permission to read that file. The analysis of hook registration relies on reading `setup.sh`'s install_hooks() function, which generates the settings, rather than reading the actual installed configuration.

## Open Questions

1. **Which Cursor adapter is active?** The Cursor adapter directory contains both `adapter.sh` (single-hook, write-lock only) and `dispatch.sh` (full dispatch). Which one is configured in `.cursor/hooks.json` in actual Cursor projects determines the enforcement level. This is project-specific and not visible from the baton repo alone. (cannot check: no access to actual Cursor project configurations)

2. **Runtime jq availability**: The governance marker protection and several JSON parsing paths depend on jq. If a user's system lacks jq, the fallback behavior degrades enforcement in non-obvious ways. Is there a mechanism to check jq availability at install time and warn? (partial answer: `baton doctor` does not currently check for jq)

3. **Temp file cleanup**: failure-tracker and post-write-tracker create files in `/tmp/`. Are these ever cleaned up between sessions? Currently they accumulate indefinitely until the OS cleans `/tmp/`. (verified: no cleanup logic exists in the hooks; `/tmp/` files persist)

## 批注区
