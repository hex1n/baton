**Question**: baton 的 junction 机制在什么情况下会 fallback 到 copy mode？追踪完整的判断链，包括 setup.sh 和 junction.sh 的交互。
**Depth**: Standard
**Key finding**: `atomic_junction()` 使用三级 fallback 链：NTFS junction -> symlink -> copy。只有当前两者都失败时才进入 copy mode，而 `setup.sh` 通过检查 `atomic_junction` 的返回值来决定是否启用 copy-mode 标记和后续行为。
**Open questions**: 1 -- 见文末

---

## Overview: Junction Distribution Architecture

Baton 使用 junction-based 分发模型：`~/.baton/` 是唯一的源（single source of truth），项目通过 NTFS junction / symlink / copy 引用它。整个判断链涉及三个层次：

```
setup.sh (orchestrator)
  |
  |-- sources junction.sh (line 54)
  |-- calls atomic_junction() for .baton/ junction (line 133)
  |-- calls atomic_junction() for each skill junction (lines 163, 177)
  |
  v
junction.sh::atomic_junction() (decision engine)
  |
  |-- Step 1: NTFS junction (via mklink /J)  --> return 0 on success
  |-- Step 2: symlink (via ln -sf)           --> return 0 on success
  |-- Step 3: copy (via cp -r)               --> return 1 (always succeeds as last resort)
  |
  v
setup.sh reads return code
  |-- return 0 --> junction/symlink mode (live link, auto-updates)
  |-- return 1 --> copy mode (static snapshot, needs manual "baton update")
```

## The Decision Chain in Detail

### Layer 1: `atomic_junction()` -- the three-step fallback

Source: `.baton/hooks/lib/junction.sh:8-36`

The function takes `SRC` and `DST` arguments and tries three linking strategies in order:

**Step 1: NTFS Junction (Windows only)**
```bash
if command -v cygpath >/dev/null 2>&1; then
    # Convert to Windows paths
    cmd //c "mklink /J \"$_win_dst\" \"$_win_src\"" >/dev/null 2>&1 && return 0
    # Retry without inner quotes (Git Bash compatibility)
    cmd //c "mklink /J $_win_dst $_win_src" >/dev/null 2>&1 && return 0
fi
```
Trigger condition: `cygpath` is available (i.e., running in Git Bash / MSYS2 on Windows). Two attempts are made with different quoting strategies because some Git Bash versions handle quote escaping differently in `cmd //c` invocations. (`junction.sh:20-28`)

NTFS junction fails when:
- Not on Windows (no `cygpath`)
- `mklink /J` fails -- this can happen due to: filesystem not NTFS (e.g., FAT32, exFAT, network share), insufficient permissions on specific NTFS configurations, or paths that contain characters the cmd shell can't handle even with both quoting strategies

**Step 2: Symlink (cross-platform)**
```bash
ln -sf "$_src" "$_dst" 2>/dev/null && [ -L "$_dst" ] && return 0
```
Two conditions must both pass: `ln -sf` must succeed AND the result must actually be a symlink (`[ -L "$_dst" ]`). (`junction.sh:31`)

Symlink fails when:
- On Windows without Developer Mode enabled (Windows requires elevated privileges or Developer Mode for `ln -s`)
- Filesystem doesn't support symlinks (some network filesystems, restricted environments)
- The `ln -sf` command succeeds but creates a regular file instead of a symlink (edge case on certain configurations -- the `[ -L "$_dst" ]` guard catches this)

**Step 3: Copy fallback (always succeeds)**
```bash
cp -r "$_src" "$_dst"
return 1
```
This is the unconditional fallback. Note the critical design detail: it returns `1`, not `0`. This signals to the caller that a copy was made rather than a live link. (`junction.sh:34-35`)

### Layer 2: `setup.sh` -- how it uses the return code

#### For `.baton/` directory junction (`create_baton_junction`, line 124-140)

```bash
if atomic_junction "$_baton_src" "$PROJECT_DIR/.baton"; then
    echo "  ✓ .baton/ → junction to source"
else
    COPY_MODE=1
    touch "$PROJECT_DIR/.baton/.copy-mode"
    echo "  ⚠ .baton/ copied (no junction support). Updates need 'baton update'."
fi
```

When `atomic_junction` returns 1 (copy fallback), `setup.sh`:
1. Sets `COPY_MODE=1` (a shell variable used later in the script) (`setup.sh:136`)
2. Creates a `.copy-mode` marker file inside the copied `.baton/` directory (`setup.sh:137`)
3. Prints a warning about needing manual updates (`setup.sh:138`)
4. At the end of setup, prints a final copy-mode warning (`setup.sh:681-682`)

Note: self-install mode (running setup inside the baton repo itself) bypasses junction creation entirely -- it detects the real `.baton/` directory and returns early. (`setup.sh:125-128`)

#### For skill junctions (`create_skill_junctions`, lines 143-181)

```bash
atomic_junction "$_src" "$_dst" || true
```

Skill junction failures are **silently swallowed** (`|| true`). (`setup.sh:163, 177`) This is a deliberate design choice: skill junctions failing is non-fatal. If the `.baton/` junction works but individual skill junctions fall back to copy, the skills still function -- they just won't auto-update. No `.copy-mode` marker is created for individual skills.

### Layer 3: Runtime junction repair -- `phase-guide.sh`

Source: `.baton/hooks/phase-guide.sh:50-66`

At every `SessionStart` event, `phase-guide.sh` auto-repairs missing skill junctions:

```bash
for _skill_dir in "$_skill_src"/baton-*; do
    ...
    _target="$_ide_skills/$_name"
    [ -d "$_target" ] && continue          # skip if already exists
    atomic_junction "$_skill_dir" "$_target" 2>/dev/null || true
done
```

This only runs for `baton-*` prefixed skills (not all skills), and only creates missing junctions -- it won't replace existing directories. Like `create_skill_junctions`, failures are silently ignored. (`phase-guide.sh:63`)

### Layer 4: `baton update` -- copy-mode recovery

Source: `bin/baton`, around line 326

When `baton update` runs, it scans all registered projects:

```bash
if [ -f "$_dir/.baton/.copy-mode" ]; then
    echo "  Refreshing copy-mode project: $_dir"
    rm -rf "$_dir/.baton"
    cp -r "$BATON_HOME/.baton" "$_dir/.baton"
    touch "$_dir/.baton/.copy-mode"     # re-create marker
    ...
fi
```

Copy-mode projects get a full re-copy from `~/.baton/.baton`. The `.copy-mode` marker is re-created after each refresh, so the project stays in copy-mode permanently unless the junction capability issue is resolved. (`bin/baton:329-333`)

`baton update --check` also detects and reports copy-mode projects. (`bin/baton:307-308`)

## Summary: Complete Fallback Decision Tree

```
atomic_junction(SRC, DST) called
  |
  +-- Is DST non-empty? (guard: junction.sh:13)
  |     No --> return 1 immediately (no operation)
  |
  +-- Does DST exist? (junction.sh:15-17)
  |     Yes --> rm -rf DST (clean slate for all strategies)
  |
  +-- Is cygpath available? (Windows detection, junction.sh:20)
  |     |
  |     Yes --> Try mklink /J with quoted paths
  |     |       Success? --> return 0 (NTFS junction)
  |     |       Fail --> Try mklink /J without inner quotes
  |     |               Success? --> return 0 (NTFS junction)
  |     |               Fail --> continue to Step 2
  |     |
  |     No --> continue to Step 2
  |
  +-- Try ln -sf AND verify -L test (junction.sh:31)
  |     Both pass? --> return 0 (symlink)
  |     Either fails --> continue to Step 3
  |
  +-- cp -r SRC DST (junction.sh:34-35)
        Always succeeds (barring disk/permission errors)
        return 1 (signals copy-mode to caller)
```

**Callers react differently to return 1:**

| Caller | Location | On return 1 |
|--------|----------|-------------|
| `create_baton_junction()` | `setup.sh:133` | Sets `COPY_MODE=1`, creates `.copy-mode` marker, warns user |
| `create_skill_junctions()` | `setup.sh:163,177` | Silently continues (`\|\| true`) |
| `phase-guide.sh` auto-repair | `phase-guide.sh:63` | Silently continues (`\|\| true`) |

## Concrete Scenarios That Trigger Copy Mode

1. **Windows without NTFS**: USB drive formatted as FAT32/exFAT, network share with non-NTFS filesystem. mklink /J fails because junctions are an NTFS feature. Symlink also fails without Developer Mode.

2. **Windows without Developer Mode and without admin**: Both mklink /J (rare failure case on some locked-down corporate configs) and ln -s (needs Developer Mode) fail.

3. **Restricted Linux/macOS environment**: A container or chroot where symlink creation is disabled (e.g., certain Docker volume mounts, read-only overlayfs layers). `ln -sf` fails or creates a regular file instead.

4. **Cross-filesystem on Unix without symlink support**: Unusual but possible with certain FUSE mounts or network filesystems that don't support symlinks.

## Open Questions

1. **Empty DST guard behavior**: When `_dst` is empty (`junction.sh:13`), `atomic_junction` returns 1 without doing any copy. This means the caller's "copy fallback" logic triggers but no actual copy happened. In `create_baton_junction`, this would set `COPY_MODE=1` and try to `touch "$PROJECT_DIR/.baton/.copy-mode"` on a nonexistent directory, which would fail silently. This edge case appears to be a theoretical concern only -- `_dst` is always constructed from `$PROJECT_DIR` which is validated earlier -- but it's not explicitly guarded at the caller level. (Unverified: no test covers this path.)

## 批注区
