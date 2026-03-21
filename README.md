# Baton

**AI assisted development shared understanding construction protocol.**

Inspired by [Boris Tane's approach](https://boristane.com/blog/how-i-use-claude-code/): read deeply, write a plan, annotate until it's right, then let AI execute.

Baton adds two things Boris can't do with words alone: **a code-level write lock** that prevents AI from writing source code until your plan is ready, and **a structured annotation protocol** that makes human-AI dialogue systematic and traceable.

## How It Works

```
research.md  →  plan.md  →  [annotation cycle]  →  <!-- BATON:GO -->  →  generate todolist  →  implement  →  finish
   (understand)    (propose)    (build shared understanding)   (approve)          (prepare)         (execute)     (verify/complete)
```

**Scenario A** (clear goal): research.md (or `research-<topic>.md`) → you state the requirement → plan.md (or `plan-<topic>.md`) → annotation cycle → BATON:GO → generate todolist → implement → finish

**Scenario B** (exploration): research.md (or `research-<topic>.md`) ← annotation cycle → plan.md (or `plan-<topic>.md`) ← annotation cycle → BATON:GO → generate todolist → implement → finish

Simple changes can skip research.md and go straight to plan.md.

### The Annotation Cycle

The annotation cycle is Baton's core mechanism. It applies to both research.md and plan.md (or their topic-named equivalents).

You can give feedback directly in the document or in chat. Free-text is the default.
`[PAUSE]` is the only explicit marker: it means stop the current direction and
investigate something else first.

For each piece of feedback:
- AI infers intent from the content instead of relying on a fixed type list
- AI answers with file:line evidence and records the result in an **Annotation Log**
- If the response changes direction or reveals a contradiction, AI updates the document immediately

**The human isn't always right.** When AI disagrees, it must explain with evidence, offer alternatives, and let the human decide. No blind compliance, no hiding concerns, no blocking decisions.

### The Write Lock

- **Blocks** source code writes when the plan doesn't exist or lacks `<!-- BATON:GO -->`
- **Allows** markdown files at all times — except AI cannot write `BATON:GO` or `BATON:OVERRIDE` markers (hook blocks these automatically)
- **Unlocks** when the plan contains the `BATON:GO` marker
- **Re-locks** if you remove the marker (e.g., to go back to annotation cycle)
- **Custom plan file**: `BATON_PLAN=plan-auth.md` — use a topic-named file (e.g. `plan-auth.md`, `plan-refactor.md`); also required when multiple plan files coexist so the write-lock knows which one to check
- **Bypass** for emergencies: `BATON_BYPASS=1` skips the lock entirely

**Governance layers:**
- **Constitution**: cross-phase invariants (evidence, permissions, state transitions) — always loaded
- **Skills**: phase-specific procedures (research / plan / implement / review) — loaded on-demand
- **Hooks**: mechanical enforcement (write-lock, bash-guard, completion-check) — block violations at write time

## Install

**Prerequisites**: `git` and `bash`. Windows users need [Git Bash](https://git-scm.com/downloads).

### Remote install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/hex1n/baton/master/install.sh | bash
```

This clones baton to `~/.baton`, creates skill symlinks in `~/.claude/skills/`, merges hook entries into `~/.claude/settings.json`, and adds the constitution reference to `~/.claude/CLAUDE.md`. One install covers all projects — no per-project setup needed.

### Local install

```bash
bash /path/to/baton/setup.sh
```

**Upgrade**: Run `setup.sh` again — it detects existing configuration and merges cleanly.

**Migrate from v4**: If you have existing v4 junction-based projects:
```bash
bash ~/.baton/setup.sh --migrate /path/to/project
```

## Update

```bash
baton update           # Pull latest baton source + re-run setup
```

Since `~/.claude/skills/` contains symlinks to `~/.baton/skills/`, updating baton is just `git pull` — changes are instantly visible to all projects.

## Testing

```bash
# Fast local confidence check:
bash tests/test-smoke.sh

# Broad regression run:
bash tests/test-full.sh
```

`tests/test-smoke.sh` is the recommended default for routine local runs. It
keeps the lighter hook- and protocol-focused checks while leaving the heavier
integration suites out of the fast path.

`tests/test-full.sh` runs the broader suite, including `test-setup.sh`,
`test-multi-ide.sh`, `test-cli.sh`, and the opt-in write-lock benchmark.

On Windows, prefer running the test scripts from Git Bash or WSL. For routine
local feedback, start with `bash tests/test-smoke.sh`; use
`bash tests/test-full.sh` when you want the heavier integration coverage.

## What Gets Installed

Baton v5 uses a **user-level flat install** — zero files in your project directory. Everything lives in `~/.claude/` and `~/.baton/`:

```
~/.baton/                              # Baton source (git clone)
├── skills/                            # Skill definitions
│   ├── baton-research/
│   ├── baton-plan/
│   ├── baton-implement/
│   ├── baton-review/
│   ├── baton-debug/
│   ├── baton-subagent/
│   └── using-baton/
├── hooks/                            # Hook scripts
│   ├── dispatch.sh                    (event-based hook dispatcher)
│   ├── manifest.conf                  (hook-to-event mapping)
│   ├── run-hook.cmd                   (cross-platform entry point)
│   └── *.sh                           (write-lock, phase-guide, etc.)
├── constitution.md                    # Cross-phase invariants
├── setup.sh                           # User-level installer
└── .baton/                            # v4 compat layer (symlinks)

~/.claude/                             # After setup
├── CLAUDE.md                          # @../.baton/constitution.md
├── settings.json                      # Baton hook entries (absolute paths)
└── skills/
    ├── baton-research/ → symlink      # → ~/.baton/skills/baton-research/
    ├── baton-plan/ → symlink
    └── ...
```

All hook routing goes through `dispatch.sh`, which reads `manifest.conf` to determine which hooks fire for each event. Since `~/.claude/skills/` contains symlinks, changes to `~/.baton/skills/` are instantly visible.

**Zero project footprint**: your project directories have no baton files — no `.baton/`, no skill junctions, no settings entries. `git clean -fdX` is safe.

## Suggested .gitignore

```
baton-tasks/
plan.md
plan-*.md
research.md
research-*.md
plans/
```

Some teams prefer to keep these for audit trails — it's up to you.

## Uninstall

```bash
bash ~/.baton/setup.sh --uninstall
```

This removes skill symlinks from `~/.claude/skills/`, hook entries from `~/.claude/settings.json`, and the constitution reference from `~/.claude/CLAUDE.md`. The `~/.baton/` directory is preserved — delete it manually if desired.

## Philosophy

Boris Tane's workflow succeeds because the human stays in the loop at every critical point. Baton preserves that:

- **Governance wrapper, not capability provider** — baton governs output and process, not tool choice. Use any AI skill; output must comply with constitution.md
- **File-derived phase detection** — your current phase is determined by file state (plan existence, BATON:GO marker, todo completion), not stored anywhere
- **Minimal CLI** — `baton update`, then just files and symlinks
- **Minimal overhead** — always-loaded rules + skills loaded on-demand per phase
- **Zero project footprint** — nothing in your project directory; jq needed once at install
- **Annotation protocol** — structured human-AI dialogue with traceable decision records

The only things automated are the things humans can't reliably enforce with words: preventing AI from writing code before the plan is approved, blocking AI from placing governance markers, and ensuring every annotation gets a response.

## License

MIT
