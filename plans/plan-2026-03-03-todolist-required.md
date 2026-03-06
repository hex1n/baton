# Todolist 必须步骤强化 + 审阅指南前置

> 状态：待审阅

## 审阅指南

在任何段落旁直接添加标注，AI 会逐条回应并记录在 Annotation Log 中：

- `[Q]` 提问 — "为什么选择这个方案？"
- `[CHANGE]` 修改请求 — "改用 Redis 而不是内存缓存"
- `[NOTE]` 补充上下文 — "历史上我们试过 X，因为 Y 放弃了"
- `[DEEPER]` 分析不够深 — "这部分需要更详细的分析"
- `[MISSING]` 遗漏 — "没有考虑到 XX 场景"

审阅完成后添加 `<!-- BATON:GO -->` 解锁代码写入。
如果需要结构化的实施检查清单，告诉 AI "generate todolist"。

---

## 问题

当前流程 `BATON:GO → [optional: generate todolist] → implement`，实际执行时 AI 在 BATON:GO 后直接开始实施，跳过了 todolist 步骤。

人的预期：todolist 是**必须步骤**，生成时机由人触发（"generate todolist"），但不能跳过。

## 方案

### 变更 1：流程描述更新

workflow.md / workflow-full.md 的 Flow 从：
```
BATON:GO → [optional: generate todolist] → implement
```
改为：
```
BATON:GO → generate todolist → implement
```

### 变更 2：Rules 更新

workflow.md / workflow-full.md 的 Rules 从：
```
Todolist is optional. Append ## Todo only after human says "generate todolist"
```
改为：
```
Todolist is required before implementation. Append ## Todo only after human says "generate todolist"
```

### 变更 3：phase-guide.sh IMPLEMENT 阶段增加 todolist 检查

当 plan.md 有 `<!-- BATON:GO -->` 但没有 `## Todo` 时，phase-guide.sh 输出提醒而非 IMPLEMENT 指引：

```
📍 BATON:GO is set but no ## Todo found.
Ask the human to say "generate todolist" before starting implementation.
```

这新增一个状态：IMPLEMENT 之前的 "等待 todolist" 子状态。

### 变更 4：phase-guide.sh ANNOTATION 阶段文本同步

ANNOTATION 阶段结尾更新为明确 todolist 是必须步骤：
```
When satisfied, human adds <!-- BATON:GO --> to approve the plan.
After approval, human says "generate todolist" to create implementation checklist.
Implementation begins only after todolist is generated.
```

### 变更 5：审阅指南位置从末尾改为开头（新增）

workflow.md / workflow-full.md / phase-guide.sh 中将：
```
plan.md must end with a ## 审阅指南 section
```
改为：
```
plan.md must begin with a ## 审阅指南 section (after title and status line)
```

workflow-full.md 的审阅指南模板位置同步调整。

## 影响范围

| 文件 | 操作 |
|------|------|
| `.baton/workflow.md` | Flow + Rules 更新 + 审阅指南位置规则 |
| `.baton/workflow-full.md` | Flow + Rules 更新 + 审阅指南模板位置 |
| `.baton/phase-guide.sh` | 新增 todolist 检查 + ANNOTATION 文本更新 + PLAN 审阅指南位置 |
| `tests/test-phase-guide.sh` | 新增 "BATON:GO without Todo" 测试 |

---

## Annotation Log

### Round 1 (2026-03-03)

**[CHANGE] § 审阅指南位置**
"审阅指南能放到 plan 的最开始位置吗？这样审阅者一打开文档就能看到，知道怎么标注了。放在最后可能不够显眼。"
→ 验证：审阅指南 ~10 行，不会过多占用版面。放在开头让审阅者第一眼看到标注格式，UX 更好。
  需同步修改 workflow.md:41、workflow-full.md:111、phase-guide.sh:125 中 "must end with" → "must begin with"。
→ 结果：采纳。新增变更 5，plan 已重构为审阅指南前置。


<!-- BATON:GO -->