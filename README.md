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

You annotate documents directly with structured markers:

| Marker | Meaning | AI Response |
|--------|---------|-------------|
| `[NOTE]` | Additional context | Incorporate, explain impact |
| `[Q]` | Question | Answer with file:line evidence |
| `[CHANGE]` | Request modification | If problematic, explain with evidence + offer alternatives |
| `[DEEPER]` | Not deep enough | Continue investigation in specified direction |
| `[MISSING]` | Something was missed | Investigate and supplement |
| `[RESEARCH-GAP]` | Needs more research | Pause, research, then return |

**The human isn't always right.** When AI disagrees, it must explain with evidence, offer alternatives, and let the human decide. No blind compliance, no hiding concerns, no blocking decisions.

Every annotation and response is recorded in an **Annotation Log** — creating a traceable record of design decisions.

### The Write Lock

- **Blocks** source code writes when `plan.md` doesn't exist or lacks `<!-- BATON:GO -->`
- **Allows** markdown files (*.md, *.mdx) at all times — research and planning are never blocked
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
│   └── adapters/           ← Cross-IDE adapters (Cline, Windsurf)
├── .agents/
│   └── skills/             ← Cross-IDE skill fallback (Codex uses this)
├── .claude/
│   ├── skills/              ← Phase methodology (baton-research, baton-plan, baton-implement)
│   └── settings.json        ← Hook configuration
├── AGENTS.md                ← Codex import: @.baton/workflow.md
└── CLAUDE.md                ← @.baton/workflow.md import
```

## Supported IDEs

| IDE | Protection Level | What You Get | Setup |
|-----|-----------------|--------------|-------|
| Claude Code | **Full protection** | Write-lock + phase guidance + stop guard | Automatic |
| Factory AI | **Full protection** | Write-lock + phase guidance + stop guard | Automatic |
| Cursor IDE | **Full protection** | Write-lock (via adapter) + phase guidance + subagent context | Automatic |
| Windsurf | **Full protection** | Write-lock (native hooks) + phase guidance + bash guard + skills | Automatic |
| Augment | **Full protection** | Write-lock + phase guidance | Automatic |
| Kiro (`.amazonq` surface) | **Hook protection** | Write-lock only (current Baton integration) + phase guidance via workflow.md + skills | Automatic |
| Copilot | **Full protection** | Write-lock (via adapter) + phase guidance + skills | Automatic |
| Cline | Hook protection | Write-lock (PreToolUse) + task completion check + skills | Automatic |
| Roo Code | Rules guidance | Workflow via .roo/rules/ + skills | Automatic |
| Codex | Rules guidance | Workflow via AGENTS.md + .agents/skills/ (no hooks) | Automatic in Codex session, or `--ide codex` |
| Zed | Rules guidance | Workflow via .rules using workflow-full fallback (no hooks, no skills) | Automatic |

> **Full protection** = technical enforcement via hooks. AI physically cannot write source code without plan approval.
> **Hook protection** = write-lock via IDE-specific hook wiring, but not all hook types supported.
> **Rules guidance** = workflow rules loaded into AI context. AI follows the plan-first flow but is not technically blocked.
> Skill-capable IDEs use `workflow.md` as the always-loaded entrypoint and keep detailed phase methodology in skills. `workflow-full.md` is reserved for rules-only fallback paths such as Zed.
> Baton's `cursor` target maps to the Cursor IDE integration surface. Cursor CLI hook parity is still partial and is not modeled separately here.
> Baton's `kiro` target currently writes to `.amazonq/`. Official Kiro and Amazon Q Developer CLI both support hooks, but their hook models now differ and Baton does not yet split them into separate installer targets.
> Roo Code remains rules-guidance by default because Baton does not yet rely on a current official Roo hook integration.
> Current implementation scope: Baton's current installer work covers Cursor IDE and the current Kiro `.amazonq` compatibility surface. This iteration does not add a first-class Amazon Q Developer CLI target, does not model Cursor CLI separately, and keeps Roo Code in rules-guidance mode.

See also:

- [IDE Capability Matrix](/Users/hex1n/IdeaProjects/baton/docs/ide-capability-matrix.md)
- [Hook Research 2026-03-07](/Users/hex1n/IdeaProjects/baton/research-ide-hooks-2026-03-07.md)

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

- **No state machine** — you know what phase you're in
- **No CLI commands** — just files and hooks
- **~400 tokens total overhead** — always-loaded rules + skills loaded on-demand per phase
- **Zero dependencies** — jq optional (falls back to awk), no Python, no Node.js
- **Annotation protocol** — structured human-AI dialogue with traceable decision records

The only things automated are the things humans can't reliably enforce with words: preventing AI from writing code before the plan is approved, and ensuring every annotation gets a response.

## License

MIT
