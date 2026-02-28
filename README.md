# Baton

**Minimal plan-first workflow for AI-assisted development.**

Inspired by [Boris Tane's approach](https://boristane.com/blog/how-i-use-claude-code/): read deeply, write a plan, annotate until it's right, then let AI execute.

Baton adds one thing Boris can't do with words alone: **a code-level write lock** that prevents AI from writing source code until your plan is ready.

## How It Works

```
research.md  →  plan.md  →  [annotate]  →  <!-- GO -->  →  implement
   (read)        (design)    (human review)    (unlock)      (execute)
```

1. AI reads code deeply, writes `research.md`
2. AI writes `plan.md` with file changes and code snippets
3. You annotate `plan.md` in your editor — AI addresses notes, repeats
4. You add `<!-- GO -->` to `plan.md` — source code writes unlock
5. AI implements the plan, checks off items, runs tests

**The write lock is the only enforcement.** Everything else is guidance in your CLAUDE.md.

## Install

```bash
# In any project:
bash /path/to/baton/setup.sh

# Or specify a target:
bash /path/to/baton/setup.sh /path/to/your/project
```

This copies `write-lock.sh` into your project and adds workflow instructions to your `CLAUDE.md`.

## What Gets Installed

```
your-project/
├── .claude/
│   ├── settings.json      ← Hook configuration
│   └── write-lock.sh      ← The write lock (~60 lines)
└── CLAUDE.md              ← Workflow instructions appended (~30 lines)
```

## The Write Lock

- **Blocks** source code writes when `plan.md` doesn't exist or lacks `<!-- GO -->`
- **Allows** markdown files (*.md) at all times — research and planning are never blocked
- **Unlocks** when `plan.md` contains `<!-- GO -->` anywhere in the file
- **Re-locks** if you remove `<!-- GO -->` (e.g., to go back to planning)
- **Bypass** for emergencies: `BATON_BYPASS=1` environment variable skips the lock entirely
- **If AI adds `<!-- GO -->` itself**: remove it immediately, return to annotation phase

## Uninstall

Delete `.claude/write-lock.sh` and remove the `## AI Workflow` section from your `CLAUDE.md`.

## Philosophy

Boris Tane's workflow succeeds because the human stays in the loop at every critical point. Baton preserves that:

- **No state machine** — you know what phase you're in
- **No CLI commands** — just files and a hook
- **No skill files** — workflow instructions live in CLAUDE.md, always in context
- **~1,000 tokens overhead** — versus ~26,000 for a full skill system

The only thing automated is the one thing humans can't reliably enforce with words: preventing AI from writing code before the plan is approved.

## License

MIT
