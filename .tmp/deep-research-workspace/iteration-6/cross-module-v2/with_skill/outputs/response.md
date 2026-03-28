**Question**: baton 的 junction 机制在什么情况下会 fallback 到 copy mode？追踪完整的判断链，包括 setup.sh 和 junction.sh 的交互。
**Depth**: Standard
**Key finding**: `atomic_junction()` 实现三级 fallback 链（NTFS junction -> symlink -> copy），通过返回值 0/1 向调用方传递结果。`setup.sh` 中有两个不同的调用场景，对 fallback 的处理策略截然不同：`.baton/` 主目录 fallback 会触发全局 copy-mode 标记，而技能目录 fallback 被静默吞掉。
**Open questions**: 1 -- see end of document

---

## Overview: Junction 分发架构

```
~/.baton/                          (single source of truth)
    └── .baton/
         ├── hooks/
         ├── skills/
         └── ...

Project A/.baton  ──junction──>  ~/.baton/.baton    (live link, auto-updates)
Project B/.baton  ──copy────>    ~/.baton/.baton    (static snapshot, needs manual sync)
                                  ^
                                  └── fallback when junction/symlink both fail
```

## Layer 1: `atomic_junction()` -- 三级 fallback 链

Source: `.baton/hooks/lib/junction.sh:8-36`

```
atomic_junction SRC DST:
    1. 清理: 如果 DST 已存在 (含断裂的 symlink), rm -rf 删除
    2. 尝试 NTFS junction (仅 Windows):
       - 前提: `cygpath` 命令存在 (Git Bash/MSYS2 环境的标志)
       - 将 SRC/DST 转为 Windows 路径格式
       - 先尝试带引号的 mklink /J (处理路径中的空格)
       - 若失败, 重试不带引号的 mklink /J (某些 Git Bash 版本需要)
       - 成功 → return 0
    3. 尝试 symlink (Linux/macOS, 或 Windows Developer Mode):
       - `ln -sf SRC DST`
       - 验证 DST 确实是 symlink (`[ -L "$_dst" ]`)
       - 成功 → return 0
    4. Fallback copy:
       - `cp -r SRC DST`
       - return 1  ← 关键: 返回 1 表示降级到 copy mode
```

**返回值语义** (verified: `junction.sh:25-35`):
- `return 0` = junction 或 symlink 创建成功 (live link)
- `return 1` = 只能 copy (static snapshot)

### 什么情况下每一级会失败？

| 级别 | 失败条件 | 证据 |
|------|----------|------|
| NTFS junction | (1) 非 Windows 环境 (无 `cygpath`); (2) Windows 上 `mklink /J` 失败 -- 通常因为目标路径在网络驱动器、非 NTFS 文件系统(如 FAT32/exFAT)、或极端权限限制 | `junction.sh:20-28` |
| Symlink | (1) Linux/macOS 上 `ln -sf` 失败 -- 通常因为跨文件系统限制或目标位于不支持 symlink 的文件系统; (2) Windows 上无 Developer Mode 且非管理员; (3) `ln -sf` 成功但 `[ -L "$_dst" ]` 检测失败 (某些挂载点行为) | `junction.sh:31` |
| Copy | 理论上 `cp -r` 也可能失败(磁盘满、权限等), 但此时函数无额外处理, 会由 shell 的 `set -eu` 或调用方捕获 | `junction.sh:34` |

## Layer 2: `setup.sh` 中的 `.baton/` 主目录 junction

Source: `setup.sh:124-139` (`create_baton_junction()`)

这是 **最关键的 junction 调用**, 决定整个项目的分发模式:

```bash
if atomic_junction "$_baton_src" "$PROJECT_DIR/.baton"; then
    echo "  ✓ .baton/ → junction to source"        # return 0 = success
else
    COPY_MODE=1                                      # return 1 = fallback
    touch "$PROJECT_DIR/.baton/.copy-mode"           # 持久化标记
    echo "  ⚠ .baton/ copied (no junction support). Updates need 'baton update'."
fi
```

**判断链**:
1. 如果是 self-install (baton 源码仓库自身), 直接 return, 不创建 junction (`setup.sh:125-128`)
2. 确定 source 路径: 优先 `$BATON_HOME/.baton`, 回退到 `$BATON_DIR/.baton` (`setup.sh:129-132`)
3. 调用 `atomic_junction`, 检查返回值
4. 若 fallback 到 copy:
   - 设置内存变量 `COPY_MODE=1` (影响 setup 后续输出)
   - 创建 `.baton/.copy-mode` 空标记文件 (持久化, 供 `baton check` 和 `baton update` 读取)
   - 输出警告

## Layer 3: 技能目录的 junction -- 不同的 fallback 策略

Source: `setup.sh:143-181` (`create_skill_junctions()`)

```bash
atomic_junction "$_src" "$_dst" || true    # setup.sh:163, 177
```

技能 junction 的 fallback **被 `|| true` 静默吞掉**。设计理由:
- 如果 `.baton/` 主目录 junction 成功, 技能目录 junction 通常也会成功 (同一文件系统/权限环境)
- 如果 `.baton/` 主目录已经 fallback 到 copy, 那么技能文件已经通过 copy 包含在内, 单独的技能 junction 失败是冗余的
- 没有为单个技能创建 `.copy-mode` 标记 -- 只有主目录级别的 copy-mode 概念

`phase-guide.sh:63` 中的运行时自动修复 junction 也使用同样的 `|| true` 模式:
```bash
atomic_junction "$_skill_dir" "$_target" 2>/dev/null || true
```

## Layer 4: `baton update` -- copy-mode 的持久化恢复

Source: `bin/baton:315-342`

```bash
if [ -f "$_dir/.baton/.copy-mode" ]; then
    echo "  Refreshing copy-mode project: $_dir"
    rm -rf "$_dir/.baton"
    cp -r "$BATON_HOME/.baton" "$_dir/.baton"
    touch "$_dir/.baton/.copy-mode"     # 重新标记
    # ... 同时 copy 技能目录
fi
```

关键行为:
- `.copy-mode` 是一个 **单向状态机**: 一旦标记, `baton update` 只会 re-copy 而不会重新尝试创建 junction
- re-copy 后重新 touch `.copy-mode` (因为 `rm -rf` 删掉了旧标记)
- `baton update --check` 也读取此标记来报告项目状态 (`bin/baton:307-308`)

## 完整判断链流程图

```
setup.sh main flow:
    │
    ├── ensure_baton_home()          # 确保 ~/.baton 存在
    ├── detect_self_install()        # 自身仓库? → 跳过 junction
    │
    ├── create_baton_junction()
    │       │
    │       ├── self-install? → return (no junction needed)
    │       │
    │       └── atomic_junction(~/.baton/.baton, project/.baton)
    │               │
    │               ├── [Windows] cygpath exists?
    │               │       ├── mklink /J (quoted) → return 0 ✓
    │               │       └── mklink /J (unquoted) → return 0 ✓
    │               │
    │               ├── ln -sf && [ -L ] → return 0 ✓
    │               │
    │               └── cp -r → return 1 ✗
    │                       │
    │                       └── caller: COPY_MODE=1
    │                           touch .baton/.copy-mode
    │                           print warning
    │
    ├── create_skill_junctions()
    │       └── atomic_junction(...) || true   # 失败静默吞掉
    │
    └── [end] if COPY_MODE=1: final warning message
```

## `baton check` 的三态检测

Source: `bin/baton:305-311`

| 检测条件 | 状态 | 含义 |
|----------|------|------|
| `[ -L "$_dir/.baton" ]` | junction | 正常 live-link 模式 |
| `[ -f "$_dir/.baton/.copy-mode" ]` | copy-mode | 降级模式, 需要手动 `baton update` |
| `[ -d "$_dir/.baton" ]` (else) | old-style | 旧版安装, 建议重新 `baton init` |

## Challenge

**Weakest point**: 技能 junction 和主目录 junction 的 fallback 一致性假设 -- 代码假设如果主目录 junction 成功, 技能 junction 也会成功。但理论上存在一个边缘场景: 主目录 junction 指向 `~/.baton/.baton`, 而技能 junction 指向的是 `$PROJECT_DIR/.baton/skills/X` (即 junction 内部的路径)。在某些 NTFS 配置下, 从一个 junction 内部创建到另一个 junction 内部的 junction 可能有不同的行为。不过实际上 `create_skill_junctions` 中 `_skill_src` 被设为 `$PROJECT_DIR/.baton/skills` (已经通过主 junction 解析), 所以这更多是理论上的担忧。

## Open Questions

1. **copy-mode 的退出路径**: 代码中 `baton update` 永远不会重新尝试创建 junction, 但也没有显式的 `baton init --retry-junction` 命令。用户需要手动删除 `.copy-mode` 标记文件后重新运行 `setup.sh` 才能回到 junction 模式。这是有意为之还是缺少的功能? (unverified -- no explicit documentation on intended recovery path beyond re-running setup)
