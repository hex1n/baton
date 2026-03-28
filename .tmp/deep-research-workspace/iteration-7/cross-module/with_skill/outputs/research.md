# Junction Fallback to Copy Mode: Complete Decision Chain

**Depth**: Deep -- cross-module trace across 4 files with version-dependent behavior.

**Key finding**: `atomic_junction()` implements a three-tier fallback chain: NTFS junction -> symlink -> copy. Copy mode activates only when **both** junction and symlink creation fail. The fallback handling differs between the two call sites in `setup.sh`: `.baton/` main directory failure triggers a persistent `COPY_MODE` flag and `.copy-mode` marker file; skill directory failures are silently swallowed. In v5 (current master), the junction mechanism has been removed from setup entirely -- it only survives in the worktree v4 code and in `phase-guide.sh`'s auto-junction for skills.

---

## Architecture: Two Versions

The codebase contains two install architectures:

| Version | File | Junction usage |
|---------|------|---------------|
| **v4** (worktrees) | `setup.sh` (v4, junction-based) | Full junction for `.baton/` and skills |
| **v5** (current master) | `setup.sh` (v5, flat install) | No junction -- user-level symlinks via `ln -sf` |

The junction mechanism (`junction.sh`) only exists in worktree copies (e.g., `.claude/worktrees/frosty-jemison/.baton/hooks/lib/junction.sh`), not in the main project root's `.baton/hooks/lib/`. The v5 setup.sh uses direct `ln -sf` for skills and user-level settings instead of project-level junctions. `junction.sh` is the v4 architecture. `setup.sh:181-200` (v5) still references "junction" in comments during the `--migrate` path, cleaning up v4 remnants.

---

## Layer 1: `atomic_junction()` -- The Fallback Chain

**File**: `.baton/hooks/lib/junction.sh` (v4 only)

```bash
atomic_junction() {
    local _src="$1" _dst="$2"

    # Remove existing target (old install, stale symlink, partial copy)
    if [ -e "$_dst" ] || [ -L "$_dst" ]; then
        rm -rf "$_dst"
    fi

    # 1. Try NTFS junction (Windows, no Developer Mode needed)
    if command -v cygpath >/dev/null 2>&1; then
        cmd //c "mklink /J \"$_win_dst\" \"$_win_src\"" >/dev/null 2>&1 && return 0
        cmd //c "mklink /J $_win_dst $_win_src" >/dev/null 2>&1 && return 0
    fi

    # 2. Try symlink (Linux/macOS, or Windows with Developer Mode)
    ln -sf "$_src" "$_dst" 2>/dev/null && [ -L "$_dst" ] && return 0

    # 3. Fallback: copy
    cp -r "$_src" "$_dst"
    return 1
}
```

`junction.sh:8-33`

**Return value contract**:
- `return 0` = junction or symlink succeeded (live link)
- `return 1` = fell back to copy (static snapshot, no auto-update)

**Decision points that trigger copy fallback**:

1. **NTFS junction failed**: `cygpath` exists (= Windows/Cygwin/MSYS) but `mklink /J` failed in both quoted and unquoted variants. Causes: insufficient permissions, cross-drive paths, antivirus interference, NTFS junction not supported on target filesystem.
2. **Symlink failed**: `ln -sf` returned non-zero OR `[ -L "$_dst" ]` check failed (destination exists but is not a symlink -- can happen on some filesystems that don't support symlinks). Causes: non-Unix filesystem (FAT32, exFAT), restrictive OS permissions, Windows without Developer Mode when Cygwin path is not available.
3. **Both 1 and 2 failed**: Only then does `cp -r` execute and `return 1` signal copy mode.

On Linux/macOS, step 2 (`ln -sf`) virtually always succeeds on standard filesystems (ext4, APFS, HFS+, etc.), making copy mode essentially unreachable. `junction.sh:28`

---

## Layer 2: `setup.sh` v4 -- Two Call Sites with Different Handling

### Call Site A: `.baton/` Main Directory (`create_baton_junction()`)

`setup.sh:124-140` (v4 worktree version)

```bash
create_baton_junction() {
    if [ "$SELF_INSTALL" = "1" ]; then
        return    # self-install: .baton/ IS the source
    fi
    _baton_src="$BATON_HOME/.baton"
    [ ! -d "$_baton_src" ] && _baton_src="$BATON_DIR/.baton"

    if atomic_junction "$_baton_src" "$PROJECT_DIR/.baton"; then
        echo "  junction ok"
    else
        COPY_MODE=1                                  # return 1 = copy fallback
        touch "$PROJECT_DIR/.baton/.copy-mode"       # persistent marker
        echo "  .baton/ copied, no junction support"
    fi
}
```

**When fallback fires**:
- `atomic_junction` returns 1 (copy fallback executed)
- `COPY_MODE=1` set as shell variable (affects end-of-script warning at line 687)
- `.baton/.copy-mode` empty marker file created inside the copied directory (persistent across sessions)

**Downstream effect**: At end of `setup.sh:687-689`:
```bash
if [ "$COPY_MODE" = "1" ]; then
    echo "  Running in copy mode. Run 'baton update' after updating baton source."
fi
```

### Call Site B: Skill Directories (`create_skill_junctions()`)

`setup.sh:143-182` (v4 worktree version)

```bash
for _skill in $BATON_SKILL_NAMES; do
    _src="$_skill_src/$_skill"
    [ ! -d "$_src" ] && continue
    _dst="$_skills_dir/$_skill"
    [ -L "$_dst" ] && continue          # already a junction, skip
    atomic_junction "$_src" "$_dst" || true   # <-- || true swallows return code
done
```

**Key difference**: `|| true` at `setup.sh:163,177` means:
- **No COPY_MODE flag set** for skill-level failures
- **No `.copy-mode` marker created** for individual skills
- Failures are completely silent

**Design rationale**: If the main `.baton/` junction fails, the skill source paths (`$PROJECT_DIR/.baton/skills/...`) are inside the already-copied directory, so they are copies too. The main `.copy-mode` marker already covers this scenario. If `.baton/` junction succeeds but a skill junction individually fails, the skill still works (as a copy) -- it just won't auto-update when baton source changes.

---

## Layer 3: `phase-guide.sh` -- SessionStart Auto-Junction

`phase-guide.sh:50-67` (v4 worktree version, present in `.baton/hooks/phase-guide.sh`)

```bash
if [ -d "$SCRIPT_DIR/../skills" ]; then
    _skill_src="$(cd "$SCRIPT_DIR/../skills" && pwd)"
    . "$SCRIPT_DIR/lib/junction.sh" 2>/dev/null || true
    for _skill_dir in "$_skill_src"/baton-*; do
        [ ! -d "$_skill_dir" ] && continue
        _name="$(basename "$_skill_dir")"
        _proj="${BATON_PROJECT_DIR:-$(pwd)}"
        for _ide_skills in "$_proj/.claude/skills" "$_proj/.cursor/skills" "$_proj/.agents/skills"; do
            [ -d "$_ide_skills" ] || continue
            _target="$_ide_skills/$_name"
            [ -d "$_target" ] && continue    # already exists, skip
            atomic_junction "$_skill_dir" "$_target" 2>/dev/null || true
        done
    done
fi
```

This runs at every session start. It **only creates missing** skill junctions (skips existing ones with `[ -d "$_target" ] && continue`). Failures are silently swallowed (`|| true`). This handles the case where baton adds a new skill after initial setup -- the next session auto-creates the junction without requiring re-running `setup.sh`.

This auto-junction does NOT exist in the v5 `phase-guide.sh` (`hooks/phase-guide.sh` in master root), which has no junction logic at all.

---

## Layer 4: `baton update` -- Copy-Mode Recovery (v4 Only)

`bin/baton:315-342` (v4 worktree version)

When `baton update` runs against registered projects:

```bash
if [ -f "$_dir/.baton/.copy-mode" ]; then
    rm -rf "$_dir/.baton"
    cp -r "$BATON_HOME/.baton" "$_dir/.baton"
    touch "$_dir/.baton/.copy-mode"     # re-create marker
    # Also re-copy skills to all IDE dirs
    for _skill_dir in "$BATON_HOME/.baton/skills"/baton-*; do
        _name="$(basename "$_skill_dir")"
        for _ide_skills in "$_dir/.claude/skills" ...; do
            rm -rf "$_ide_skills/$_name"
            cp -r "$_skill_dir" "$_ide_skills/$_name"
        done
    done
fi
```

**Copy-mode is sticky**: `baton update` never retries junction creation. It always re-copies and re-stamps `.copy-mode`. The only way to exit copy-mode is to manually delete `.copy-mode` and re-run `setup.sh` (which will re-attempt `atomic_junction`).

`baton update --check` (`bin/baton:295-313`) classifies projects into three states:
1. `[ -L "$_dir/.baton" ]` -- junction (healthy)
2. `[ -f "$_dir/.baton/.copy-mode" ]` -- copy-mode (degraded)
3. `[ -d "$_dir/.baton" ]` -- old-style (needs re-init)

---

## Layer 5: v5 Migration (`setup.sh:171-232` on master)

The current v5 `setup.sh` on master has a `--migrate` command that cleans up v4 junction artifacts:

```bash
# Remove .baton junction/symlink (not the source directory)
if [ -L "$_dir/.baton" ]; then
    rm -f "$_dir/.baton"
elif [ -d "$_dir/.baton" ] && [ ! -f "$_dir/.baton/dispatch.sh" ]; then
    rm -rf "$_dir/.baton"    # copy, not source repo
fi
# Remove skill junctions from IDE directories
for _ide_skills in .claude/skills .cursor/skills .agents/skills; do ...
```

v5 replaces project-level junctions with user-level symlinks in `~/.claude/skills/` via simple `ln -sf`, which never has a copy fallback -- if `ln -sf` fails in v5, setup just prints an error and returns 1.

---

## Complete Decision Flow (v4)

```
setup.sh starts
  |
  +-- source junction.sh (line 54)
  |
  +-- create_baton_junction() (line 660)
  |       |
  |       +-- SELF_INSTALL=1? --> skip (line 125-128)
  |       |
  |       +-- atomic_junction($src, $dst)
  |               |
  |               +-- cygpath available? (Windows)
  |               |       +-- mklink /J (quoted) --> success? return 0
  |               |       +-- mklink /J (unquoted) --> success? return 0
  |               |
  |               +-- ln -sf --> created? && is symlink? --> return 0
  |               |
  |               +-- cp -r --> return 1  (COPY FALLBACK)
  |                       |
  |                       caller: COPY_MODE=1
  |                               touch .baton/.copy-mode
  |
  +-- create_skill_junctions() (line 661)
  |       |
  |       +-- for each skill x IDE:
  |               atomic_junction($src, $dst) || true
  |               (failures silently swallowed)
  |
  +-- [end] if COPY_MODE=1: print warning (line 687-689)
```

---

## Conditions Summary: When Does Copy Mode Activate?

| Condition | Affects | Evidence |
|-----------|---------|----------|
| Windows without Cygwin/MSYS AND symlinks disabled | `.baton/` + skills | `junction.sh:17,28` |
| FAT32/exFAT filesystem (no symlink support) | `.baton/` + skills | `junction.sh:28` -- `ln -sf` fails or `[ -L ]` check fails |
| Cross-drive junction on Windows (NTFS limitation) | `.baton/` + skills | `junction.sh:22-24` -- `mklink /J` across drives fails |
| Restrictive permissions (sandboxed environment) | `.baton/` + skills | `junction.sh:22,28` -- both mklink and ln fail |
| Standard Linux/macOS with ext4/APFS/HFS+ | **Never** | `ln -sf` always works on these filesystems |

---

## Open Questions

1. **Copy-mode exit path**: In v4, `baton update` never retries junction. The only documented recovery is re-running `setup.sh` manually. This appears intentional (no explicit `--retry-junction` command exists) but is not documented for users beyond the setup-time warning message. `junction.sh` and `bin/baton` (v4 worktree)

---

## Weakest Conclusion

The claim that "copy mode is essentially unreachable on Linux/macOS" is based on the reasoning that `ln -sf` always works on standard filesystems. This is true for ext4, APFS, HFS+, and other common filesystems, but edge cases exist: network-mounted filesystems (some NFS configurations), FUSE mounts, container environments with restricted syscalls, or non-standard security modules (SELinux in strict mode). These could cause `ln -sf` to fail even on Linux/macOS. However, I found no code or documentation addressing these edge cases. The claim is reasonable but not rigorously verified against exotic environments.
