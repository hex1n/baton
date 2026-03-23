# Distributing Baton as a Claude Code Plugin

## Overview

Claude Code has a mature plugin system (available since v1.0.33) with a well-defined packaging format, marketplace distribution model, and official registry. Baton's current architecture maps surprisingly well onto the plugin structure, but there are several concrete gaps that need bridging. This document lays out the plugin requirements, compares them against baton's current layout, and identifies what would need to change.

## Claude Code Plugin System — How It Works

### Plugin File Structure

A Claude Code plugin is a self-contained directory with this layout (verified: https://code.claude.com/docs/en/plugins-reference):

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          # Manifest (only required field: "name")
├── skills/                   # Agent Skills (SKILL.md in subdirs)
│   └── my-skill/
│       └── SKILL.md
├── commands/                 # Simple markdown commands
├── agents/                   # Subagent definitions
├── hooks/
│   └── hooks.json            # Hook configurations
├── .mcp.json                 # MCP server configs
├── .lsp.json                 # LSP server configs
├── settings.json             # Default settings (currently only "agent" key)
├── scripts/                  # Hook/utility scripts
└── LICENSE
```

Key rules:
- `.claude-plugin/` contains ONLY `plugin.json`. All other directories are at the plugin root.
- Skills are namespaced: a plugin named `baton` would expose skills as `/baton:baton-plan`, `/baton:baton-implement`, etc.
- Paths inside the plugin must be relative and start with `./`.
- Plugins are copied to a cache (`~/.claude/plugins/cache`) at install time. Files outside the plugin directory are NOT copied (no `../` traversal). Symlinks within the plugin directory ARE followed during copy.
- `${CLAUDE_PLUGIN_ROOT}` references the installed plugin path. `${CLAUDE_PLUGIN_DATA}` persists across updates.

### plugin.json Manifest

The only required field is `name`. Full schema (verified: plugins-reference):

```json
{
  "name": "baton",
  "version": "1.0.0",
  "description": "Plan-first governance workflow for AI coding assistants",
  "author": { "name": "hex1n" },
  "homepage": "https://github.com/hex1n/baton",
  "repository": "https://github.com/hex1n/baton",
  "license": "MIT",
  "keywords": ["governance", "workflow", "plan-first"],
  "hooks": "./hooks/hooks.json",
  "skills": "./skills/"
}
```

### Hook Format

Plugin hooks go in `hooks/hooks.json` (not `.claude/settings.json`). The format is the same JSON schema Claude Code uses for user hooks. Scripts must use `${CLAUDE_PLUGIN_ROOT}` to reference bundled files:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/my-hook.sh"
        }]
      }
    ]
  }
}
```

Supported hook types: `command`, `http`, `prompt`, `agent`.

### Installation Mechanism

Three paths to get a plugin installed:

1. **Local testing**: `claude --plugin-dir ./my-plugin`
2. **Marketplace install**: `/plugin install baton@marketplace-name` or `claude plugin install baton@marketplace-name`
3. **Official marketplace**: browsable via `/plugin` Discover tab, installed with `/plugin install baton@claude-plugins-official`

Installation scopes: `user` (default, `~/.claude/settings.json`), `project` (`.claude/settings.json`), `local` (`.claude/settings.local.json`), `managed` (org-level).

### Marketplace Distribution

A marketplace is a git repo with `.claude-plugin/marketplace.json`:

```json
{
  "name": "my-marketplace",
  "owner": { "name": "Author Name" },
  "plugins": [
    {
      "name": "baton",
      "source": "./plugins/baton",
      "description": "Plan-first governance workflow",
      "version": "1.0.0"
    }
  ]
}
```

Plugin sources can be: relative paths within the marketplace repo, GitHub repos (`owner/repo`), git URLs, git subdirectories, or npm packages.

### Official Anthropic Marketplace & Review Process

- Name: `claude-plugins-official`
- Auto-available to all Claude Code users
- Browsable at claude.com/plugins
- **Submission**: via in-app forms at `claude.ai/settings/plugins/submit` or `platform.claude.com/plugins/submit`
- No public documentation of the review criteria or timeline (verified: searched all plugin docs pages, no review process details beyond "submit via form")

## Baton's Current Structure

Baton's distribution model is fundamentally different from the plugin system. Here's what exists today (verified: read all files):

```
baton/                            # Git repo, cloned to ~/.baton/
├── .baton/
│   ├── constitution.md           # Always-loaded governance rules
│   ├── annotation-template.md
│   ├── hooks/
│   │   ├── dispatch.sh           # Event router, reads manifest.conf
│   │   ├── manifest.conf         # event:matcher:script mapping
│   │   ├── run-hook.cmd          # Cross-platform polyglot wrapper
│   │   ├── write-lock.sh         # PreToolUse hook
│   │   ├── bash-guard.sh         # PreToolUse hook
│   │   ├── post-write-tracker.sh # PostToolUse hook
│   │   ├── quality-gate.sh       # PostToolUse hook
│   │   ├── phase-guide.sh        # SessionStart hook
│   │   ├── stop-guard.sh         # Stop hook
│   │   ├── completion-check.sh   # TaskCompleted hook
│   │   ├── failure-tracker.sh    # PostToolUseFailure hook
│   │   ├── pre-compact.sh        # PreCompact hook
│   │   ├── subagent-context.sh   # SubagentStart hook
│   │   └── lib/
│   │       ├── common.sh
│   │       ├── junction.sh
│   │       └── plan-parser.sh
│   ├── skills/
│   │   ├── baton-plan/SKILL.md
│   │   ├── baton-implement/SKILL.md + review-prompt.md
│   │   ├── baton-research/SKILL.md + templates + review prompts
│   │   ├── baton-review/SKILL.md
│   │   ├── baton-debug/SKILL.md
│   │   ├── baton-subagent/SKILL.md
│   │   ├── baton-evolve/SKILL.md + review-prompt.md
│   │   └── using-baton/SKILL.md
│   └── adapters/
│       ├── cursor/adapter.sh + dispatch.sh
│       └── codex/adapter.sh + dispatch.sh
├── .claude/
│   ├── settings.json             # Hook registrations for Claude Code
│   └── skills/                   # Claude-native skills (deep-research, verify)
├── setup.sh                      # Per-project installer
├── install.sh                    # Global installer (curl | bash)
├── bin/baton                     # CLI entry point
└── CLAUDE.md                     # @.baton/constitution.md reference
```

### Current Distribution Flow

1. `install.sh` clones the repo to `~/.baton/`
2. `setup.sh` creates NTFS junctions from project `.baton/` to `~/.baton/.baton/`
3. `setup.sh` creates skill junctions from `.claude/skills/baton-*` to `.baton/skills/baton-*`
4. `setup.sh` generates/merges `.claude/settings.json` with hook registrations
5. `setup.sh` injects `@.baton/constitution.md` into `CLAUDE.md`
6. IDE-specific adapters handle Cursor and Codex

### Current Hook Architecture

Baton uses its own dispatch layer:
- `.claude/settings.json` registers all events to call `run-hook.cmd <EventName>`
- `run-hook.cmd` is a bash/cmd polyglot that delegates to `dispatch.sh`
- `dispatch.sh` reads `manifest.conf` and routes events to individual hook scripts
- Hook scripts communicate via `BATON_STDIN` (buffered stdin), exit codes (0=ok, 2=block)

## Gap Analysis: What Needs to Change

### 1. Directory Restructuring

| Current | Plugin Required | Change Needed |
|---------|----------------|---------------|
| `.baton/skills/baton-*/SKILL.md` | `skills/baton-*/SKILL.md` at plugin root | Move skills up one level |
| `.baton/hooks/*.sh` | `scripts/*.sh` (convention) | Move hook scripts, update paths |
| `.baton/hooks/manifest.conf` | Not used | Replaced by `hooks/hooks.json` |
| `.baton/hooks/dispatch.sh` | Not used directly | Dispatch layer needs redesign (see below) |
| `.baton/constitution.md` | Stays in plugin, referenced via `${CLAUDE_PLUGIN_ROOT}` | Path references change |
| `.claude/settings.json` | `hooks/hooks.json` | Hook format migration |
| No `.claude-plugin/` | `.claude-plugin/plugin.json` required | Create manifest |

Proposed plugin layout:

```
baton-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── baton-plan/SKILL.md
│   ├── baton-implement/SKILL.md + review-prompt.md
│   ├── baton-research/SKILL.md + templates
│   ├── baton-review/SKILL.md
│   ├── baton-debug/SKILL.md
│   ├── baton-subagent/SKILL.md
│   ├── baton-evolve/SKILL.md
│   └── using-baton/SKILL.md
├── hooks/
│   └── hooks.json
├── scripts/
│   ├── dispatch.sh
│   ├── write-lock.sh
│   ├── bash-guard.sh
│   ├── phase-guide.sh
│   ├── post-write-tracker.sh
│   ├── quality-gate.sh
│   ├── stop-guard.sh
│   ├── completion-check.sh
│   ├── failure-tracker.sh
│   ├── pre-compact.sh
│   ├── subagent-context.sh
│   └── lib/
│       ├── common.sh
│       ├── junction.sh
│       └── plan-parser.sh
├── constitution.md
├── annotation-template.md
└── LICENSE
```

### 2. Hook Registration Rewrite

**This is the biggest structural change.** Currently, baton registers one dispatch entry per event in `.claude/settings.json`, and its own `dispatch.sh` reads `manifest.conf` to fan out to individual scripts. The plugin system replaces this:

**Option A — Flatten into hooks.json (recommended):** Eliminate `dispatch.sh` and `manifest.conf`. Register each hook script directly in `hooks/hooks.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|CreateFile|NotebookEdit",
        "hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/write-lock.sh"}]
      },
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/bash-guard.sh"}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|CreateFile|NotebookEdit",
        "hooks": [
          {"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/post-write-tracker.sh"},
          {"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/quality-gate.sh"}
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/phase-guide.sh"}]
      }
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/stop-guard.sh"}]}
    ],
    "SubagentStart": [
      {"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/subagent-context.sh"}]}
    ],
    "TaskCompleted": [
      {"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/completion-check.sh"}]}
    ],
    "PostToolUseFailure": [
      {"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/failure-tracker.sh"}]}
    ],
    "PreCompact": [
      {"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/pre-compact.sh"}]}
    ]
  }
}
```

**Option B — Keep dispatch.sh:** Register a single dispatch entry per event in `hooks.json`, with `dispatch.sh` still reading `manifest.conf`. This preserves baton's internal extensibility but adds an indirection layer the plugin system doesn't need.

**Recommendation**: Option A. The plugin system already provides per-event, per-matcher registration — exactly what `dispatch.sh` + `manifest.conf` duplicate. Flattening removes a layer of complexity and makes debugging easier (`/hooks` shows each script individually). The manifest.conf-based extensibility only matters for baton's multi-IDE story (Cursor/Codex adapters), which becomes irrelevant in a Claude-Code-only plugin.

### 3. Hook Script Adaptation

Each hook script currently reads input from `$BATON_STDIN` (set by `dispatch.sh`). In the plugin model, hook scripts receive JSON on stdin directly from Claude Code. Changes needed:

- Remove `BATON_STDIN` references; read from stdin directly (or buffer in each script)
- Replace `BATON_PROJECT_DIR` with `$CLAUDE_PROJECT_DIR` (provided by Claude Code to hooks)
- Replace hardcoded `.baton/` paths with `${CLAUDE_PLUGIN_ROOT}/` paths
- The `run-hook.cmd` polyglot wrapper becomes unnecessary — Claude Code handles shell invocation

### 4. Constitution Loading

Currently, `CLAUDE.md` contains `@.baton/constitution.md` which Claude Code auto-loads. In the plugin model:

- **Option**: Use a `SessionStart` hook that outputs the constitution content as a `systemMessage` in the JSON response
- **Option**: Ship constitution.md as part of a skill or agent that gets auto-loaded
- **Option**: Include constitution.md content in the plugin's skills (e.g., in `using-baton/SKILL.md`) so it loads when the skill triggers

This is a design decision — the plugin system has no direct equivalent of `@file` include directives in CLAUDE.md. The SessionStart hook approach is closest to the current behavior.

### 5. Skill Namespacing

Plugin skills are namespaced: `/baton:baton-plan` instead of `/baton-plan`. This changes the user experience but is unavoidable. The skill names become slightly more verbose. Users would type `/baton:baton-plan` or the plugin name could be shortened (e.g., name the plugin `b` for `/b:plan` — though this is aggressive).

Alternative: name the plugin `baton` and rename skills to drop the `baton-` prefix internally, yielding `/baton:plan`, `/baton:implement`, `/baton:review`, etc.

### 6. Multi-IDE Support

The current adapters for Cursor and Codex (`adapters/cursor/`, `adapters/codex/`) would NOT be part of the Claude Code plugin. The plugin system is Claude Code-specific. Multi-IDE support would need to remain as a separate distribution path (the current setup.sh approach).

### 7. Junction Architecture

The junction-based distribution (one source, many projects via NTFS junctions) is replaced by the plugin cache system. Once installed as a plugin, Claude Code copies it to `~/.claude/plugins/cache/`. Updates happen via `/plugin update` or marketplace auto-update instead of `git pull` + junction refresh.

The `baton` CLI (`bin/baton`), `install.sh`, `setup.sh`, and the junction utility (`lib/junction.sh`) are all irrelevant in the plugin model. Plugin installation is handled entirely by Claude Code's plugin manager.

### 8. State & Data Persistence

Baton currently writes state files (tracker files, task artifacts) to the project directory. In the plugin model:
- Project-directory writes still work (plugins can write to the project)
- Plugin-specific persistent state can use `${CLAUDE_PLUGIN_DATA}` (survives updates)
- `baton-tasks/` directory creation in the project would continue as-is

## Distribution Path to the Official Marketplace

### Creating a Marketplace (Interim)

Before official marketplace acceptance, distribute via a custom marketplace:

1. Create a GitHub repo (e.g., `hex1n/baton-plugins`)
2. Add `.claude-plugin/marketplace.json` listing the baton plugin
3. Users add it: `/plugin marketplace add hex1n/baton-plugins`
4. Users install: `/plugin install baton@hex1n-baton-plugins`

### Official Marketplace Submission

Submit via:
- `claude.ai/settings/plugins/submit`
- `platform.claude.com/plugins/submit`

No public documentation exists on review criteria, approval timeline, or rejection reasons. The process is opaque from the outside (verified: searched all docs pages). Given that the official marketplace already hosts code intelligence, external integrations, and development workflow plugins, a governance/workflow plugin like baton should be within scope — but this is judgment, not evidence.

## Summary: Effort Estimate

| Work Item | Complexity | Notes |
|-----------|-----------|-------|
| Create plugin.json manifest | Trivial | New file, ~10 lines |
| Restructure directories | Small | Move skills/, scripts, constitution.md to plugin root |
| Rewrite hooks.json | Medium | Flatten manifest.conf into hooks.json, update all paths to use `${CLAUDE_PLUGIN_ROOT}` |
| Adapt hook scripts | Medium | Replace BATON_STDIN with direct stdin, BATON_PROJECT_DIR with CLAUDE_PROJECT_DIR, fix paths |
| Solve constitution loading | Small | SessionStart hook outputting systemMessage, or embed in a skill |
| Rename skills (drop `baton-` prefix) | Trivial | Optional UX improvement |
| Remove/separate multi-IDE code | Small | Adapters stay in the non-plugin distribution path |
| Remove junction/installer code from plugin | Trivial | These files just don't ship in the plugin |
| Test plugin locally | Small | `claude --plugin-dir ./baton-plugin` |
| Create marketplace repo | Trivial | New repo with marketplace.json |
| Submit to official marketplace | Unknown | Opaque process, no public timeline |

The core effort is in the hook system adaptation (items 3-4), which requires touching every hook script to change how they receive input and reference paths. The structural changes (items 1-2) are straightforward moves.

## Open Questions

1. **Constitution auto-loading**: How do other governance plugins handle always-loaded instruction content? The plugin system has no `@include` mechanism. A SessionStart hook returning a `systemMessage` is the most reliable approach, but the message doesn't persist across compaction the way CLAUDE.md content does. **This is the most significant gap** — CLAUDE.md `@file` references are compaction-resilient; hook-injected system messages may not be. (unverified: no documentation found on systemMessage persistence across compaction)

2. **Review process opacity**: No public information on what the official marketplace review evaluates. This means the submission could be rejected for unknown reasons. Shipping via a custom marketplace first (interim path) mitigates this risk.

3. **Dual distribution**: If baton needs to support both plugin-based distribution (Claude Code only) AND the current multi-IDE setup.sh approach (Claude + Cursor + Codex), the codebase would need to maintain two distribution paths. The plugin version could be generated from the source repo via a build/packaging script.

4. **Hook execution model differences**: Baton's dispatch.sh runs all matching hooks in sequence with exit code aggregation (first exit-2 wins). The plugin hooks.json registers each hook independently — Claude Code runs them, but the aggregation behavior may differ. Need to verify whether multiple hooks on the same event+matcher run sequentially and how exit codes compose. (unverified: plugin hook execution order not documented)

## 批注区
