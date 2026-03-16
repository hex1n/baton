# Plan: setup.sh — directory-level symlinks for skill installation

## State: APPROVED
## Complexity: Small

## Problem

`install_skills()` in setup.sh symlinks only `SKILL.md` per skill directory. New files added alongside SKILL.md (e.g., `investigation-infrastructure.md`, `template-codebase.md`, `template-external.md`) won't be available in target projects after installation.

## Requirements

- [HUMAN] chat: Use directory-level symlinks instead of file-level symlinks
- Must preserve: atomic_link/atomic_copy fallback for Windows
- Must preserve: self-install detection and verification
- Must preserve: uninstall cleanup
- Must preserve: .agents/ fallback directory

## Approach

Change `install_skills()` to symlink the entire skill directory (`$_skill_source_dir/$_skill` → `$_ide_dir`) instead of individual SKILL.md files.

### What changes

**1. Install loop (lines 871-895)** — currently:
```sh
_src="$_skill_source_dir/$_skill/SKILL.md"
mkdir -p "$_ide_dir"
atomic_link "$_src" "$_dst"   # _dst = $_ide_dir/SKILL.md
```
Change to: symlink the directory itself. Remove `mkdir -p` (the symlink replaces the directory). Remove any existing directory/symlink at `$_ide_dir` before creating the new symlink.

**2. Self-install check (lines 845-862)** — currently checks:
```sh
_check="$PROJECT_DIR/$_check_dir/$_skill/SKILL.md"
if [ ! -L "$_check" ] || [ ! -f "$_check" ]; then
```
Change to: check if the directory itself is a symlink:
```sh
_check="$PROJECT_DIR/$_check_dir/$_skill"
if [ ! -L "$_check" ] || [ ! -d "$_check" ]; then
```

**3. Uninstall loop (lines 447-458)** — currently:
```sh
if [ -d "$_skill_dir" ]; then
    rm -rf "$_skill_dir"
fi
```
This already handles both real directories and symlinks (`rm -rf` on a symlink removes the link, not the target). No change needed, but add `[ -L "$_skill_dir" ]` check for clarity.

**4. Copy fallback path** — `atomic_link` falls back to `atomic_copy` on Windows without symlink support. For directory-level operation, the fallback needs to copy the entire directory, not just one file. Need to add `atomic_link_dir` or adjust `atomic_link` to handle directories.

**5. Symlink copy-warning check (lines 909-921)** — currently checks `SKILL.md` file symlink. Change to check directory symlink.

### Key design decision: atomic_link for directories

Current `atomic_link` creates a file symlink with atomic mv. For directories:
- `ln -sf` can create a symlink to a directory
- Fallback: `cp -r` instead of `cp` for directory copy
- Atomic mv still works for renaming a symlink

Add `atomic_link_dir()` that:
1. Removes existing target (directory or symlink)
2. Creates symlink via `ln -s`
3. Falls back to `cp -r` if symlinks not supported

### Surface Scan

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `setup.sh` `install_skills()` | L1 | modify | Install loop, self-install check, copy-warning |
| `setup.sh` `atomic_link()` | L1 | keep + add `atomic_link_dir()` | Need directory-level equivalent |
| `setup.sh` uninstall section | L1 | skip | Already handles symlinks via `rm -rf` |
| `tests/test-setup.sh` | L2 | verify | May need updates if tests check file-level symlinks |
| `tests/test-cli.sh` | L2 | verify | May reference skill file paths |

### Write Set

- `setup.sh` — modify (`install_skills`, add `atomic_link_dir`, self-install check, copy-warning check)

### Verification

1. Run `bash setup.sh` on baton repo itself (self-install) — verify symlinks intact
2. Run `bash setup.sh /tmp/test-project` — verify directory symlinks created
3. Run existing tests: `tests/test-setup.sh`

## Self-Challenge

1. **Directory symlink vs file symlink for .agents/ fallback**: `.agents/` is used by platforms that may not handle directory symlinks the same way. Need to verify. The atomic_link fallback to copy already handles this — on platforms where symlinks fail, it copies the directory.

2. **Existing installations**: Projects that already have file-level symlinks need migration. The install path should handle replacing old file-symlink-in-directory with new directory-symlink. Removing the old directory before creating the new symlink covers this.

3. **What if a user added custom files to a skill directory in their project?**: Directory symlinks would replace those. But baton skill directories should only contain baton-managed files, so this is acceptable. The uninstall already does `rm -rf`.

## 批注区

### [Annotation 1]
- Trigger / 触发点: 我看了一下现在的setup.sh 有1500多行代码 能优化吗?
- Intent as understood / 理解后的意图: setup.sh 太长了，是否可以重构/简化
- Response / 回应: 能优化，但这是一个独立的任务，不应混入当前的 symlink 改动。1500+ 行 shell 脚本的重构涉及：拆分为多个文件（install/uninstall/migrate/utils）、减少重复的 IDE 适配逻辑、简化迁移路径等。建议当前任务只做 directory symlink 改动，setup.sh 重构作为后续独立任务。
- Status: ✅ accepted (as separate task)
- Impact: none — 不影响当前 plan
- 
<!-- BATON:GO -->

## Retrospective

- **Surprise**: Multi-plan detection by hooks caused a significant delay — the hook blocks ALL writes (including mv/rename) when multiple plan files exist, creating a circular dependency. Future tasks: clean up completed plans immediately or use BATON_PLAN env var.
- **Wrong prediction**: Expected uninstall tests might need changes, but the 2 failures (uninstall @import cleanup) are pre-existing bugs unrelated to our changes.
- **What went well**: The actual code change was straightforward — `atomic_link_dir` follows the same pattern as `atomic_link`, and the install loop change was clean. The self-install repair path worked correctly on first run.

<!-- BATON:COMPLETE -->

## Todo

- [x] 1. Add `atomic_link_dir()` function
  Change: Add directory-level symlink function after existing `atomic_link()`. Removes existing target (dir or symlink), creates symlink, falls back to `cp -r` on Windows.
  Files: `setup.sh`
  Verify: Read function, verify it handles: symlink creation, existing dir removal, existing symlink removal, cp -r fallback
  Deps: none
  Artifacts: none

- [x] 2. Modify `install_skills()` install loop to use directory symlinks
  Change: Replace file-level `atomic_link` of SKILL.md with directory-level `atomic_link_dir` of entire skill directory. Remove `mkdir -p` for IDE dirs. Update `.agents/` fallback similarly.
  Files: `setup.sh`
  Verify: Read modified install loop, verify it symlinks directories not files; verify migration from old file-symlinks handled (rm existing dir before symlink)
  Deps: 1

- [x] 3. Update self-install check to verify directory symlinks
  Change: Change check from `SKILL.md` file symlink to skill directory symlink (`[ ! -L "$_check" ] || [ ! -d "$_check" ]`)
  Files: `setup.sh`
  Verify: Read modified check, verify it checks directory symlink not file symlink
  Deps: none

- [x] 4. Update copy-warning check to verify directory symlinks
  Change: Change sample check from `SKILL.md` file to skill directory (`[ ! -L "$_sample_dir" ]`)
  Files: `setup.sh`
  Verify: Read modified check, verify it checks directory not file
  Deps: none

- [x] 5. Run verification
  Change: none (verification only)
  Files: none
  Verify: Run `bash setup.sh` (self-install), verify all `.claude/skills/baton-*` are directory symlinks; run `tests/test-setup.sh`
  Deps: 1, 2, 3, 4
  Artifacts: none