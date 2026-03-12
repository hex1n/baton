# Baton v3 实现设计

> 日期: 2026-03-02
> 基础: docs/first-principles.md
> 定位: Baton 是 AI 辅助开发的"共同理解构建协议"
> 两层架构: workflow.md（跨切面核心，始终加载）+ SKILL.md（per-phase 权威，规范性）
> 三个组件: 文档（载体）+ 标注协议（对话方式）+ 写锁（时序保证）

---

## 一、架构总览

### 文件结构

```
.baton/
├── write-lock.sh          # 写锁（PreToolUse hook）
├── phase-guide.sh         # 阶段引导（SessionStart hook）— 优先提示 skill，回退到硬编码摘要
├── stop-guard.sh          # 停止提醒（Stop hook）
├── bash-guard.sh          # Bash 写入警告（PreToolUse Bash hook）
├── workflow.md            # 跨切面核心规则（始终加载）
└── adapters/              # 跨 IDE 适配器（不变）

.claude/skills/             # 阶段方法论（agentskills.io 标准，per-phase 权威）
├── baton-research/SKILL.md # 研究阶段 skill（规范性）
├── baton-plan/SKILL.md     # 计划+标注阶段 skill（规范性）
└── baton-implement/SKILL.md# 实现阶段 skill（规范性）
```

### 运行时产出的文件（用户项目中）

```
project/
├── research.md            # AI 的理解（可选，简单任务可跳过）
├── plan.md                # 双方共识（标注循环的主要载体）
└── plans/                 # 归档目录
    ├── plan-2026-03-01-auth-refactor.md
    └── research-2026-03-01-auth-refactor.md
```

### Hook 配置（不变）

```json
{
  "hooks": {
    "SessionStart": [{ "type": "command", "command": "sh .baton/phase-guide.sh" }],
    "PreToolUse": [
      { "type": "command", "command": "sh .baton/write-lock.sh", "matcher": "Edit|Write|MultiEdit|CreateFile|NotebookEdit" },
      { "type": "command", "command": "sh .baton/bash-guard.sh", "matcher": "Bash" }
    ],
    "Stop": [{ "type": "command", "command": "sh .baton/stop-guard.sh" }]
  }
}
```

---

## 二、workflow.md（核心规则，始终加载）

**设计约束**：只包含 AI 必须始终遵守的跨切面规则。阶段方法论由 SKILL.md 提供（per-phase 权威）。对于支持 skills 但不支持 SessionStart 的 IDE，始终加载的入口也应保持为这个 slim 文件，避免把 phase methodology 常驻进上下文。

```markdown
## Baton — 共同理解构建协议

写锁: plan.md 含 `<!-- BATON:GO -->` 才能写源码。markdown 始终可写。
删除 `<!-- BATON:GO -->` 可回退到标注循环。

### 流程
场景 A（目标明确）: research.md → 人提需求 → plan.md → 标注循环 → BATON:GO → 生成 todolist → 实现
场景 B（需要探索）: research.md ← 标注循环 → plan.md ← 标注循环 → BATON:GO → 生成 todolist → 实现
简单改动可跳过 research.md。

### 标注协议
人在 research.md、plan.md 或 chat 中给反馈。自由文本是默认形式；`[PAUSE]` 是唯一显式 marker：
- 自由文本补充上下文 / 提问 / 指出方案问题 → AI 推断意图，用 file:line 回应
- 自由文本指出深度不足或遗漏 → AI 继续调查并更新文档
- `[PAUSE]` → 暂停当前方向，先做补充研究，再回来处理剩余反馈

所有反馈都要记录到 `## Annotation Log`，且 AI 必须同时更新文档正文，不允许只写 log 不改正文。

**人不一定对。** 有问题必须用证据说明，给替代方案。最终决定权在人。

### 规则
- BATON:GO 前不写源码。NEVER 自行添加 BATON:GO
- plan.md 不含 todolist。人说"生成 todolist"后追加 ## Todo
- 每条标注必须回应 + 记录 Annotation Log
- 只改计划中的文件；需加文件先在 plan 中提出
- 同一方法失败 3× → 停下报告
- 实现过程中发现遗漏 → 停下，更新 plan.md，等人确认
- 全部完成后提醒归档到 plans/
```

---

## 三、SKILL.md 阶段方法论（per-phase 权威）

每个阶段的 SKILL.md 是该阶段的规范性权威。workflow.md 提供跨切面核心规则，SKILL.md 提供阶段方法论。两层模型：workflow.md（始终加载）+ SKILL.md（按需调用）。

以下是各阶段 SKILL.md 的内容设计：

### [RESEARCH] 研究阶段引导

```markdown
### [RESEARCH] 研究阶段

目标：建立 AI 对代码的理解，形成可供人审阅的文档。

research.md 应该让人能判断：
1. AI 是否充分理解了代码
2. AI 的理解是否正确
3. 是否有遗漏

不设固定模板，但研究应该回答：
- **研究了什么** — 范围，读了哪些文件，为什么选这些
- **代码怎么运行的** — 关键执行路径、调用链，每个节点附 file:line
  调用链追到叶子节点或明确截止点（标注截止原因）
- **有什么风险** — 用 ✅（已确认安全）/ ❌（发现问题）/ ❓（待确认）标记
  每个风险附验证证据或待验证原因
- **还不知道什么** — 未读的文件及原因，未验证的假设

深度技巧：
- 调用链不要停在接口层，追到实现
- 对每个"应该没问题"追问：真的验证过了吗？
- 用 subagent 并行追踪不同分支的调用链（10+ 文件时）

场景 B 中 research.md 可能经历标注循环：
人用自由文本指出问题、遗漏或方向调整（必要时写 `[PAUSE]`）→ AI 回应并更新 → 循环直到人满意
```

### [PLAN] 计划阶段引导

```markdown
### [PLAN] 计划阶段

目标：基于研究和需求，形成人可审批的改动方案。

plan.md 应该让人能判断：
- AI 打算做什么（具体改动）
- 为什么这么做（理由、取舍）
- 有什么风险（应对策略）

plan.md 应包含：
- **做什么** — 具体改动，引用 research 中的发现
- **为什么** — 设计理由、考虑过的替代方案及其取舍
- **影响什么** — 涉及的文件、受影响的调用方/使用方
- **风险 + 应对** — 可能出问题的点及策略

plan.md 不包含 todolist。
人对 plan 满意后说"生成 todolist"→ AI 在 plan.md 末尾追加 ## Todo。
每个 todo item 应包含：具体改动、涉及文件、验证方式。

#### 方案分析（第一性原理）

计划不是直接给"怎么做"，而是从研究发现中**推导**出方案：

1. **提取根本约束**：从 research.md 中识别出限制方案选择的硬性约束
   （架构限制、性能瓶颈、依赖关系、向后兼容、团队规范 等）

2. **推导 2-3 个方案**，每个方案需说明：
   - 可行性：✅ 可行 / ⚠️ 有风险 / ❌ 不可行，附判断依据（evidence: file:line）
   - 优点和缺点（对照根本约束逐条分析）
   - 预估影响范围（涉及的文件数、调用方数量）

3. **给出推荐 + 理由**
   推荐不是偏好，而是约束条件下的最优选择。理由应可追溯到 research 中的具体发现。

#### 当研究发现根本问题时

如果 research 阶段发现项目现有设计本身有问题（例如：架构不支持新需求、技术债导致无法安全修改），
AI 必须**诚实呈现**，而不是在有问题的基础上硬做方案：

1. 用 evidence 说明问题本质（不是"我觉得"，而是"file:line 显示..."）
2. 给出两类方案对比：
   - **方案 A：在现有结构内打补丁**（做什么、风险、技术债增量）
   - **方案 B：解决根本问题**（改什么、成本、长期收益）
3. 明确说明：这是架构级决策，需要人决定
4. 不替人做决定，也不隐瞒问题假装能做

示例：
    研究发现：当前 auth 模块耦合在 controller 层（evidence: src/auth/controller.ts:30-80）。
    新需求（API 网关鉴权）无法复用现有逻辑。

    方案 A（打补丁）：在网关层重新实现一套鉴权。
    - 可行性：✅ 技术上可行
    - 缺点：两套鉴权逻辑，未来维护成本翻倍
    - 风险：逻辑不同步导致安全漏洞

    方案 B（解决根本问题）：将 auth 提取为独立 service。
    - 可行性：⚠️ 涉及 12 个文件、3 个调用方
    - 优点：一次解决，后续需求都能复用
    - 成本：预估改动量大，需要回归测试

    ⚠️ 这是架构级决策。方案 A 快但积累债务，方案 B 彻底但成本高。请决定方向。
```

### [ANNOTATION] 标注循环详细说明

```markdown
### [ANNOTATION] 标注循环

标注循环是 Baton 的核心机制。适用于 research.md 和 plan.md。

#### 完整流程
1. AI 产出文档（research.md 或 plan.md）
2. 人阅读，在文档中直接写反馈，或在 chat 中给反馈
3. AI 读取文档，找到所有新标注
4. AI 逐条回应：
   - 如果人说的对 → 采纳，更新文档
   - 如果人说的有问题 → 用证据说明，给替代方案，让人决定
5. 所有回应记录到 ## Annotation Log
6. 人看 AI 回应，可能继续标注 → 回到步骤 3
7. 人满意 → 添加 BATON:GO → 说"生成 todolist" → 进入实现阶段

#### 标注格式
人直接在文档中相关位置写反馈。自由文本是默认形式；只有需要暂停当前方向时才写 `[PAUSE]`。

例如：

    ### 设计方案：使用 Service 层校验
    为什么不在 middleware 统一做？这样每个 service 都要重复
    历史上 middleware 做过校验但因为性能问题移到了 service 层

#### AI 回应的核心原则

人不一定对。AI 的职责是把它知道的信息传递给人，不是盲从。

正确的 AI 行为：
- 人说"改用 Redis" → AI 发现全项目 0 个 Redis 依赖 → 说明引入成本 + 给替代方案 → 让人决定
- 人说"这个函数不安全" → AI 验证发现确实有问题 → 承认错误，更新文档
- 人说"删掉这个检查" → AI 发现这个检查防止了空指针 → 说明风险 + 问人是否确定

错误的 AI 行为：
- 人说什么就改什么（盲从）
- AI 觉得人错了但不说（隐瞒）
- AI 反复争辩不让人做决定（过度抵抗）

#### Annotation Log 格式

    ## Annotation Log

    ### Round 1 (YYYY-MM-DD)

    **Question § 设计方案**
    "为什么不在 middleware 统一做？"
    → 推断意图：质疑设计选择
    → middleware 不了解业务语义，无法做字段级校验（evidence: src/middleware/validate.ts:30 只做 JSON schema 校验）。
      如果要做业务校验需要把业务逻辑耦合进 middleware。
    → 结果：人接受，保持 service 层校验

    **Change Request § 缓存策略**
    "改用 Redis"
    → 推断意图：要求修改缓存方案
    → ⚠️ 当前全项目使用进程内缓存（evidence: 0 个 Redis 依赖）。
      引入 Redis 需要：(1) docker-compose 配置 (2) 连接管理 (3) 序列化
      替代方案：现有 CacheManager 加 TTL（src/cache.ts:30）
    → 等待人决定

#### [PAUSE] 处理流程
1. 暂停对当前文档其他标注的处理
2. 针对暂停主题做补充研究
3. 将研究结果追加到 research.md（作为 ## Supplement: <topic>）
4. 回到当前文档，继续处理剩余标注
5. 在 Annotation Log 中记录：暂停原因 + 关键发现 + 对当前文档的影响
```

### [IMPLEMENT] 实现阶段引导

```markdown
### [IMPLEMENT] 实现阶段
> 仅在 plan.md 含 <!-- BATON:GO --> 后生效

- 按 ## Todo 顺序实现
- 每个 item 完成后：typecheck/build → 通过后标记 [x]
- 全部完成后：跑完整测试套件，在 plan.md 底部记录结果
- 实现过程中发现计划遗漏：
  · 小补充 → 更新 plan.md 说明，人确认后继续
  · 需要改设计方向 → 停下，告知人。人删除 BATON:GO 回退到标注循环
- 全部完成 + 测试通过 → 提醒归档：
  mkdir -p plans && mv plan.md plans/plan-$(date +%Y-%m-%d)-topic.md
- 如果中途停止 → 在 plan.md 追加 ## Lessons Learned（什么有效/什么无效/下次怎么做）

Todolist 有依赖关系的 items 应顺序执行（后续 item 需要看到前面的实际代码）。
无依赖的 items 可并行（subagent）。超长 todolist (10+) 建议分批。
```

---

## 四、phase-guide.sh 设计

### Skills-first 架构（v5.0）

phase-guide.sh 采用 skills-first 策略：优先检测对应阶段的 baton skill 是否已安装，
已安装时提示用户调用 skill（如 `/baton-research`），未安装时回退到硬编码摘要。

每个阶段独立检测对应 skill：
- RESEARCH → `has_skill baton-research`
- PLAN / ANNOTATION → `has_skill baton-plan`
- IMPLEMENT → `has_skill baton-implement`

`has_skill()` 函数从 pwd 开始向上遍历目录树，在 9 种 IDE 的 skills 目录中查找 SKILL.md，
与 find_plan 使用相同的 walk-up 算法。

### 状态检测逻辑

```
# 优先级从高到低检测

1. 归档检测
   plan.md 存在 + BATON:GO + 所有 todo 标记 [x] + 无未标记 todo
   → 输出：任务已完成，建议归档

2. AWAITING_TODO
   plan.md 存在 + BATON:GO + 无 ## Todo
   → 输出：提醒人说 "generate todolist"

3. 实现阶段
   plan.md 存在 + BATON:GO + ## Todo 存在
   → 有 baton-implement skill：提示 /baton-implement
   → 无 skill：输出硬编码 IMPLEMENT 摘要

4. 标注循环（plan）
   plan.md 存在 + 无 BATON:GO
   → 有 baton-plan skill：提示 /baton-plan
   → 无 skill：输出硬编码 ANNOTATION 摘要

5. 计划阶段
   research.md 存在 + 无 plan.md
   → 有 baton-plan skill：提示 /baton-plan
   → 无 skill：输出硬编码 PLAN 摘要

6. 研究阶段
   无 research.md + 无 plan.md
   → 有 baton-research skill：提示 /baton-research
   → 无 skill：输出硬编码 RESEARCH 摘要

7. 跳过研究（边界情况）
   无 research.md + plan.md 存在
   → 视为标注循环（简单任务直接写了 plan）
```

### Skill 检测输出示例

**有 skill 时**（简洁提示，详细方法论由 skill 本身提供）：
```
📍 RESEARCH phase — invoke /baton-research to begin investigation
```

**无 skill 时**（回退到硬编码摘要）：
```
📍 RESEARCH phase — name the file by topic: research-<topic>.md
Investigate code: start from entry points, trace call chains with file:line evidence.
...
```

**归档提醒**（无 skill 区分）：
```
📋 All tasks complete. Consider archiving:
   mkdir -p plans && mv plan.md plans/plan-$(date +%Y-%m-%d)-topic.md
   mv research.md plans/research-$(date +%Y-%m-%d)-topic.md
💡 The Annotation Log records design decision rationale — valuable long-term reference.
```

---

## 五、write-lock.sh 设计

### 变更：最小改动

与当前 baton 的 write-lock.sh 相比，逻辑**几乎不变**：

```
1. BATON_BYPASS=1 → 放行（不变）
2. 读取目标文件路径（不变）
3. 目标是 .md/.mdx/.markdown → 放行（不变）
4. 找 plan.md（walk-up 算法，不变）
5. 无 plan.md → 阻止（不变）
6. plan.md 无 BATON:GO → 阻止（不变）
7. plan.md 有 BATON:GO → 放行（不变）
```

**唯一改动：阻止消息措辞更新**

无 plan.md 时：
```
🔒 Blocked: 无 plan.md。
📍 先完成研究（research.md），再写计划（plan.md）。简单改动可直接写 plan.md。
```

plan.md 无 BATON:GO 时：
```
🔒 Blocked: plan.md 未审批。
📍 标注循环进行中。完成审批后添加 <!-- BATON:GO --> 解锁。
```

---

## 六、stop-guard.sh 设计

### 变更：增加归档提醒

在当前逻辑基础上增加：

```
现有逻辑（不变）：
- 无 plan.md → 静默退出
- plan.md 无 BATON:GO → 静默退出
- plan.md + BATON:GO + 有未完成 todo → 提醒进度

新增逻辑：
- plan.md + BATON:GO + 全部 todo 完成 → 提醒归档
```

归档提醒输出：
```
✅ 所有 todo items 已完成。
📋 建议归档：mkdir -p plans && mv plan.md plans/plan-$(date +%Y-%m-%d)-topic.md
```

---

## 七、bash-guard.sh 设计

**不变。** 保持当前逻辑：在 plan 未审批时对 bash 文件写操作发出 advisory 警告。

---

## 八、setup.sh 设计

### 变更

1. **版本号更新**：v2.0 → v3.0
2. **安装的文件更新**：workflow.md 内容更新，workflow-full.md 已移除
3. **v2 → v3 迁移**：
   - 检测 v2 安装 → 原地升级（替换 workflow.md / phase-guide.sh / stop-guard.sh，删除 workflow-full.md）
   - write-lock.sh 仅更新阻止消息
   - 其他文件不变
4. **CLAUDE.md 中的引用不变**：`@.baton/workflow.md`

---

## 九、README.md 设计

### 关键更新

**标题**：
```
Baton — AI 辅助开发的共同理解构建协议
```

**核心流程图更新**：
```
research.md  →  plan.md  →  [标注循环]  →  <!-- BATON:GO -->  →  implement
   (理解)       (方案)     (构建共同理解)     (审批)            (执行)
```

**新增段落：标注循环**

说明标注循环是 Baton 的核心，适用于 research.md 和 plan.md。
强调自由文本 + `[PAUSE]`、AI 推断意图、以及"人不一定对，AI 用证据回应"。

**新增段落：两种场景**

简要说明场景 A（目标明确）和场景 B（需要探索）的区别。

**保留不变**：写锁说明、IDE 支持表、安装/卸载、.gitignore 建议、哲学段落。

---

## 十、测试计划

### test-write-lock.sh 更新

| # | 测试 | 变更 |
|---|------|------|
| 1-18 | 现有 18 个测试 | 大部分不变 |
| 新增 | 阻止消息包含新措辞 | 验证 "标注循环" / "研究" 关键词 |

### test-phase-guide.sh 更新

| # | 测试 | 预期 |
|---|------|------|
| 1 | 无文件 → RESEARCH 引导 | 包含"研究阶段"、"调用链"、"file:line" |
| 2 | 有 research.md，无 plan.md → PLAN 引导 | 包含"计划阶段"、"引用 research" |
| 3 | 有 plan.md，无 GO → ANNOTATION 引导 | 包含"标注循环"、"`[PAUSE]`"、"Free-text is the default"、"人不一定正确" |
| 4 | 有 plan.md + GO → IMPLEMENT 引导 | 包含"实现阶段"、"typecheck" |
| 5 | 有 plan.md + GO + 全部 [x] → 归档提醒 | 包含"归档"、"plans/" |
| 6 | 无 research.md + 有 plan.md → ANNOTATION 引导 | 简单改动场景 |
| 7 | BATON_PLAN 自定义文件名 | 不变 |
| 8 | walk-up 目录查找 | 不变 |
| 12-17 | skill 检测分支覆盖 | 验证 has_skill() walk-up、per-skill 检测、fallback 抑制 |

### test-stop-guard.sh 更新

| # | 测试 | 变更 |
|---|------|------|
| 1-9 | 现有 9 个测试 | 不变 |
| 新增 | plan + GO + 全部完成 → 归档提醒 | 验证输出包含"归档"关键词 |

### test-workflow-consistency.sh 更新

验证 workflow.md 与 SKILL.md 之间无矛盾（跨切面规则不与阶段方法论冲突）。

### 新增：test-annotation-protocol.sh

这不是 hook 测试，而是文档一致性测试：
- workflow.md / SKILL.md / README / setup.sh 对自由文本 + `[PAUSE]` 模型表述一致
- SKILL.md 中有推断意图、`[PAUSE]` 处理和 Annotation Log 示例

---

## 十一、与外部系统的兼容性设计

### 与 Superpowers 的关系

```
Superpowers 触发时机        Baton 的态度
─────────────────────────  ────────────
brainstorming              可在研究阶段使用，产出喂入 research.md
writing-plans              可在 plan 审批后用于生成更细粒度的 todolist
TDD                        可在实现阶段使用（写锁已解除）
systematic-debugging        可在研究阶段使用（bug 排查场景）
verification               可在实现完成后使用
executing-plans            可在实现阶段使用
code-reviewer              可在实现完成后使用
```

**不冲突的原因**：Baton 管文档级的人机交互协议，Superpowers 管执行方法论。层次不同。

**using-superpowers 的"1% 必须调用"规则**：这和 Baton 不矛盾。
Superpowers 的 skill 在 Baton 的各阶段内部被调用，不跨越 Baton 的阶段边界。
例如：在研究阶段调用 systematic-debugging skill → 产出写入 research.md → 正常进入 plan 阶段。

### 与 Planning-with-Files 的关系

**建议：明确分工。**

```
Baton 管什么              Planning-with-Files 管什么
────────────────          ──────────────────────────
人机交互（标注循环）         AI 自身的 context 管理
research.md / plan.md      task_plan.md / findings.md / progress.md（如需要）
```

实际使用中：
- 如果 Planning-with-Files 的 findings.md 和 Baton 的 research.md 重复 → 建议只用 research.md
- task_plan.md / progress.md 可以继续用于 AI 自身的阶段跟踪，但对人不可见的工作

---

## 十二、迁移路径

### 从当前 Baton v2 迁移

对使用当前 baton 的项目：

1. 运行 `setup.sh` → 检测 v2，升级到 v3
2. 替换文件：workflow.md、phase-guide.sh、stop-guard.sh；删除 workflow-full.md
3. write-lock.sh 仅更新阻止消息
4. 其他文件不变
5. 已有的 plan.md 继续兼容（`<!-- BATON:GO -->` 标记不变）

**向后兼容**：v3 的写锁逻辑与 v2 完全相同。唯一区别是引导文案和标注协议。

### 从 Baton_bak v2-alpha 迁移

baton_bak 的用户：
- 显式 marker 流程改为自由文本 + `[PAUSE]`；AI 不再依赖固定标签，而是从内容中推断意图
- research / plan 使用统一协议，不再区分专用 marker 集合
- 不再需要 CLI（bin/baton）
- 不再需要 context-slice（可选使用 superpowers subagent 替代）
- 不再需要 project-config.json、hard-constraints.md、review-checklists.md

---

## 十三、实现优先级

### P0：必须实现（核心价值）

| 组件 | 改动量 | 说明 |
|------|-------|------|
| workflow.md | 重写 | 跨切面核心规则 |
| SKILL.md (x3) | 重写 | 各阶段方法论（per-phase 权威） |
| phase-guide.sh | 改造 | skills-first + 硬编码 fallback + 归档提醒 |
| README.md | 重写 | 体现新定位和标注循环 |

### P1：应该实现（完善体验）

| 组件 | 改动量 | 说明 |
|------|-------|------|
| stop-guard.sh | 小改 | 增加归档提醒 |
| write-lock.sh | 小改 | 更新阻止消息措辞 |
| setup.sh | 中改 | v3 版本号 + 迁移逻辑 |
| 测试 | 中改 | 更新 phase-guide 测试 + 新增 annotation 一致性测试 |

### P2：可选增强

| 组件 | 说明 |
|------|------|
| 中文 README | README.zh-CN.md |
| Cursor 适配 | .cursor/rules/baton.md 更新 |
| CI 更新 | .github/workflows/ci.yml |

---

## 十四、设计约束检查

| 约束 | 满足？ | 说明 |
|------|-------|------|
| 写锁物理强制 | ✅ | 与 v2 相同的 hook 机制 |
| 跨切面核心精简 | ✅ | workflow.md 只含跨切面规则，阶段方法论由 SKILL.md 提供 |
| 零依赖 | ✅ | 纯 shell + markdown |
| 标注循环结构化 | ✅ | free-text + `[PAUSE]` + Annotation Log |
| research + plan 都可标注 | ✅ | 同一协议，不同载体 |
| 人可以错，AI 要回推 | ✅ | 明确的回应规则 + 正确/错误行为示例 |
| 与 superpowers 不冲突 | ✅ | 层次分离：文档协议 vs 执行方法论 |
| 简单改动可跳过 research | ✅ | 写锁不检查 research.md |
| 归档机制 | ✅ | phase-guide 检测 + stop-guard 提醒 |
| Todolist 从 plan 分离 | ✅ | 人说"生成 todolist"后追加 |
