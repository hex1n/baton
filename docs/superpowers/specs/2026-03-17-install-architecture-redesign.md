# Baton Install Architecture Redesign

## Problem

The current installation architecture has three layers of state:
`origin` -> `~/.baton` (sparse clone) -> `project/.baton` (copy/symlink).
Each layer is a potential stale cache. `baton init` and `baton update` do not
pull from origin, so projects silently fall behind. The `setup.sh` script is
~1400 lines of migration, version-checking, and fallback logic.

## Design Principles

1. **Single source of truth** -- one copy of baton on disk, projects reference
   it directly.
2. **No copying** -- junctions and runtime dispatch eliminate file duplication.
3. **One command update** -- `baton update` = `git pull`, all projects see
   changes instantly.
4. **Static project config** -- `settings.json` never needs updating after init.

## Constraints

- Primary user: single developer, multiple projects, occasionally shared.
- Windows without Developer Mode -- symlinks unreliable, NTFS junctions work.
- Project baton files are gitignored (not committed to project repos).
- Must support Claude Code, Cursor, and Codex IDEs.

## Architecture

### Current (three-layer copy)

```
origin -> git clone (sparse) -> ~/.baton
                                    |
                              setup.sh copies/symlinks
                                    |
                              project/.baton (hook copies)
                              project/.claude/skills (dir symlinks/copies)
```

### New (single-source reference)

```
origin -> git clone -> ~/.baton (plain clone, single source)
                           |
                      baton init (one-time, generates pointers)
                           |
                      project/.baton/           <- junction -> ~/.baton/.baton
                      project/.claude/skills/*  <- junctions -> ~/.baton/.baton/skills/*
                      project/.claude/settings.json  <- generated, static
                      project/CLAUDE.md              <- @.baton/constitution.md injected
```

### Project footprint after `baton init`

```
project/
+-- .baton/                    -> junction -> ~/.baton/.baton/
|   +-- hooks/
|   |   +-- dispatch.sh          (baton source, not a project file)
|   |   +-- manifest.conf
|   |   +-- write-lock.sh
|   |   +-- ...
|   +-- skills/
|   |   +-- baton-research/
|   |   +-- ...
|   +-- constitution.md
+-- .claude/
|   +-- settings.json            (generated once, static)
|   +-- skills/
|       +-- baton-research/    -> junction -> ~/.baton/.baton/skills/baton-research
|       +-- baton-plan/        -> junction -> ~/.baton/.baton/skills/baton-plan
|       +-- ...
+-- CLAUDE.md                    (contains @.baton/constitution.md)
```

## dispatch.sh -- Event-Based Hook Dispatcher

A ~45-line script that lives in baton source (accessed through the `.baton/`
junction). All hook entries in `settings.json` point to it.

### manifest.conf format

```conf
# event:matcher:script
# matcher empty = match all, comma-separated for multiple
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

### dispatch.sh implementation

```bash
#!/usr/bin/env bash
# dispatch.sh -- event-based hook dispatcher
# Runs each hook in a subshell to isolate exit codes and variable state.
# Buffers stdin so multiple hooks can access the input payload.
set -eu

_event="$1"; shift
_dir="$(cd "$(dirname "$0")" && pwd)"
_manifest="$_dir/manifest.conf"

[ ! -f "$_manifest" ] && exit 0

# Export project dir before junction resolution changes pwd context
export BATON_PROJECT_DIR
BATON_PROJECT_DIR="$(pwd)"

# Buffer stdin once -- hook scripts read from BATON_STDIN instead of stdin.
# Claude Code passes tool name and input as JSON on stdin to hooks.
export BATON_STDIN
BATON_STDIN="$(cat 2>/dev/null || true)"

# Extract tool name from stdin JSON for matcher filtering.
# PreToolUse/PostToolUse stdin has "tool_name" field.
_tool=""
if [ -n "$BATON_STDIN" ]; then
    _tool="$(printf '%s' "$BATON_STDIN" | jq -r '.tool_name // empty' 2>/dev/null)" || true
    # awk fallback if jq unavailable
    if [ -z "$_tool" ]; then
        _tool="$(printf '%s' "$BATON_STDIN" | sed -n 's/.*"tool_name" *: *"\([^"]*\)".*/\1/p' | head -1)" || true
    fi
fi

_exit_code=0

while IFS=: read -r _evt _matcher _script || [ -n "$_evt" ]; do
    case "$_evt" in ''|\#*) continue ;; esac
    [ "$_evt" != "$_event" ] && continue

    if [ -n "$_matcher" ] && [ -n "$_tool" ]; then
        case ",$_matcher," in
            *",$_tool,"*) ;;
            *) continue ;;
        esac
    fi

    # Run in subshell: isolates exit codes and variable state.
    # Hook scripts must read BATON_STDIN instead of stdin.
    _rc=0
    ( . "$_dir/$_script.sh" ) || _rc=$?

    # For PreToolUse: first blocking exit (exit 2) wins
    if [ "$_rc" -eq 2 ] && [ "$_exit_code" -ne 2 ]; then
        _exit_code=2
    fi
done < "$_manifest"

exit "$_exit_code"
```

### Hook script migration requirement

Existing hook scripts need two changes to work under dispatch.sh:

1. **Shebang**: Keep `#!/usr/bin/env bash` (dispatch.sh uses bash).
2. **stdin**: Replace `STDIN="$(cat 2>/dev/null || true)"` with
   `STDIN="$BATON_STDIN"`. The dispatcher buffers stdin once and exports it
   as `BATON_STDIN`. Each hook runs in a subshell and cannot read stdin
   directly (it was already consumed by the dispatcher).
3. **`$0` resolution**: `$0` inside a sourced subshell points to dispatch.sh.
   Since dispatch.sh and all hook scripts share the same directory (accessed
   via junction), `dirname "$0"` still resolves correctly. This is a design
   constraint: hook scripts must remain in the same directory as dispatch.sh.
   Note: `BASH_SOURCE[0]` in a sourced script points to the sourced file
   itself (not dispatch.sh), making it more reliable. Hooks should prefer
   `BASH_SOURCE[0]` over `$0` for path resolution.

### settings.json (static, generated once)

Uses Claude Code's nested hook format. All events use empty matcher (`""`)
so dispatch.sh receives every invocation and handles matcher filtering
internally via manifest.conf. The tool name is extracted from stdin JSON
(Claude Code passes tool input as JSON on stdin to hooks).

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash .baton/hooks/dispatch.sh PreToolUse" }] }
    ],
    "PostToolUse": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash .baton/hooks/dispatch.sh PostToolUse" }] }
    ],
    "SessionStart": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash .baton/hooks/dispatch.sh SessionStart" }] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash .baton/hooks/dispatch.sh Stop" }] }
    ],
    "PreCompact": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash .baton/hooks/dispatch.sh PreCompact" }] }
    ],
    "SubagentStart": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash .baton/hooks/dispatch.sh SubagentStart" }] }
    ],
    "TaskCompleted": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash .baton/hooks/dispatch.sh TaskCompleted" }] }
    ],
    "PostToolUseFailure": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash .baton/hooks/dispatch.sh PostToolUseFailure" }] }
    ]
  }
}
```

### Key design decisions

- **`#!/usr/bin/env bash`**: Hook scripts use bash features (`local`, `[[`,
  `${BASH_SOURCE[0]}`, C-style for loops). dispatch.sh must use bash.
- **Subshell isolation**: Each hook runs in `( . script.sh )`. This prevents
  `exit 0` in one hook from killing the dispatcher and prevents variable
  pollution between hooks.
- **Buffered stdin**: `BATON_STDIN` is exported before the loop. Hooks read
  from this variable instead of stdin. This is the one required migration
  change in existing hook scripts.
- **PreToolUse exit 2 propagation**: The dispatcher captures exit codes from
  subshells. If any hook exits 2 (block operation), the dispatcher exits 2
  after running all matching hooks.
- **Path resolution via `$0`**: `dispatch.sh` resolves its own directory via
  `dirname "$0"`. Through a junction this transparently resolves to the baton
  source files. No dependency on `$BATON_HOME` environment variable. Design
  constraint: all hook scripts must remain in the same directory as
  dispatch.sh.
- **New hooks require only manifest update**: Add script file + manifest line
  in baton source, `git pull`, all projects see it immediately.
- **New event types are uncommon**: Adding a new Claude Code event type
  requires updating `settings.json`. To minimize this, settings.json
  registers all 8 current event types upfront.

## NTFS Junction Strategy

### Creation function

```bash
atomic_junction() {
    _src="$1" _dst="$2"
    # Remove existing target (old install, stale symlink, partial copy)
    if [ -e "$_dst" ] || [ -L "$_dst" ]; then
        rm -rf "$_dst"
    fi
    # 1. try NTFS junction (no Developer Mode needed)
    cmd //c "mklink /J \"$(cygpath -w "$_dst")\" \"$(cygpath -w "$_src")\"" \
        >/dev/null 2>&1 && return 0
    # 2. try symlink
    ln -sf "$_src" "$_dst" 2>/dev/null && [ -L "$_dst" ] && return 0
    # 3. fallback: copy
    cp -r "$_src" "$_dst"
    return 1  # non-zero signals copy fallback
}
```

The function removes any existing target before creating the junction. This
handles migration from old installs and re-runs of `baton init`.

### Fallback chain

1. **NTFS junction** (`mklink /J`) -- works without Developer Mode on Windows.
2. **Symlink** (`ln -sf`) -- works on Linux/macOS and Windows with Developer
   Mode.
3. **Copy** (`cp -r`) -- universal fallback. Creates marker file
   `.baton/.copy-mode` so `baton update` knows to re-copy.

### Verified behavior (tested on user's machine)

- Junction creation: works without Developer Mode.
- Read transparency: files readable as if in a regular directory.
- New file visibility: files added to source directory are immediately visible
  through junction.
- Bash tests: `[ -d ]` returns true, `[ -L ]` returns true.

## SessionStart Auto-Junction for New Skills

When baton adds a new skill directory, projects need a corresponding junction
under `.claude/skills/`. The SessionStart hook (`phase-guide.sh`) auto-detects
and creates missing junctions:

```bash
# Auto-create missing skill junctions
_skill_src="$(cd "$(dirname "$0")/../skills" && pwd)"
for _skill_dir in "$_skill_src"/baton-*; do
    [ ! -d "$_skill_dir" ] && continue
    _name="$(basename "$_skill_dir")"
    _target=".claude/skills/$_name"
    if [ ! -d "$_target" ]; then
        mkdir -p .claude/skills
        cmd //c "mklink /J \"$(cygpath -w "$_target")\" \"$(cygpath -w "$_skill_dir")\"" \
            >/dev/null 2>&1 \
            || ln -sf "$_skill_dir" "$_target" 2>/dev/null \
            || cp -r "$_skill_dir" "$_target"
    fi
done
```

This runs at session start. Cost: one directory scan of `.baton/skills/`,
negligible.

## `baton init` Flow

~150-200 lines total (down from ~1400).

```
1. Ensure ~/.baton exists
   - Not found -> git clone (plain, no sparse checkout)
   - Found     -> git pull --ff-only

2. Detect self-install
   - If project/.baton/skills exists and project/.baton is not a junction
     -> SELF_INSTALL=1, skip .baton junction

3. Create .baton junction (unless self-install)
   - atomic_junction ~/.baton/.baton -> project/.baton

4. Detect IDEs (or use --ide flag)
   - Claude Code: .claude/ exists or create
   - Cursor: .cursor/ exists
   - Codex: always create .agents/ fallback

5. Create skill junctions per IDE
   - Scan .baton/skills/baton-*
   - For each IDE, create junction in its skills directory

6. Generate or merge settings.json (MUST NOT overwrite existing config)
   - If settings.json does not exist: generate fresh with baton hooks + env
   - If settings.json exists: merge baton dispatch entries into existing
     hooks object, preserving all non-baton hook entries, env settings,
     and any other top-level keys. Use jq if available, otherwise awk-based
     merge (same strategy as current setup.sh merge_json_with_jq).
   - Baton entries are identified by command containing "dispatch.sh"
   - On re-init: replace existing baton entries, leave everything else

7. Inject CLAUDE.md / AGENTS.md
   - Add @.baton/constitution.md if not present

8. Add .gitignore entries
   - .baton/
   - .claude/skills/baton-*
   - .cursor/skills/baton-*
   - .agents/skills/baton-*

9. CLAUDE.md handling
   - If CLAUDE.md does not exist, create it with @.baton/constitution.md
   - If CLAUDE.md exists, append @.baton/constitution.md if not present

10. Register project (optional, for doctor --all)
```

## `baton update` Flow

```
baton update          # = git -C ~/.baton pull --ff-only
                      #   If .copy-mode marker found in any registered project:
                      #     re-copy .baton/ and skills to those projects

baton update --check  # Verify junction health across registered projects
```

No `baton update --all` needed -- junctions point to source, pull updates
everything.

No `baton self-update` needed -- merged into `baton update`.

## CLI Commands

| Command | Behavior |
|---------|----------|
| `baton init [dir]` | One-time setup: clone/pull, create junctions, generate config |
| `baton update` | `git pull ~/.baton`. Re-copy for copy-mode projects. |
| `baton update --check` | Verify junction integrity across projects |
| `baton uninstall [dir]` | Remove junctions, settings entries, CLAUDE.md injection |
| `baton doctor [dir]` | Health check: junction status, skill presence, config validity |
| `baton list` | List registered projects |
| `baton status [dir]` | Show workflow phase and progress (unchanged) |

Removed commands:
- `baton update --all` -- unnecessary with junction architecture
- `baton self-update` -- merged into `baton update`

## Self-Install (Baton Source Repo)

Detection: `.baton/skills/` exists as a real directory (not a junction).

Behavior differences:
- Skip `.baton/` junction creation (real directory already present).
- Skill junctions point to `project/.baton/skills/` (not `~/.baton`).
- `dispatch.sh` path resolution works identically (via `dirname $0`).
- Everything else unchanged.

## Multi-IDE Support

| IDE | Hook config | Skills location |
|-----|-------------|-----------------|
| Claude Code | `.claude/settings.json` | `.claude/skills/baton-*` |
| Cursor | `.cursor/hooks.json` | `.cursor/skills/baton-*` |
| Codex | `AGENTS.md` (advisory) | `.agents/skills/baton-*` |

Each IDE gets its own set of skill junctions. Hook config format differs per
IDE but dispatch mechanism is the same.

### IDE adapter integration

Cursor and Codex have different hook protocols than Claude Code:

- **Cursor**: Hooks must output JSON (`{"decision":"allow"}` or
  `{"decision":"block","reason":"..."}`). The current `adapter-cursor.sh`
  wraps individual hooks and translates exit codes to JSON.
- **Codex**: Hooks output to stdout as context for the agent. The current
  `adapter-codex.sh` wraps hooks similarly.

Under the dispatch model, each IDE gets its own dispatch entry point:

- `dispatch.sh` -- Claude Code (exit codes)
- `dispatch-cursor.sh` -- Wraps dispatch.sh, translates exit code to JSON
- `dispatch-codex.sh` -- Wraps dispatch.sh, captures stdout

These adapter dispatchers are ~10 lines each and live in baton source
alongside dispatch.sh.

## Migration Strategy

When `baton init` detects an existing old-style installation:

1. Detect old version: `.baton/hooks/*.sh` are real files (not junction
   traversal), or `.baton/` is not a junction.
2. Remove old hook script copies from project `.baton/hooks/`.
3. Remove old `.baton/` directory.
4. Create `.baton/` junction to `~/.baton/.baton/`.
5. Regenerate `settings.json` with event-based dispatch format. Note: the
   JSON schema changes from per-hook matcher entries to a single dispatch
   entry per event type. The old per-script entries are fully replaced.
6. Existing skill junctions: keep if valid, recreate if broken.
7. Preserve `CLAUDE.md` injection (already uses `@.baton/constitution.md`).

## Code Size Impact

| File | Current | New |
|------|---------|-----|
| `setup.sh` | ~1400 lines | ~150-200 lines |
| `install.sh` | ~108 lines | ~60 lines |
| `bin/baton` | ~360 lines | ~250 lines |
| `dispatch.sh` | (new) | ~45 lines |
| `dispatch-cursor.sh` | (new) | ~10 lines |
| `dispatch-codex.sh` | (new) | ~10 lines |
| `manifest.conf` | (new) | ~12 lines |
| **Total** | **~1870 lines** | **~550 lines** |

## Copy-Mode Recovery

When junctions fail and baton falls back to copy mode, the marker file
`.baton/.copy-mode` is created. `baton update` behavior in copy mode:

1. `git pull` in `~/.baton` (same as junction mode).
2. Scan registered projects for `.copy-mode` marker.
3. For each copy-mode project: `rm -rf .baton && cp -r ~/.baton/.baton .baton`.
4. Re-copy skill directories to each IDE's skills location.
5. settings.json is left unchanged (already static and correct).

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Junction not supported on some Windows configs | Three-level fallback: junction -> symlink -> copy |
| `~/.baton` moved or deleted breaks all projects | `baton doctor` detects broken junctions, `baton init` repairs |
| Junction can't cross drive letters | Document: project and `~/.baton` must be on same drive |
| Copy-mode projects still need manual update | `baton update` auto-detects `.copy-mode` marker and re-copies |
| `dispatch.sh` adds ~15ms overhead per hook call | Acceptable at human interaction speed |
| `git pull --ff-only` fails with local changes in `~/.baton` | Warn user, suggest `git stash` or `git reset` |
| Hook scripts use `$0` which points to dispatch.sh | Same directory constraint: all hooks in `.baton/hooks/` |
| `pwd` through junction may resolve to real path | Hooks that walk up to find project root must use the cwd at dispatch entry, not `dirname $0` resolution. dispatch.sh should export `BATON_PROJECT_DIR="$(pwd)"` before the loop. |
