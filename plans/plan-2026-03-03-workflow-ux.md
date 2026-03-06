# Workflow UX 改进：标注引导 + Todolist 阶段强化

> 背景：Phase 1 实施过程中发现的 UX 问题
> 状态：方案已标注，修订中

## 问题

### 问题 1：标注没有落点

plan.md 写完后是连续文字，人类不知道：
- 在哪里加 `[Q]` `[CHANGE]` 等标记
- 格式是 inline 还是集中标注
- 标注后 AI 怎么回应、记录在哪

### 问题 2：todolist 阶段被跳过

workflow 规定 `plan.md → 标注循环 → generate todolist → BATON:GO → 实施`，但实际中：
- 人类看完 plan 觉得没问题就直接加了 BATON:GO
- 没有显式的 "generate todolist" 步骤
- AI 也没有拦截（write-lock 只检查 BATON:GO，不检查 todolist 是否存在）

---

## 根因分析

### 根因 1：phase-guide.sh ANNOTATION 阶段发出了矛盾信号

`phase-guide.sh:98`：
```
Human will say "generate todolist" or add <!-- BATON:GO --> when satisfied.
```

这里用了 **"or"**（或者），暗示两者是**可替代**的。但 workflow.md:17 规定的流程是**顺序**的：
```
annotation cycle → generate todo → BATON:GO → implement
```

人类看到 "or" 自然选了最短路径：直接加 BATON:GO，跳过 todolist。

### 根因 2：write-lock.sh 只检查 BATON:GO，不检查 ## Todo

`write-lock.sh:85-87`：
```sh
if grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    exit 0
fi
```

只要有 BATON:GO 就放行。没有 todolist 也不会拦截或警告。

### 根因 3：plan.md 模板没有标注引导

AI 生成的 plan.md 是纯技术内容，没有任何给人类的交互引导。人类打开 plan.md 后：
- 不知道可以标注
- 不知道标注格式
- 不知道标注位置

workflow-full.md 里有详细的标注格式说明（lines 149-158），但这是 AI 读的文档，不是人类在 plan.md 里看到的内容。

---

## 方案

### 方案 1：AI 在 plan.md 末尾生成标注引导区

AI 每次生成 plan.md 时，在末尾追加一个人类可见的引导区：

```markdown
---

## 审阅指南

在任何段落旁直接添加标注，AI 会逐条回应并记录在 Annotation Log 中：

- `[Q]` 提问 — "为什么选择这个方案？"
- `[CHANGE]` 修改请求 — "改用 Redis 而不是内存缓存"
- `[NOTE]` 补充上下文 — "历史上我们试过 X，因为 Y 放弃了"
- `[DEEPER]` 分析不够深 — "这部分的性能影响需要更详细的分析"
- `[MISSING]` 遗漏 — "没有考虑到并发场景"

审阅完成后告诉 AI "generate todolist"，AI 会追加 ## Todo。
确认 todolist 无误后，添加 `<!-- BATON:GO -->` 解锁代码写入。
```

**实现方式：** 修改 workflow.md 和 workflow-full.md，在 PLAN phase 规定 AI 必须在 plan.md 末尾附加此引导区。phase-guide.sh 的 PLAN phase 提示中也加入这一要求。

**优点：** 零代码变更（只改 markdown），人类在 plan.md 里直接看到引导
**成本：** 每个 plan.md 多 ~10 行

### 方案 2：修复 phase-guide.sh 的表述 + workflow 流程

~~将 "or" 改为顺序关系~~（已根据 [NOTE] 1 修订）

`phase-guide.sh:98` 改为更清晰的表述，保留人的选择权：
```
When satisfied, human adds <!-- BATON:GO --> to approve the plan.
Human may also say "generate todolist" to get a structured checklist before or after approval.
```

同步更新 workflow.md 中的 Flow 描述，从：
```
annotation cycle → generate todo → BATON:GO → implement
```
改为：
```
annotation cycle → BATON:GO → [optional: generate todolist] → implement
```

**核心变化：** BATON:GO 是审批门，todolist 是可选辅助。人决定是否需要 todolist。

### 方案 3：AI 新建 plan 前必须归档旧 plan

当前问题：AI 写新 plan 时直接覆盖了旧 plan 内容，无归档。

在 workflow.md 和 workflow-full.md 中新增规则：
```
当 plan.md 已存在且包含实质内容时，AI 在写入新 plan 前必须先归档：
mkdir -p plans && cp plan.md plans/plan-$(date +%Y-%m-%d)-<topic>.md
```

在 phase-guide.sh 的 PLAN/RESEARCH phase 中，如果检测到 plan.md 已存在，输出提醒：
```
⚠️ Existing plan.md detected. Archive it before writing a new plan:
   mkdir -p plans && mv plan.md plans/plan-YYYY-MM-DD-topic.md
```

---

## 修订后的推荐

**三个方案全部采纳**，互补：

| 方案 | 作用 | 变更文件 |
|------|------|----------|
| 方案 1 | 让人类知道可以标注、如何标注 | workflow.md, workflow-full.md, phase-guide.sh |
| 方案 2 | 表述清晰化 + 流程更新（BATON:GO 为审批门，todolist 可选） | workflow.md, workflow-full.md, phase-guide.sh |
| 方案 3 | 防止旧 plan 被覆盖 | workflow.md, workflow-full.md, phase-guide.sh |

**变更范围：**

| 文件 | 操作 |
|------|------|
| `.baton/workflow.md` | 更新：Flow 中 todolist 改为可选；新增 plan 归档规则 |
| `.baton/workflow-full.md` | 更新：[PLAN] 章节加审阅引导区模板；Flow 同步；归档规则 |
| `.baton/phase-guide.sh` | 更新：ANNOTATION 阶段表述修正；PLAN/RESEARCH 阶段旧 plan 检测 |
| `tests/test-phase-guide.sh` | 更新：增加 "existing plan.md detected" 提醒测试 |

---

## Annotation Log

### Round 1 (2026-03-03)

**[Q] § plan 覆盖问题**
"刚才生成这个 plan 时把之前的 plan 内容给覆盖了，没有对之前的 plan 做归档"
→ 确认是 AI 执行错误。Phase 1 plan.md 未被 git commit，无法恢复。
  但其核心内容在 `docs/plans/2026-03-03-baton-v4-design.md` 的 ## Todo 中保留。
  根因：workflow 虽有归档提醒（ARCHIVE state），但 AI 没有在写新 plan 前检查旧 plan 是否需要归档。
→ 新增方案 3：AI 写新 plan 前必须归档旧 plan。
→ 结果：采纳，加入方案

**[NOTE] § todolist 流程调整**
"人在 plan 中审阅通过后加 BATON:GO，由人去决定是否生成 todoList"
→ 原方案 2 要求 "先 todolist 后 BATON:GO"（顺序强制），与此 NOTE 矛盾。
  NOTE 的设计意图：BATON:GO 是唯一审批门，todolist 是可选辅助工具。
  这更灵活——简单变更不需要 todolist，复杂变更人会主动要求。
→ 已修订方案 2：Flow 从 `todo → BATON:GO` 改为 `BATON:GO → [optional: todolist]`。
  原方案 3（软警告缺失 todolist）取消，因为没有 todolist 是合法的。
→ 结果：采纳，方案 2 已修订，方案 3 替换为归档保护

### Round 2 (2026-03-03)

**[Q] § 审阅指南自动生成**
"生成 plan 时，能否在 plan.md 末尾自动添加审阅指南 section？"
→ 是的，这正是方案 1 的内容。实现方式：
  1. workflow.md / workflow-full.md 的 PLAN 规则中新增 "plan 末尾须附加 ## 审阅指南"
  2. phase-guide.sh 的 PLAN phase 提示中加入此要求
  AI 每次生成 plan 都会自动附上标注格式说明 + todolist/BATON:GO 触发方式。
→ 结果：已在方案 1 中覆盖，无需额外变更

---

## 审阅指南

在任何段落旁直接添加标注，AI 会逐条回应并记录在 Annotation Log 中：

- `[Q]` 提问 — "为什么选择这个方案？"
- `[CHANGE]` 修改请求 — "改用 Redis 而不是内存缓存"
- `[NOTE]` 补充上下文 — "历史上我们试过 X，因为 Y 放弃了"
- `[DEEPER]` 分析不够深 — "这部分需要更详细的分析"
- `[MISSING]` 遗漏 — "没有考虑到 XX 场景"

审阅完成后添加 `<!-- BATON:GO -->` 解锁代码写入。
如果需要结构化的实施检查清单，告诉 AI "generate todolist"。

<!-- BATON:GO -->
