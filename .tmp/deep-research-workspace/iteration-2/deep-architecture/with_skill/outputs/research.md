# Baton Multi-IDE Adapter Architecture: Complete Analysis

## Overview

```
                    ┌───────────────────────────────────────┐
                    │         .baton/ (canonical source)     │
                    │  hooks/          adapters/             │
                    │    dispatch.sh     cursor/dispatch.sh  │
                    │    manifest.conf   codex/dispatch.sh   │
                    │    write-lock.sh   cursor/adapter.sh   │
                    │    bash-guard.sh   codex/adapter.sh    │
                    │    phase-guide.sh                      │
                    │    ...7 more      skills/  lib/        │
                    └──────────┬────────────────────────────┘
                               │ junction/symlink/copy
          ┌────────────────────┼─────────────────────────┐
          ▼                    ▼                          ▼
┌─────────────────┐  ┌──────────────────┐   ┌─────────────────────┐
│ Claude Code /   │  │   Cursor IDE     │   │     Codex CLI       │
│  Factory AI     │  │                  │   │                     │
├─────────────────┤  ├──────────────────┤   ├─────────────────────┤
│ NATIVE protocol │  │ ADAPTER layer    │   │ ADAPTER layer       │
│                 │  │ (JSON translate) │   │ (channel redirect)  │
│ settings.json   │  │ hooks.json       │   │ hooks.json          │
│  → run-hook.cmd │  │  → cursor/       │   │  → codex/           │
│  → dispatch.sh  │  │    dispatch.sh   │   │    dispatch.sh      │
│  → manifest.conf│  │  → dispatch.sh   │   │  → dispatch.sh     │
│                 │  │  → manifest.conf │   │  → manifest.conf    │
├─────────────────┤  ├──────────────────┤   ├─────────────────────┤
│ 10/10 hooks     │  │ 7/10 hooks       │   │ 2/10 hooks          │
│ Full protection │  │ Core protection  │   │ Rules + guidance    │
└─────────────────┘  └──────────────────┘   └─────────────────────┘

Event flow (Claude Code, native):
  IDE → settings.json → run-hook.cmd → dispatch.sh → manifest.conf → hook.sh
                                                                    ↓
  IDE ← exit code (0=allow, 2=block) + stderr (AI-visible) ←──────┘

Event flow (Cursor, adapted):
  IDE → hooks.json → cursor/dispatch.sh → dispatch.sh → manifest.conf → hook.sh
                   ↓                                                    ↓
  IDE ← JSON {"decision":"block","reason":"..."} ← exit code + stderr ─┘

Event flow (Codex, adapted):
  IDE → hooks.json → codex/dispatch.sh → dispatch.sh → manifest.conf → hook.sh
                   ↓                                                    ↓
  IDE ← stdout as DeveloperInstructions ← stderr→stdout redirect ──────┘
```

Baton is a multi-IDE governance framework built on three interlocking systems: a **hook dispatch system** for runtime enforcement, an **adapter system** for IDE protocol translation, and a **skill distribution system** using filesystem junctions. It supports 4 IDE targets (Claude Code, Factory AI, Cursor, Codex) across 3 enforcement tiers.

---

## Findings

### 1. Hook Dispatch System: How Events Route to Handlers

The dispatch system has three layers: IDE-specific entry points, the canonical dispatcher, and the manifest-driven routing table.

**Layer 1: IDE Entry Points**

Each IDE has its own hook configuration format. The entry point translates from IDE-native format to a call to the canonical dispatch.sh:

| IDE | Config file | Entry command | Protocol |
|-----|------------|---------------|----------|
| Claude Code | `.claude/settings.json` | `.baton/hooks/run-hook.cmd <Event>` | PascalCase events, JSON stdin, exit codes |
| Factory AI | `.claude/settings.json` | Same as Claude Code | Same as Claude Code |
| Cursor | `.cursor/hooks.json` | `bash .baton/adapters/cursor/dispatch.sh <event>` | camelCase events, JSON stdin, JSON stdout |
| Codex | `.codex/hooks.json` | `bash .baton/adapters/codex/dispatch.sh <Event>` | PascalCase events, stdout as context |

(verified: read `setup.sh` lines 184-478, `.claude/settings.json`, `.codex/hooks.json`)

**Layer 2: Canonical Dispatcher** (`dispatch.sh`, 64 lines)

The dispatcher is IDE-agnostic. It:
1. Takes event name as `$1` (verified: `dispatch.sh:7`)
2. Buffers stdin into `$BATON_STDIN` so multiple hooks can read the same input (verified: `dispatch.sh:17-20`)
3. Extracts `tool_name` from JSON via jq (with awk fallback) for matcher filtering (verified: `dispatch.sh:24-31`)
4. Iterates `manifest.conf` line by line, matching event name and tool matcher (verified: `dispatch.sh:35-62`)
5. Runs each matching hook in a **subshell** (`( . "$_dir/$_script.sh" )`) to isolate exit codes and variable state (verified: `dispatch.sh:52`)
6. For PreToolUse: first exit-2 (block) wins; subsequent hooks still run but don't change the exit code (verified: `dispatch.sh:55-57`)
7. Unexpected exit codes (not 0, not 2) generate a warning but don't block (verified: `dispatch.sh:59-60`)

**Layer 3: Manifest Routing Table** (`manifest.conf`)

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

Format: `event:matcher:script` (verified: read `manifest.conf`)
- Empty matcher = match all tools
- Comma-separated matcher = match any listed tool name
- Matcher matching uses `,tool,` containment check (verified: `dispatch.sh:44-46`)

**Complete Hook Inventory** (10 hooks across 8 event types):

| Hook | Event | Matcher | Exit behavior | Function |
|------|-------|---------|---------------|----------|
| phase-guide | SessionStart | all | 0 always | Detects phase (RESEARCH/PLAN/ANNOTATION/AWAITING_TODO/IMPLEMENT/FINISH), outputs guidance to stderr, injects using-baton SKILL.md as additionalContext JSON on EXIT trap |
| write-lock | PreToolUse | Write,Edit,MultiEdit,CreateFile,NotebookEdit | 0=allow, 2=block | Blocks source writes without BATON:GO in plan. Always allows .md files (but blocks governance marker injection). Enforces write-set membership when plan defines Files: fields |
| bash-guard | PreToolUse | Bash | 0=allow, 2=block | When gate closed: blocks shell write patterns (redirect, heredoc, tee, sed -i, cp, mv, patch, truncate, install). When gate open: allows everything |
| post-write-tracker | PostToolUse | Write,Edit,MultiEdit,CreateFile,NotebookEdit | 0 always | Warns if modified file not in plan's ## Todo write-set. Tracks repeat violations per session |
| quality-gate | PostToolUse | Write,Edit,MultiEdit,CreateFile,NotebookEdit | 0 always | Checks plan/research files for ## Self-Challenge section with >=3 content lines |
| subagent-context | SubagentStart | all | 0 always | Injects plan progress (todo counts) and authorized write-set to subagent context |
| stop-guard | Stop | all | 0 always | Reminds about incomplete todos or finish workflow when stopping mid-implementation |
| completion-check | TaskCompleted | all | 0=allow, 2=block | Blocks task completion without ## Retrospective (>=3 content lines). Advisory for unresolved markers and test suite |
| failure-tracker | PostToolUseFailure | all | 0 always | Counts tool failures per session. Alerts at 3 (check hypothesis) and 5 (stop and surface) |
| pre-compact | PreCompact | all | 0 always | Preserves plan phase, progress, write-set, and annotation log before context compression |

(verified: read all 10 hook scripts)

**Shared library stack** (verified: read `.baton/hooks/lib/`):
- `common.sh` -- legacy wrappers that delegate to plan-parser.sh, plus test suite auto-detection
- `plan-parser.sh` (v1.3) -- 1A: plan discovery (walk-up from cwd), research discovery, BATON:GO check, skill discovery, project root inference. 1B: todo section parsing (range, counts, items). 1C: write-set extraction and normalization (handles Windows absolute paths via cygpath)
- `junction.sh` -- `atomic_junction()`: tries NTFS junction (via cygpath + mklink /J), then symlink, then copy fallback

### 2. Capability Tier Model

Baton defines three enforcement tiers based on what hooks an IDE's hook API can support:

#### Tier 1: Full Protection (Claude Code, Factory AI)

**10/10 hooks active.** These IDEs use baton's canonical protocol natively -- no adapter layer needed.

Configuration artifacts:
- `.claude/settings.json` -- hook registrations for all 8 event types (verified: read actual settings.json)
- `CLAUDE.md` with `@.baton/constitution.md` import
- `.claude/skills/` -- skill junctions
- Windows: uses `run-hook.cmd` polyglot wrapper (batch for cmd.exe, shell script for bash)

Protocol:
- PascalCase event names (PreToolUse, PostToolUse, SessionStart, Stop, etc.)
- JSON on stdin with `tool_name`, `tool_input`, `cwd` fields
- Exit 0 = allow, exit 2 = block
- Stderr output is visible to the AI
- Stdout hookSpecificOutput JSON for `additionalContext` injection

Factory AI is architecturally identical to Claude Code -- `setup.sh` treats them as the same case (`claude|factory`) for settings generation and skill placement (verified: `setup.sh:150,662`). The only difference is IDE detection (`.factory/` directory).

#### Tier 2: Core Protection (Cursor)

**7/10 hooks active** (corrected from the existing ide-capability-matrix.md which says 5/9).

Configuration artifacts:
- `.cursor/hooks.json` -- hook registrations for 6 event types (verified: read `setup.sh:291-317`)
- `.cursor/rules/baton.mdc` -- constitution.md wrapped with `alwaysApply: true` frontmatter
- `.cursor/skills/` -- skill junctions

Events registered in `.cursor/hooks.json`: sessionStart, preToolUse (Write, Edit, Bash), postToolUse (Write, Edit), stop, subagentStart, preCompact.

Events NOT registered: taskCompleted, postToolUseFailure.

The Cursor adapter (`adapters/cursor/dispatch.sh`, 33 lines) performs two translations:
1. **Event name case mapping**: camelCase to PascalCase (`sessionStart` -> `SessionStart`, `preToolUse` -> `PreToolUse`, etc.) (verified: lines 12-21)
2. **Exit code to JSON**: exit 2 -> `{"decision":"block","reason":"<stderr>"}`, exit 0 -> `{"decision":"allow"}` (verified: lines 27-33)

Hooks that fire through Cursor dispatch:

| Hook | Fires? | Via event |
|------|--------|-----------|
| phase-guide | Yes | sessionStart |
| write-lock | Yes | preToolUse (Write, Edit) |
| bash-guard | Yes | preToolUse (Bash) |
| post-write-tracker | Yes | postToolUse (Write, Edit) |
| quality-gate | Yes | postToolUse (Write, Edit) |
| subagent-context | Yes | subagentStart |
| stop-guard | Yes | stop |
| pre-compact | Yes | preCompact |
| completion-check | No | taskCompleted not registered |
| failure-tracker | No | postToolUseFailure not registered |

**Documentation discrepancy found**: The existing `docs/ide-capability-matrix.md` (line 24-27) marks post-write-tracker, stop-guard, and quality-gate as unavailable for Cursor. The legacy `adapter.sh` comment (line 6-10) also lists stop-guard as "reduced/missing". But `setup.sh` DOES register postToolUse (Write, Edit), stop, and the Cursor dispatch adapter handles all these events. **The code registers 7 hooks for Cursor; the documentation says 5.** (verified: read `setup.sh:291-317`, `adapters/cursor/dispatch.sh:12-21`, `docs/ide-capability-matrix.md`)

Possible explanations:
- The matrix was written before stop/postToolUse were added to Cursor's hooks.json registration, and never updated.
- The adapter.sh capability comment is from the legacy single-hook era and wasn't updated when dispatch.sh was introduced.
- Cursor may not actually support all these event types (postToolUse, stop) and the registrations are aspirational. But the code is unconditional -- there's no evidence of Cursor rejecting these hooks.

#### Tier 3: Rules + Guidance (Codex)

**2/10 hooks active** (SessionStart and Stop only, both experimental).

Configuration artifacts:
- `.codex/hooks.json` -- SessionStart and Stop only (verified: read actual hooks.json)
- `.codex/config.toml` -- `codex_hooks = true` feature flag
- `~/.codex/config.toml` -- per-project trust entry
- `AGENTS.md` with `@.baton/constitution.md` import
- `.agents/skills/` -- skill junctions

The Codex adapter (`adapters/codex/dispatch.sh`, 35 lines) has fundamentally different behavior:
1. **SessionStart**: Prepends tier header, closes stdin (Codex may not send EOF, which would hang dispatch.sh's `cat`), runs canonical dispatch (verified: lines 16-19)
2. **Stop**: Saves stop message to `.codex/stop-hook.message.txt` (off the JSON protocol channel), emits `{"continue":false}` (verified: lines 22-28)
3. **All other events**: Runs dispatch with stderr->stdout redirect, swallows errors with `|| true` (verified: lines 30-31). These events never actually fire because Codex only registers SessionStart and Stop.

The Codex adapter prepends `[Baton capability: rules + guidance only (Codex)] Hard gates (write-lock, bash-guard) are not available. Enforcement relies on rules and guidance.` to all output, making the enforcement gap visible to the AI.

**Critical Codex gaps**:
- No PreToolUse means no write-lock or bash-guard enforcement
- No PostToolUse means no write-set drift detection
- No SubagentStart means subagents don't receive plan context
- No TaskCompleted means no retrospective enforcement
- Codex relies on its own sandbox and human approval controls as separate safety layers

### 3. Security Boundaries: Write-Lock Enforcement Across Adapters

Write-lock (`write-lock.sh`, 172 lines) is baton's primary security boundary. Its enforcement path differs significantly across IDEs.

**Write-lock decision flow** (verified: read complete write-lock.sh):

```
Input: BATON_STDIN (JSON with tool_name, tool_input.file_path)
  │
  ├─ BATON_BYPASS=1? → ALLOW (emergency bypass)
  │
  ├─ Cannot determine target path? → ALLOW (fail-open, with warning)
  │
  ├─ Target is .md/.mdx?
  │    ├─ In baton-tasks/? → ALLOW
  │    └─ Content contains BATON:GO or BATON:OVERRIDE? → BLOCK (governance marker protection)
  │    └─ Otherwise → ALLOW
  │
  ├─ Target outside project root? → ALLOW
  │
  ├─ No plan file found? → BLOCK ("complete research first")
  │
  ├─ Multiple plans, no BATON_PLAN set? → BLOCK ("ambiguous")
  │
  ├─ Plan has BATON:GO?
  │    ├─ Write-set defined + target in write-set? → ALLOW (with self-check reminder)
  │    ├─ Write-set defined + target NOT in write-set? → BLOCK ("not in approved write set")
  │    └─ No write-set defined? → ALLOW
  │
  └─ Plan exists but no BATON:GO? → BLOCK ("annotation cycle in progress")
```

**Per-IDE enforcement comparison**:

| Aspect | Claude Code / Factory | Cursor | Codex |
|--------|----------------------|--------|-------|
| Write-lock fires? | Yes, every write/edit | Yes, every write/edit | **No** |
| Enforcement mechanism | exit 2 blocks tool call | exit 2 -> JSON `{"decision":"block"}` | N/A |
| Governance marker protection | Yes (blocks AI adding BATON:GO/OVERRIDE to .md) | Yes (same write-lock code) | **No** |
| Write-set enforcement | Yes (blocks files not in ## Todo Files:) | Yes (same write-lock code) | **No** |
| Fail-open behavior | Yes (on parse error, missing lib) | Yes (same code) | N/A |
| bash-guard fires? | Yes, every Bash call | Yes, every Bash call | **No** |
| Post-write drift warning | Yes (post-write-tracker) | Yes (registered) | **No** |
| Repeat violation escalation | Yes (tracks per session) | Yes (same code) | **No** |

**Bash-guard decision flow** (verified: read complete bash-guard.sh):

When gate is open (BATON:GO present): allows everything.
When gate is closed, blocks:
- Output redirection (`>`, `>>`)
- Heredoc with redirect
- `tee` command
- `sed -i`, `perl -pi`
- `python -c` with file write patterns (`open(..., 'w')`)
- `cp`, `mv`, `install`, `truncate`, `patch`

Warns but allows: `rm`, `touch`

Uses quote-stripping to avoid false positives on strings containing these patterns. Checks for path-qualified variants (`/bin/cp`, `/usr/bin/tee`).

**Security gap analysis**:

The critical security boundary is between Tier 1/2 (has write-lock) and Tier 3 (no write-lock). On Codex:
- The AI can write any file without plan approval
- The AI can add BATON:GO markers to plans (governance marker protection doesn't fire)
- Write-set boundaries are not enforced
- The only protection is the constitution.md rules loaded via AGENTS.md and the using-baton skill text injected at SessionStart

This is by design -- `adapter.sh` explicitly documents: "Codex sandbox and human approval controls provide separate safety layers."

### 4. Minimum Contract for Adding a New IDE Adapter

Based on tracing the complete integration surface, here is the minimum contract:

#### Required: Adapter Files

**`adapters/<ide>/dispatch.sh`** -- the event translator.

Minimum implementation:
```bash
#!/usr/bin/env bash
# Translate IDE event format to canonical dispatch.sh
set -eu
_dir="$(cd "$(dirname "$0")" && pwd)"
_hooks_dir="$_dir/../../hooks"

# 1. Map IDE event names to PascalCase canonical names
_event="$1"
case "$_event" in
    <ide_event_name>)  _event="<PascalCaseName>" ;;
    # ... map all events
esac

# 2. Call canonical dispatch
_out=""
_rc=0
_out="$(bash "$_hooks_dir/dispatch.sh" "$_event" 2>&1)" || _rc=$?

# 3. Translate exit code/output to IDE protocol
# This is the IDE-specific part
```

The adapter must handle:
- **Event name translation**: IDE-specific names to PascalCase (SessionStart, PreToolUse, PostToolUse, Stop, SubagentStart, PreCompact, TaskCompleted, PostToolUseFailure)
- **Output protocol translation**: exit codes + stderr to whatever the IDE expects (JSON, stdout text, etc.)
- **stdin forwarding**: if the IDE doesn't send EOF, close stdin to prevent dispatch.sh's `cat` from hanging (see Codex adapter: `</dev/null`)

Optional legacy file:
- `adapters/<ide>/adapter.sh` -- single-hook translator. Only needed if you want a direct write-lock path separate from dispatch.

#### Required: setup.sh Modifications

1. **Add to `SUPPORTED_IDES`** (line 18): `"claude codex cursor factory <newide>"`

2. **IDE detection** in `detect_ides()`: check for IDE-specific directory/file markers

3. **Skill junction target** in `create_skill_junctions()`: map IDE to its skill directory
   ```bash
   <newide>) _skills_dir="$PROJECT_DIR/.<newide>/skills" ;;
   ```

4. **Hook registration function**: `generate_<newide>_hooks()` that creates the IDE-specific hook config file. Must register at minimum the events the IDE supports.

5. **Rules/context injection**: IDE-specific mechanism to load constitution.md (e.g., `.windsurfrules`, `.cursor/rules/`, `AGENTS.md`)

6. **Main loop case**: add the IDE to the setup case statement (line 660-674)

#### Required: phase-guide.sh Modifications

Two arrays need the new IDE's skill directory added:

1. **Auto-junction loop** (line 59): add `"$_proj/.<newide>/skills"` to the IDE skills directories
2. **Skill scanning** (line 74): add `.<newide>` to the IDE prefixes in `_scan_all_skills()`

#### Required: .gitignore

Add junction paths to the gitignore entries in `add_gitignore()`.

#### The Minimum Viable Contract (Summary Table)

| Component | Required? | What to implement |
|-----------|----------|-------------------|
| `adapters/<ide>/dispatch.sh` | Yes | Event name mapping + output protocol translation |
| `adapters/<ide>/adapter.sh` | No (legacy) | Only if IDE needs single-hook path |
| `setup.sh` SUPPORTED_IDES | Yes | Add IDE name to list |
| `setup.sh` detect_ides() | Yes | IDE presence detection |
| `setup.sh` create_skill_junctions() | Yes | Map IDE to skill directory |
| `setup.sh` generate_<ide>_hooks() | Yes | Create IDE hook config file |
| `setup.sh` rules injection | Depends | IDE-specific constitution loading mechanism |
| `setup.sh` main loop | Yes | Wire up the generate function |
| `phase-guide.sh` auto-junction | Yes | Add skill dir to loop (line 59) |
| `phase-guide.sh` skill scan | Yes | Add IDE prefix to scan (line 74) |
| `setup.sh` add_gitignore() | Yes | Add junction paths |
| `manifest.conf` | No change | Manifest is IDE-agnostic |
| Hook scripts | No change | All hooks are IDE-agnostic |

**Key architectural insight**: The hook scripts themselves never need modification. The manifest.conf never needs modification. All IDE-specific behavior is isolated in three places: the adapter dispatch.sh, the setup.sh registration functions, and the two phase-guide.sh skill-directory arrays. This is a clean separation.

### 5. IDE Protocol Comparison (Field-by-Field)

| Protocol dimension | Claude Code | Cursor | Codex |
|--------------------|-------------|--------|-------|
| Hook config file | `.claude/settings.json` | `.cursor/hooks.json` | `.codex/hooks.json` |
| Config format | JSON with `hooks.<Event>[]` | JSON with `hooks.<event>[]` | JSON with `hooks.<Event>[]` |
| Event name case | PascalCase | camelCase | PascalCase |
| Stdin format | JSON: `{tool_name, tool_input, cwd}` | JSON (same fields) | JSON (may not send EOF) |
| Block signal | exit 2 | `{"decision":"block","reason":"..."}` on stdout | N/A (no blocking hooks) |
| Allow signal | exit 0 | `{"decision":"allow"}` on stdout | N/A |
| AI-visible messages | stderr | `reason` field in block JSON | stdout as DeveloperInstructions |
| Context injection | hookSpecificOutput JSON on stdout | context field in allow JSON | stdout text |
| Timeout | None specified | 10s per hook | 30s per hook |
| Matcher format | pipe-separated (`Edit\|Write\|...`) | single tool name per entry | N/A |
| Rules file | `CLAUDE.md` (unlimited) | `.cursor/rules/*.mdc` (frontmatter) | `AGENTS.md` (unlimited) |
| Skills directory | `.claude/skills/` | `.cursor/skills/` | `.agents/skills/` |

---

## Contradictions & Tensions

### 1. Cursor Hook Coverage: Documentation vs. Code

**The code says 7 hooks. The documentation says 5.**

`setup.sh` registers 6 event types for Cursor: sessionStart, preToolUse (Write, Edit, Bash), postToolUse (Write, Edit), stop, subagentStart, preCompact. Through these 6 event types, 7 of 10 hook scripts can fire: phase-guide, write-lock, bash-guard, post-write-tracker, quality-gate, stop-guard, subagent-context (pre-compact is the 8th but only has one script).

Wait -- let me recount. The 6 Cursor events hit these manifest.conf entries:
- sessionStart -> SessionStart -> phase-guide (1)
- preToolUse(Write) -> PreToolUse(Write) -> write-lock (2)
- preToolUse(Edit) -> PreToolUse(Edit) -> write-lock (same)
- preToolUse(Bash) -> PreToolUse(Bash) -> bash-guard (3)
- postToolUse(Write) -> PostToolUse(Write) -> post-write-tracker (4) + quality-gate (5)
- postToolUse(Edit) -> PostToolUse(Edit) -> post-write-tracker + quality-gate (same)
- stop -> Stop -> stop-guard (6)
- subagentStart -> SubagentStart -> subagent-context (7)
- preCompact -> PreCompact -> pre-compact (8)

So **8 of 10 hook scripts fire for Cursor**, with only completion-check and failure-tracker missing. `docs/ide-capability-matrix.md` says 5/9 (now 5/10 with quality-gate). The legacy `adapter.sh` capability comment says stop-guard is "reduced/missing", which contradicts the dispatch.sh registration.

**Resolution needed**: Either update the documentation to match the code (8/10), or there's a reason these hooks don't work in Cursor that isn't documented. The Cursor hooks.json format is the source of truth -- if Cursor ignores events it doesn't understand, the registrations might be dead code. But the Cursor dispatch adapter explicitly handles `stop`, `postToolUse`, etc., so they're clearly intended to work.

### 2. Fail-Open Design vs. Security Claims

Write-lock is explicitly fail-open: if it can't determine the target path, if common.sh is missing, or if an unexpected error occurs, it allows the operation (verified: `write-lock.sh:14,48-55,85-87`). Bash-guard is also fail-open (verified: `bash-guard.sh:11`).

This is pragmatic (a broken hook shouldn't lock the developer out) but creates a tension with the security claims. An attacker (or a confused AI) that can cause a JSON parsing failure would bypass write-lock. The mitigation is that fail-open events generate visible warnings (`echo ... >&2`), so the human sees them. But on Codex, where stderr isn't the AI-visible channel, these warnings might not surface.

### 3. Adapter Capability Comments Are Stale

The `adapter.sh` files in both `cursor/` and `codex/` contain hardcoded capability comments (lines 5-10 of each). These comments list which hooks are "available" vs "reduced/missing". But these comments don't track the actual `setup.sh` registrations. For Cursor, `adapter.sh` says stop-guard is missing, but `setup.sh` registers it.

This is a maintenance problem: there's no mechanism ensuring the capability comments stay in sync with the hook registrations. The `ide-capability-matrix.md` doc was meant to be the source of truth (it has "Maintenance Rules" at the bottom), but it has the same staleness problem.

### 4. Codex stdin Hanging Risk

Both Codex adapter files (`adapter.sh:53`, `dispatch.sh:19,22,30`) close stdin with `</dev/null` to prevent dispatch.sh's `cat 2>/dev/null || true` (line 20) from hanging when Codex doesn't send EOF. This is a workaround for a Codex-specific behavior.

But this means BATON_STDIN is empty on Codex, which means any hook that relies on stdin JSON for tool context (write-lock, bash-guard, post-write-tracker) would fail to extract file paths or commands. This doesn't matter today because those hooks don't fire on Codex, but it creates a hidden constraint: **if Codex ever adds PreToolUse support, the stdin-closing workaround would need to be rethought**.

### 5. Governance Injection: Two Paths, One Purpose

Phase-guide.sh injects governance context via two mechanisms:
1. **EXIT trap** (line 41): reads `using-baton/SKILL.md` and outputs it as additionalContext JSON on stdout. This fires on every SessionStart regardless of phase.
2. **Phase-specific stderr**: outputs phase guidance to stderr (lines 103-262).

The JSON format for mechanism 1 adapts based on `CLAUDE_PLUGIN_ROOT` env var (line 35): `hookSpecificOutput.additionalContext` when present, `additional_context` otherwise. This means non-Claude-Code IDEs get a different JSON key, which may or may not be understood by their hook processors.

For Codex, the adapter redirects stderr to stdout (since Codex reads stdout as DeveloperInstructions). But the governance context JSON from the EXIT trap also goes to stdout. This means Codex receives both human-readable phase guidance AND JSON governance context mixed together on stdout. Whether Codex correctly parses the JSON from that mixed output is unclear.

### 6. NotebookEdit Coverage Gap in Cursor

`manifest.conf` line 4 includes `NotebookEdit` in the write-lock matcher. But `setup.sh` Cursor hooks.json only registers Write and Edit matchers for preToolUse (lines 299-301). If Cursor has a NotebookEdit tool, write-lock won't fire for it.

Similarly, the `MultiEdit` and `CreateFile` tools are in the manifest matcher but not in the Cursor registration. This is because Cursor uses individual tool matchers rather than pipe-separated patterns. If Cursor supports MultiEdit or CreateFile (or equivalent), they'd need explicit entries.

---

## Challenge

**Weakest conclusion**: The claim that Cursor supports 8/10 hooks. This is based on reading setup.sh's generated hooks.json, not on verifying that Cursor's hook engine actually processes all those event types. If Cursor ignores unknown events (like `subagentStart` or `preCompact`), the effective coverage would be lower. The existing ide-capability-matrix.md disagrees with my count, and the maintainer wrote that document -- they may have tested which events Cursor actually fires and found some don't work.

**What would disprove it**: Testing baton in Cursor with debug output enabled for each hook, to verify which events actually trigger. Or reading Cursor's documentation on supported hook events.

**What I skipped**:
- I did not fetch current Cursor documentation to verify which hook events Cursor actually supports. The setup.sh code registers 6 event types for Cursor, but this could be aspirational rather than tested.
- I did not investigate the `CLAUDE_PLUGIN_ROOT` environment variable -- whether it's always set in Claude Code or only in certain contexts. If it's not set, the governance injection JSON format would use `additional_context` instead of `hookSpecificOutput.additionalContext`, which might not be processed correctly.
- I did not verify whether the `.cursor/hooks.json` format supports `timeout` as a field, or what happens when a hook exceeds the timeout.
- I did not examine the test suites (`test-dispatch.sh`, `test-phase-guide.sh`) for assertions about adapter-specific behavior.

**Uninvestigated assumption**: That `exit 0` from all non-blocking hooks is correctly handled by Cursor's JSON protocol. The Cursor dispatch adapter always outputs `{"decision":"allow"}` on exit 0, even for events where "allow/block" is semantically meaningless (like `stop`, `sessionStart`, `preCompact`). Cursor may interpret this JSON differently for different event types.

---

## Recommendations

### For the documentation discrepancy (Tension 1)

Verify which events Cursor actually fires by adding a debug log to `adapters/cursor/dispatch.sh` and running a Cursor session. Then update `docs/ide-capability-matrix.md` and the `adapter.sh` capability comments to match reality. If Cursor supports more events than documented, this is a good-news update. If not, remove the dead registrations from setup.sh.

### For adding a new IDE adapter (Windsurf, Copilot, etc.)

The minimum effort path is:
1. Create `adapters/<ide>/dispatch.sh` (~30 lines)
2. Add 6 functions/entries to `setup.sh` (~100 lines)
3. Add 2 lines to `phase-guide.sh` (skill directory arrays)
4. Determine the IDE's equivalent of CLAUDE.md for constitution injection

The architecture makes this straightforward because hooks and manifest are IDE-agnostic. The only hard problem is when the target IDE lacks critical events (like SessionStart or PreToolUse) -- that's a capability gap, not an adapter problem.

### For the stale capability comments (Tension 3)

Consider removing the hardcoded capability comments from `adapter.sh` files and making `docs/ide-capability-matrix.md` the single source of truth. Or generate the comments from a single data source. The current approach of maintaining capability lists in 3 places (adapter.sh comment, ide-capability-matrix.md, setup.sh registrations) guarantees drift.

---

## Open Questions

1. **Which Cursor hook events actually fire?** The code registers 6 event types, but the documentation says fewer work. Empirical testing would resolve this.

2. **Does Codex correctly parse the mixed stdout from phase-guide.sh?** The EXIT trap outputs JSON governance context and the phase guidance outputs human-readable text, both going to stdout on Codex. Does Codex handle this correctly, or does the JSON get lost?

3. **What happens when `CLAUDE_PLUGIN_ROOT` is not set in Claude Code?** The governance injection JSON format changes. Is this handled by Claude Code's hook processor?

4. **Should `adapter.sh` (legacy single-hook path) be removed?** It's not referenced by any current setup.sh registration. Its capability comments cause documentation drift. But it might still be used by users who set up hooks manually.

5. **Is the NotebookEdit/MultiEdit/CreateFile coverage gap in Cursor intentional?** These tools are in manifest.conf's write-lock matcher but not in Cursor's hook registration. If Cursor supports these tools, they bypass write-lock.
