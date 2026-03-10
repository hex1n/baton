# Plan: 评审报告修复 — 实现层硬化

**复杂度**: Small
**来源**: research.md（评审报告逐项验证）

## Requirements

1. 修复 /bin/sh 兼容性错误 [研究断言 2, ✅ 已验证]
2. 加固 write-lock 路径归一化 + 补测试 [研究断言 1, ⚠️ 代码脆弱已验证]
3. doctor 闭环校验 IDE 配置引用的所有 hook [研究断言 4, ✅ 已验证]
4. 明确 Bash 写路径策略 [研究断言 5, ✅ 已验证]

## Constraints

- 所有 hook 脚本已声明 `#!/bin/sh`，项目存在 POSIX 兼容性要求
- hook 必须 fail-open（exit 0 on error），不能因修复引入阻塞性故障
- setup.sh 已有 hook 注入链路，bash-guard 接入需用现有机制
- 测试在 Git Bash 下运行较慢（~15s/assertion），不宜大规模加测试

## Approach Analysis

### A: 统一改 shebang 为 bash（推荐）

将所有使用 Bashism 的脚本 shebang 改为 `#!/usr/bin/env bash`。

- **可行性**: ✅ — baton 所有目标环境（macOS, Linux, Windows Git Bash）均有 bash
- **优点**: 最小改动（只改 shebang），不需要重写任何逻辑
- **缺点**: 放弃了纯 POSIX sh 的可移植性承诺
- **影响**: phase-guide.sh:1, bin/baton:1

### B: 去除 Bashism，保持 /bin/sh

用 POSIX 等价写法替换 `${var/pattern/replacement}`：
```sh
RESEARCH_NAME=$(echo "$PLAN_NAME" | sed 's/plan/research/')
```

- **可行性**: ✅ — sed 是 POSIX 标准
- **优点**: 保持纯 POSIX 兼容
- **缺点**: 引入子进程开销（微不足道）；需要验证 sed 在所有变量值下行为一致
- **影响**: phase-guide.sh:25, bin/baton:155

### 排除说明

两种方案都可行。选 **A** 是因为：这两个文件中 `_common.sh` sourcing 用的 `$(cd ... && pwd)` 模式在严格 POSIX sh 下也有边缘行为差异，改 bash 一劳永逸。且项目 setup.sh 本身就是 `#!/usr/bin/env bash`，统一更清晰。

## Recommendation

**方案 A**: 统一 shebang 为 `#!/usr/bin/env bash`

## Change List

### 1. 修 shebang — phase-guide.sh, bin/baton

| 文件 | 改动 |
|------|------|
| `.baton/hooks/phase-guide.sh:1` | `#!/bin/sh` → `#!/usr/bin/env bash` |
| `bin/baton:1` | `#!/bin/sh` → `#!/usr/bin/env bash` |

同时修改所有其他 `#!/bin/sh` 的 hook 脚本保持一致：
- `.baton/hooks/write-lock.sh`
- `.baton/hooks/stop-guard.sh`
- `.baton/hooks/bash-guard.sh`
- `.baton/hooks/completion-check.sh`
- `.baton/hooks/post-write-tracker.sh`
- `.baton/hooks/pre-compact.sh`
- `.baton/hooks/subagent-context.sh`
- `.baton/hooks/_common.sh`

### 2. 加固 write-lock 路径归一化 — write-lock.sh

[CODE] write-lock.sh:63 当前逻辑：
```sh
TARGET_REAL="$(cd "$(dirname "$TARGET")" 2>/dev/null && pwd)/$(basename "$TARGET")" 2>/dev/null || TARGET_REAL="$TARGET"
```

改为更健壮的归一化，处理父目录不存在的场景：
```sh
# Try realpath/readlink -f first (handles non-existent paths)
TARGET_REAL="$(realpath -m "$TARGET" 2>/dev/null || readlink -f "$TARGET" 2>/dev/null)" || true
if [ -z "$TARGET_REAL" ]; then
    # Fallback: manual normalization
    TARGET_REAL="$(cd "$(dirname "$TARGET")" 2>/dev/null && pwd)/$(basename "$TARGET")" 2>/dev/null || TARGET_REAL="$TARGET"
fi
```

`realpath -m` 不要求路径存在（GNU coreutils）。macOS 可能需要 `readlink -f` 或保留现有 fallback。

### 3. 补 write-lock 测试 — test-write-lock.sh

添加测试用例：父目录不存在时，write-lock 仍正确阻止写入。

### 4. doctor 闭环校验 — bin/baton

[CODE] bin/baton:67 当前只检查 4 个脚本：
```sh
for _script in write-lock.sh phase-guide.sh stop-guard.sh bash-guard.sh; do
```

改为从 IDE 配置中提取实际引用的 hook 列表并校验，或直接扩展硬编码列表：
```sh
for _script in write-lock.sh phase-guide.sh stop-guard.sh bash-guard.sh \
               post-write-tracker.sh subagent-context.sh completion-check.sh pre-compact.sh; do
```

### 5. 接入 bash-guard — setup.sh

在 Claude hook 注入中增加 bash-guard 作为 PreToolUse (Bash) hook：

[CODE] setup.sh:819 之后添加：
```sh
run_merge_and_record merge_nested_hook_entry "$SETTINGS" "PreToolUse" "bash .baton/hooks/bash-guard.sh" \
  '{"matcher":"Bash","hooks":[{"type":"command","command":"bash .baton/hooks/bash-guard.sh"}]}'
```

bash-guard 保持 advisory-only（exit 0），不影响用户操作，但会在 stderr 输出警告。

同步更新 Cursor 配置注入段。

### 6. 安装列表补全 — setup.sh

[CODE] setup.sh:1075-1078 扩展 `install_versioned_script` 列表，包含所有 IDE 配置引用的 hook：
```sh
install_versioned_script "write-lock.sh"
install_versioned_script "phase-guide.sh"
install_versioned_script "stop-guard.sh"
install_versioned_script "bash-guard.sh"
install_versioned_script "post-write-tracker.sh"
install_versioned_script "subagent-context.sh"
install_versioned_script "completion-check.sh"
install_versioned_script "pre-compact.sh"
```

## Surface Scan (L1)

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.baton/hooks/phase-guide.sh` | L1 | modify | shebang 修复 |
| `.baton/hooks/write-lock.sh` | L1 | modify | shebang + 路径归一化 |
| `.baton/hooks/stop-guard.sh` | L1 | modify | shebang 统一 |
| `.baton/hooks/bash-guard.sh` | L1 | modify | shebang 统一 |
| `.baton/hooks/completion-check.sh` | L1 | modify | shebang 统一 |
| `.baton/hooks/post-write-tracker.sh` | L1 | modify | shebang 统一 |
| `.baton/hooks/pre-compact.sh` | L1 | modify | shebang 统一 |
| `.baton/hooks/subagent-context.sh` | L1 | modify | shebang 统一 |
| `.baton/hooks/_common.sh` | L1 | modify | shebang 统一 |
| `bin/baton` | L1 | modify | shebang + doctor 扩展 |
| `setup.sh` | L1 | modify | bash-guard 注入 + 安装列表补全 |
| `tests/test-write-lock.sh` | L2 | modify | 补测试用例 |
| `tests/test-phase-guide.sh` | L2 | skip | shebang 改动不影响测试逻辑（测试用 `bash` 显式调用） |
| `tests/test-cli.sh` | L2 | skip | 同上 |

## Self-Review

### Internal Consistency Check
- 推荐方案 A（改 shebang），change list 全部对应方案 A ✅
- 每项改动追溯到 research.md 验证结论 ✅
- Surface Scan 中 "modify" 的文件全部出现在 change list ✅
- skip 的测试文件：测试用 `bash "$script"` 显式调用，shebang 不影响 ✅

### External Risks
- **最大风险**: `realpath -m` 在 macOS 上可能不可用（需 coreutils）。缓解：保留 fallback 链
- **可能让计划失败的因素**: 如果某些环境确实依赖 `/bin/sh` 执行这些脚本（而非 bash），改 shebang 会引入 bash 依赖。但所有目标平台都有 bash
- **被排除的方案 B（去 Bashism）**: 更保守但需要逐文件审计所有 Bashism，当前只发现 2 处但不排除有遗漏

## Todo

- [x] ✅ 1. Shebang 统一 | Files: .baton/hooks/{phase-guide,write-lock,stop-guard,bash-guard,completion-check,post-write-tracker,pre-compact,subagent-context,_common}.sh, bin/baton | Verify: `head -1` 检查每个文件 | Deps: none | Artifacts: none
- [x] ✅ 2. write-lock 路径归一化加固 | Files: .baton/hooks/write-lock.sh | Verify: 手动验证 + todo #3 测试 | Deps: #1 | Artifacts: none
- [x] ✅ 3. 补 write-lock 测试（父目录不存在场景）| Files: tests/test-write-lock.sh | Verify: 运行该测试 | Deps: #2 | Artifacts: none
- [x] ✅ 4. doctor 闭环校验 | Files: bin/baton | Verify: `bin/baton doctor` 输出包含所有 8 个 hook | Deps: #1 | Artifacts: none
- [x] ✅ 5. 接入 bash-guard + 安装列表补全 | Files: setup.sh | Verify: grep 确认 bash-guard 在 PreToolUse 配置中 + install_versioned_script 列表完整 | Deps: none | Artifacts: none

## Retrospective

- Plan 基本准确，没有意外。所有改动都在预期范围内。
- `realpath -m` 在 Windows Git Bash 下可用，macOS 需要 `readlink -f` fallback — 计划中的 fallback 链设计正确。
- Windows Git Bash 下完整测试套件极慢（>10min），手动单点验证更高效。
- 评审报告的断言 1（write-lock 绕过）确认不成立：即使在修复前，兜底拼接就已经阻止了绕过。但路径归一化加固仍有价值——消除了脆弱性。
- 评审报告的断言 3（文件缺失）确认不成立：文件一直存在，只是 `install_versioned_script` 列表不完整。现已补全。

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 BATON:GO 批准标记，然后告诉 AI "generate todolist" -->

<!-- BATON:GO -->