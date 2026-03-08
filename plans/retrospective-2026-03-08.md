# 复盘：Baton 第一性原理分析任务

## 任务轨迹

| 阶段 | 做了什么 | 产出 |
|------|---------|------|
| RESEARCH | 从入口文件逐层追踪 baton 的 5 层架构、8 个 hooks、5 个 adapters、安装器 | research.md（9 章） |
| 批注 R1 | 人类问 baton 是不是 HITL → AI 补充分析 | 确认 baton 是 HITL 系统 |
| 批注 R2 | 人类问项目方向 → AI 补充战略分析 | 提出 harness engineering 方向 |
| 批注 R3 | 人类指出核心是循环批注 → AI 修正 | 锚定 annotation cycle 为核心 |
| PLAN v1 | 出 plan，推荐方案 B（技术债 + doc-quality.sh hook） | plan.md 初版 |
| 批注 P1 | 人类问"还有更好的方案吗" → AI 提出方案 D（skills-only） | 推荐改为 D，但正文未对齐 |
| 生成 Todo | 人类说"根据方案D生成todo" → AI 在冲突版本上生成了 todolist | 12 条 todo（建立在不一致的 plan 上） |
| 外部 Review | GPT-5.4 找出 3 个结构性问题 | research-plan-review.md |
| 人类重写 | 人类亲自重写 plan.md 为方案 C | 当前 plan.md（5 项变更，内部一致） |

## 做对了什么

### 1. 研究阶段质量高

- 从入口文件出发逐层追踪，没有跳过实现直接看接口
- 覆盖了全部 8 hooks、5 adapters、安装器、CLI、CI、git hooks
- 正确识别了 SYNCED 复制、OpenCode 分叉、CI 覆盖缺口三个具体问题
- 每个结论都有 file:line 证据

### 2. 批注循环中敢于修正方向

- R1 人类问 HITL，AI 没有敷衍，认真分析并确认
- R2 补充战略分析时提出了 harness engineering 这个有价值的框架
- R3 人类指出核心是循环批注，AI 接受并修正了自己的分析层次

### 3. 方案分析的思考深度

- 识别出 gate vs harness 的张力是真实的洞察
- 对方案 B/C/D 的优缺点分析本身并不差

## 做错了什么

### 1. Plan 阶段的合同意识崩溃（严重）

批注循环中从 B 切到 D，只做了增量 patch：
- 改了推荐 → ✅
- 改了 Self-Review → ✅
- 写了 Annotation Log → ✅
- **没有回头清理变更清单正文** → ❌

结果：同一个文档里，变更清单说"做 doc-quality.sh"，推荐说"不做 doc-quality.sh"，Todo 说"做 skills 强化"。三处互相矛盾。

### 2. 在冲突版本上生成了 Todo（严重）

人类说"根据方案D生成todo"，AI 应该先检查文档一致性再生成。但 AI 直接按 D 的理解写了 todo，而正文里方案 B 的变更 4 还在。这等于 todo 和 plan 正文脱节，违反了 baton 把 plan 当合同的核心前提。

### 3. 断了研究追溯链（中等）

research.md:456-459,517-520 明确把质量评估列为方向 D 的组成部分。AI 在 plan 里把 doc-quality.sh 整体定性为 gate 思维并删掉，没有补新的研究证据。正确做法是：要么保留质量评估（最终选了这条路），要么回 research 补出反证。

### 4. Self-Review 没有触发修复行动（中等）

AI 写了"skills-only 可能遗漏质量评估层"，但把它当"已知风险"而不是"必须解决的冲突"。Self-Review 应该是最后一道检查，不是用来展示"我知道有问题但我不修"。

## 根因分析

```
表象：文档内部矛盾
  ↑
直接原因：批注循环中做增量修改但不做全局一致性检查
  ↑
思维模式：把 plan 当"讨论在进展"而不是"合同在修订"
  ↑
根本原因：对新想法（harness purity）的兴奋覆盖了对流程纪律的坚持
```

对"gate vs harness"这个区分的智识兴奋导致：
- 急于推 skills-only 的"纯"方案
- 选择性忽略 research 中不支持删除质量评估的证据
- 用 Self-Review 承认问题但不修复，作为心理安全阀

## 流程改进

| 问题 | 对策 |
|------|------|
| 批注后文档不一致 | **方向性修改后必须通读全文**：每次改推荐方向，强制重新审阅变更清单、Self-Review、Todo 三处是否对齐 |
| 在冲突版本上生成 Todo | **生成 Todo 前先做一致性校验**：检查推荐方案 vs 变更清单 vs Self-Review 是否指向同一个方案 |
| 研究追溯链断裂 | **删除 research 已定义的内容时，必须补反证**：不能仅凭推理否定 research 的结论，要回到代码层面找证据 |
| Self-Review 不触发行动 | **Self-Review 中的"风险"如果描述的是内部矛盾而不是外部不确定性，必须升级为 blocker 并修复** |

## 对 Baton 流程本身的观察

这次任务恰好验证了 baton 的核心假设：**AI 会犯结构性错误，需要人类审阅来捕获。** GPT-5.4 的 review + 人类的重写，正是循环批注在起作用。

但也暴露了一个当前流程没有覆盖的缺口：baton 有 write-lock（防止没有 GO 就写代码）、有 phase-guide（引导阶段切换），但**没有 plan 内部一致性检查**。变更 4（doc-quality.sh）正好是朝这个方向走的第一步。
