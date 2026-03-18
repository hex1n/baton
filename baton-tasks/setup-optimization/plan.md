# Plan: setup.sh 优化 — 简化 JSON 策略 + 拆文件

## State: PROPOSING
## Complexity: Medium

## Requirements

- [Research C1] JSON 操作占 36%（~590 行），是最大复杂度源
- [Research C2] jq hook 遍历逻辑在 3 个函数中重复 ~100 行
- [Research C3] cleanup 函数重复 error handling ~30 行
- [Research Path 4] 简化 JSON 策略：区分"新建直写" vs "merge 需要 jq"
- [Research Path 1] 拆文件提升可读性
- [HUMAN] 不必保持单文件，可以 source
- [HUMAN] configure_* 可以尝试抽象
- 保持零依赖原则（no Node.js, no Python）

## First Principles Decomposition

**Problem**: setup.sh 1621 行，JSON 操作占 36%，维护困难。根因是 shell 处理 JSON 天然痛苦，且 merge 逻辑（罕见场景）被当作默认路径处理。

**Constraints**:
- 零依赖（POSIX shell + optional jq）
- 向后兼容（已安装项目 re-run setup.sh 不能丢失用户自定义 hooks）
- 跨平台（macOS, Linux, Windows/MSYS）
- 测试覆盖（254/256 现有测试需通过）

**Solution**: 两阶段优化

### Phase A: 简化 JSON 策略

**核心洞察**：当前代码对每个 hook 条目都调用 `merge_nested_hook_entry` / `merge_flat_hook_entry`（通过 jq merge），即使文件是全新创建的。configure_claude 有 9 个 `run_merge_and_record` 调用 + 4 个 `normalize` 调用 = 13 次 jq 操作。

**简化策略**：

每种 IDE 的 configure 函数已经有两个分支：
1. `if [ -f "$SETTINGS" ]` → merge 路径（已有配置文件）
2. `else` → 新建路径（heredoc 直写）

问题是 merge 路径太复杂。优化方向：

**判断现有文件是否只包含 baton hooks**：
- 如果是 → 用 heredoc 直写覆盖（和新建一样简单）
- 如果有用户自定义内容 → 用 jq merge（需要 jq，没有 jq 则 warn + skip）

这样常见路径（新安装 + 纯 baton 升级）都走直写，只有罕见路径（用户有自定义 hooks）才需要 jq merge。

**预期效果**：
- configure_claude 的 13 次 `run_merge_and_record` 调用可以简化为：检查一次 → 直写 or merge
- `merge_flat_hook_entry`、`normalize_nested_hook_matcher`、`remove_single_command_hook_entry` 可能可以删除（仅 migration 场景需要，可归入 jq merge 分支）

### Phase B: 拆文件

按功能拆分为：
- `setup.sh` — 入口 + 参数解析 + 主流程（~300 行）
- `lib/json-ops.sh` — JSON 操作函数（jq 封装、merge、cleanup）（~200 行优化后）
- `lib/ide-config.sh` — configure_* 函数 + IDE 检测/选择（~300 行）
- `lib/install-core.sh` — 文件安装、symlink、版本检测（~200 行）

setup.sh 开头 `source` 这些文件。分发时需要确保 lib/ 目录跟随 .baton/。

## Surface Scan

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `setup.sh` | L1 | modify | 主重构目标 |
| `tests/test-setup.sh` | L2 | verify + possibly modify | 测试可能依赖 setup.sh 的内部函数或输出格式 |
| `tests/test-cli.sh` | L2 | verify | 可能引用 setup.sh |
| `tests/test-phase-guide.sh` | L2 | verify | 使用 setup.sh 安装后的环境 |
| `tests/test-constitution-consistency.sh` | L2 | verify | 可能依赖安装结果 |
| `README.md` | L2 | skip | 安装命令不变（`bash setup.sh`），无需改 |

## Approach

### Phase A 具体改动

**A1. 新增 `has_only_baton_hooks()` 函数** (~15 行)

检查一个 JSON 配置文件是否只包含 baton 管理的 hooks（没有用户自定义内容）。利用已有的 `baton_hook_count_in_json_file` 和总 hook 计数比较。

**A2. 重写 configure_claude 的 merge 路径** (~30 行替代 ~50 行)

```
if [ ! -f "$SETTINGS" ] || has_only_baton_hooks "$SETTINGS"; then
    # 直写完整 JSON（heredoc）
else
    # 需要 jq merge（保留用户自定义 hooks）
    if ! command -v jq >/dev/null 2>&1; then
        echo "  ⚠ settings.json has custom hooks. Install jq for safe merge, or edit manually."
        return
    fi
    # jq merge 路径（保留现有 merge 逻辑，但只在这条路径调用）
fi
```

**A3. 同样重写 configure_cursor 和 configure_codex** (~20 行各)

**A4. 提取共享 jq helper** (~20 行替代 ~100 行重复)

将 `hook_command`、`baton_ref`、`event_entries` 定义为 shell 变量中的 jq 片段，传入各调用函数。

**A5. 简化 cleanup_baton_json_hook_file** (~30 行替代 ~80 行)

提取 `_check_jq_status` 辅助函数消除 3 段重复 case 语句。

### Phase B 具体改动

**B1. 创建 lib/ 目录和拆分文件**

按功能拆分，每个文件头部注明用途和 source 依赖。setup.sh 开头：
```sh
BATON_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$BATON_DIR/lib/json-ops.sh"
. "$BATON_DIR/lib/ide-config.sh"
. "$BATON_DIR/lib/install-core.sh"
```

**B2. 更新安装路径**

`install_versioned_script` 需要同时安装 lib/ 到目标项目。或者 — lib/ 不需要安装到目标项目，因为 setup.sh 运行时从 baton 安装目录 source。确认：setup.sh 总是从 baton 安装目录执行，不需要把 lib/ 复制到目标项目。

### 预期行数

| 文件 | Phase A 后 | Phase B 后 |
|------|-----------|-----------|
| setup.sh | ~1350 (消除 ~270 行) | ~300 |
| lib/json-ops.sh | — | ~200 |
| lib/ide-config.sh | — | ~350 |
| lib/install-core.sh | — | ~250 |
| **总计** | **~1350** | **~1100** |

从 1621 行降到 ~1100 行（-32%），且主文件只有 ~300 行。

## Write Set

- `setup.sh` — modify (Phase A: 简化 JSON 策略; Phase B: 拆分)
- `lib/json-ops.sh` — create (Phase B)
- `lib/ide-config.sh` — create (Phase B)
- `lib/install-core.sh` — create (Phase B)

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| `has_only_baton_hooks` 判断不准确 | 用户自定义 hooks 被覆盖 | 保守策略：任何无法识别的内容都走 merge 路径 |
| 拆文件后 source 路径问题 | setup.sh 从非预期目录执行时 source 失败 | BATON_DIR 已经是绝对路径，source 用 "$BATON_DIR/lib/..." |
| 测试依赖 setup.sh 内部函数 | 拆文件后测试 break | 测试中也 source lib/*.sh |
| jq-only merge 路径没有 awk fallback | 有自定义 hooks + 没有 jq 的用户无法升级 | 给出明确提示 + 手动编辑说明 |

## Self-Challenge

1. **是否过度简化了 merge 路径？** `has_only_baton_hooks` 的核心假设是：大部分安装是新安装或纯 baton 升级。如果用户常常添加自定义 hooks，简化的价值降低。但实际上 IDE hooks 是 baton 引入的概念，大多数用户不会手动添加。合理。

2. **Phase A 和 Phase B 是否应该分开做？** 分开更安全——Phase A 不改文件结构，只改逻辑；Phase B 只改文件结构，不改逻辑。如果 Phase A 引入 bug，不需要同时排查文件拆分问题。建议分两个 commit。

3. **怀疑者会质疑什么？** "为什么不直接删掉没有 jq 时的 awk fallback，强制要求 jq？" 这会打破零依赖原则。当前方案保留了无 jq 的直写路径（覆盖大部分场景），只在罕见路径（用户自定义 hooks）要求 jq。

## 批注区

(No annotations yet)


