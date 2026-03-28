# Baton Junction Fallback 完整判断链分析

## 概览

Baton 的 junction 机制通过 `atomic_junction()` 函数（定义在 `.baton/hooks/lib/junction.sh`）实现三级降级策略：**NTFS junction → symlink → copy**。`setup.sh` 是主要调用方，负责在 fallback 到 copy 后设置全局标记和用户提示。`phase-guide.sh` 在运行时也会调用 `atomic_junction()` 进行技能目录的自动修复。

---

## 第一层：`atomic_junction()` 内部判断链

文件：`.baton/hooks/lib/junction.sh`（第 8-36 行）

```
atomic_junction SRC DST → 返回 0 表示 junction/symlink 成功，返回 1 表示 copy fallback
```

### 步骤 1：前置守卫

- 如果 `$_dst` 为空字符串，直接 `return 1`（防止 `rm -rf ""` 删除 CWD）。
- 如果目标路径已存在（`-e` 或 `-L`），先 `rm -rf` 清除。

### 步骤 2：尝试 NTFS Junction（仅 Windows）

**触发条件**：`command -v cygpath` 成功（即运行环境是 Git Bash / MSYS2 / Cygwin）。

操作：
1. 用 `cygpath -w` 将 Unix 路径转成 Windows 路径。
2. **第一次尝试**：`cmd //c "mklink /J \"$_win_dst\" \"$_win_src\""` — 带内引号，处理路径中的空格和特殊字符。
3. **第二次尝试**（第一次失败时）：`cmd //c "mklink /J $_win_dst $_win_src"` — 不带内引号，兼容某些 Git Bash 版本的引号处理差异。

**成功**时 `return 0`，不再继续。

**Junction 会失败的场景**：
- 跨驱动器卷（NTFS junction 不支持跨卷）
- 目标文件系统不是 NTFS（如 FAT32 的 USB、网络共享）
- 权限不足（某些受限企业环境禁止 mklink）
- 路径中包含 cygpath 或 cmd 无法处理的 Unicode 字符

### 步骤 3：尝试 Symlink（跨平台）

**触发条件**：步骤 2 未执行（非 Windows）或执行后失败。

操作：`ln -sf "$_src" "$_dst" 2>/dev/null && [ -L "$_dst" ]`

两个条件都满足才算成功：`ln` 命令返回 0 **且** 结果是一个符号链接。

**成功**时 `return 0`。

**Symlink 会失败的场景**：
- **Windows 无 Developer Mode**：普通用户没有 `SeCreateSymbolicLinkPrivilege`，`ln -s` 静默失败
- 目标文件系统不支持符号链接（如某些网络文件系统）
- `ln` 命令返回 0 但实际创建了硬链接或其他东西（因此有 `[ -L "$_dst" ]` 二次验证）

### 步骤 4：Fallback 到 Copy

**触发条件**：步骤 2 和 3 都失败。

操作：`cp -r "$_src" "$_dst"` 然后 `return 1`。

返回值 1 是关键信号——调用方通过这个返回值判断是否进入了 copy mode。

---

## 第二层：`setup.sh` 对返回值的处理

文件：`setup.sh`

### 2A：`.baton` 主目录 junction（第 124-140 行）

```sh
create_baton_junction() {
    # self-install 跳过（源码仓库本身不需要 junction）
    if [ "$SELF_INSTALL" = "1" ]; then return; fi

    # 确定 junction 源：优先 ~/.baton/.baton，回退到当前仓库的 .baton
    _baton_src="$BATON_HOME/.baton"
    [ ! -d "$_baton_src" ] && _baton_src="$BATON_DIR/.baton"

    if atomic_junction "$_baton_src" "$PROJECT_DIR/.baton"; then
        # 返回 0 → 成功
        echo "  ✓ .baton/ → junction to source"
    else
        # 返回 1 → copy fallback 触发
        COPY_MODE=1                              # 全局标记
        touch "$PROJECT_DIR/.baton/.copy-mode"   # 持久化标记文件
        echo "  ⚠ .baton/ copied (no junction support). Updates need 'baton update'."
    fi
}
```

**关键行为**：
1. 设置 `COPY_MODE=1` 全局变量（影响安装结束时的提示信息，第 681-683 行）。
2. 创建 `.baton/.copy-mode` 空文件——这是持久化的标记，后续 `baton check`、`baton update` 都依赖它。

### 2B：技能目录 junction（第 143-182 行）

```sh
create_skill_junctions() {
    for _skill in $BATON_SKILL_NAMES; do
        _dst="$_skills_dir/$_skill"
        [ -L "$_dst" ] && continue         # 已经是 junction/symlink，跳过
        [ -d "$_dst" ] && echo "..."       # 是普通目录，提示替换
        atomic_junction "$_src" "$_dst" || true   # ← 注意 || true
    done
}
```

**关键差异**：技能 junction 的 `atomic_junction` 调用末尾有 `|| true`，意味着即使 fallback 到 copy（返回 1），也不会触发错误处理。技能目录的 copy fallback 是**静默的**——不会设置 `COPY_MODE`，也不会创建标记文件。

**设计逻辑**：`.baton` 主目录的 copy-mode 标记已经涵盖了这种情况。如果主目录 junction 失败，技能 junction 也必然失败（同一文件系统/权限环境），所以单独标记是冗余的。

---

## 第三层：运行时自动修复 — `phase-guide.sh`

文件：`.baton/hooks/phase-guide.sh`（第 50-67 行）

```sh
if [ -d "$SCRIPT_DIR/../skills" ]; then
    . "$SCRIPT_DIR/lib/junction.sh" 2>/dev/null || true
    for _skill_dir in "$_skill_src"/baton-*; do
        for _ide_skills in ...; do
            [ -d "$_target" ] && continue          # 已存在就跳过
            atomic_junction "$_skill_dir" "$_target" 2>/dev/null || true
        done
    done
fi
```

这段代码在每次 SessionStart 时执行，检查所有 `baton-*` 技能目录。如果某个 IDE 的 skills 目录里缺少某个技能，尝试重新创建 junction。同样使用 `|| true` 静默降级。

---

## 第四层：`baton update` 的 copy-mode 恢复

文件：`bin/baton`（第 315-342 行）

```sh
if [ -f "$_dir/.baton/.copy-mode" ]; then
    echo "  Refreshing copy-mode project: $_dir"
    rm -rf "$_dir/.baton"
    cp -r "$BATON_HOME/.baton" "$_dir/.baton"
    touch "$_dir/.baton/.copy-mode"          # 重新标记
    # 同时复制所有技能目录...
fi
```

当 `.copy-mode` 标记存在时，`baton update` 知道这个项目无法使用 junction，所以：
1. 删除旧的 `.baton` 目录。
2. 从 `~/.baton/.baton` 全量复制。
3. 重新 touch `.copy-mode` 标记（因为 rm -rf 删掉了）。
4. 同时复制所有技能目录到各 IDE 的 skills 目录。

注意 `baton update` **不会重新尝试创建 junction**——一旦标记为 copy-mode，就永远是 copy-mode，除非用户手动删除标记并重新运行 `baton init`。

---

## 第五层：`baton check` 的诊断

文件：`bin/baton`（第 67-113 行）

`baton check` 通过三级判断识别安装类型：
1. `-L "$_dir/.baton"` → junction/symlink（正常状态）
2. `-f "$_dir/.baton/.copy-mode"` → copy-mode（降级状态）
3. `-d "$_dir/.baton"` + 检查内容 → self-install 或 old-style copy

对于技能目录，如果 `.baton` 是 junction 但某个技能不是（`[ ! -L "$_spath" ]`），标记为 "stale"。

---

## 完整 Fallback 判断链总结

```
setup.sh 被调用
  │
  ├── 是源码仓库（self-install）？ → 跳过 junction，直接使用
  │
  └── 非源码仓库
       │
       ├── atomic_junction(.baton) 被调用
       │    │
       │    ├── cygpath 存在（Windows）？
       │    │    ├── mklink /J（带引号） → 成功 → return 0
       │    │    ├── mklink /J（无引号） → 成功 → return 0
       │    │    └── 两次都失败 → 继续
       │    │
       │    ├── ln -sf && [ -L ] → 成功 → return 0
       │    │
       │    └── cp -r → return 1
       │
       ├── return 0：正常模式
       │    └── 技能 junction 同样尝试三级降级（静默 || true）
       │
       └── return 1：COPY_MODE=1 + touch .copy-mode
            ├── 技能也 cp -r（静默）
            ├── 安装结束提示用户
            └── baton update 识别标记，全量复制更新
```

---

## 会触发 Copy Fallback 的具体场景

| 场景 | 原因 | 阶段 |
|------|------|------|
| 非 NTFS 文件系统的 Windows | mklink /J 不支持 FAT32/exFAT | 步骤 2 失败 |
| 跨驱动器卷的 junction | NTFS junction 不支持跨卷 | 步骤 2 失败 |
| Windows 无 Developer Mode + 受限用户 | 无 symlink 权限 + junction 也因某种原因失败 | 步骤 2+3 失败 |
| 企业安全策略禁止 mklink | 组策略限制 | 步骤 2 失败 |
| 网络共享/远程文件系统 | 不支持 junction 和 symlink | 步骤 2+3 失败 |
| Linux/macOS 上无 symlink 权限 | 文件系统或 SELinux 限制 | 步骤 3 失败 |
| 路径为空 | 前置守卫 | 直接 return 1 |
| `$_dst` 为空字符串 | 编程错误/参数缺失 | 前置守卫直接 return 1 |

---

## 设计评注

1. **返回值语义清晰**：0 = 引用（junction/symlink），1 = 副本（copy）。调用方通过返回值决定后续行为。

2. **主目录 vs 技能目录的不对称处理**：主目录的 copy fallback 会设置持久标记并警告用户；技能目录的 copy fallback 完全静默。这是合理的——主目录的状态决定了整个项目的分发模式。

3. **标记文件的持久性**：`.copy-mode` 是一个"一次进入就不自动退出"的状态机。`baton update` 在重新复制后会重新创建这个标记。只有用户主动重新运行 `baton init` 才能尝试回到 junction 模式。

4. **Windows 双重尝试**：NTFS junction 的两次尝试（带引号/不带引号）是对 Git Bash 版本兼容性的防御。不同版本的 MSYS2 对 `cmd //c` 的引号传递行为不同。
