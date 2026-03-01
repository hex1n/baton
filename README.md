# Baton

**Minimal plan-first workflow enforcer for AI-assisted development.**

Inspired by [Boris Tane's approach](https://boristane.com/blog/how-i-use-claude-code/): read deeply, write a plan, annotate until it's right, then let AI execute.

Baton adds one thing Boris can't do with words alone: **a code-level write lock** that prevents AI from writing source code until your plan is ready.

## How It Works

```
research.md  →  plan.md  →  [annotate]  →  <!-- BATON:GO -->  →  implement
   (read)        (design)    (human review)    (unlock)      (execute)
```

1. AI reads code deeply, writes `research.md`
2. AI writes `plan.md` with file changes and code snippets
3. You annotate `plan.md` in your editor — AI addresses notes, repeats
4. You add `<!-- BATON:GO -->` to `plan.md` — source code writes unlock
5. AI implements the plan, checks off items, runs tests

### The Annotation Cycle

Step 3 above — "annotate" — is where Baton differs from other plan-first tools. It's not a one-time review. It's a **loop enforced by the write-lock**:

```
AI implements login feature
  → needs middleware/auth.ts (not in plan)
  → 🔒 write-lock blocks the write
  → AI updates plan.md: "need auth.ts for session validation"
  → You review, add file to plan scope
  → AI continues → hits another unplanned file
  → 🔒 blocked again → cycle repeats
```

Every unplanned file change triggers a human review. The AI can't skip this — the lock is physical, not advisory. This means you understand the *reason* behind every source file modification, not just the diff.

**Three layers of guidance:**
- **Layer 0**: Minimal workflow rules always in context (~250 tokens)
- **Layer 1**: Phase-specific guidance injected at session start (~100 tokens)
- **Layer 2**: Actionable blocking messages when writes are denied

## Install

```bash
# In any project:
bash /path/to/baton/setup.sh

# Or specify a target:
bash /path/to/baton/setup.sh /path/to/your/project
```

Setup auto-detects your IDE and installs the right configuration.

**Upgrade**: Run setup.sh again — it detects the installed version and updates only what changed. v1 installations are migrated automatically.

## What Gets Installed

```
your-project/
├── .baton/
│   ├── workflow.md         ← Universal rules (~250 tokens)
│   ├── workflow-full.md    ← Full fallback (for reference)
│   ├── write-lock.sh       ← Write lock (~100 lines)
│   ├── phase-guide.sh      ← Session start guidance (~67 lines)
│   ├── stop-guard.sh       ← Stop hook: TODO reminder (~37 lines)
│   ├── bash-guard.sh       ← Advisory bash detection (~33 lines)
│   └── adapters/           ← Cross-IDE adapters (Cline, Windsurf)
├── .claude/
│   └── settings.json       ← Hook configuration
└── CLAUDE.md               ← @.baton/workflow.md import
```

## The Write Lock

- **Blocks** source code writes when `plan.md` doesn't exist or lacks `<!-- BATON:GO -->`
- **Allows** markdown files (*.md, *.mdx) at all times — research and planning are never blocked
- **Unlocks** when `plan.md` contains `<!-- BATON:GO -->` anywhere in the file
- **Re-locks** if you remove `<!-- BATON:GO -->` (e.g., to go back to planning)
- **Custom plan file**: `BATON_PLAN=design.md` to use a different plan file name
- **Bypass** for emergencies: `BATON_BYPASS=1` skips the lock entirely
- **If AI adds `<!-- BATON:GO -->` itself**: remove it immediately, return to annotation phase

## Supported IDEs

| IDE | Protection Level | What You Get | Setup |
|-----|-----------------|--------------|-------|
| Claude Code | **Full protection** | Write-lock + phase guidance + stop guard | Automatic |
| Factory AI | **Full protection** | Write-lock + phase guidance + stop guard | Automatic |
| Cursor | Rules guidance | Workflow rules via .mdc (hook needs manual config for write-lock) | Automatic |
| Windsurf | Rules guidance | Workflow rules injected, AI follows voluntarily | Automatic |
| Cline | Rules guidance | Workflow rules injected, adapter available for manual hook setup | Automatic |
| OpenCode | Plugin protection | JS plugin provides write-lock (no phase guidance) | Manual |

> **Full protection** = technical enforcement via hooks. AI physically cannot write source code without plan approval.
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

Or manually: delete the `.baton/` directory and remove the `@.baton/workflow.md` line from your `CLAUDE.md`.

## Philosophy

Boris Tane's workflow succeeds because the human stays in the loop at every critical point. Baton preserves that:

- **No state machine** — you know what phase you're in
- **No CLI commands** — just files and hooks
- **~350 tokens total overhead** — 250 always-loaded + ~100 dynamic at session start
- **Zero dependencies** — jq optional (falls back to awk), no Python, no Node.js

The only thing automated is the one thing humans can't reliably enforce with words: preventing AI from writing code before the plan is approved.

## License

MIT
