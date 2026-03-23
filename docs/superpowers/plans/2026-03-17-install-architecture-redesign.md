# Install Architecture Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the three-layer copy architecture with junction-based single-source references, reducing setup.sh from ~1400 lines to ~200 and making `baton update` a single `git pull`.

**Architecture:** Projects reference `~/.baton/.baton/` via NTFS junctions (or symlink/copy fallback). A single `dispatch.sh` in baton source handles all hook routing via `manifest.conf`. No hook scripts are copied to projects.

**Tech Stack:** Bash, NTFS junctions (`mklink /J`), jq (optional, for JSON merging)

**Spec:** `docs/superpowers/specs/2026-03-17-install-architecture-redesign.md`

---

## Chunk 1: Core Dispatch System

### Task 1: dispatch.sh and manifest.conf

**Files:**
- Create: `.baton/hooks/dispatch.sh`
- Create: `.baton/hooks/manifest.conf`
- Test: `tests/test-dispatch.sh`

- [ ] **Step 1: Write test for dispatch.sh**

Create `tests/test-dispatch.sh` with the test framework pattern from existing tests:

```bash
#!/bin/bash
# test-dispatch.sh — Tests for event-based hook dispatcher
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATON_DIR="$SCRIPT_DIR/.."
DISPATCH="$BATON_DIR/.baton/hooks/dispatch.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_eq() {
    TOTAL=$((TOTAL + 1))
    if [ "$1" = "$2" ]; then
        echo "  pass: $3"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $3 (expected '$2', got '$1')"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    TOTAL=$((TOTAL + 1))
    if echo "$1" | grep -q "$2"; then
        echo "  pass: $3"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $3 (output does not contain '$2')"
        FAIL=$((FAIL + 1))
    fi
}

# --- Test: dispatch routes to correct hook by event ---
echo "=== dispatch routes by event ==="
mkdir -p "$tmp/hooks"
cat > "$tmp/hooks/test-hook.sh" << 'HOOK'
echo "hook-fired"
exit 0
HOOK
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
SessionStart::test-hook
MANIFEST
cp "$DISPATCH" "$tmp/hooks/dispatch.sh"
chmod +x "$tmp/hooks/dispatch.sh"

_out="$(bash "$tmp/hooks/dispatch.sh" SessionStart 2>&1)" || true
assert_contains "$_out" "hook-fired" "SessionStart routes to test-hook"

_out="$(bash "$tmp/hooks/dispatch.sh" Stop 2>&1)" || true
assert_eq "$_out" "" "Stop does not route to SessionStart hook"

# --- Test: matcher filtering via stdin JSON tool_name ---
echo "=== matcher filtering ==="
cat > "$tmp/hooks/write-hook.sh" << 'HOOK'
echo "write-matched"
exit 0
HOOK
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
PreToolUse:Write,Edit:write-hook
MANIFEST

# dispatch.sh extracts tool_name from stdin JSON for matcher filtering
_out="$(echo '{"tool_name":"Write"}' | bash "$tmp/hooks/dispatch.sh" PreToolUse 2>&1)" || true
assert_contains "$_out" "write-matched" "Write matches Write,Edit matcher (from stdin JSON)"

_out="$(echo '{"tool_name":"Bash"}' | bash "$tmp/hooks/dispatch.sh" PreToolUse 2>&1)" || true
assert_eq "$_out" "" "Bash does not match Write,Edit matcher"

# No stdin = no tool name = no matcher match
_out="$(bash "$tmp/hooks/dispatch.sh" PreToolUse 2>&1 < /dev/null)" || true
assert_eq "$_out" "" "no stdin means no tool_name, matcher hooks skipped"

# Empty matcher matches regardless
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
PreToolUse::write-hook
MANIFEST
_out="$(bash "$tmp/hooks/dispatch.sh" PreToolUse 2>&1 < /dev/null)" || true
assert_contains "$_out" "write-matched" "empty matcher matches without tool_name"

# --- Test: BATON_STDIN is available ---
echo "=== BATON_STDIN buffering ==="
cat > "$tmp/hooks/stdin-hook.sh" << 'HOOK'
echo "stdin=$BATON_STDIN"
exit 0
HOOK
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
PreToolUse::stdin-hook
MANIFEST

_out="$(echo '{"tool_name":"Write"}' | bash "$tmp/hooks/dispatch.sh" PreToolUse 2>&1)" || true
assert_contains "$_out" 'stdin={"tool_name":"Write"}' "BATON_STDIN contains piped input"

# --- Test: BATON_PROJECT_DIR is exported ---
echo "=== BATON_PROJECT_DIR export ==="
cat > "$tmp/hooks/dir-hook.sh" << 'HOOK'
echo "projdir=$BATON_PROJECT_DIR"
exit 0
HOOK
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
SessionStart::dir-hook
MANIFEST

_out="$(cd "$tmp" && bash "$tmp/hooks/dispatch.sh" SessionStart 2>&1)" || true
# BATON_PROJECT_DIR should be $tmp (the cwd when dispatch was called)
assert_contains "$_out" "projdir=" "BATON_PROJECT_DIR is set"

# --- Test: subshell isolation — exit 0 does not kill dispatcher ---
echo "=== subshell isolation ==="
cat > "$tmp/hooks/hook-a.sh" << 'HOOK'
echo "a-fired"
exit 0
HOOK
cat > "$tmp/hooks/hook-b.sh" << 'HOOK'
echo "b-fired"
exit 0
HOOK
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
Stop::hook-a
Stop::hook-b
MANIFEST

_out="$(bash "$tmp/hooks/dispatch.sh" Stop 2>&1)" || true
assert_contains "$_out" "a-fired" "hook-a fires"
assert_contains "$_out" "b-fired" "hook-b fires after hook-a exit 0"

# --- Test: exit 2 propagation for PreToolUse ---
echo "=== exit 2 propagation ==="
cat > "$tmp/hooks/blocker.sh" << 'HOOK'
echo "blocked"
exit 2
HOOK
cat > "$tmp/hooks/after-block.sh" << 'HOOK'
echo "after-block"
exit 0
HOOK
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
PreToolUse::blocker
PreToolUse::after-block
MANIFEST

_rc=0
_out="$(echo '{"tool_name":"Write"}' | bash "$tmp/hooks/dispatch.sh" PreToolUse 2>&1)" || _rc=$?
assert_eq "$_rc" "2" "dispatch exits 2 when hook blocks"
assert_contains "$_out" "after-block" "hooks after blocker still run"

# --- Test: comments and blank lines in manifest ---
echo "=== manifest comments ==="
cat > "$tmp/hooks/manifest.conf" << 'MANIFEST'
# This is a comment

SessionStart::hook-a
# Another comment
MANIFEST

_out="$(bash "$tmp/hooks/dispatch.sh" SessionStart 2>&1)" || true
assert_contains "$_out" "a-fired" "comments and blanks are skipped"

# --- Test: missing manifest exits cleanly ---
echo "=== missing manifest ==="
rm -f "$tmp/hooks/manifest.conf"
_rc=0
bash "$tmp/hooks/dispatch.sh" SessionStart >/dev/null 2>&1 || _rc=$?
assert_eq "$_rc" "0" "missing manifest exits 0"

echo ""
echo "dispatch tests: $PASS passed, $FAIL failed out of $TOTAL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-dispatch.sh`
Expected: FAIL — dispatch.sh does not exist yet

- [ ] **Step 3: Create dispatch.sh**

Create `.baton/hooks/dispatch.sh`:

```bash
#!/usr/bin/env bash
# dispatch.sh — event-based hook dispatcher
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

# Buffer stdin once — hook scripts read from BATON_STDIN instead of stdin.
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

    # Run in subshell: isolates exit codes and variable state
    _rc=0
    ( . "$_dir/$_script.sh" ) || _rc=$?

    # For PreToolUse: first blocking exit (exit 2) wins
    if [ "$_rc" -eq 2 ] && [ "$_exit_code" -ne 2 ]; then
        _exit_code=2
    fi
done < "$_manifest"

exit "$_exit_code"
```

- [ ] **Step 4: Create manifest.conf**

Create `.baton/hooks/manifest.conf`:

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

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash tests/test-dispatch.sh`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add .baton/hooks/dispatch.sh .baton/hooks/manifest.conf tests/test-dispatch.sh
git commit -m "feat: add dispatch.sh event-based hook dispatcher + manifest.conf"
```

---

### Task 2: Migrate hook scripts to BATON_STDIN

**Files:**
- Modify: `.baton/hooks/write-lock.sh` (stdin reading, ~line 24-26)
- Modify: `.baton/hooks/bash-guard.sh` (stdin reading, ~line 34-35)
- Modify: `.baton/hooks/post-write-tracker.sh` (stdin reading, ~line 18-20)
- Modify: `.baton/hooks/failure-tracker.sh` (stdin reading, ~line 13-15)

All 4 hooks that read stdin use the same pattern:
```bash
# Current:
STDIN=""
[ ! -t 0 ] && STDIN="$(cat 2>/dev/null || true)"

# New (supports both direct invocation and dispatch):
if [ -n "${BATON_STDIN+x}" ]; then
    STDIN="$BATON_STDIN"
else
    STDIN=""
    [ ! -t 0 ] && STDIN="$(cat 2>/dev/null || true)"
fi
```

This is backward-compatible: if invoked directly (not via dispatch), falls back to reading stdin.

- [ ] **Step 1: Run existing tests as baseline**

Run: `bash tests/test-write-lock.sh && bash tests/test-bash-guard.sh`
Expected: All PASS (baseline before migration)

- [ ] **Step 2: Update write-lock.sh stdin reading**

In `.baton/hooks/write-lock.sh`, replace the stdin reading block (~lines 24-26):

```bash
# Old:
STDIN=""
[ ! -t 0 ] && STDIN="$(cat 2>/dev/null || true)"

# New:
if [ -n "${BATON_STDIN+x}" ]; then
    STDIN="$BATON_STDIN"
else
    STDIN=""
    [ ! -t 0 ] && STDIN="$(cat 2>/dev/null || true)"
fi
```

- [ ] **Step 3: Update bash-guard.sh stdin reading**

Same pattern replacement in `.baton/hooks/bash-guard.sh` (~lines 34-35).

- [ ] **Step 4: Update post-write-tracker.sh stdin reading**

Same pattern replacement in `.baton/hooks/post-write-tracker.sh` (~lines 18-20).

- [ ] **Step 5: Update failure-tracker.sh stdin reading**

Same pattern replacement in `.baton/hooks/failure-tracker.sh` (~lines 13-15).

- [ ] **Step 6: Run existing tests to verify no regressions**

Run: `bash tests/test-write-lock.sh && bash tests/test-bash-guard.sh && bash tests/test-new-hooks.sh`
Expected: All PASS — backward compatible

- [ ] **Step 7: Add dispatch-mode test to test-dispatch.sh**

Append to `tests/test-dispatch.sh`: a test that runs a real hook (write-lock)
through dispatch.sh with JSON stdin, verifying BATON_STDIN is used correctly.
The test should pipe a write-lock JSON payload and confirm the hook reads it.

- [ ] **Step 8: Commit**

```bash
git add .baton/hooks/write-lock.sh .baton/hooks/bash-guard.sh \
       .baton/hooks/post-write-tracker.sh .baton/hooks/failure-tracker.sh \
       tests/test-dispatch.sh
git commit -m "feat: migrate hook stdin reading to BATON_STDIN for dispatch compatibility"
```

---

## Chunk 2: Junction Infrastructure and Setup

### Task 3: atomic_junction utility function

**Files:**
- Create: `.baton/hooks/junction.sh` (shared utility for junction/symlink/copy)
- Test: `tests/test-junction.sh`

- [ ] **Step 1: Write junction tests**

Create `tests/test-junction.sh`:

```bash
#!/bin/bash
# test-junction.sh — Tests for atomic_junction utility
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0; TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_eq() {
    TOTAL=$((TOTAL + 1))
    if [ "$1" = "$2" ]; then echo "  pass: $3"; PASS=$((PASS + 1))
    else echo "  FAIL: $3 (expected '$2', got '$1')"; FAIL=$((FAIL + 1)); fi
}

. "$SCRIPT_DIR/../.baton/hooks/junction.sh"

# --- Test: creates junction/symlink/copy to a directory ---
echo "=== atomic_junction creates link ==="
mkdir -p "$tmp/source" && echo "content" > "$tmp/source/file.txt"
atomic_junction "$tmp/source" "$tmp/target"
_content="$(cat "$tmp/target/file.txt")"
assert_eq "$_content" "content" "target/file.txt readable through junction"

# --- Test: new files in source visible through junction ---
echo "=== new file visibility ==="
echo "new" > "$tmp/source/new.txt"
if [ -f "$tmp/target/new.txt" ]; then
    _vis="yes"
else
    _vis="no"
fi
# Junction/symlink: yes. Copy: no. Both are acceptable.
echo "  info: new file visibility = $_vis (junction/symlink=yes, copy=no)"

# --- Test: replaces existing target ---
echo "=== replaces existing target ==="
mkdir -p "$tmp/old-target" && echo "old" > "$tmp/old-target/stale.txt"
mkdir -p "$tmp/source2" && echo "fresh" > "$tmp/source2/fresh.txt"
atomic_junction "$tmp/source2" "$tmp/old-target"
assert_eq "$(cat "$tmp/old-target/fresh.txt")" "fresh" "old target replaced"

# --- Test: copy-mode marker on fallback ---
echo "=== copy-mode detection ==="
# atomic_junction returns 0 for junction/symlink, 1 for copy
# We can't force copy mode in test, but we can check the return value
_rc=0
atomic_junction "$tmp/source" "$tmp/target2" || _rc=$?
echo "  info: atomic_junction returned $_rc (0=junction/symlink, 1=copy)"

echo ""
echo "junction tests: $PASS passed, $FAIL failed out of $TOTAL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-junction.sh`
Expected: FAIL — junction.sh does not exist

- [ ] **Step 3: Create junction.sh**

Create `.baton/hooks/junction.sh`:

```bash
#!/usr/bin/env bash
# junction.sh — Shared utility for creating directory junctions/symlinks/copies.
# Source this file; do not execute directly.

# atomic_junction SRC DST
#   Creates a directory junction (Windows), symlink (Unix), or copy (fallback).
#   Returns 0 for junction/symlink, 1 for copy fallback.
atomic_junction() {
    local _src="$1" _dst="$2"

    # Remove existing target
    if [ -e "$_dst" ] || [ -L "$_dst" ]; then
        rm -rf "$_dst"
    fi

    # 1. Try NTFS junction (Windows, no Developer Mode needed)
    if command -v cygpath >/dev/null 2>&1; then
        cmd //c "mklink /J \"$(cygpath -w "$_dst")\" \"$(cygpath -w "$_src")\"" \
            >/dev/null 2>&1 && return 0
    fi

    # 2. Try symlink
    ln -sf "$_src" "$_dst" 2>/dev/null && [ -L "$_dst" ] && return 0

    # 3. Fallback: copy
    cp -r "$_src" "$_dst"
    return 1
}
```

- [ ] **Step 4: Run tests**

Run: `bash tests/test-junction.sh`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add .baton/hooks/junction.sh tests/test-junction.sh
git commit -m "feat: add atomic_junction utility (junction/symlink/copy fallback)"
```

---

### Task 4: New setup.sh

This is the largest task. The new setup.sh replaces ~1400 lines with ~200.

**Files:**
- Rewrite: `setup.sh`
- Test: `tests/test-setup.sh` (update existing tests)

- [ ] **Step 1: Back up current setup.sh**

```bash
cp setup.sh setup.sh.v3-backup
```

- [ ] **Step 2: Write new setup.sh**

Rewrite `setup.sh` with these sections:
1. **Argument parsing** — `--ide`, `--choose`, `--uninstall`, positional dir
2. **Source junction.sh** — for `atomic_junction`
3. **ensure_baton_home()** — git clone or pull
4. **detect_self_install()** — check if `.baton/skills/` is real dir
5. **detect_ides()** — check for `.claude/`, `.cursor/`, always `.agents/`
6. **create_baton_junction()** — junction `.baton/` to source
7. **create_skill_junctions()** — per-IDE skill junctions
8. **generate_settings_json()** — generate or merge (jq with awk fallback)
9. **inject_rules()** — CLAUDE.md / AGENTS.md
10. **add_gitignore()** — append entries if missing
11. **uninstall()** — reverse all of the above

Key settings.json format (must match Claude Code's expected schema):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .baton/hooks/dispatch.sh PreToolUse"
          }
        ]
      }
    ]
  }
}
```

The `generate_settings_json()` function must:
- Preserve existing `env` section and non-baton hook entries
- Identify baton entries by `dispatch.sh` in command string
- Also identify old-style baton entries by `.baton/hooks/` in command string
  (for migration: remove old per-hook entries, add new dispatch entries)
- Use jq if available, awk fallback otherwise
- On fresh install: generate full JSON with all 8 event types
- On re-init: replace only baton entries

When `atomic_junction` returns non-zero (copy fallback), setup.sh must create
the `.copy-mode` marker: `touch "$PROJECT_DIR/.baton/.copy-mode"`. This marker
tells `baton update` to re-copy instead of relying on junction transparency.

- [ ] **Step 3: Update test-setup.sh**

Update `tests/test-setup.sh` assertions to match new behavior:
- Check for `.baton/` junction (or directory if copy-mode)
- Check for skill junctions in `.claude/skills/`
- Check settings.json contains `dispatch.sh` references
- Check `.gitignore` entries
- Check CLAUDE.md injection
- Remove version-comparison assertions (no more per-script versions)
- Add test: re-init preserves existing env settings in settings.json
- Add test: uninstall removes junctions and settings entries

- [ ] **Step 4: Run tests**

Run: `bash tests/test-setup.sh`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add setup.sh tests/test-setup.sh
git commit -m "feat: rewrite setup.sh with junction-based architecture"
```

---

### Task 5: Update install.sh

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Simplify install.sh**

Remove sparse checkout logic. The new install.sh:
1. Clone `~/.baton` (plain clone, no `--sparse`, no `--filter`)
2. Or pull if exists
3. Add `~/.baton/bin` to PATH
4. Run `setup.sh` in current dir

```bash
#!/bin/sh
# install.sh — Global installer for baton
set -eu

BATON_HOME="${BATON_HOME:-$HOME/.baton}"
BATON_REPO="${BATON_REPO:-https://github.com/hex1n/baton.git}"

echo "Installing baton..."

# 1. Ensure ~/.baton is a git repository
if [ -d "$BATON_HOME/.git" ]; then
    echo "  ✓ $BATON_HOME already exists"
    if git -C "$BATON_HOME" pull --ff-only 2>/dev/null; then
        echo "  ✓ Updated to latest"
    else
        echo "  ⚠ Could not auto-update (local changes?). Run: git -C $BATON_HOME pull --ff-only"
    fi
elif [ -d "$BATON_HOME" ]; then
    echo "  ⚠ $BATON_HOME exists but is not a git repository"
    echo "  Remove it first: rm -rf $BATON_HOME"
    exit 1
else
    echo "  Cloning baton to $BATON_HOME..."
    git clone "$BATON_REPO" "$BATON_HOME"
    echo "  ✓ Cloned baton"
fi

# 2. Ensure bin/baton executable
chmod +x "$BATON_HOME/bin/baton" 2>/dev/null || true

# 3. Add ~/.baton/bin to PATH
BATON_BIN="$BATON_HOME/bin"
PATH_ENTRY="export PATH=\"$BATON_BIN:\$PATH\""

for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
    if [ -f "$profile" ] && ! grep -qF "$BATON_BIN" "$profile" 2>/dev/null; then
        printf '\n# baton CLI\n%s\n' "$PATH_ENTRY" >> "$profile"
        echo "  ✓ Added PATH to $profile"
    fi
done

# 4. Auto-init current directory
export PATH="$BATON_BIN:$PATH"
echo ""
echo "Done! Baton installed to $BATON_HOME"
echo ""

if bash "$BATON_HOME/setup.sh" "$@" "$(pwd)"; then
    echo "  ✓ Initialized baton in current directory"
else
    echo "  ⚠ Auto-init failed. Run: baton init"
fi

echo ""
echo "  Restart your shell or run:"
echo "    export PATH=\"$BATON_BIN:\$PATH\""
```

- [ ] **Step 2: Commit**

```bash
git add install.sh
git commit -m "feat: simplify install.sh — remove sparse checkout, plain clone"
```

---

## Chunk 3: CLI and IDE Adapters

### Task 6: Update bin/baton CLI

**Files:**
- Modify: `bin/baton`

- [ ] **Step 1: Simplify CLI**

Changes to `bin/baton`:

1. **`baton update`**: Change from running `setup.sh` to `git pull` + copy-mode recovery.

```bash
update)
    echo "Updating baton..."
    if git -C "$BATON_HOME" pull --ff-only; then
        echo "✓ Updated to latest"
    else
        echo "⚠ Update failed. Check for local changes in $BATON_HOME"
        exit 1
    fi
    # Copy-mode recovery: re-copy to projects that can't use junctions
    if [ -f "$REGISTRY" ]; then
        while IFS= read -r _dir; do
            [ -z "$_dir" ] && continue
            [ ! -d "$_dir" ] && continue
            if [ -f "$_dir/.baton/.copy-mode" ]; then
                echo "  Refreshing copy-mode project: $_dir"
                rm -rf "$_dir/.baton"
                cp -r "$BATON_HOME/.baton" "$_dir/.baton"
                touch "$_dir/.baton/.copy-mode"
                # Re-copy skills
                for _skill_dir in "$BATON_HOME/.baton/skills"/baton-*; do
                    [ ! -d "$_skill_dir" ] && continue
                    _name="$(basename "$_skill_dir")"
                    for _ide_skills in "$_dir/.claude/skills" "$_dir/.cursor/skills" "$_dir/.agents/skills"; do
                        [ -d "$_ide_skills" ] || continue
                        rm -rf "$_ide_skills/$_name"
                        cp -r "$_skill_dir" "$_ide_skills/$_name"
                    done
                done
            fi
        done < "$REGISTRY"
    fi
    ;;
```

2. **Remove `self-update`**: It's now `baton update`.

3. **Remove `update --all`**: Junctions make this unnecessary.

4. **Add `update --check`**: Verify junction health.

```bash
# Inside update case, before the git pull:
if [ "${2:-}" = "--check" ]; then
    # Verify junction health
    if [ ! -f "$REGISTRY" ] || [ ! -s "$REGISTRY" ]; then
        echo "No projects registered."
        exit 0
    fi
    while IFS= read -r _dir; do
        [ -z "$_dir" ] && continue
        if [ ! -d "$_dir" ]; then
            printf "  ✗ %-50s (not found)\n" "$_dir"
        elif [ -L "$_dir/.baton" ] || [ -f "$_dir/.baton/.copy-mode" ]; then
            printf "  ✓ %-50s\n" "$_dir"
        elif [ -d "$_dir/.baton" ]; then
            printf "  ⚠ %-50s (old-style install, run baton init)\n" "$_dir"
        fi
    done < "$REGISTRY"
    exit 0
fi
```

5. **Update `doctor`**: Check junction status instead of script versions.

- [ ] **Step 2: Update test-cli.sh**

Update `tests/test-cli.sh` to reflect:
- `baton update` does git pull (not setup.sh)
- `baton self-update` removed (or aliased to `baton update`)
- `baton update --all` removed
- `baton update --check` added

- [ ] **Step 3: Run tests**

Run: `bash tests/test-cli.sh`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add bin/baton tests/test-cli.sh
git commit -m "feat: simplify baton CLI — merge self-update into update, add --check"
```

---

### Task 7: IDE adapter dispatchers

**Files:**
- Create: `.baton/hooks/dispatch-cursor.sh`
- Create: `.baton/hooks/dispatch-codex.sh`
- Modify: `.baton/adapters/adapter-cursor.sh` (or replace)
- Modify: `.baton/adapters/adapter-codex.sh` (or replace)

- [ ] **Step 1: Create dispatch-cursor.sh**

```bash
#!/usr/bin/env bash
# dispatch-cursor.sh — Cursor adapter for dispatch.sh
# Translates exit codes to JSON responses
set -eu

_dir="$(cd "$(dirname "$0")" && pwd)"
_out=""
_rc=0
_out="$(bash "$_dir/dispatch.sh" "$@" 2>&1)" || _rc=$?

if [ "$_rc" -eq 2 ]; then
    printf '{"decision":"block","reason":"%s"}\n' "$_out"
else
    printf '{"decision":"allow"}\n'
fi
```

- [ ] **Step 2: Create dispatch-codex.sh**

```bash
#!/usr/bin/env bash
# dispatch-codex.sh — Codex adapter for dispatch.sh
# Captures stdout as context for the agent
set -eu

_dir="$(cd "$(dirname "$0")" && pwd)"
bash "$_dir/dispatch.sh" "$@" 2>&1 || true
# Codex uses stdout as context, exit 0 always
exit 0
```

- [ ] **Step 3: Commit**

```bash
git add .baton/hooks/dispatch-cursor.sh .baton/hooks/dispatch-codex.sh
git commit -m "feat: add IDE adapter dispatchers for Cursor and Codex"
```

---

### Task 8: SessionStart auto-junction for new skills

**Files:**
- Modify: `.baton/hooks/phase-guide.sh` (add auto-junction at start)

- [ ] **Step 1: Add auto-junction to phase-guide.sh**

At the top of `phase-guide.sh` (after sourcing `_common.sh`), add:

```bash
# Auto-create missing skill junctions for IDE directories
_skill_src="$(cd "$SCRIPT_DIR/../skills" 2>/dev/null && pwd)" 2>/dev/null || true
if [ -n "$_skill_src" ] && [ -d "$_skill_src" ]; then
    . "$SCRIPT_DIR/junction.sh"
    for _skill_dir in "$_skill_src"/baton-*; do
        [ ! -d "$_skill_dir" ] && continue
        _name="$(basename "$_skill_dir")"
        for _ide_skills in .claude/skills .cursor/skills .agents/skills; do
            [ -d "$_ide_skills" ] || continue
            _target="$_ide_skills/$_name"
            [ -d "$_target" ] && continue
            atomic_junction "$_skill_dir" "$_target" 2>/dev/null || true
        done
    done
fi
```

- [ ] **Step 2: Test manually**

Create a temp skill dir in `.baton/skills/baton-test-skill/` with a SKILL.md,
run phase-guide.sh, verify junction was created in `.claude/skills/`.
Clean up after.

- [ ] **Step 3: Commit**

```bash
git add .baton/hooks/phase-guide.sh
git commit -m "feat: SessionStart auto-creates missing skill junctions"
```

---

## Chunk 4: Integration and Self-Install

### Task 9: Self-install handling

**Files:**
- Modify: `setup.sh` (self-install detection in Task 4, verify it works)

- [ ] **Step 1: Test self-install**

From the baton source repo itself, run:
```bash
bash setup.sh .
```

Verify:
- `.baton/` is NOT replaced with a junction (it's the real source dir)
- `.claude/skills/baton-*` junctions point to `.baton/skills/baton-*`
- `settings.json` uses dispatch.sh commands
- Existing `env` settings in `settings.json` are preserved

- [ ] **Step 2: Test in a separate project**

```bash
mkdir -p /tmp/test-project && cd /tmp/test-project
bash /path/to/baton/setup.sh .
```

Verify:
- `.baton/` is a junction to `~/.baton/.baton/`
- `.claude/skills/baton-*` are junctions
- `settings.json` generated correctly
- CLAUDE.md contains `@.baton/constitution.md`
- `.gitignore` has baton entries

- [ ] **Step 3: Test migration from old install**

Create a project with old-style install (real .baton/hooks/ files), run
`baton init`, verify it replaces with junction architecture.

- [ ] **Step 4: Commit any fixes**

```bash
git add -u
git commit -m "fix: integration fixes for self-install and migration"
```

---

### Task 10: Update self-install symlinks and cleanup

**Files:**
- Remove: `.claude/skills/baton-*/` committed symlinks (replace with junctions at runtime)
- Remove: `.agents/skills/baton-*/` committed symlinks
- Modify: `.gitignore` (add skill junction entries)
- Remove: `setup.sh.v3-backup` (if tests pass)

- [ ] **Step 1: Update .gitignore for baton source repo**

The baton source repo itself should gitignore the skill junctions in
`.claude/skills/` and `.agents/skills/` since they are now created at runtime
by setup.sh (self-install mode), not committed as symlinks.

Update `.gitignore`:
```
.claude/skills/baton-*
.agents/skills/baton-*
```

- [ ] **Step 2: Remove committed skill symlinks**

```bash
git rm .claude/skills/baton-debug .claude/skills/baton-implement \
      .claude/skills/baton-plan .claude/skills/baton-research \
      .claude/skills/baton-review .claude/skills/baton-subagent
git rm .agents/skills/baton-debug .agents/skills/baton-implement \
      .agents/skills/baton-plan .agents/skills/baton-research \
      .agents/skills/baton-review .agents/skills/baton-subagent
```

- [ ] **Step 3: Run self-install to recreate as junctions**

```bash
bash setup.sh .
```

Verify `.claude/skills/baton-*` are now junctions (not committed symlinks).

- [ ] **Step 4: Run full test suite**

Run: `bash tests/test-smoke.sh`
Expected: All PASS

- [ ] **Step 5: Remove backup**

```bash
rm -f setup.sh.v3-backup
```

- [ ] **Step 6: Final commit**

```bash
git add .gitignore
git commit -m "feat: complete install architecture redesign — junction-based, single-source"
```

---

## Summary

| Task | What | Lines changed |
|------|------|---------------|
| 1 | dispatch.sh + manifest.conf + tests | ~200 new |
| 2 | Hook stdin migration (4 hooks) | ~20 changed |
| 3 | atomic_junction utility + tests | ~60 new |
| 4 | New setup.sh | ~200 new (replaces ~1400) |
| 5 | Simplified install.sh | ~60 (replaces ~108) |
| 6 | Simplified bin/baton | ~250 (replaces ~360) |
| 7 | IDE adapter dispatchers | ~20 new |
| 8 | SessionStart auto-junction | ~15 new |
| 9 | Self-install + migration testing | fixes only |
| 10 | Cleanup committed symlinks | removal + .gitignore |
