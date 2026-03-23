# Setup.sh File Inventory: Complete Map of Files Touched Per IDE

**Depth**: Standard — broad sweep across 4 IDEs, cross-IDE comparison, inconsistency analysis.

## Overview

setup.sh creates/modifies files in three zones: the project directory, `~/.baton/` (BATON_HOME), and `~/.codex/` (user-level). Factory is treated as Claude Code's twin — it uses `.claude/` for everything. The diagram below shows the flow:

```
setup.sh
├── ensure_baton_home()          → ~/.baton/ (git clone or pull)
├── create_baton_junction()      → .baton/ (junction → ~/.baton/.baton)
├── create_skill_junctions()     → .claude/skills/*, .cursor/skills/*, .agents/skills/*
├── Per-IDE configuration:
│   ├── claude/factory           → .claude/settings.json, CLAUDE.md
│   ├── cursor                   → .cursor/hooks.json, .cursor/rules/baton.mdc
│   └── codex                    → AGENTS.md, .codex/hooks.json, .codex/config.toml, ~/.codex/config.toml
└── add_gitignore()              → .gitignore
```

## Complete File Inventory

### 1. Shared Files (All IDEs)

| File | Generated/Copied | Contents | Gitignored | IDEs | Source |
|------|-------------------|----------|------------|------|--------|
| `.baton/` | Junction (or copy) to `~/.baton/.baton` | Entire baton runtime: hooks, adapters, skills, constitution.md | Yes (`.baton/` in .gitignore by setup) | All | `setup.sh:124-140` |
| `.baton/.copy-mode` | Generated (touch) | Empty marker file; only created if junction creation fails | Yes (inside `.baton/`) | All (fallback only) | `setup.sh:137` |
| `.gitignore` | Modified (appended) | Entries for `.baton/`, `.codex/`, plus per-skill entries for all three skill dirs | No (tracked) | All | `setup.sh:507-538` |
| `.agents/skills/<skill>/` | Junction per skill | Skill content (SKILL.md etc.) | Yes (`.agents/skills/baton-*` in repo .gitignore; setup adds per-skill entries) | **All IDEs** (always created, even if codex not selected) | `setup.sh:167-180` |

### 2. Claude Code Files

| File | Generated/Copied | Contents | Gitignored | Source |
|------|-------------------|----------|------------|--------|
| `.claude/settings.json` | Generated (jq or hardcoded template) | Hook registrations: 9 entries across 8 event types. Commands route through `.baton/hooks/run-hook.cmd` | No (tracked per repo .gitignore `!.claude/settings.json`) | `setup.sh:185-282` |
| `CLAUDE.md` | Generated or modified | `@.baton/constitution.md` import directive. Created if missing; appended if present without the directive; old `@.baton/workflow.md` imports migrated. | No (tracked; root CLAUDE.md excluded from `**/CLAUDE.md` ignore) | `setup.sh:481-503` |
| `.claude/skills/<skill>/` | Junction per skill | Skill directories | Yes (`.claude/skills/baton-*` in repo .gitignore; setup adds entries) | `setup.sh:150-151, 156-164` |

### 3. Factory Files

| File | Generated/Copied | Contents | Gitignored | Source |
|------|-------------------|----------|------------|--------|
| `.claude/settings.json` | Same as Claude Code | Identical hook registrations | No | `setup.sh:662-664` |
| `CLAUDE.md` | Same as Claude Code | Identical | No | `setup.sh:665` |
| `.claude/skills/<skill>/` | Same as Claude Code | Identical | Yes | `setup.sh:150-151` |

Factory detection: `.factory/` directory exists (`setup.sh:90`). All output goes to `.claude/` — Factory shares Claude Code's config namespace entirely.

### 4. Cursor Files

| File | Generated/Copied | Contents | Gitignored | Source |
|------|-------------------|----------|------------|--------|
| `.cursor/hooks.json` | Generated (hardcoded JSON template, or jq merge) | Hook registrations for 6 event types. Commands route through `bash .baton/adapters/cursor/dispatch.sh`. | Not gitignored by setup | `setup.sh:285-346` |
| `.cursor/rules/baton.mdc` | Generated (cat from constitution.md) | YAML frontmatter (`alwaysApply: true`) + full constitution.md content | Not gitignored by setup | `setup.sh:349-360` |
| `.cursor/skills/<skill>/` | Junction per skill | Skill directories | Yes (`.cursor/skills/baton-*` in repo .gitignore; setup adds entries) | `setup.sh:151, 156-164` |

### 5. Codex Files

| File | Generated/Copied | Contents | Gitignored | Source |
|------|-------------------|----------|------------|--------|
| `AGENTS.md` | Generated or modified | `@.baton/constitution.md` directive. Created if missing; appended or migrated if present. | Not gitignored by setup | `setup.sh:364-382` |
| `.codex/hooks.json` | Generated (hardcoded JSON template, or jq merge) | Hook registrations for 2 event types only (SessionStart, Stop). Commands route through `bash .baton/adapters/codex/dispatch.sh`. | Yes (`.codex/` in .gitignore by setup) | `setup.sh:385-441` |
| `.codex/config.toml` | Generated or modified | `[features] codex_hooks = true` feature flag | Yes (inside `.codex/`) | `setup.sh:443-458` |
| `~/.codex/config.toml` | Modified (appended) | Project trust entry: `[projects.'<path>'] trust_level = "trusted"` | N/A (user-level, outside project) | `setup.sh:460-477` |
| `.agents/skills/<skill>/` | Junction per skill | Skill directories (also created for non-codex installs — see inconsistency #4) | Yes (setup adds entries) | `setup.sh:152-153, 167-180` |

### 6. Runtime Files (created by adapters, not setup.sh directly)

| File | Generated/Copied | Contents | Gitignored | Source |
|------|-------------------|----------|------------|--------|
| `.codex/stop-hook.message.txt` | Generated at runtime by Codex adapter | Stop-guard reminder text (human-readable, saved off-channel because Codex Stop expects JSON on stdout) | Yes (inside `.codex/`) | `adapters/codex/dispatch.sh:24-26`, `adapters/codex/adapter.sh:42-45` |

### 7. BATON_HOME Files (outside project)

| File | Generated/Copied | Contents | Source |
|------|-------------------|----------|--------|
| `~/.baton/` | Git clone (if not present) or `git pull --ff-only` (if present) | Full baton repo clone. The `.baton/` junction in projects points here. | `setup.sh:57-72` |

## Inconsistencies Found

### Inconsistency 1: Event Coverage Disparity

The number of hook events registered differs significantly per IDE:

| Event | Claude/Factory | Cursor | Codex |
|-------|---------------|--------|-------|
| PreToolUse | Yes (2 entries: write tools + Bash) | Yes (3 entries: Write, Edit, Bash) | **No** |
| PostToolUse | Yes (1 entry: write tools) | Yes (2 entries: Write, Edit) | **No** |
| SessionStart | Yes | Yes | Yes |
| Stop | Yes | Yes | Yes |
| PreCompact | Yes | Yes | **No** |
| SubagentStart | Yes | Yes | **No** |
| TaskCompleted | Yes | **No** | **No** |
| PostToolUseFailure | Yes | **No** | **No** |

Codex only gets 2 of 8 events. Cursor gets 6 of 8 (missing TaskCompleted, PostToolUseFailure). Only Claude/Factory get all 8. This is partially by design (Codex has no PreToolUse gate — stated in adapter.sh comments), but **TaskCompleted and PostToolUseFailure are missing from Cursor with no documented rationale** (`verified: compared setup.sh:196-206 vs setup.sh:291-317`).

### Inconsistency 2: PreToolUse Matcher Granularity

Claude/Factory groups all write tools in one matcher (`Edit|Write|MultiEdit|CreateFile|NotebookEdit`), while Cursor splits them into separate entries per tool (`Write`, `Edit` — and **omits `MultiEdit`, `CreateFile`, `NotebookEdit`**).

- Claude/Factory PreToolUse: `Edit|Write|MultiEdit|CreateFile|NotebookEdit` + `Bash` (2 entries, 6 tools covered)
- Cursor PreToolUse: `Write`, `Edit`, `Bash` (3 entries, **only 3 tools covered**)

This means **Cursor's write-lock does not fire for MultiEdit, CreateFile, or NotebookEdit** (`verified: setup.sh:299-301`). Same gap exists for PostToolUse (`verified: setup.sh:303-305` — only `Write` and `Edit`).

### Inconsistency 3: No CLAUDE.md or Rules File for Codex/Cursor Parity

- Claude/Factory get `CLAUDE.md` with `@.baton/constitution.md` import.
- Codex gets `AGENTS.md` with the same import — this is correct (Codex reads AGENTS.md).
- Cursor gets `.cursor/rules/baton.mdc` with the full constitution inlined — also correct (Cursor reads .mdc rules).

This is **not an inconsistency** — each IDE reads a different rules file format. Coverage is actually correct here.

### Inconsistency 4: .agents/skills/ Always Created

`create_skill_junctions()` at lines 167-180 **always** creates `.agents/skills/<skill>/` junctions, regardless of whether codex is in the selected IDE list. The code explicitly says:

```bash
# Always create .agents/skills fallback
if ! echo " $IDES " | grep -q ' codex '; then
```

This means even a Claude-only install gets `.agents/skills/` directories. This is intentional (called "fallback") but may cause confusion — users see an `.agents/` directory they didn't ask for.

### Inconsistency 5: Gitignore Coverage Gaps

Setup adds these gitignore entries (`setup.sh:510-520`):
- `.baton/` and `.codex/` (only if not self-install)
- `.<ide>/skills/<skill>` for each skill name, for `.claude/skills`, `.cursor/skills`, `.agents/skills`

**Not gitignored by setup:**
- `.cursor/hooks.json` — tracked, could conflict between developers
- `.cursor/rules/baton.mdc` — tracked, generated from constitution.md, will duplicate content in git
- `AGENTS.md` — tracked (correct, needed by Codex)
- `.cursor/` directory itself — not ignored

In the **repo's own .gitignore**, there are entries for `.claude/skills/baton-*`, `.cursor/skills/baton-*`, `.agents/skills/baton-*` using a glob pattern — but setup.sh adds per-skill entries like `.claude/skills/baton-research`. These could overlap/conflict.

### Inconsistency 6: Dispatch Command Format Differences

| IDE | Command format | Dispatch path |
|-----|---------------|---------------|
| Claude/Factory | `.baton/hooks/run-hook.cmd PreToolUse` | Direct to dispatch.sh via polyglot wrapper |
| Cursor | `bash .baton/adapters/cursor/dispatch.sh preToolUse` | Adapter translates camelCase to PascalCase, then calls dispatch.sh |
| Codex | `bash .baton/adapters/codex/dispatch.sh SessionStart` | Adapter handles stdin/stdout protocol translation |

Claude/Factory use PascalCase event names natively. Cursor hooks.json uses camelCase (the adapter translates). Codex hooks.json uses **PascalCase** directly. This is correct per each IDE's convention, but it means two different naming conventions exist in the generated config files.

### Inconsistency 7: Hook Timeout Values

- Cursor: all hooks have `"timeout": 10` (seconds) — (`setup.sh:296-316`)
- Codex: hooks have `"timeout": 30` (seconds) — (`setup.sh:399, 410`)
- Claude/Factory: **no timeout specified** in settings.json — (`setup.sh:213-252`)

The 3x timeout difference between Cursor (10s) and Codex (30s) is notable. Claude/Factory rely on whatever the IDE's default timeout is.

### Inconsistency 8: Codex Has Legacy adapter.sh + Newer dispatch.sh

Two dispatch mechanisms exist for Codex:
- `.baton/adapters/codex/adapter.sh` — legacy, directly calls `phase-guide.sh` and `stop-guard.sh` by name
- `.baton/adapters/codex/dispatch.sh` — newer, calls dispatch.sh generically

Setup.sh references only `dispatch.sh` (`setup.sh:386`). The old `adapter.sh` is unused dead code. Same pattern exists for Cursor (adapter.sh is legacy, dispatch.sh is current). (`verified: setup.sh:287 vs adapter file contents`)

## Summary Table: Files by IDE

| File | Claude | Factory | Cursor | Codex |
|------|--------|---------|--------|-------|
| `.baton/` (junction) | Yes | Yes | Yes | Yes |
| `.claude/settings.json` | Yes | Yes | - | - |
| `CLAUDE.md` | Yes | Yes | - | - |
| `.claude/skills/<skill>/` | Yes | Yes | - | - |
| `.cursor/hooks.json` | - | - | Yes | - |
| `.cursor/rules/baton.mdc` | - | - | Yes | - |
| `.cursor/skills/<skill>/` | - | - | Yes | - |
| `AGENTS.md` | - | - | - | Yes |
| `.codex/hooks.json` | - | - | - | Yes |
| `.codex/config.toml` | - | - | - | Yes |
| `~/.codex/config.toml` | - | - | - | Yes |
| `.agents/skills/<skill>/` | **Yes** | **Yes** | **Yes** | Yes |
| `.gitignore` | Yes | Yes | Yes | Yes |

## Open Questions

1. **Is the Cursor tool matcher gap (missing MultiEdit, CreateFile, NotebookEdit) intentional?** Cursor may not support pipe-separated matchers — would need to verify Cursor's hook spec. If it does support them, this is a bug. If not, each tool needs its own entry.

2. **Should Cursor get TaskCompleted and PostToolUseFailure events?** These were added to Claude/Factory but not Cursor. If Cursor supports these event types, this is an omission.

3. **Are the legacy adapter.sh files (cursor and codex) still referenced anywhere?** They appear to be dead code superseded by dispatch.sh — could be cleaned up.

## 批注区
