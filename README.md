# Baton

**AI assisted development shared understanding construction protocol.**

Inspired by [Boris Tane's approach](https://boristane.com/blog/how-i-use-claude-code/): read deeply, write a plan, annotate until it's right, then let AI execute.

Baton adds two things Boris can't do with words alone: **a code-level write lock** that prevents AI from writing source code until your plan is ready, and **a structured annotation protocol** that makes human-AI dialogue systematic and traceable.

## How It Works

```
research.md  →  plan.md  →  [annotation cycle]  →  <!-- BATON:GO -->  →  generate todolist  →  implement
   (understand)    (propose)    (build shared understanding)   (approve)          (prepare)         (execute)
```

**Scenario A** (clear goal): research.md → you state the requirement → plan.md → annotation cycle → BATON:GO → generate todolist → implement

**Scenario B** (exploration): research.md ← annotation cycle → plan.md ← annotation cycle → BATON:GO → generate todolist → implement

Simple changes can skip research.md and go straight to plan.md.

### The Annotation Cycle

The annotation cycle is Baton's core mechanism. It applies to both research.md and plan.md.

You can give feedback directly in the document or in chat. Free-text is the default.
`[PAUSE]` is the only explicit marker: it means stop the current direction and
investigate something else first.

For each piece of feedback:
- AI infers intent from the content instead of relying on a fixed type list
- AI answers with file:line evidence and records the result in an **Annotation Log**
- If the response changes direction or reveals a contradiction, AI updates the document immediately

**The human isn't always right.** When AI disagrees, it must explain with evidence, offer alternatives, and let the human decide. No blind compliance, no hiding concerns, no blocking decisions.

### The Write Lock

- **Blocks** source code writes when `plan.md` doesn't exist or lacks `<!-- BATON:GO -->`
- **Allows** markdown files (*.md, *.mdx, *.markdown) at all times — research and planning are never blocked
- **Unlocks** when `plan.md` contains `<!-- BATON:GO -->` anywhere in the file
- **Re-locks** if you remove `<!-- BATON:GO -->` (e.g., to go back to annotation cycle)
- **Custom plan file**: `BATON_PLAN=design.md` to use a different plan file name
- **Bypass** for emergencies: `BATON_BYPASS=1` skips the lock entirely
- **If AI adds `<!-- BATON:GO -->` itself**: remove it immediately, return to annotation phase

**Three layers of guidance:**
- **Layer 0**: Workflow rules always in context (~400 tokens)
- **Layer 1**: Phase-specific skills (baton-research / baton-plan / baton-implement) with fallback to session-start hook extraction
- **Layer 2**: Actionable blocking messages when writes are denied

## Install

**Prerequisites**: `git` and `bash`. Windows users need [Git Bash](https://git-scm.com/downloads).

### Remote install (recommended)

```bash
# Run from your project directory — installs baton globally and initializes the current project in one step:
cd /path/to/project
curl -fsSL https://raw.githubusercontent.com/hex1n/baton/master/install.sh | bash

# Install for specific IDEs:
curl -fsSL https://raw.githubusercontent.com/hex1n/baton/master/install.sh | bash -s -- --ide codex
curl -fsSL https://raw.githubusercontent.com/hex1n/baton/master/install.sh | bash -s -- --ide cursor,codex
```

This installs the `baton` CLI to `~/.baton` (sparse clone, only essential files) and automatically runs `baton init` in the current directory. Pass `--ide` to select specific IDEs instead of auto-detection.

### Local install

```bash
# In any project:
bash /path/to/baton/setup.sh

# Or specify a target:
bash /path/to/baton/setup.sh /path/to/your/project

# Install only to selected IDEs:
bash /path/to/baton/setup.sh --ide cursor,codex /path/to/your/project

# Or choose interactively:
bash /path/to/baton/setup.sh --choose /path/to/your/project

# If you're bootstrapping a Codex project outside a Codex session:
bash /path/to/baton/setup.sh --ide codex /path/to/your/project
```

In an interactive terminal, `setup.sh` now prompts you to choose which IDEs to
configure. In non-interactive usage, it falls back to auto-detect. If you pass
`--ide`, Baton installs only to the IDEs you selected. If you pass `--choose`,
it forces the interactive selector. In Codex sessions, Baton detects Codex
automatically and creates `AGENTS.md` on first install. Outside a Codex
session, use `--ide codex` to bootstrap the Codex files explicitly.

The interactive selector shows a short capability summary for each IDE and
accepts IDE names or numeric shortcuts such as `1,3,4` or `134`.

**Upgrade**: Run setup.sh again — it detects the installed version and updates only what changed.

## Update

```bash
baton self-update      # Pull latest baton source to ~/.baton
baton update           # Update current project's baton scripts
baton update --all     # Update all registered projects
```

`self-update` runs `git pull` in `~/.baton`. `update` re-runs setup.sh, which compares script versions and only copies what changed.

## What Gets Installed

Depending on the IDEs detected or selected, Baton installs the relevant subset of:

```
your-project/
├── .baton/
│   ├── workflow.md         ← Universal rules (~400 tokens)
│   ├── workflow-full.md    ← Full reference (fallback for rules-only IDEs / missing skills)
│   ├── write-lock.sh       ← Write lock (~100 lines)
│   ├── phase-guide.sh      ← Session start: detects phase, prompts skill or extracts fallback
│   ├── stop-guard.sh       ← Stop hook: progress/archival reminder
│   ├── bash-guard.sh       ← Advisory bash detection
│   └── adapters/           ← Cross-IDE adapters (Cursor, Codex)
├── .claude/
│   ├── skills/              ← Phase methodology (baton-research, baton-plan, baton-implement)
│   └── settings.json        ← Hook configuration
├── CLAUDE.md                ← Claude import: @.baton/workflow.md
├── AGENTS.md                ← Generated for Codex installs: @.baton/workflow.md
└── .agents/skills/          ← Generated Codex fallback skills
```

## Supported IDEs

| IDE | Protection Level | What You Get | Setup |
|-----|-----------------|--------------|-------|
| Claude Code | **Full protection** | Write-lock + phase guidance + stop guard + 8 hooks | Automatic |
| Factory AI | **Full protection** | Write-lock + phase guidance + stop guard (Claude-style) | Automatic |
| Cursor IDE | **Full protection** | Write-lock (via adapter) + phase guidance + subagent context | Automatic |
| Codex | Rules guidance | Experimental `SessionStart` + `Stop` hooks (best-effort) + generated `AGENTS.md` + generated `.agents/skills/`; no write-lock | Automatic (detects `AGENTS.md`, `.agents/` dir, or Codex env), or `--ide codex` |

> **Full protection** = technical enforcement via hooks. AI physically cannot write source code without plan approval.
> **Rules guidance** = workflow rules loaded into AI context. AI follows the plan-first flow but is not technically blocked.
>
> **Codex note**: Baton uses experimental `SessionStart`/`Stop` hooks in Codex for phase guidance and stop reminders, plus `AGENTS.md` rules and `.agents/skills/`. These hooks are advisory only: Codex still has **no PreToolUse write-lock** or plan-unlisted write enforcement. For full hard-gated protection, use Claude Code, Factory AI, or Cursor.

## Suggested .gitignore

```
plan.md
research.md
plans/
```

Some teams prefer to keep these for audit trails — it's up to you.

## Uninstall

```bash
bash /path/to/baton/setup.sh --uninstall /path/to/your/project
```

Or manually: delete `.baton/`, remove baton-* skill directories from each IDE's skills folder, and remove baton workflow imports from rules files such as `CLAUDE.md`, `AGENTS.md`, `.rules`, or IDE-specific rules directories. `setup.sh --uninstall` now removes Baton-owned JSON hook entries by exact command match while preserving unrelated settings; legacy Baton commands such as `sh .claude/write-lock.sh` are included in that cleanup. If a config file is invalid JSON, `jq` is unavailable, or any config still references `.baton/` after cleanup, Baton leaves `.baton/` in place and warns for manual review. In self-install mode, Baton also preserves the repository's source `.baton/` and `.claude/skills/` directories.

## Philosophy

Boris Tane's workflow succeeds because the human stays in the loop at every critical point. Baton preserves that:

- **File-derived phase detection** — your current phase is determined by file state (plan existence, BATON:GO marker, todo completion), not stored anywhere
- **Minimal CLI** — `baton init` / `baton update`, then just files and hooks
- **~400 tokens total overhead** — always-loaded rules + skills loaded on-demand per phase
- **Zero dependencies** — jq optional (falls back to awk), no Python, no Node.js
- **Annotation protocol** — structured human-AI dialogue with traceable decision records

The only things automated are the things humans can't reliably enforce with words: preventing AI from writing code before the plan is approved, and ensuring every annotation gets a response.

## License

MIT
