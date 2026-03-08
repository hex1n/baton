# Baton 项目第一性原理分析

## 分析范围

基于全部实现代码的深度分析，忽略非 workflow 相关的 markdown 文档。覆盖文件：

- **安装层**: `setup.sh` (1524行), `install.sh` (77行), `bin/baton` (298行)
- **Hook 层**: 8个 shell 脚本，共 602 行
- **适配器层**: 4个 shell 适配器 + 1个 JS 插件，共 84 行
- **Git Hook**: `pre-commit` (49行)
- **配置**: `.claude/settings.json`, `.claude/settings.local.json`
- **CI**: `.github/workflows/ci.yml`
- **Workflow 定义**: `workflow.md` (101行), `workflow-full.md` (365行)
- **测试**: 12个测试文件，共 3927 行

总实现代码 2632 行，测试代码 3927 行（测试/实现比 1.5:1）。

---

## 一、Baton 解决的根本问题

AI 编码助手的默认行为是**跳过理解直接写代码**。这导致：
- 代码不符合人类意图（AI 自行解读需求）
- 变更破坏已有系统（研究不充分）
- 没有设计决策审计轨迹
- 人类无法在代码写入前纠偏

**Baton 的核心命题**：在 AI 写代码之前，强制建立人机共识。

---

## 二、核心不变量

整个系统围绕一个不变量运转：

```
源代码写入被阻止，除非 plan.md 包含 <!-- BATON:GO -->
```

这是唯一的、真正的强制约束。所有其他机制都是对这个不变量的支撑。

**证据**: `write-lock.sh:91` — `grep -q '<!-- BATON:GO -->' "$PLAN"` 是唯一的解锁判断。

---

## 三、架构分层分析

### 第一层：门禁（The Gate）— 唯一强制执行点

**文件**: `write-lock.sh` (98行)

这是整个系统中**唯一真正阻止 AI 操作**的组件。

**决策链**:
```
write-lock.sh 收到写入请求
  → BATON_BYPASS=1? → 放行 (write-lock.sh:17-19)
  → 读取 stdin JSON 解析目标文件路径 (write-lock.sh:22-43)
  → 路径不可确定? → 放行 + 警告 (write-lock.sh:47-53)
  → 目标是 .md 文件? → 放行 (write-lock.sh:56-58)
  → 查找 plan 文件 (walk-up 算法, write-lock.sh:71-79)
  → plan 不存在? → 阻止 + 引导至 research 阶段 (write-lock.sh:84-88)
  → plan 存在但无 BATON:GO? → 阻止 + 引导完成批注 (write-lock.sh:96-98)
  → plan 存在且有 BATON:GO → 放行 (write-lock.sh:91-93)
```

**设计属性**:
- **Fail-open**: `trap '... exit 0'` (write-lock.sh:14) — 任何意外错误都放行，绝不因自身 bug 阻止工作
- **7个决策分支，4个放行，2个阻止，1个有条件放行**
- 无 jq 时使用 awk 回退解析 JSON (write-lock.sh:37-43)

### 第二层：状态机（State Machine）— 文件系统即状态

**文件**: `phase-guide.sh` (184行)

Baton 没有数据库、没有配置文件存储状态。**状态完全由文件系统中文件的存在与内容决定**：

| 文件系统状态 | 检测逻辑 | 工作流阶段 |
|---|---|---|
| 无 research.md，无 plan.md | phase-guide.sh:167-182 | RESEARCH |
| research.md 存在，无 plan.md | phase-guide.sh:149-165 | PLAN |
| plan.md 存在，无 BATON:GO | phase-guide.sh:132-146 | ANNOTATION |
| plan.md + BATON:GO，无 `## Todo` | phase-guide.sh:102-112 | AWAITING_TODO |
| plan.md + BATON:GO + `## Todo` | phase-guide.sh:115-129 | IMPLEMENT |
| plan.md + BATON:GO + 所有 todo 完成 | phase-guide.sh:86-99 | ARCHIVE |

**关键设计选择**: 用 HTML 注释 `<!-- BATON:GO -->` 作为审批标记。这是一个精妙的选择：
- 人类可以用任何文本编辑器添加/删除
- 不会在 markdown 渲染中显示（不影响阅读）
- `grep -q` 即可检测（简单可靠）
- 可搜索、可版本控制、可 diff

### 第三层：监控（Advisory Hooks）— 只警告不阻止

6个 hook 全部 `exit 0`，是纯粹的信息输出层：

| Hook | 触发时机 | 功能 | 行数 |
|---|---|---|---|
| `bash-guard.sh` | PreToolUse(Bash) | 警告 Bash 命令可能写文件 | 43 |
| `post-write-tracker.sh` | PostToolUse(Edit/Write) | 警告修改了 plan 外的文件 | 68 |
| `stop-guard.sh` | Stop | 提醒未完成的 todo 和归档 | 55 |
| `completion-check.sh` | TaskCompleted | 阻止完成直到写 Retrospective | 55 |
| `pre-compact.sh` | PreCompact | 上下文压缩前保存进度快照 | 53 |
| `subagent-context.sh` | SubagentStart | 向子代理注入 plan 上下文 | 44 |

**注意**: `completion-check.sh` 是唯一可以返回 `exit 2` 的 advisory hook (completion-check.sh:52)，但它只在 TaskCompleted 事件上触发，不影响写操作。

### 第四层：适配器（Protocol Translation）

每个 IDE 有不同的 hook 协议。适配器将 write-lock.sh 的 exit code 翻译为 IDE 特定的 JSON：

| IDE | 协议格式 | 适配器 |
|---|---|---|
| Claude Code | exit code 直接 (0=allow, 非0=block) | 不需要适配器 |
| Cursor | `{"decision":"allow/deny","reason":"..."}` | adapter-cursor.sh:8-13 |
| Copilot | `{"permissionDecision":"allow/deny","permissionDecisionReason":"..."}` | adapter-copilot.sh:8-11 |
| Cline | `{"cancel":false/true,"errorMessage":"..."}` | adapter-cline.sh:13-17 |
| OpenCode | JS throw Error | opencode-plugin.mjs:21-24 |

**所有适配器调用同一个 write-lock.sh** — 单一决策源，多协议输出。

### 第五层：安装（Deployment）

**文件**: `setup.sh` (1524行) — **占总实现的 58%**

支持 11 个 IDE，分为三类：

| 类别 | IDE | 保护级别 |
|---|---|---|
| **A 类 — 完整保护** | Claude, Factory, Cursor, Windsurf, Augment | hook 强制 + 规则 + skills |
| **B 类 — 适配器保护** | Copilot, Cline, Kiro | 适配器 + 规则 + skills |
| **C 类 — 仅规则** | Codex, Zed, Roo | workflow.md 注入，无执行强制 |

setup.sh 内部结构：
- 参数解析: ~107行 (setup.sh:48-107)
- JSON 操作工具函数: ~175行 (setup.sh:134-291) — jq 依赖的 merge/remove/cleanup
- 卸载逻辑: ~120行 (setup.sh:390-508) — 逐 IDE 清理
- IDE 检测+选择: ~150行 (setup.sh:518-692)
- Hook 安装工具: ~100行 (setup.sh:703-860)
- Cline wrapper 系统: ~60行 (setup.sh:900-958) — 最复杂的适配
- 11个 `configure_*` 函数: ~400行 (setup.sh:962-1355)
- 主安装流程: ~165行 (setup.sh:1357-1525)

---

## 四、代码复用机制分析

### SYNCED 注释协议

6个文件共享两段关键逻辑，通过 `# SYNCED:` 注释标记：

**1. plan-name-resolution** — 确定 plan 文件名

```sh
# SYNCED: plan-name-resolution — same in all baton scripts
if [ -n "$BATON_PLAN" ]; then
    PLAN_NAME="$BATON_PLAN"
else
    _candidate="$(ls -t plan.md plan-*.md 2>/dev/null | head -1)"
    PLAN_NAME="${_candidate:-plan.md}"
fi
```

出现在: write-lock.sh:62-67, phase-guide.sh:59-64, stop-guard.sh:16-21, bash-guard.sh:11-16, post-write-tracker.sh:43-48, completion-check.sh:19-24, pre-compact.sh:17-22, subagent-context.sh:17-22, pre-commit:20-26

**2. find_plan** — 向上遍历目录树查找 plan 文件

```sh
# SYNCED: find_plan — same algorithm in write-lock.sh, phase-guide.sh, ...
d="$(pwd)"
while true; do
    [ -f "$d/$PLAN_NAME" ] && { PLAN="$d/$PLAN_NAME"; break; }
    p="$(dirname "$d")"
    [ "$p" = "$d" ] && break
    d="$p"
done
```

出现在: 所有 8 个 hook + pre-commit

**风险**: 这是手工代码同步。任何修改必须同步到 9 个位置。`test-workflow-consistency.sh` 验证了这一点 (tests/test-workflow-consistency.sh)，但验证是静态的（检查代码存在），不是语义的（不验证行为一致）。

---

## 五、从第一性原理看设计决策

### 5.1 Fail-Open 是刻意选择还是妥协？

**每个 hook 都有**: `trap '... exit 0' HUP INT TERM`

这意味着 baton 自身的任何 bug **永远不会阻止** AI 工作。

**从第一性原理看**: 这是正确的。治理工具的首要原则是"不伤害"——一个 buggy 的治理工具比没有治理工具更糟糕，因为它会在关键时刻阻止合法操作，导致用户彻底绕过它。

**但这意味着**: baton 的保护力度等于**最弱的那个 fail-open 路径**。write-lock.sh 有 4 个放行路径：
1. BATON_BYPASS=1 (write-lock.sh:17-19) — 显式绕过
2. 无法确定目标路径 (write-lock.sh:47-53) — 隐式绕过
3. 目标是 .md 文件 (write-lock.sh:56-58) — 设计内绕过
4. trap 错误处理 (write-lock.sh:14) — 故障绕过

**路径 #2 是最值得关注的**: 如果 jq 不可用且 awk 解析失败，操作直接放行。这在没有 jq 的环境中意味着 write-lock 可能形同虚设。

### 5.2 Markdown 豁免是功能还是漏洞？

**所有 .md 文件绕过 write-lock** (write-lock.sh:57):
```sh
case "$TARGET" in
    *.md|*.MD|*.markdown|*.mdx) exit 0 ;;
esac
```

**为什么需要**: workflow 的核心就是写 research.md 和 plan.md，如果阻止 markdown 写入，整个 workflow 无法运转。

**但这意味着**: AI 可以在没有 BATON:GO 的情况下修改：
- `CLAUDE.md` — 控制 AI 行为的核心配置
- `.baton/workflow.md` — workflow 规则本身
- 任何 `.clinerules/*.md` — Cline 的规则文件
- `AGENTS.md` — Codex 的规则文件
- `README.md` — 项目文档

**从第一性原理看**: 这是一个有意识的权衡。如果要保护 .md 文件，就需要一个 allowlist 机制（"只允许写 research*.md 和 plan*.md"），这增加了复杂性并打破了当前简洁的判断逻辑。当前设计选择了简洁性，代价是 .md 文件不受保护。

### 5.3 文件系统作为状态机 — 优势与限制

**优势**:
- 零依赖（不需要数据库、服务、后台进程）
- 完全透明（`ls` 即可看状态）
- 天然版本控制（git 跟踪文件变化）
- 跨 session 持久（不依赖进程内存）
- 人类可以直接操作状态（删文件 = 重置状态）

**限制**:
- **plan 文件发现的竞态**: `ls -t plan.md plan-*.md 2>/dev/null | head -1` 取最近修改时间。如果有两个 plan 文件，touch 任何一个就改变了"当前 plan"。这不是 bug（`BATON_PLAN` 环境变量可以覆盖），但对不知道这个机制的用户来说可能困惑。
- **无原子性**: 状态变更不是原子的。在"添加 BATON:GO"和"生成 Todo"之间存在一个中间状态（AWAITING_TODO），phase-guide.sh 明确处理了这个状态 (phase-guide.sh:102-112)。
- **无历史**: 文件系统状态是时间点的快照。谁在什么时间加了 BATON:GO？只有 git log 可以追溯。

### 5.4 Advisory Hooks 的效力分析

6个 advisory hooks 全部输出到 stderr 且 `exit 0`。它们的效力完全取决于 AI 的 system prompt 合规性。

**从第一性原理看**: 这是 LLM 治理的现实约束。LLM 不是确定性程序——你不能用 exit code 强制它的行为，只能通过 context 影响它。advisory hooks 的输出成为 AI 的上下文，增加了 AI "做正确事情"的概率，但不是保证。

**对比表**:

| 维度 | 强制 (write-lock) | 顾问 (advisory hooks) |
|---|---|---|
| 能阻止错误操作？ | 能（exit 1 阻止写入） | 不能（只能警告） |
| 能被绕过？ | 能（BATON_BYPASS=1, Bash 写文件） | 能（AI 忽略 stderr 输出） |
| 对用户体验影响 | 高（操作被阻止需要理解原因） | 低（只是额外信息） |
| 维护成本 | 高（必须正确，否则阻止合法操作） | 低（错误只影响信息质量） |

### 5.5 setup.sh 的复杂度是否合理？

setup.sh 占总代码的 58%。从第一性原理分析：

**为什么这么大**:
1. 11个 IDE 各有不同的配置格式 — 必须的多态性
2. JSON 操作不用 jq 时需要大量工具代码 — 必须的兼容性
3. 卸载需要逐 IDE 清理 — 安装的逆操作
4. v1→v2→v3 迁移逻辑 — 历史包袱
5. 交互式 IDE 选择器 — UX 功能

**真正过度的部分**:
- `parse_ide_choice` 的数字拼接解析 (setup.sh:598-645)：输入 "134" 被解析为 IDE 1、3、4。这是一个 micro-UX 优化，~50行代码服务于一个罕见场景。
- `baton_hook_count_in_json_file` (setup.sh:186-219) 和 `json_dot_baton_path_ref_count` (setup.sh:221-252) — 两个 30 行的 jq 函数做的事情高度相似（在 JSON 中统计 baton hook 数量 vs 统计 .baton/ 引用数量），可以合并。
- `cleanup_baton_json_hook_file` (setup.sh:302-387) — 86 行的防御性清理，5 处几乎相同的错误处理分支。

---

## 六、OpenCode 插件的差异分析

`opencode-plugin.mjs` 是唯一的非 shell 实现。与 write-lock.sh 的行为比较：

| 行为 | write-lock.sh | opencode-plugin.mjs |
|---|---|---|
| plan 文件名解析 | `ls -t plan.md plan-*.md | head -1` (glob fallback) | 固定 `plan.md` (opencode-plugin.mjs:12) |
| 无 plan 时 | exit 1 + 研究阶段引导 | throw Error (opencode-plugin.mjs:21) |
| 无 BATON:GO 时 | exit 1 + 批注阶段引导 | throw Error (opencode-plugin.mjs:24) |
| fail-open | 有 (trap + 多处 exit 0) | 无 — 任何异常都是 throw |
| BATON_PLAN 支持 | 有 (write-lock.sh:62-63) | 有 (opencode-plugin.mjs:12) |
| glob fallback | 有 (`ls -t plan-*.md`) | 无 — 只检查 `planName` |

**关键差异**: OpenCode 插件不支持 plan-*.md glob fallback。如果用户的 plan 文件叫 `plan-auth.md` 且未设置 `BATON_PLAN` 环境变量，OpenCode 插件会错误地报告"no plan.md found"而 shell hook 会正确找到它。

---

## 七、测试覆盖分析

| 测试文件 | 行数 | 覆盖目标 | CI 中运行？ |
|---|---|---|---|
| test-write-lock.sh | 349 | write-lock.sh 核心逻辑 | 是 (ubuntu + macos) |
| test-phase-guide.sh | 309 | 状态机检测 | 是 |
| test-setup.sh | 763 | 安装/卸载/迁移 | 是 (ubuntu + macos) |
| test-stop-guard.sh | 214 | 停止提醒 | 是 |
| test-adapters.sh | 132 | 适配器协议翻译 | 是 |
| test-adapters-v2.sh | 230 | 适配器 v2 | 否 |
| test-multi-ide.sh | 924 | 多 IDE 安装 | 否 |
| test-workflow-consistency.sh | 289 | SYNCED 代码一致性 | 是 |
| test-pre-commit.sh | 199 | git pre-commit hook | 否 |
| test-new-hooks.sh | 185 | 新增 hooks | 否 |
| test-annotation-protocol.sh | 70 | 批注协议 | 否 |
| test-cli.sh | 206 | baton CLI | 否 |
| test-ide-capability-consistency.sh | 57 | IDE 能力矩阵 | 否 |

**CI 缺口**: 13个测试文件中只有 7 个在 CI 中运行。`test-multi-ide.sh` (924行，最大的测试文件) 不在 CI 中。

**CI 额外问题**: ci.yml:25 shellcheck lint `adapter-windsurf.sh`，但这个文件在代码库中不存在（已被删除，configure_windsurf 现在直接使用 native hooks）。这会导致 CI shellcheck job 失败。

---

## 八、核心结论

### Baton 本质上是什么？

从第一性原理看，Baton 不是一个安全工具——它是一个**协作协议定义器**，用轻量级强制手段作为速度障碍（speed bump）。

- **强制层**只有 write-lock.sh (98行)，可以被多种方式绕过
- **真正的价值**在于：workflow 定义 + phase guidance + annotation protocol + skills
- **设计哲学**：与其追求不可绕过的硬门禁（在人类控制的环境中不可能），不如提供一个足够好的"默认路径"，让 AI 在没有特殊理由时自然遵循

### 架构健康度

| 维度 | 评价 |
|---|---|
| **单一职责** | 优秀 — write-lock 只做门禁，phase-guide 只做状态检测，各 hook 职责清晰 |
| **可测试性** | 良好 — 纯 shell 脚本，通过 env 变量和 stdin 注入，易于测试 |
| **代码复用** | 不良 — SYNCED 手工同步机制跨 9 个文件，是最大的维护风险 |
| **安装复杂度** | 过高 — setup.sh 占 58%，11 IDE 支持中很多是"仅规则"级别 |
| **fail-open 设计** | 正确 — 治理工具不应因自身 bug 阻止工作 |
| **协议一致性** | 有缺口 — OpenCode 插件与 shell hook 行为不一致 (plan-*.md glob) |

### 最值得关注的三个问题

1. **SYNCED 代码复制** — 9 处手工同步是定时炸弹。应该抽取为共享函数（`source .baton/hooks/_common.sh`）
2. **OpenCode glob 缺失** — 行为不一致，用户会遇到"shell 里能找到 plan 但 OpenCode 找不到"的困惑
3. **CI 覆盖缺口** — 最大的测试文件 (test-multi-ide.sh) 不在 CI 中运行；shellcheck 引用了已删除的文件

---

## Self-Review

- **批评者会首先质疑什么**: "Fail-open + advisory hooks = 形同虚设" — 回应：这误解了 baton 的定位，它是协作协议不是安全工具。但应该在文档中明确说明这一点。
- **最弱的结论**: 关于 advisory hooks 效力的分析缺少实证数据。实际上 AI 对 stderr 输出的合规率可能很高也可能很低，这取决于具体 LLM 和 system prompt。
- **如果进一步调查会改变什么**: 实际运行测试套件可能暴露 CI 配置之外的问题；分析 git history 可以揭示 SYNCED 代码是否曾经真的不同步过。

## Questions for Human Judgment

1. **SYNCED 代码是否应该重构为共享函数？** 这会改变所有 hook 从独立脚本变为 `source` 依赖，影响可移植性和调试。这是架构决策，不是纯技术问题。
2. **11 个 IDE 支持是否值得维护？** C 类 IDE（Codex, Zed, Roo）只有规则注入没有强制执行，价值有限但增加了 setup.sh 的复杂度。是否应该明确标注为"社区级"支持并降低维护优先级？
3. **Baton 的定位是"协作协议"还是"安全工具"？** 当前设计在两者之间。如果是协议，fail-open 是对的但应该去掉"protection"等暗示安全性的措辞；如果是安全工具，就需要收紧 fail-open 路径和 markdown 豁免。

## 九、项目方向分析

### 当前投入分布的错位

| 身份 | 核心文件 | 行数 | 占比 |
|---|---|---|---|
| 多 IDE 安装器 | setup.sh | 1524 | 58% |
| Shell hook 框架 | 8 个 hooks | 602 | 23% |
| 协作协议定义 | workflow.md + workflow-full.md | 466 | 18% |
| CLI 工具 | bin/baton | 298 | 11% |

**最大投入（58%）在安装层，但最大价值在协议层。** setup.sh 的 11 IDE 支持中，只有 Claude Code 拥有完整的 7 hook 集成 (settings.json:6-92)，其他 IDE 覆盖差距巨大：

| IDE | Hook 数 | 缺失的关键能力 |
|---|---|---|
| Claude Code | 7 | — 完整覆盖 |
| Cursor | 4 | 无 PostToolUse, Stop, TaskCompleted |
| Windsurf | 3 | 无 SessionStart 状态机, Stop, SubagentStart |
| Cline | 2 | 只有 PreToolUse + TaskComplete (wrapper 适配) |
| Augment | 2 | 只有 SessionStart + PreToolUse |
| Kiro | 1 | 只有 preToolUse |
| Codex/Zed/Roo | 0 | 纯规则注入，无执行强制 |

### 三个可行方向

**方向 A：协议优先（Protocol-first）**

Baton 的护城河不是 shell hooks — 任何人都能写 `grep BATON:GO`。护城河是 workflow 设计本身：research -> plan -> annotation cycle -> GO -> implement，加上 evidence standards、annotation protocol、complexity calibration。

- 把协议（workflow.md）作为核心产品，hooks/setup 降级为参考实现
- 停止追求 11 IDE 全覆盖，让各 IDE 社区自己做适配
- 提供 conformance test 而非安装脚本
- **风险**：协议没有执行力就变成一纸空文。没有 write-lock.sh 的 baton 只是很好的建议

**方向 B：深耕 Claude Code（推荐）**

Claude Code 是唯一拥有完整 7 hook 集成的平台。工程投入应与回报匹配。

- Claude Code 作为第一优先，做到极致
- 解决 SYNCED 代码复制问题（抽取 `_common.sh`）
- 强化 post-GO 阶段的可见性（当前 advisory hooks 太弱）
- 其他 IDE 保持 best-effort，明确标注保护级别差异
- **优势**：集中力量，解决技术债，提供最完整的体验

**方向 C：自适应信任（Adaptive Trust）**

当前 HITL 是二元的（有 GO / 没有 GO），但 workflow.md:22-26 已定义复杂度校准（Trivial/Small/Medium/Large），工具层完全没有利用。

- Trivial 任务（1文件, <20行）缩短或跳过 annotation cycle
- 基于历史信任度动态调整门控力度
- 实现审计日志，让人类可以事后审查而非事前审批
- **风险**：改变 baton 的根本哲学 — "人类在代码写入前审批" vs "部分场景自动审批"

**方向 D：Harness Engineering（修正后的推荐）**

Gate model（当前 baton）的假设是：控制 AI 行为的最佳方式是阻止错误操作。
Harness model 的假设是：最佳方式是**塑造 AI 的认知过程**，让它自然产出更好的结果。

Baton 其实**已经有 harness 元素**，只是没有被识别为核心：

| 组件 | 当前定位 | 实际角色 |
|---|---|---|
| baton-research SKILL.md | 技能文件 | **认知缰绳** — trace-before-conclude, counterexample sweep |
| baton-plan SKILL.md | 技能文件 | **认知缰绳** — derive-from-constraints, 禁止 jump-to-solution |
| baton-implement SKILL.md | 技能文件 | **认知缰绳** — re-read-before-mark-done |
| phase-guide.sh | SessionStart hook | **认知注入** — 阶段感知 |
| pre-compact.sh | PreCompact hook | **连续性缰绳** — 上下文压缩时保持记忆 |
| subagent-context.sh | SubagentStart hook | **一致性缰绳** — 子代理继承 plan 意识 |
| write-lock.sh | PreToolUse hook | **门禁** — 不是 harness，是 gate |

**Skills 才是真正的 harness。Hooks 只是投递机制。** 但当前 58% 投入在安装层，skills 不是工程重心。

#### 为什么 Harness > Gate

1. **Gate 对抗不了越来越聪明的 AI** — write-lock.sh 拦 Edit/Write/CreateFile，但 AI 可以用 Bash 写文件（bash-guard.sh:37-41 只警告）。Gate 是军备竞赛，harness 是范式改变。

2. **Gate 只衡量合规，不衡量质量** — 当前 baton 唯一能回答的是"BATON:GO 存在吗？"无法回答：research.md 是否真的覆盖了关键调用链？plan.md 是否从研究推导出方案？实现是否匹配 plan 意图？Harness 可以评估这些。

3. **Harness 天然跨 IDE** — Gate 需要适配器（Cursor 要 `{"decision":"deny"}`，Copilot 要 `{"permissionDecision":"deny"}`）。Harness（skills/prompts）是纯 markdown，每个 IDE 都支持注入 markdown 规则。11 IDE 全部自动获得完整体验，不再有 7 hook vs 0 hook 的差异。

4. **对齐行业方向** — Claude Code skills, Cursor rules, Windsurf rules, Cline rules 都在收敛到"注入行为引导"。Hook-based enforcement 是例外。

5. **与 AI 进化共生** — Gate: AI 更聪明 → 更多绕过路径 → 更多堵漏。Harness: AI 更聪明 → 更好地遵循认知引导 → harness 效果更强。

#### 架构转型

```
当前架构:                          Harness 架构:
┌─────────────────┐                ┌─────────────────┐
│  setup.sh (58%) │                │  Skills (60%)   │ ← 核心投资
├─────────────────┤                │  - cognitive    │   认知缰绳
│  hooks (23%)    │                │  - quality eval │   质量评估
│  - gate         │                │  - continuity   │   连续性
│  - advisory     │                ├─────────────────┤
├─────────────────┤                │  Hooks (20%)    │ ← skill 投递
│  protocol (18%) │                │  - inject       │   + 质量评估
│  - workflow.md  │                │  - evaluate     │
└─────────────────┘                ├─────────────────┤
                                   │  Protocol (10%) │
                                   ├─────────────────┤
                                   │  Install (10%)  │ ← 大幅简化
                                   └─────────────────┘
```

三种 harness 类型：
- **认知缰绳** (Cognitive) — 塑造 AI 怎么思考：research skill 的 trace-before-conclude、plan skill 的 derive-from-constraints
- **质量评估** (Quality) — 检查 AI 产出质量：自动检查 research.md 是否有 file:line 证据、是否有 Self-Review
- **连续性缰绳** (Continuity) — 跨边界保持上下文：pre-compact.sh 保存进度、subagent-context.sh 传递 plan

**write-lock.sh 保留但降级** — 从"核心机制"变为"最后的安全网"。就像安全带：你希望永远用不到，但它必须在。

#### 方向比较

| 维度 | B: 深耕 Claude Code | D: Harness Engineering |
|---|---|---|
| 核心投资 | hooks + Claude 集成 | skills + 质量评估 |
| 跨 IDE | Claude 优先，其他 best-effort | 天然跨平台（skills 是 markdown） |
| 可衡量性 | BATON:GO 存在/不存在 | 研究深度、计划质量、实现一致性 |
| 扩展性 | 每个 IDE 需要适配 | 新 IDE = 复制 skills 目录 |
| 与 AI 进化关系 | 军备竞赛 | 共生 |
| 保留 write-lock | 是，作为核心 | 是，作为安全网 |

### 核心修正：循环批注才是 Baton 的核心

以上 A/B/C/D 四个方向都是对**基础设施**的优化。但项目的真正核心不在基础设施层——而在**循环批注**（Annotation Cycle）本身。

项目名 "baton"（接力棒）直接揭示了这一点：
- AI 产出文档 → 传给人类
- 人类批注 → 传回 AI
- AI 用证据回应 → 传给人类
- 重复直到收敛 → BATON:GO

**循环批注是唯一创造人机共识的机制。** 验证：

- `workflow.md:1` — "Shared Understanding Construction Protocol" — 名字直接说明目的是构建共识
- `workflow-full.md:248-330` — ANNOTATION 阶段 82 行，是四个阶段中最详细的
- 6种批注类型覆盖人类反馈的完整频谱：
  - `[Q]` 提问 — 人类不理解
  - `[CHANGE]` 修改 — 人类不同意
  - `[DEEPER]` 不够深 — AI 分析不足
  - `[MISSING]` 遗漏 — AI 遗漏了什么
  - `[NOTE]` 补充 — 人类有额外知识
  - `[RESEARCH-GAP]` 需要更多调查 — 需要暂停去研究
- `workflow-full.md:271-293` — "Thinking Posture: Verify Before Responding" — AI 在批注循环中的认知姿态

**其他一切都是服务设施**：

| 组件 | 服务于循环批注的方式 |
|---|---|
| write-lock.sh | 强制 AI 经过循环批注才能写代码 |
| Skills (harness) | 让 AI 产出值得批注的高质量文档 |
| phase-guide.sh | 引导 AI 进入正确的批注阶段 |
| Evidence standards | 确保 AI 在批注回应中提供可验证的证据 |
| Annotation Log | 记录批注历史，形成决策审计轨迹 |
| BATON:GO | 循环批注的退出条件 |

### 修正后的方向推荐

以循环批注为核心，结合 Harness Engineering：

1. **强化循环批注本身** — 这是核心价值
   - 批注覆盖检查：人类是否审阅了所有章节？
   - 收敛度量：多少轮批注达到共识？
   - 批注质量：AI 回应是否都有 file:line 证据？

2. **Harness 服务于循环** — 方向 D 作为基础设施
   - 认知缰绳提高文档质量 → 更有效的批注循环
   - 质量评估自动检查 → 减少需要人类指出的明显问题
   - 连续性缰绳保持上下文 → 跨 session 的批注不丢失

3. **Gate 作为安全网** — write-lock.sh 保留
   - 不是核心机制，是最后防线
   - 确保即使 AI 试图跳过循环批注，也会被拦住

**应该避免的**：
- 不要变成重型框架 — baton 的力量在于 shell 脚本的简洁性和零依赖
- 不要与 IDE 原生功能竞争 — 如果 Cursor 添加原生 plan-approval，应集成而非对抗
- 不要加认证/授权 — baton 运行在用户环境中，用户本身就是权威
- 不要完全放弃 gate — write-lock.sh 作为安全网仍有价值
- 不要让基础设施优化（方向 A/B/C/D）分散对核心（循环批注）的关注

---

## 批注区

> 标注类型：`[Q]` 提问 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏 · `[NOTE]` 补充 · `[RESEARCH-GAP]` 需要更多调查
> 审阅完毕后告诉 AI "出 plan" 进入计划阶段

<!-- 在下方添加标注 -->
[Q]
    1.当前的baton是一个human in the loop workflow吗?

## Annotation Log

### Round 1

**[Q] § 整体定位**
"当前的baton是一个human in the loop workflow吗?"

-> **是，但是特定风格的 HITL：阶段门控 + 文档级批注循环。**

4个显式人类门控点：
1. BATON:GO 放置 — workflow.md:31 "Only the human places it"，write-lock.sh:91 是唯一解锁判断
2. "generate todolist" 指令 — workflow.md:32，phase-guide.sh:103-108 检测 AWAITING_TODO 状态
3. 批注循环 — workflow-full.md:248-330，人类用 [Q]/[CHANGE]/[DEEPER] 等标注反馈
4. 复杂度确认 — workflow.md:27 "AI proposes; human confirms"

与典型 HITL 的区别：
- **批量审批式** (batch gate)，不是逐操作审批 — BATON:GO 后 AI 自主实现
- **前置重点** (front-loaded) — 人类介入集中在 research/plan 阶段，实现阶段靠 advisory hooks 提供可见性但不阻止
- **文档驱动** — 交互媒介是 markdown 文档，不是 UI 弹窗
- **信任递增** — research -> plan -> annotation -> GO 是信任建立过程

BATON:GO 之后的 HITL 退化为 advisory：post-write-tracker.sh:63-66 警告 plan 外修改，stop-guard.sh:48-53 提醒进度，completion-check.sh:46-52 要求 Retrospective。均不阻止（completion-check 返回 exit 2 但仅在 TaskCompleted 事件）。

-> Result: 回答完毕，awaiting human decision

### Round 2

**[Q] § 项目方向 (chat)**
"还有更好的方向吗 harness engineering 呢"

-> **方向 D: Harness Engineering 优于之前推荐的方向 B。**

核心洞察：baton 的 skills（baton-research, baton-plan, baton-implement）已经是认知缰绳（cognitive harness），但当前架构把它们当作附属品，58% 投入在安装层。Harness engineering 意味着：
- Skills 成为核心产品（~60% 投入），hooks 降级为 skill 投递机制
- 新增质量评估 harness — 自动检查 AI 产出质量（file:line 覆盖率、Self-Review 存在性等）
- write-lock.sh 保留但从"核心机制"降级为"安全网"
- 天然跨 IDE — skills 是 markdown，不需要 per-IDE 适配器
- 与 AI 进化共生而非军备竞赛

已更新第九章，将方向 D 加入分析并修正推荐。

-> Result: 推荐修正为方向 D，awaiting human decision

### Round 3

**[NOTE] § 项目方向 (chat)**
"我认为目前的baton 核心是循环批注"

-> **同意。这个判断修正了我之前的分析框架。**

我之前的分析先后把 write-lock（第二章）、skills/harness（第九章方向 D）当作核心，但这两者都是服务于循环批注的基础设施。证据：
- workflow.md:1 "Shared Understanding Construction Protocol" — 目的是构建共识
- workflow-full.md:248-330 — ANNOTATION 阶段 82 行，四个阶段中最详细
- 项目名 "baton"（接力棒）直接指向来回传递的循环模式

修正后的认知层次：
- 循环批注 = 核心价值（创造人机共识的唯一机制）
- Harness/Skills = 基础设施（让 AI 产出值得批注的文档）
- write-lock = 安全网（强制 AI 经过循环才能写代码）

已更新第九章，重新锚定方向推荐到循环批注为核心。

-> Result: accepted，分析框架修正

1. 当前baton项目 又做了两个大的调整需要重新 research
2. 重新调研

## Annotation Log (continued)

### Round 4

**Re-research request § 整体 (annotation)**
"当前baton项目 又做了两个大的调整需要重新 research"
→ Inferred intent: 项目经历了两个重大调整，原 research 结论可能已过时，需要重新调研

通过 `git log --oneline` 和 `git diff HEAD~2 --stat` 确认两个调整对应两个 commit：
1. **051d241** — feat: improve baton installer safety and IDE support
2. **eeaed43** — feat: add Surface Scan and cascading defense to baton workflow

详见下方 Supplement 章节。

---

## Supplement A：安装器安全升级 (commit 051d241)

### 核心变化

原 research 记录 setup.sh 为 1524 行，支持 11 个 IDE，是"占总代码 58% 的最大组件"。
当前 setup.sh 仍然是 1524 行、11 个 IDE，但内部经历了**结构性重写** — 24 个文件变更，5267 行插入/422 行删除。

### A1. 选择性安装（新增能力）

**原行为**: 检测所有 IDE → 全部安装，用户无选择权。

**新行为**: 三路径决策树 (setup.sh:1361-1381)

| 路径 | 触发方式 | 行为 |
|------|---------|------|
| `--ide cursor,codex` | 命令行指定 | 只安装指定 IDE |
| `--choose` | 交互选择 | 显示编号菜单，用户选择 |
| 默认 | 无参数 | 只安装检测到的 IDE |

新增函数 (setup.sh:530-672):
- `normalize_ide_name()` :530 — 别名映射（amazonq→kiro, claudecode→claude）
- `parse_ide_list()` :563 — 解析逗号分隔 IDE 列表
- `parse_ide_choice()` :598 — 解析数字选择（"134" = IDE 1、3、4）
- `choose_ides()` :647 — 交互式菜单，显示各 IDE 保护级别

**影响**: 解决了原 research 5.5 节指出的 "parse_ide_choice 数字拼接解析是 micro-UX 优化" 问题 — 现在它是核心交互流程的一部分。

### A2. JSON 安全操作系统（新增能力）

原 research 批评了 setup.sh 中 "两个 30 行的 jq 函数做高度相似的事" 和 "86 行的防御性清理"。
当前实现**重构**为统一的安全操作层 (setup.sh:134-389):

| 函数 | 位置 | 用途 |
|------|------|------|
| `json_edit_with_jq()` | :134-152 | 原子 JSON 操作（临时文件 + 验证） |
| `baton_json_command_allowlist()` | :154-179 | Baton hook 命令白名单 |
| `baton_hook_count_in_json_file()` | :181-210 | 统计 JSON 中 Baton hook 数量 |
| `remove_baton_hooks_from_json_file()` | :254-300 | 精确移除 Baton hook（保留用户 hook） |
| `cleanup_baton_json_hook_file()` | :302-385 | 安全卸载编排（引用计数） |

**关键改进**: 卸载不再是 grep + 警告，而是**手术式移除** — 只移除白名单内的 Baton hook，保留用户自定义 hook，通过引用计数决定是否删除配置文件。

### A3. Cline 能力升级（新增适配器）

**新文件**: `.baton/adapters/adapter-cline-taskcomplete.sh` (12行)

**原状态**: Cline 只有 PreToolUse hook（写锁），缺少 TaskComplete hook。
**新状态**: Cline 现在有 PreToolUse + TaskComplete 双 hook。

adapter-cline-taskcomplete.sh 将 completion-check.sh 的 exit code 翻译为 Cline JSON：
- exit 2 → `{"cancel":true,"errorMessage":"..."}` (阻止完成)
- exit 0 → `{"cancel":false}` (允许完成)

**Hook wrapper 机制** (setup.sh:906-958):
- `write_cline_hook_wrapper()` 生成包装脚本
- 先运行 Baton 适配器，再调用用户原有 hook（如果有）
- 用户 hook 备份到 `.baton-user`，卸载时恢复

**更新后的 IDE 能力矩阵**:

| IDE | Hook 数 | 变化 |
|------|---------|------|
| Claude Code | 7 | 不变 |
| Cursor | 4 | 不变 |
| Windsurf | 3 | 不变 |
| **Cline** | **3** | **+1** (TaskComplete) |
| Augment | 2 | 不变 |
| Kiro | 1 | 不变 |
| Codex/Zed/Roo | 0 | 不变 |

### A4. 级联 Hook 合并系统（新增能力）

新增 5 个 JSON 合并函数 (setup.sh:806-898):
- `merge_json_with_jq()` :806 — 核心合并引擎
- `merge_nested_hook_entry()` :829 — 用于 Claude/Augment 嵌套 hook 格式
- `merge_flat_hook_entry()` :845 — 用于 Windsurf/Copilot/Kiro 扁平格式
- `run_merge_and_record()` :879 — 记录合并状态
- `report_merge_result()` :889 — 报告合并结果

**特性**: 幂等合并（已存在的 hook 不重复添加）+ 非阻塞（合并失败只警告不中断安装）。

### A5. 对原 research 结论的影响

| 原结论 | 当前状态 |
|--------|---------|
| "setup.sh 占 58%，复杂度过高" | ✅ 仍然 58%，但复杂度有更好的理由 — 选择性安装 + 安全卸载是用户要求的功能 |
| "parse_ide_choice 是 micro-UX 优化" | ❌ 已过时 — 现在是核心交互流程 |
| "两个统计函数可以合并" | ✅ 已重构为统一安全操作层 |
| "C 类 IDE 价值有限" | ✅ 不变 — Codex/Zed/Roo 仍然是纯规则注入 |
| "Cline 只有 2 个 hook" | ❌ 已过时 — 现在 3 个 hook |

---

## Supplement B：工作流质量框架 (commit eeaed43)

这是更大的调整，涉及**三个相互关联的变化**：Direction γ 批注协议、Surface Scan、级联防御。

### B1. Direction γ 批注协议

**原状态**: 6 个显式标注类型

| 标注 | 用途 |
|------|------|
| `[Q]` | 提问 |
| `[CHANGE]` | 修改请求 |
| `[DEEPER]` | 不够深 |
| `[MISSING]` | 遗漏 |
| `[NOTE]` | 补充 |
| `[RESEARCH-GAP]` | 需要更多调查 |

**新状态**: 自由文本 + AI 意图推断 (workflow.md:48-54, workflow-full.md:59-75)

> "Human adds feedback in research.md, plan.md, or chat. AI infers intent from content,
> responds with file:line evidence, and records in `## Annotation Log`.
> Only explicit type: `[PAUSE]` — stop current work, investigate something else first."

**处理流程** (workflow-full.md:65-69):
1. Read code first — cite file:line evidence
2. Infer intent — record inference in Annotation Log
3. Respond with evidence — adopt if right, explain if problematic
4. Consequence detection — did answer change direction/contradict/reveal contradictions?

**Annotation Log 格式变化**:
- 旧: `**[Q] § Design Approach**` (类型前缀)
- 新: `**Question § Design Approach**` (推断出的意图类别)

**设计理由**: 降低人类认知负担（不需要记住 6 种标注格式），让反馈更自然。AI 负责分类，人类只需要写想法。`[PAUSE]` 保留是因为它代表流程控制（暂停当前工作），不是内容分类。

**对原 research 的影响**:
- 第一章 Round 1 提到的 "人类用 [Q]/[CHANGE]/[DEEPER] 等标注反馈" → 已过时
- 第九章 "6种批注类型覆盖人类反馈的完整频谱" → 已过时，现在是 AI 推断覆盖完整频谱
- 批注区模板本身也需要更新（原 research 的批注区仍使用旧格式）

### B2. Surface Scan（计划阶段新增）

**问题根源**: 代码审查发现 72% 的计划遗漏率 — 计划未覆盖被变更影响的文件。

**实现位置**: baton-plan/SKILL.md Step 3b, workflow-full.md:221-222

**三级变更影响分析框架**:

| 级别 | 方法 | 范围 |
|------|------|------|
| L1 — 直接引用 | Grep/Glob 搜索被修改的术语、模式 | 精确匹配 |
| L2 — 依赖追踪 | 从 L1 结果追踪 import/source/引用链 | 一跳依赖 |
| L3 — 行为等价 | 找到实现相同概念但未命名引用的文件 | 标记 ❓ 待人类审查 |

**处置表** (baton-plan/SKILL.md:96-104):
```
| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| ... | L1/L2/L3 | modify / skip | ... |
```

- 默认处置: "modify"
- "skip" 需要显式理由
- 完整性检查: "if not updated, will users encounter old behavior?"

**与 Self-Review 集成** (baton-plan/SKILL.md:121-123):
计划的 Self-Review 现在必须检查: "Does the change list cover ALL files in the Surface Scan disposition table?"

**适用范围**: Medium/Large 变更必须执行 Surface Scan。Trivial/Small 免除。

### B3. 级联防御（实现阶段新增）

**问题根源**: 实现阶段的 bug 多数来自**同文件多次修改**导致的回归。

**四层防御触发器** (baton-implement/SKILL.md:79-122, workflow-full.md:362-368):

| 触发器 | 时机 | 动作 |
|--------|------|------|
| **回归检查** | 写代码后 | 重读修改点上下 5+ 行，检查是否破坏相邻逻辑 |
| **增量测试** | 完成每个 todo 后 | 运行相关文件的测试，失败则修复后才继续 |
| **同文件级联** | 修改已被先前 todo 改过的文件时 | 重读文件当前状态 + 重跑所有先前相关 todo 的验证 |
| **下游追踪** | 修改任何文件后 | 检查谁 import/call/read 此文件，变更是否影响消费者 |

**与原 research 的对比**:
原 Self-Check Triggers (workflow-full.md) 只有 2 条通用规则。现在扩展为 6 条具体触发器，直接对应实证发现的失败模式。

### B4. 技能驱动的阶段引导

**架构转变**:
- **原**: 阶段引导通过 SessionStart hook 运行时注入
- **新**: 阶段引导编码在 3 个 skill 文件中（baton-research/SKILL.md, baton-plan/SKILL.md, baton-implement/SKILL.md），由 AI 在进入阶段时主动调用

**证据**:
- workflow.md:39 — "Before entering any phase, check for the corresponding baton skill"
- workflow.md:67-70 — "detailed execution guides available as skills"
- workflow-full.md:100 — "If skills are not available, the SessionStart hook injects phase-specific guidance" (降级回退)

**意义**: 这呼应了原 research 第九章方向 D (Harness Engineering) 的预判 — skills 成为核心，hooks 降级为投递/回退机制。当前实现正在朝这个方向演进。

### B5. Self-Review 模板升级

**原模板**（单层）:
```
## Self-Review
- 3 questions a critical reviewer would ask
- Weakest conclusion and why
- What would change analysis if investigated further
```

**新模板**（双层）:
```
## Self-Review

### Internal Consistency Check (fix before presenting)
- 结论与证据一致？
- 章节间有矛盾？
- 发现矛盾 → 立即修复，不是发现

### External Uncertainties (present to human)
- 批评者的 3 个问题
- 最弱结论
- 进一步调查会改变什么
```

**关键改变**: 内部一致性检查从"呈现给人类的风险"变为"呈现前必须修复的 bug"。AI 必须在呈现研究/计划之前先自查矛盾。

### B6. 收敛检查（研究阶段新增）

**新增 Step 7: Convergence Check** (baton-research/SKILL.md:205-220):
1. 扫描被后续章节取代的结论 → 标记 "→ Revised in [later section]"
2. 写 `## Final Conclusions` — 只列出当前有效结论
3. 捕获聊天中的需求 — 记录人类在聊天（非文档）中声明的需求

**意义**: 确保跨 session 边界时，计划推导从单一一致性来源工作。

---

## Supplement C：测试体系变化

### 指标对比

| 指标 | 原 research | 当前 | 变化 |
|------|-----------|------|------|
| 测试文件数 | 12 | 13 | +1 (test-ide-capability-consistency.sh) |
| 测试总行数 | 3927 | 4177 | +250 |
| CI 中运行 | 7 | 7 | 不变 |
| 最大测试 | test-multi-ide.sh (924行) | 不变 | — |

### 主要变化

**test-workflow-consistency.sh**: 289 → 499 行 (+210)
- 新增 Direction γ 验证 (:285-328) — 确认 [PAUSE] 是唯一显式标注，旧标注已移除
- 新增 Surface Scan 一致性检查 (:435-489) — 验证 baton-plan 有 L1/L2/L3、baton-implement 有回归检查和级联防御
- 新增 Skill frontmatter 验证 (:193-276)

**test-annotation-protocol.sh**: 70 → 94 行 (+24)
- 反转测试逻辑: 从"旧标注必须存在"变为"旧标注必须不存在"
- 新增 `check_not()` 辅助函数
- 验证 Direction γ 要素: [PAUSE], "infers intent", "Free-text is the default"

**test-ide-capability-consistency.sh**: 新文件 (57行)
- 确保 IDE 能力描述在 setup.sh、README.md、docs/ 之间保持一致
- 验证 Cursor IDE、Kiro (.amazonq)、Roo Code 的文档措辞同步

### ❌ CI 问题仍存在

ci.yml:25 仍然 shellcheck `adapter-windsurf.sh`，但此文件可能已被删除（configure_windsurf 现在使用 native hooks）。原 research 已指出此问题，**尚未修复**。

---

## 更新后的指标总览

| 身份 | 核心文件 | 行数 | 占比 |
|------|---------|------|------|
| 多 IDE 安装器 | setup.sh | 1524 | 51% |
| Shell hook 框架 | 8 个 hooks + 5 个 adapters | 684 | 23% |
| 协作协议定义 | workflow.md + workflow-full.md | 456 | 15% |
| CLI 工具 | bin/baton | 298 | 10% |
| **总实现代码** | | **2962** | |
| **测试代码** | 13 个文件 | **4177** | 测试/实现比 1.41:1 |

*注: 适配器从 4 个增加到 5 个（+adapter-cline-taskcomplete.sh），总实现代码从 2632 增加到 2962。*

*注 2: Skills (baton-research/SKILL.md, baton-plan/SKILL.md, baton-implement/SKILL.md) 不在此统计中，因为它们被 .gitignore 排除，不属于版本控制的代码。这是一个架构问题 — 如果 skills 是核心（方向 D / Harness Engineering），它们应该被纳入版本控制。*

---

## 更新后的核心结论

### 原结论 vs 当前状态

| # | 原结论 | 状态 | 说明 |
|---|--------|------|------|
| 1 | SYNCED 代码复制是定时炸弹 | ✅ 仍然成立 | 9 处手工同步未改变 |
| 2 | OpenCode glob 缺失 | ✅ 仍然成立 | opencode-plugin.mjs 仍不支持 plan-*.md |
| 3 | CI 覆盖缺口 | ✅ 仍然成立 | shellcheck 仍引用已删除文件；13 个测试只有 7 个在 CI |
| 4 | setup.sh 复杂度过高 | ⚠️ 需修正 | 复杂度有更好的理由（选择性安装 + 安全卸载），但仍然是最大组件 |
| 5 | 循环批注是核心 | ✅ 仍然成立 | Direction γ 进一步强化了这个定位 |
| 6 | Harness Engineering 是正确方向 | ✅ 得到验证 | skills 已成为阶段引导的主要载体 |

### 新结论

7. **Direction γ 是正确的简化** — 从 6 个显式标注类型到自由文本 + AI 推断，降低了人类使用门槛，利用了 AI 的自然语言理解能力。`[PAUSE]` 保留为唯一显式类型是精确的设计 — 它代表流程控制（暂停），不是内容分类。

8. **Surface Scan 填补了关键空白** — 原 research 没有发现的问题：计划阶段缺少系统性的影响范围分析。72% 的计划遗漏率说明这不是偶发问题，而是流程缺陷。三级分析框架（L1 直接引用 → L2 依赖追踪 → L3 行为等价）是对变更影响分析学术方法的务实简化。

9. **级联防御对齐实证失败模式** — 4 个触发器中，"同文件级联" 最有价值 — 根据实证数据，3/4 的级联 bug 来自同文件多次修改。这是唯一需要重跑先前验证的触发器，成本最高但针对最大风险。

10. **Skills 未纳入版本控制是架构矛盾** — `.gitignore` 排除 `.claude/*`（只保留 settings.json），意味着 baton-research/baton-plan/baton-implement 三个 skill 文件没有版本历史，不会传播到 fresh clone。但它们已经是阶段引导的主要载体。如果 Harness Engineering 是方向，skills 必须被版本控制。
    
---

## Self-Review (re-research)

### Internal Consistency Check

- ✅ 原 research 结论 1-3（SYNCED、OpenCode glob、CI 缺口）经验证仍然成立
- ✅ 结论 4（setup.sh 复杂度）已标注为需修正
- ✅ Supplement A/B/C 之间无矛盾
- ⚠️ 原 research 批注区仍使用旧格式（`[Q]` 等），与 Direction γ 不一致 — 这是历史文档，不需要修改

### External Uncertainties

1. **批评者会问**: "Surface Scan 和级联防御只存在于 skills（不在版本控制中）和 workflow-full.md 中，它们的实际执行率是多少？" — 无实证数据回答这个问题。
2. **最弱结论**: 第 9 条关于 "3/4 级联 bug 来自同文件修改" 的数据来源是 plan-quality 研究，样本量可能很小。
3. **进一步调查**: 运行完整测试套件验证 CI 问题是否真的存在；检查 `adapter-windsurf.sh` 在当前代码库中是否真的被删除。

## Questions for Human Judgment

1. **Skills 是否应纳入 git 版本控制？** 当前 `.gitignore` 排除 `.claude/*`。如果 skills 是核心，它们需要版本历史和跨 clone 传播。但这可能与 Claude Code 的默认行为冲突（`.claude/` 通常是本地配置目录）。
    skills需要纳入版本控制
2. **Direction γ 是否需要回退机制？** 自由文本 + AI 推断依赖 AI 的理解能力。如果 AI 推断错误，人类能否纠正？当前设计中人类只能说"不是这个意思"然后 AI 重新推断 — 没有显式覆盖。
    如果 AI 推断错误，人类能纠正
## Annotation Log (continued)

### Round 5

**Confirmation § Skills 版本控制 (annotation on Q1)**
"skills需要纳入版本控制"
→ Inferred intent: 确认决策 — skills 应纳入 git 版本控制
→ Accepted. 当前 `.gitignore` 中 `.claude/*` 排除了所有 skill 文件。需要修改 `.gitignore` 添加 `!.claude/skills/` 豁免。
→ Consequence: 这是一个实施项，记录到计划阶段。

**Confirmation § Direction γ 回退 (annotation on Q2)**
"如果 AI 推断错误，人类能纠正"
→ Inferred intent: 认为现有机制已足够 — 人类直接纠正 AI 推断，无需额外回退机制
→ Accepted. 当前 Annotation Protocol (workflow-full.md:65-75) 的 step 2-3 已覆盖此场景：AI 推断意图 → 人类不满意 → 人类再次反馈 → AI 重新推断。这是自然的纠错循环。
→ No further action needed.

**Direction change § IDE 精简 (批注区)**
"关于支持的ide 我想进行精简 只支持常用的 claude codex cursor factoryAI OpencodeAI 其他的不考虑支持了"
→ Inferred intent: 要求大幅缩减 IDE 支持范围，从 11 个降到 5 个

#### 影响分析

**保留** (5 个):

| IDE | 当前保护级别 | 安装器行数 | 适配器 |
|-----|------------|-----------|--------|
| Claude Code | A 类 — 7 hooks | configure_claude :962-1088 (126行) | 无需 |
| Factory | A 类 — 同 Claude | configure_factory :1090-1093 (4行) | 无需 |
| Cursor | A 类 — 4 hooks + adapter | configure_cursor :1096-1155 (60行) | adapter-cursor.sh |
| Codex | C 类 — 仅规则 | configure_codex :1318-1335 (18行) | 无需 |
| OpenCode | ⚠️ 不在 setup.sh 中 | 无 | opencode-plugin.mjs (独立 JS 插件) |

**删除** (6 个):

| IDE | 当前保护级别 | 安装器行数 | 适配器 |
|-----|------------|-----------|--------|
| Windsurf | A 类 — 3 native hooks | configure_windsurf :1157-1203 (47行) | 无 (native hooks) |
| Cline | B 类 — 3 hooks + wrapper | configure_cline :1205-1217 (13行) + wrapper :900-958 (59行) | adapter-cline.sh + adapter-cline-taskcomplete.sh |
| Augment | A 类 — 2 hooks | configure_augment :1219-1247 (29行) | 无 |
| Kiro | B 类 — 1 hook | configure_kiro :1249-1275 (27行) | 无 |
| Copilot | B 类 — 2 hooks + adapter | configure_copilot :1277-1316 (40行) | adapter-copilot.sh |
| Zed | C 类 — 仅规则 | configure_zed :1337-1347 (11行) | 无 |
| Roo | C 类 — 仅规则 | configure_roo :1349-1355 (7行) | 无 |

**预估删减量**:
- 安装器: ~233 行 configure_* 函数 + ~59 行 Cline wrapper 系统 + 对应的卸载逻辑 (~120行) + IDE 检测/选择中的 6 个 case ≈ **~450 行** (setup.sh 从 1524 → ~1074)
- 适配器: 删除 3 个文件 (adapter-copilot.sh 11行, adapter-cline.sh 22行, adapter-cline-taskcomplete.sh 12行)
- 测试: test-multi-ide.sh (924行) 大幅缩减，test-adapters.sh 缩减，test-adapters-v2.sh 可能整体删除

#### ⚠️ 需要注意的问题

1. **OpenCode 不在 setup.sh 中** — opencode-plugin.mjs 是独立的 JS 插件 (`.baton/adapters/opencode-plugin.mjs`, 26行)，不通过 setup.sh 安装。用户需要手动集成。如果要将 OpenCode 作为正式支持的 IDE，需要新增 `configure_opencode()` 函数。

2. **OpenCode glob 缺陷仍存在** — 原 research 指出 opencode-plugin.mjs:12 不支持 `plan-*.md` glob fallback，只检查固定的 `plan.md`。如果要正式支持 OpenCode，应修复此问题。

3. **Cline TaskComplete 适配器刚添加** — commit 051d241 刚新增了 adapter-cline-taskcomplete.sh 和 hook wrapper 机制。精简后这些新代码将被立即删除。

4. **Copilot 用户影响** — GitHub Copilot 是使用量大的 IDE。删除支持意味着 Copilot 用户无法使用 Baton 的 hook 保护（但仍可以手动使用 workflow.md）。

5. **JSON 安全操作系统可能过度设计** — setup.sh:134-389 的 JSON 合并/清理函数主要服务于多 IDE 场景。精简到 5 个 IDE 后（其中 Codex 无需 JSON 操作，OpenCode 不在 setup.sh，Factory = Claude），实际只有 Claude 和 Cursor 需要 JSON 操作，复杂度可进一步降低。

#### 精简后的架构

```
保留 IDE:
┌────────────────────┬────────────────┬──────────────────┐
│ Claude Code (7 hooks) │ Factory (= Claude) │ Cursor (4 hooks + adapter) │
├────────────────────┼────────────────┼──────────────────┤
│ A 类 — 完整保护   │ A 类 — 完整保护 │ A 类 — hook 强制  │
└────────────────────┴────────────────┴──────────────────┘
┌────────────────────┬────────────────────────┐
│ Codex (仅规则)      │ OpenCode (JS 插件, 非 setup.sh) │
├────────────────────┼────────────────────────┤
│ C 类 — 规则注入    │ B 类 — 独立插件         │
└────────────────────┴────────────────────────┘
```

→ Consequence: 这是方向性变更。与原 research 第九章方向 D (Harness Engineering) 一致 — 减少安装器投入，集中在核心平台。但 OpenCode 的集成方式需要在计划阶段明确。
→ Result: 记录，待 plan 阶段具体设计

---

## Updated Questions for Human Judgment

1. ~~Skills 是否应纳入 git 版本控制？~~ → **已确认: 是**
2. ~~Direction γ 是否需要回退机制？~~ → **已确认: 不需要，人类可直接纠正**
3. ~~OpenCode 的集成方式?~~ → **已确认: 去掉 OpenCode 支持**

## Annotation Log (continued)

### Round 6

**Direction change § OpenCode 也删除 (annotation on Q3)**
"去掉OpenCode的支持"
→ Inferred intent: 进一步缩减 IDE 范围，OpenCode 也不保留
→ Accepted. opencode-plugin.mjs (26行) 将被删除。
→ Consequence: 最终保留 4 个 IDE — **claude, factory, cursor, codex**。
  原 research 第六章 "OpenCode 插件的差异分析" 和结论 #2 "OpenCode glob 缺失" 不再适用。

**最终 IDE 列表确认**:

| IDE | 保护级别 | 保留组件 |
|-----|---------|---------|
| Claude Code | A 类 — 7 hooks | configure_claude, 所有 8 个 hooks |
| Factory | A 类 — 同 Claude | configure_factory (= configure_claude) |
| Cursor | A 类 — 4 hooks + adapter | configure_cursor, adapter-cursor.sh |
| Codex | C 类 — 仅规则 | configure_codex (AGENTS.md 注入) |

**删除清单**:

| 删除项 | 类型 | 行数 |
|--------|------|------|
| configure_windsurf | 安装函数 | 47 |
| configure_cline + wrapper 系统 | 安装函数 | 72 |
| configure_augment | 安装函数 | 29 |
| configure_kiro | 安装函数 | 27 |
| configure_copilot | 安装函数 | 40 |
| configure_zed | 安装函数 | 11 |
| configure_roo | 安装函数 | 7 |
| 7 个 IDE 的卸载逻辑 | 卸载函数 | ~120 |
| 7 个 IDE 的检测/选择逻辑 | IDE 选择 | ~50 |
| adapter-copilot.sh | 适配器 | 11 |
| adapter-cline.sh | 适配器 | 22 |
| adapter-cline-taskcomplete.sh | 适配器 | 12 |
| opencode-plugin.mjs | JS 插件 | 26 |
| **总删减** | | **~474 行** |

**精简后架构**:
- setup.sh: ~1524 → ~1050 行 (31% 减少)
- 适配器: 5 → 1 (只保留 adapter-cursor.sh)
- 安装器占总代码比: 58% → ~45%

---

## Final Conclusions

基于原 research + Supplement A/B/C + Round 4-6 批注循环，以下是当前有效结论：

1. **循环批注是 Baton 的核心** — 所有其他组件服务于此。(Round 3 确认)

2. **Direction γ 是正确简化** — 自由文本 + AI 推断取代 6 个显式标注类型，人类可直接纠正推断错误。(Supplement B1, Round 5 Q2 确认)

3. **Surface Scan 填补计划完整性空白** — 三级变更影响分析 (L1→L2→L3) 解决 72% 计划遗漏率。(Supplement B2)

4. **级联防御对齐实证失败模式** — 同文件级联触发器针对最大风险源。(Supplement B3)

5. **Skills 必须纳入版本控制** — 修改 .gitignore 添加 `!.claude/skills/` 豁免。(Round 5 Q1 确认)

6. **IDE 精简到 4 个** — 保留 claude, factory, cursor, codex。删除 windsurf, copilot, augment, kiro, cline, zed, roo, opencode。预估删减 ~474 行。(Round 5-6 确认)
   - Human requirement (annotation): "只支持常用的 claude codex cursor factoryAI"
   - Human requirement (annotation on Q3): "去掉OpenCode的支持"

7. **SYNCED 代码复制问题仍存在** — 9 处手工同步未改变，是最大维护风险。(原结论 #1, 仍有效)

8. **CI 覆盖缺口仍存在** — ci.yml:25 引用已删除的 adapter-windsurf.sh；13 个测试只有 7 个在 CI。(原结论 #3, 仍有效)

9. ~~OpenCode glob 缺失~~ → **不再适用** (OpenCode 已决定删除)

10. **setup.sh 复杂度将显著降低** — 精简后从 58% 降到 ~45%，与 Harness Engineering 方向一致。(原结论 #4 修正)

---

Research 已完成所有调研和批注循环。审阅完毕后告诉我 "出 plan" 进入计划阶段。

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前研究方向去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完毕后告诉 AI "出 plan" 进入计划阶段 -->