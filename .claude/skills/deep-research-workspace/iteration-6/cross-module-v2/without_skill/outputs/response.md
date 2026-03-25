# Baton Junction Mechanism: Copy-Mode Fallback Complete Decision Chain

## Summary

`atomic_junction()` in `junction.sh` implements a three-tier fallback strategy: NTFS junction -> symlink -> copy. The copy-mode fallback triggers when **both** junction creation and symlink creation fail. `setup.sh` consumes the return code to set a project-wide `COPY_MODE` flag and stamp a `.copy-mode` sentinel file. The `baton` CLI then uses that sentinel to adjust its update and health-check behavior.

---

## Tier 1: The Core Decision — `atomic_junction()` in `junction.sh`

**File**: `.baton/hooks/lib/junction.sh`, lines 8-36

The function tries three strategies in order, returning 0 (success, linked) or 1 (fallback, copied):

### Step 1: NTFS Junction (Windows only)

```bash
if command -v cygpath >/dev/null 2>&1; then
    cmd //c "mklink /J \"$_win_dst\" \"$_win_src\"" >/dev/null 2>&1 && return 0
    cmd //c "mklink /J $_win_dst $_win_src" >/dev/null 2>&1 && return 0
fi
```

**Triggers this step**: `cygpath` exists (Git Bash / MSYS2 / Cygwin on Windows).

**Falls through when**:
- `cygpath` is not available (not on Windows) -- skips entirely
- `mklink /J` fails with quoted paths AND unquoted paths. Failure reasons:
  - Insufficient filesystem permissions (rare for junctions, but possible in locked-down enterprise)
  - Source path doesn't exist or is inaccessible
  - Destination is on a non-NTFS filesystem (FAT32, exFAT, network share)
  - Path contains characters that break both quoting strategies

The two attempts (quoted then unquoted) exist because different Git Bash versions handle `cmd //c` argument escaping differently.

### Step 2: Symlink (all platforms)

```bash
ln -sf "$_src" "$_dst" 2>/dev/null && [ -L "$_dst" ] && return 0
```

**Falls through when**:
- `ln -s` itself fails (stderr suppressed) -- e.g., filesystem doesn't support symlinks
- `ln -s` appears to succeed but `[ -L "$_dst" ]` is false -- this catches the case where `ln` silently creates something other than a symlink, or where the `-f` flag removed the target but the symlink creation still failed
- On Windows without Developer Mode: `ln -s` in Git Bash typically fails because symlink creation requires either Developer Mode enabled or admin privileges

### Step 3: Copy (universal fallback)

```bash
cp -r "$_src" "$_dst"
return 1
```

Always succeeds (barring disk full / permission errors). **Returns 1** to signal to the caller that this is a degraded copy, not a live link.

**Key design detail**: the return code is the entire API contract. Callers that care about the distinction check it; callers that don't use `|| true`.

---

## Tier 2: `setup.sh` Consuming the Return Code

### `.baton/` Directory Junction (Critical Path)

**File**: `setup.sh`, lines 124-139 (`create_baton_junction`)

```bash
if atomic_junction "$_baton_src" "$PROJECT_DIR/.baton"; then
    echo "  .baton/ -> junction to source"
else
    COPY_MODE=1
    touch "$PROJECT_DIR/.baton/.copy-mode"
    echo "  .baton/ copied (no junction support). Updates need 'baton update'."
fi
```

This is the **only call site where the return code materially changes setup behavior**:
- `COPY_MODE=1` is set as a script-global variable
- `.baton/.copy-mode` sentinel file is created inside the copied directory
- The sentinel persists across sessions -- it's the durable marker that this project can't use junctions

The `COPY_MODE` variable is checked at the end of `setup.sh` (line 681) to print a warning:
```bash
if [ "$COPY_MODE" = "1" ]; then
    echo "  Running in copy mode. Run 'baton update' after updating baton source."
fi
```

### Skill Junctions (Non-Critical Path)

**File**: `setup.sh`, lines 143-181 (`create_skill_junctions`)

```bash
atomic_junction "$_src" "$_dst" || true
```

Skill junctions use `|| true` -- they **swallow the failure**. If a skill junction falls back to copy, no sentinel is set and no warning is emitted for that specific skill. The rationale: if the `.baton/` directory itself is already a junction, skills inside it are accessible through that junction anyway. The per-IDE skill directories (`.claude/skills/`, `.cursor/skills/`, `.agents/skills/`) are convenience links.

However, if `.baton/` is already in copy-mode, the skill directories are also copies (they're sourced from inside the copied `.baton/skills/`), so the copy-mode sentinel on `.baton/` implicitly covers skills too.

---

## Tier 3: `baton` CLI Using the Copy-Mode Sentinel

**File**: `bin/baton`

### Health Check (`baton check`)

Lines 67-81 -- detects installation type by checking, in order:
1. `[ -L "$_dir/.baton" ]` -- junction/symlink (healthy v4)
2. `[ -f "$_dir/.baton/.copy-mode" ]` -- copy-mode (degraded v4)
3. `[ -d "$_dir/.baton" ]` with skills + dispatch -- self-install (baton source repo)
4. `[ -d "$_dir/.baton" ]` without the above -- old-style copy (pre-v4)
5. Otherwise -- not found

Lines 108-113 -- skill health assessment distinguishes junction-expected vs copy-mode projects to avoid false warnings about non-junction skill directories.

### Update (`baton update`)

Lines 315-370 -- two distinct update paths:

**Copy-mode projects** (line 329: `[ -f "$_dir/.baton/.copy-mode" ]`):
- Deletes the entire `.baton/` directory
- Re-copies from `$BATON_HOME/.baton`
- Re-stamps `.copy-mode` sentinel
- Re-copies each skill to each IDE skills directory
- No attempt to re-try junction creation (stays in copy mode permanently unless user runs `baton init` again)

**Junction projects** (line 343: `[ -L "$_dir/.baton" ]`):
- `.baton/` itself is already live-linked, so git pull on `$BATON_HOME` automatically updates it
- Scans for "stale" skill directories that are plain dirs instead of junctions and repairs them by calling `atomic_junction`

### Junction Health (`baton update --check`)

Lines 300-312 -- reads the project registry and classifies each project as junction / copy-mode / old-style.

---

## Complete Fallback Scenario Walkthrough

The most common scenario where copy-mode activates:

1. **Windows machine without Developer Mode, NTFS junction fails for some reason**
2. `setup.sh` runs, calls `atomic_junction "$BATON_HOME/.baton" "$PROJECT_DIR/.baton"`
3. `atomic_junction` tries `mklink /J` -- fails (e.g., path on a network share)
4. `atomic_junction` tries `ln -sf` -- fails (no Developer Mode, no admin)
5. `atomic_junction` does `cp -r`, returns 1
6. `setup.sh` catches the return 1, sets `COPY_MODE=1`, stamps `.copy-mode`
7. Skill junctions also fall back to copy (same environment limitations), but silently via `|| true`
8. All subsequent `baton update` calls detect `.copy-mode` and use the copy-refresh path
9. `baton check` reports the project as copy-mode

**On Linux/macOS**, copy-mode is essentially unreachable because `ln -sf` (step 2 in `atomic_junction`) reliably works on all standard filesystems.

---

## Key Files

| File | Role |
|------|------|
| `.baton/hooks/lib/junction.sh` | Core `atomic_junction()` function -- three-tier fallback logic |
| `setup.sh` | Consumes return code, sets `COPY_MODE` flag, creates `.copy-mode` sentinel |
| `bin/baton` | Reads `.copy-mode` sentinel for health checks and update strategy |
| `.baton/.copy-mode` | Sentinel file -- durable marker that a project is in degraded copy mode |

## Design Observations

1. **Junction is the default and strongly preferred** -- NTFS junctions don't require Developer Mode or admin rights (unlike symlinks), so they work on most Windows installs. The two-attempt strategy (quoted/unquoted paths) handles Git Bash escaping quirks.

2. **Copy-mode is sticky** -- once a project enters copy-mode, `baton update` keeps it in copy-mode. Only a fresh `baton init` (re-running setup.sh) can attempt to restore junction mode.

3. **Asymmetric error handling** -- the `.baton/` junction is the critical path (return code checked, sentinel stamped). Skill junctions are convenience links (failures swallowed). This makes sense because if `.baton/` itself is a junction, skills are already accessible through it.

4. **No runtime junction checks** -- hooks and dispatch don't verify junction health at runtime. A broken junction would manifest as missing files, not a graceful fallback.
