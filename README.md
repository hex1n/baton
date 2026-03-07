# Baton

**AI assisted development shared understanding construction protocol.**

Inspired by [Boris Tane's approach](https://boristane.com/blog/how-i-use-claude-code/): read deeply, write a plan, annotate until it's right, then let AI execute.

Baton adds two things Boris can't do with words alone: **a code-level write lock** that prevents AI from writing source code until your plan is ready, and **a structured annotation protocol** that makes human-AI dialogue systematic and traceable.

## How It Works

```
research.md  →  plan.md  →  [annotation cycle]  →  <!-- BATON:GO -->  →  implement
   (understand)    (propose)    (build shared understanding)   (approve)      (execute)
```

**Scenario A** (clear goal): research.md → you state the requirement → plan.md → annotation cycle → generate todo → BATON:GO → implement

**Scenario B** (exploration): research.md ← annotation cycle → plan.md ← annotation cycle → generate todo → BATON:GO → implement

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
```

Setup auto-detects your IDE and installs the right configuration.

**Upgrade**: Run setup.sh again — it detects the installed version and updates only what changed.

## What Gets Installed

```
your-project/
├── .baton/
│   ├── workflow.md         ← Universal rules (~400 tokens)
│   ├── workflow-full.md    ← Full reference (fallback when skills unavailable)
│   ├── write-lock.sh       ← Write lock (~100 lines)
│   ├── phase-guide.sh      ← Session start: detects phase, prompts skill or extracts fallback
│   ├── stop-guard.sh       ← Stop hook: progress/archival reminder
│   ├── bash-guard.sh       ← Advisory bash detection
│   └── adapters/           ← Cross-IDE adapters (Cline, Windsurf)
├── .claude/
│   ├── skills/              ← Phase methodology (baton-research, baton-plan, baton-implement)
│   └── settings.json        ← Hook configuration
└── CLAUDE.md                ← @.baton/workflow.md import
```

## Supported IDEs

| IDE | Protection Level | What You Get | Setup |
|-----|-----------------|--------------|-------|
| Claude Code | **Full protection** | Write-lock + phase guidance + stop guard | Automatic |
| Factory AI | **Full protection** | Write-lock + phase guidance + stop guard | Automatic |
| Cursor | **Full protection** | Write-lock (via adapter) + phase guidance + subagent context | Automatic |
| Windsurf | **Full protection** | Write-lock (native hooks) + phase guidance + bash guard | Automatic |
| Augment | **Full protection** | Write-lock + phase guidance | Automatic |
| Amazon Q / Kiro | **Hook protection** | Write-lock only (preToolUse); phase guidance via rules | Automatic |
| Copilot | **Full protection** | Write-lock (via adapter) + phase guidance | Automatic |
| Cline | Hook protection | Write-lock (PreToolUse) + task completion check | Automatic |
| Roo Code | Rules guidance | Workflow rules injected via .roo/rules/ | Automatic |
| Codex | Rules guidance | Workflow via AGENTS.md (no hooks) | Automatic |
| Zed | Rules guidance | Workflow via .rules (no hooks) | Automatic |

> **Full protection** = technical enforcement via hooks. AI physically cannot write source code without plan approval.
> **Hook protection** = write-lock via IDE-specific hook wiring, but not all hook types supported.
> **Rules guidance** = workflow rules loaded into AI context. AI follows the plan-first flow but is not technically blocked.

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

Or manually: delete `.baton/`, remove baton-* skill directories from each IDE's skills folder, and remove the `@.baton/workflow.md` line from `CLAUDE.md`. Note: `setup.sh --uninstall` cleans rules files and skills automatically, but hook config files (`.claude/settings.json`, `.cursor/hooks.json`, `.augment/settings.json`, `.amazonq/hooks.json`) require manual review — the script warns about these.

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