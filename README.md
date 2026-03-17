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
# Run from your project directory — installs baton globally and initializes the current project in one step:
cd /path/to/project
curl -fsSL https://raw.githubusercontent.com/hex1n/baton/master/install.sh | bash

# Install for specific IDEs:
curl -fsSL https://raw.githubusercontent.com/hex1n/baton/master/install.sh | bash -s -- --ide codex
curl -fsSL https://raw.githubusercontent.com/hex1n/baton/master/install.sh | bash -s -- --ide cursor,codex
```

This installs the `baton` CLI to `~/.baton` and automatically runs `baton init` in the current directory. Projects reference `~/.baton` via NTFS junctions (Windows) or symlinks (Unix), so updates propagate instantly without per-project copying. Pass `--ide` to select specific IDEs instead of auto-detection.

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

**Upgrade**: Run setup.sh again — it detects existing configuration and merges cleanly.

## Update

```bash
baton update           # Pull latest baton source — all projects see changes instantly
baton update --check   # Verify junction health across registered projects
```

Since projects reference `~/.baton` via junctions (not copies), `baton update` is just `git pull` — one command updates all projects simultaneously. No need for per-project updates.

For projects in copy-mode (junction unavailable), `baton update` automatically detects the `.copy-mode` marker and re-copies.

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

Projects reference `~/.baton` via junctions — no hook scripts are copied. The project footprint is minimal:

```
your-project/
├── .baton/                       ← Junction → ~/.baton/.baton/ (single source)
│   ├── constitution.md              (cross-phase invariants, always loaded)
│   ├── hooks/
│   │   ├── dispatch.sh              (event-based hook dispatcher)
│   │   ├── manifest.conf            (hook-to-event mapping)
│   │   ├── dispatch-cursor.sh       (Cursor adapter: exit code → JSON)
│   │   ├── dispatch-codex.sh        (Codex adapter: stdout passthrough)
│   │   ├── junction.sh              (shared junction/symlink/copy utility)
│   │   ├── write-lock.sh            (PreToolUse, hard block)
│   │   ├── phase-guide.sh           (SessionStart, phase detection + skills)
│   │   ├── bash-guard.sh            (PreToolUse, shell write blocking)
│   │   ├── post-write-tracker.sh    (PostToolUse, write-set drift)
│   │   ├── quality-gate.sh          (PostToolUse, plan compliance)
│   │   ├── stop-guard.sh            (Stop, progress reminder)
│   │   ├── subagent-context.sh      (SubagentStart, plan injection)
│   │   ├── completion-check.sh      (TaskCompleted, retrospective gate)
│   │   ├── pre-compact.sh           (PreCompact, context summary)
│   │   └── failure-tracker.sh       (PostToolUseFailure, failure counter)
│   └── skills/                      (baton-research, baton-plan, etc.)
├── .claude/
│   ├── skills/baton-*/           ← Junctions → .baton/skills/baton-*
│   └── settings.json            ← Generated: dispatch.sh entries per event
├── .cursor/                      (if Cursor detected)
│   ├── hooks.json               ← Generated: dispatch-cursor.sh entries
│   ├── rules/baton.mdc          ← Constitution embed
│   └── skills/baton-*/          ← Junctions
├── .codex/                       (if Codex detected)
│   ├── hooks.json               ← SessionStart + Stop via dispatch-codex.sh
│   └── config.toml              ← codex_hooks feature flag
├── CLAUDE.md                    ← @.baton/constitution.md
├── AGENTS.md                    ← @.baton/constitution.md (Codex)
└── .agents/skills/baton-*/      ← Junctions (fallback for all IDEs)
```

All hook routing goes through `dispatch.sh`, which reads `manifest.conf` to determine which hooks fire for each event. New hooks only need a manifest line + script file — `baton update` propagates instantly via junctions.

## Supported IDEs

| IDE | Protection Level | Events | Setup |
|-----|-----------------|--------|-------|
| Claude Code | **Full protection** | 8 events via dispatch.sh (PreToolUse, PostToolUse, SessionStart, Stop, PreCompact, SubagentStart, TaskCompleted, PostToolUseFailure) | Automatic |
| Factory AI | **Full protection** | Same as Claude Code (shares `.claude/settings.json`) | Automatic |
| Cursor IDE | **Core protection** | 6 events via dispatch-cursor.sh (preToolUse, postToolUse, sessionStart, stop, subagentStart, preCompact) | Automatic |
| Codex | **Rules + hooks** | 2 events via dispatch-codex.sh (SessionStart, Stop) + AGENTS.md rules | Automatic or `--ide codex` |

> **Full protection** = technical enforcement via hooks. AI physically cannot write source code without plan approval.
> **Core protection** = hard write-lock plus a reduced hook set via Cursor's JSON response protocol.
> **Rules + hooks** = `AGENTS.md` rules + experimental SessionStart/Stop hooks. No PreToolUse write-lock.
>
> All IDEs share the same dispatch architecture: `dispatch.sh` reads `manifest.conf` for hook routing, IDE-specific adapters (`dispatch-cursor.sh`, `dispatch-codex.sh`) translate the protocol. Adding a hook to one IDE automatically makes it available to all IDEs that support the corresponding event type.

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
bash /path/to/baton/setup.sh --uninstall /path/to/your/project
```

This removes junctions, hook entries from all IDE config files, rules files, constitution references, and Codex feature flags. Requires `jq` for clean JSON removal; without `jq`, manual cleanup of settings.json may be needed.

## Philosophy

Boris Tane's workflow succeeds because the human stays in the loop at every critical point. Baton preserves that:

- **Governance wrapper, not capability provider** — baton governs output and process, not tool choice. Use any AI skill; output must comply with constitution.md
- **File-derived phase detection** — your current phase is determined by file state (plan existence, BATON:GO marker, todo completion), not stored anywhere
- **Minimal CLI** — `baton init` / `baton update`, then just files and junctions
- **Minimal overhead** — always-loaded rules + skills loaded on-demand per phase
- **Zero dependencies** — jq optional (falls back to awk), no Python, no Node.js
- **Annotation protocol** — structured human-AI dialogue with traceable decision records

The only things automated are the things humans can't reliably enforce with words: preventing AI from writing code before the plan is approved, blocking AI from placing governance markers, and ensuring every annotation gets a response.

## License

MIT
