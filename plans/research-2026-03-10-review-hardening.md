# 评审报告深度分析 — 逐项验证

基于对源码的独立调查，对 `baton-review.md` 中 5 个断言逐一验证。

## 评审断言 1: write-lock 存在真实绕过漏洞

**评审结论**: 当目标文件的父目录不存在时（如 `src/app.ts` 但 `src/` 不存在），`cd` 失败导致 `TARGET_REAL` 退化，被当作"项目外文件"而 exit 0 放行。

**验证结果: ⚠️ 推理有误，但代码确实脆弱**

评审的推理链在关键环节出错：

- [CODE] write-lock.sh:63 — `cd` 失败时，`TARGET_REAL` 退化为相对路径如 `app.ts`
- [CODE] write-lock.sh:65-68 — 但接下来的 case 语句会把非绝对路径重新拼接为 `${PROJECT_DIR}/app.ts`
- [CODE] write-lock.sh:69-72 — 拼接后的路径匹配 `"$PROJECT_DIR"/*`，**不会 exit 0 放行**

```sh
case "$TARGET_REAL" in
    /*) ;;  # absolute, keep as-is
    *) TARGET_REAL="${PROJECT_DIR}/${TARGET_REAL}" ;;  # ← 会兜底拼接
esac
case "$TARGET_REAL" in
    "$PROJECT_DIR"/*) ;;  # inside project, continue checks  ← 不会绕过
    *) exit 0 ;;
esac
```

所以评审说的"被当作项目外文件放行"**不成立**。路径会被重新锚定到 `PROJECT_DIR` 下，继续走后续检查。

**但代码确实脆弱**：`cd` 失败时路径归一化不完整，`TARGET_REAL` 变成 `${PROJECT_DIR}/app.ts` 而不是 `${PROJECT_DIR}/src/app.ts`，路径信息丢失。如果后续有基于精确路径的白名单逻辑，可能产生问题。

**测试覆盖缺口确实存在** — 没有测试覆盖"父目录不存在"的场景。

**评审声称的 "28/37 passed, 9 failed" 测试结果**：❓ 无法复现验证。可能来自不同版本或环境差异（如 CRLF 问题导致的额外失败）。

| 子断言 | 判定 |
|--------|------|
| `cd` 会失败 | ✅ 正确 |
| TARGET_REAL 退化 | ✅ 正确 |
| 退化后被当作项目外文件放行 | ❌ **错误** — 有兜底拼接 |
| 存在可复现绕过 | ❌ 未证实 |
| 测试覆盖有缺口 | ✅ 正确 |
| 代码脆弱需加固 | ✅ 正确 |

---

## 评审断言 2: phase-guide.sh 和 bin/baton 有 /bin/sh 兼容性错误

**评审结论**: 两个文件声明 `#!/bin/sh` 但使用了 Bash 特有的字符串替换语法。

**验证结果: ✅ 完全正确**

- [CODE] phase-guide.sh:1 — `#!/bin/sh`
- [CODE] phase-guide.sh:25 — `RESEARCH_NAME="${PLAN_NAME/plan/research}"` ← Bashism
- [CODE] bin/baton:1 — `#!/bin/sh`
- [CODE] bin/baton:155 — `_rname="${_pname/plan/research}"` ← Bashism

行号完全准确。`${var/pattern/replacement}` 不是 POSIX sh 语法，在严格 `/bin/sh` 环境下会报 `Bad substitution`。

除这两处外，其余代码均为 POSIX 兼容（`[ ]` 条件、无数组、无 `(( ))`）。

**修复方案**: 改 shebang 为 `#!/usr/bin/env bash`，或用 POSIX 等价写法：
```sh
RESEARCH_NAME=$(echo "$PLAN_NAME" | sed 's/plan/research/')
```

---

## 评审断言 3: setup.sh 注入了不存在的 hook 引用

**评审结论**: setup.sh 在 IDE 配置中注入了 4 个 hook 引用（post-write-tracker.sh, subagent-context.sh, completion-check.sh, pre-compact.sh），但安装阶段只安装了另外 4 个，导致"看起来配置成功，实际运行时缺文件"。

**验证结果: ⚠️ 关键事实断言错误，但暴露了真实的架构问题**

评审声称这 4 个文件"缺失"——**这是错误的**。实际 `.baton/hooks/` 目录包含所有 9 个文件：

```
_common.sh              ✅ 存在
bash-guard.sh           ✅ 存在
completion-check.sh     ✅ 存在
phase-guide.sh          ✅ 存在
post-write-tracker.sh   ✅ 存在
pre-compact.sh          ✅ 存在
stop-guard.sh           ✅ 存在
subagent-context.sh     ✅ 存在
write-lock.sh           ✅ 存在
```

但评审确实指出了一个真实的架构问题：

- [CODE] setup.sh:1075-1078 — `install_versioned_script` 只安装 4 个 hook
- [CODE] setup.sh:818-824 — IDE 配置引用了 7 个 hook

这意味着：如果用户通过 `install.sh`（稀疏 clone）安装 baton 而非完整 clone，这些文件可能确实不在目标项目中。这取决于安装路径是否复制了完整的 `.baton/hooks/` 目录。

| 子断言 | 判定 |
|--------|------|
| 4 个 hook 文件不存在 | ❌ **错误** — 全部存在 |
| install 阶段只装了 4 个 | ✅ 正确 |
| IDE 配置引用了 7 个 | ✅ 正确 |
| 存在安装一致性问题 | ⚠️ 取决于安装路径 |

---

## 评审断言 4: doctor 检查有盲区

**评审结论**: `baton doctor` 只检查 4 个脚本，检不出被引用但缺失的 hook。

**验证结果: ✅ 正确**

- [CODE] bin/baton:67 — doctor 只检查 `write-lock.sh phase-guide.sh stop-guard.sh bash-guard.sh`
- 不检查 `post-write-tracker.sh`, `subagent-context.sh`, `completion-check.sh`, `pre-compact.sh`

虽然断言 3 中这些文件实际存在，但 doctor 确实没有做"IDE 配置引用的 hook 是否都存在"的闭环校验。如果某个 hook 被删除或损坏，doctor 不会发现。

---

## 评审断言 5: Bash 写路径没有被封死

**评审结论**: bash-guard.sh 是 advisory only，且未接入 IDE hook 链路，Bash 工具写文件不受约束。

**验证结果: ✅ 完全正确**

- [CODE] bash-guard.sh:2-5 — 明确声明 "Always exit 0 — never blocks, only warns"
- [CODE] bash-guard.sh:38 — 无条件 `exit 0`
- [CODE] setup.sh:819 — Claude `PreToolUse` 只注册了 `write-lock.sh`，matcher 为 `Edit|Write|MultiEdit|CreateFile|NotebookEdit`，不包含 `Bash`
- [CODE] setup.sh:993 — Cursor `preToolUse` 只注册了 `adapter-cursor.sh`
- bash-guard.sh 虽然被安装（setup.sh:1078）且在 allowlist 中（setup.sh:170-171），但**未注册为任何 IDE 的 hook**

`echo > file`, `tee`, `sed -i`, `cp`, `mv` 等 Bash 写操作确实不受 write-lock 约束。

---

## 总结

| # | 断言 | 判定 | 严重程度 |
|---|------|------|----------|
| 1 | write-lock 可绕过 | ❌ 推理错误，绕过不成立；但代码脆弱+测试缺口 | 中（非高） |
| 2 | /bin/sh 兼容性错误 | ✅ 完全正确 | 高 |
| 3 | setup 安装缺失 hook | ⚠️ 核心事实错误（文件存在），但暴露架构问题 | 中（非高） |
| 4 | doctor 有盲区 | ✅ 正确 | 中 |
| 5 | Bash 写路径未封死 | ✅ 完全正确 | 中高 |

### 评审报告质量评估

**优点**:
- 方向正确，确实找到了真实问题（#2, #4, #5）
- 有代码行号引用，比纯观点性评审好得多
- 整体框架判断准确："方向对，实现需硬化"

**问题**:
- 断言 1 的推理链在关键环节出错（忽略了 lines 65-68 的兜底拼接），把"代码脆弱"升级为"可复现绕过"，结论过重
- 断言 3 声称文件"不存在"是事实性错误，可能是评审者在非完整环境下测试导致的

### 建议优先修复项

1. **修 shebang**（断言 2）— 改为 `#!/usr/bin/env bash` 或去 Bashism，一分钟的事
2. **加固 write-lock 路径归一化**（断言 1）— 补 `readlink -f` / `realpath` 兜底 + 补测试
3. **doctor 闭环校验**（断言 4）— 让 doctor 检查 IDE 配置引用的所有 hook
4. **明确 Bash 写路径策略**（断言 5）— 接入 bash-guard 或在文档中声明边界

## 批注区
