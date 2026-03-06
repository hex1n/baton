# Baton 架构方案深度对比分析

> 日期: 2026-03-02
> 背景: 分析所有已讨论的方案，寻找最优设计

---

## 一、方案全景

| # | 方案 | 核心思路 | 来源 |
|---|------|---------|------|
| A | 当前 Baton | 写锁 + 极简引导 (~350 tokens) | 开源版本 |
| B | Baton_bak v2 | 8 个 skill + CLI + 三层治理 | 你的早期设计 |
| C | Superpowers | 方法论 skill 集（brainstorming/TDD/debugging/verification） | 第三方插件 |
| D | Planning-with-Files | Manus 式文件外脑（task_plan/findings/progress） | 第三方插件 |
| E | 协议层 + 质量门控 | Baton 定义标准，不管方法，hook 强制检查 | 本次讨论方案 1 |
| F | 条目级门控 | BATON:GO 从计划级下沉到条目级，逐条审批 | 本次讨论方案 2 |

---

## 二、评估维度定义

| 维度 | 含义 |
|------|------|
| **物理强制力** | 能否技术上阻止 AI 违规（不是靠 prompt "说"） |
| **研究深度保障** | 能否确保 AI 追完调用链、验证风险、不停在表层 |
| **计划可审性** | 人能否高效审查计划（注意力负担、结构清晰度） |
| **标注循环** | 是否有结构化的人机标注协议（不是"你 review 一下"） |
| **AI 漂移防护** | 长计划/长会话中 AI 是否会偏离目标 |
| **人的认知负担** | 人需要付出多少注意力才能有效参与 |
| **与其他系统兼容性** | 是否与 superpowers/planning-with-files 等打架 |
| **实现复杂度** | hook/skill/CLI 的开发量 |
| **token 开销** | 注入 context 的 token 量 |
| **演化弹性** | 能否随项目复杂度增长而平滑扩展 |

---

## 三、逐方案深度分析

### 方案 A：当前 Baton（极简写锁）

**核心机制**：
- `write-lock.sh` 在 PreToolUse 拦截 Edit/Write/CreateFile
- `plan.md` 中有 `<!-- BATON:GO -->` 则放行，否则阻止
- `phase-guide.sh` 在 SessionStart 输出阶段引导（~100 tokens）
- `workflow.md` 提供基础规则（~250 tokens）

**优势**：
- 物理强制力是真实的 — AI 写不了源码
- 极简 — 零依赖，350 tokens，几个 shell 脚本
- 概念清晰 — 文件存在即状态

**致命缺陷**：
1. **研究引导 = 一句话**：`"Deeply read relevant code"` 没有任何深度标准
2. **计划模板 = 5 个关键词**：`Goal | Scope | Approach | Risks | Verification`，太粗无法标注
3. **标注循环 = 纯概念**：没有标注格式、没有处理流程、没有记录机制
4. **Context Slice = 不存在**：长计划 AI 必然漂移
5. **与 superpowers 硬冲突**：两个系统争抢生命周期控制权

**结论**：保留了门锁但拆掉了门框。写锁有价值，其余引导不足以产生高质量输出。

---

### 方案 B：Baton_bak v2（完整工作流系统）

**核心机制**：
- 8 个独立 skill（research/plan/annotation-cycle/context-slice/implement/verification/code-reviewer/using-baton）
- CLI 工具（bin/baton）管理任务生命周期
- 三层架构：Layer 0（独立使用）/ Layer 1（任务流+锁）/ Layer 2（治理）
- phase-lock.sh 强制阶段门控
- Hard Constraints 带版本号和过期检测

**优势**：
1. **研究有深度要求**：风险必须 ✅/❌/❓，禁止用通用知识代替验证，要求追完整执行路径
2. **标注循环结构化**：[NOTE]/[Q]/[CHANGE]/[RESEARCH-GAP] 四种标注 + 轮次记录 + 冲突检测
3. **Context Slice 防漂移**：每个 todo item 生成独立切片，subagent 只读切片
4. **[RESEARCH-GAP] 回环**：标注中发现研究不足可以回到研究阶段补充
5. **阶段检测精确**：detect_phase() 通过文件内容判断 7 种状态

**致命缺陷**：
1. **与 superpowers 高度重叠**：implement skill ≈ executing-plans，verification-gate ≈ verification-before-completion，code-reviewer ≈ requesting-code-review
2. **体量膨胀**：8 个 skill（每个 200-400 行）+ CLI（700+ 行）+ 配置文件 + 模板
3. **token 开销大**：每个 skill 加载到 context 占用大量 tokens
4. **全家桶耦合**：虽然声称 Layer 0 可独立使用，但 skill 之间有隐式依赖（annotation-cycle 依赖 plan-first-plan 的输出格式）
5. **审批仍是一次性的**：plan APPROVED 后所有 item 一起解锁，人在长计划中仍然注意力衰减
6. **CLI 增加了使用门槛**：需要 `baton new-task`、`baton next` 等命令

**结论**：解决了方案 A 的所有引导不足问题，但代价是成为了另一个 superpowers，且一次性审批没有解决人的注意力问题。

---

### 方案 C：Superpowers（方法论 Skill 集）

**核心机制**：
- 独立 skill 提供方法论：brainstorming 探索设计、writing-plans 写计划、TDD 红绿重构、systematic-debugging 四阶段调试、verification 五步门控
- `using-superpowers` meta-skill 强制路由（"1% 可能就必须调用"）
- subagent-driven-development 用新 subagent 执行每个任务 + spec/quality 双重审查

**优势**：
1. **方法论成熟**：TDD 的红绿重构、debugging 的根因追踪、verification 的证据门控都是经过验证的工程实践
2. **粒度好**：writing-plans 要求 2-5 分钟一个任务
3. **执行纪律强**：subagent-driven 有 spec-reviewer + quality-reviewer 双重检查
4. **可组合**：每个 skill 独立，按需加载

**致命缺陷**：
1. **零物理强制**：所有纪律靠 prompt 里的 "MUST"/"NEVER"/"Iron Law"，AI 可以无视
2. **没有标注循环**：brainstorming 是对话式探索，不是结构化标注
3. **没有写锁**：AI 随时可以写源码，跳过计划
4. **brainstorming ≠ 代码研究**：brainstorming 探索设计意图，不追调用链、不读实现、不验证风险
5. **using-superpowers 太霸道**：拦截一切操作路由到 skill，与任何其他工作流系统冲突

**结论**：方法论是好的，但缺乏强制力。适合作为"内部方法"被更高层系统调用，不适合作为"外层控制"。

---

### 方案 D：Planning-with-Files（Manus 式文件外脑）

**核心机制**：
- 三个持久化文件：task_plan.md（阶段跟踪）、findings.md（发现记录）、progress.md（会话日志）
- 2-Action Rule：每 2 次操作后立即保存发现
- Context Window = RAM，Filesystem = Disk
- 3-Strike Error Protocol：3 次失败后升级到用户

**优势**：
1. **对抗 context 丢失**：关键信息持久化到文件，不依赖 context window
2. **2-Action Rule 实用**：强制频繁记录，防止信息丢失
3. **错误追踪好**：所有错误记录在表格中，防止重复尝试

**致命缺陷**：
1. **零物理强制**：所有规则靠 prompt
2. **没有标注循环**：纯粹是 AI 的自我管理工具，人不参与
3. **没有研究深度要求**：只说"记录发现"，不说"研究多深"
4. **与 baton 文件冲突**：task_plan.md vs plan.md、findings.md vs research.md，同一任务出现 6 个计划文件
5. **定位不同**：这是 AI 的"工作记忆管理"，不是"人机协作协议"

**结论**：解决的问题不同（AI 自身的 context 管理 vs 人机协作质量控制）。它的 2-Action Rule 和错误追踪可以被其他系统吸收，但本身不能替代工作流管控。

---

### 方案 E：协议层 + 质量门控

**核心机制**：
- Baton 只定义阶段间的交接标准（不管内部方法）
- 研究模板 + 质量门控：risk 必须 ✅/❌、evidence 必须 file:line、coverage 必须达标
- 计划模板 + 质量门控：必须引用研究、必须有可标注条目、必须有风险段
- 标注协议：[NOTE]/[Q]/[CHANGE]/[RESEARCH-GAP]
- Context Slice：审批后逐条目生成切片
- 写锁增强：门控消息包含具体缺失项（不只是"blocked"）

**优势**：
1. **物理强制 + 智能反馈**：不只阻止，还告诉 AI 具体差什么
2. **与 superpowers 兼容**：Baton 管门控和标准，superpowers 管方法
3. **标注循环结构化**：继承 baton_bak 的标注协议
4. **轻量**：不需要 8 个 skill 和 CLI

**缺陷**：
1. **审批仍是一次性的**：`<!-- BATON:GO -->` 通过后整个计划解锁
2. **人的注意力问题未解决**：复杂计划仍然是一大坨要审
3. **质量门控可被 AI 博弈**：AI 可能写出形式上达标但实质浅薄的 research（比如给每个 risk 标 ✅ 但验证不充分）
4. **superpowers 研究深度不保证**：即使有质量门控，如果 superpowers brainstorming 不追调用链，门控只能挡住但不能教会它怎么做深

**结论**：比方案 A 好很多（有标准、有标注、有切片），但一次性审批的根本问题没解决。

---

### 方案 F：条目级门控（Item-Level Gating）

**核心机制**：
- `[GO]` 标记从计划级下沉到条目级
- Decisions 段一次性审批（战略层），Todo 条目逐个审批（战术层）
- 写锁按条目的 Files 列表限定范围
- 实现过程中 AI 可更新后续条目，人审更新后再放行

**优势**：
1. **物理强制 + 文件级范围控制**：不只锁 "有没有计划"，还锁 "能写哪些文件"
2. **人的注意力最优**：每次只审一个条目，不会走神
3. **发现友好**：实现中发现新依赖 → 更新后续 items → 人审更新 → 自然的增量规划
4. **每个条目自身就是 Context Slice**：不需要单独的 slice 机制
5. **与 superpowers 天然兼容**：每个 [GO] 条目内部用什么方法（TDD/debugging/whatever）随意

**缺陷**：
1. **审批次数多**：每个 item 都要人操作一次 [GO]，复杂任务可能有 10-20 个 items
2. **大局观可能丢失**：人一次只看一个 item，可能忽略 items 之间的整体一致性
3. **研究深度仍无保障**：条目级门控解决的是"审批粒度"问题，不解决"研究够不够深"
4. **写锁实现复杂度上升**：hook 需要解析 plan.md 中每个条目的 Files 列表
5. **item 间依赖管理**：如果 item 3 依赖 item 2 的输出，人需要理解依赖链

**结论**：在审批粒度和人的注意力管理上是根本性改进，但研究深度和大局观需要补充机制。

---

## 四、维度对比矩阵

| 维度 | A 当前Baton | B v2全家桶 | C Superpowers | D Files外脑 | E 协议层 | F 条目级 |
|------|:---------:|:---------:|:------------:|:----------:|:-------:|:-------:|
| 物理强制力 | ★★★★★ | ★★★★★ | ☆☆☆☆☆ | ☆☆☆☆☆ | ★★★★★ | ★★★★★ |
| 研究深度保障 | ★☆☆☆☆ | ★★★★☆ | ★★☆☆☆ | ★☆☆☆☆ | ★★★☆☆ | ★★☆☆☆ |
| 计划可审性 | ★★☆☆☆ | ★★★☆☆ | ★★★★☆ | ★★☆☆☆ | ★★★☆☆ | ★★★★★ |
| 标注循环 | ★☆☆☆☆ | ★★★★★ | ☆☆☆☆☆ | ☆☆☆☆☆ | ★★★★☆ | ★★★☆☆ |
| AI漂移防护 | ☆☆☆☆☆ | ★★★★★ | ★★★☆☆ | ★★☆☆☆ | ★★★★☆ | ★★★★★ |
| 人的认知负担 | ★★☆☆☆ | ★★☆☆☆ | ★★★☆☆ | ★★★★☆ | ★★☆☆☆ | ★★★★★ |
| 系统兼容性 | ★★☆☆☆ | ★☆☆☆☆ | ★★☆☆☆ | ★★★★☆ | ★★★★☆ | ★★★★★ |
| 实现复杂度 | ★★★★★ | ★☆☆☆☆ | — | — | ★★★☆☆ | ★★★☆☆ |
| token开销 | ★★★★★ | ★★☆☆☆ | ★★★☆☆ | ★★★☆☆ | ★★★★☆ | ★★★★☆ |
| 演化弹性 | ★★☆☆☆ | ★★★★☆ | ★★★★☆ | ★★☆☆☆ | ★★★★☆ | ★★★★★ |

> ★ 越多越好。Superpowers 和 Planning-with-Files 的实现复杂度不适用（它们是第三方系统，不需要我们实现）。

---

## 五、核心矛盾分析

上面 6 个方案，没有一个在所有维度上都满分。原因是存在三个根本性矛盾：

### 矛盾 1：审批粒度 vs 大局观

```
细粒度审批（方案 F）       粗粒度审批（方案 A/B/E）
  ↓                          ↓
人每次只看一个 item          人一次看整个 plan
  ↓                          ↓
注意力集中，不走神            能看到 items 之间的一致性
  ↓                          ↓
但可能见树不见林              但复杂计划会注意力衰减
```

### 矛盾 2：研究深度 vs 自主性

```
强制深度标准（方案 B/E）     宽松引导（方案 A/C）
  ↓                          ↓
AI 必须追完调用链             AI 自行判断何时"够深"
  ↓                          ↓
质量有保障                   效率高，简单任务不过度研究
  ↓                          ↓
但简单任务也要走全流程         但复杂任务 AI 会偷懒
```

### 矛盾 3：系统完整性 vs 兼容性

```
全家桶（方案 B）              纯门控（方案 A）
  ↓                          ↓
自成体系，不依赖外部           只管锁，方法靠别人
  ↓                          ↓
不与其他系统冲突（因为替代了它们）不与其他系统冲突（因为不管它们的事）
  ↓                          ↓
但如果外部系统更好呢？          但如果没有外部系统呢？
```

---

## 六、前述方案的根本缺陷

方案 A-F 有一个共同的思维定式：**把 baton 当作"阶段管道"来设计**。
无论是门控、质量检查还是条目级审批，都在追问"如何控制 AI 从阶段 X 到阶段 Y"。

但实际使用中的工作流不是管道，而是**对话**：

```
人提需求 → AI 产出文档 → 人看了提反馈 → AI 回应并修改 → 循环直到满意 → 下一步
```

这个"提反馈 → 回应 → 修改 → 循环"的过程才是 baton 的核心价值。
它发生在 research 上，也发生在 plan 上。
它不是某个阶段的特有功能 — **它是通用的人机协作协议**。

之前所有方案都把标注循环当作 plan 阶段的附属品。这是错的。

---

## 七、方案 G：以标注循环为核心的协作协议

### 核心重构：标注循环不是功能，是底层协议

```
旧思维：research → [gate] → plan → [annotation cycle] → [gate] → implement
新思维：任何文档 ←→ 标注循环（通用协议）←→ 人满意后进入下一步
```

Baton 的本质是两件事：
1. **写锁** — 物理阻止 AI 在计划审批前写源码
2. **标注循环** — 结构化的人机文档协作协议，适用于任何文档

### 使用场景

#### 场景 A：目标明确（重构/新增/修改功能）

```
① AI 深度 research → 产出 research.md
② 人阅读 research，提出需求："重构这个函数" / "新增XX功能"
③ AI 基于 research.md + 需求 → 产出 plan.md
④ 人标注 plan.md（循环直到满意）
⑤ 人说"生成 todolist" → AI 在 plan.md 末尾追加 ## Todo
⑥ 人说"开始实现" → 写锁解除 → AI 实现 → typecheck
```

这个场景中：
- research.md 不需要标注循环（人看完直接提需求）
- plan.md 经历完整标注循环
- todolist 是 plan 审批的产物，不是计划的一部分

#### 场景 B：模糊想法 / 深度调研 / 排查问题

```
① 人描述想法或问题
② AI 深度调研 → 产出 research.md
③ 人标注 research.md（循环：不够深就继续挖，方向不对就调整）
④ 研究清晰后 → 人说"出 plan" → AI 产出 plan.md
⑤ 人标注 plan.md（循环直到满意）
⑥ 生成 todolist → 实现 → typecheck
```

这个场景中：
- research.md **经历标注循环**（这是场景 B 的关键差异）
- plan.md 也经历标注循环
- 标注协议完全相同，只是载体不同

#### 场景对比

| | 场景 A（目标明确） | 场景 B（需要探索） |
|---|---|---|
| research.md | AI 自主完成，人阅读 | AI 产出后**人标注循环改进** |
| 需求来源 | 人直接提出 | 从研究中逐步明确 |
| plan.md | 标注循环 | 标注循环 |
| todolist | plan 审批后生成 | plan 审批后生成 |

### 标注协议（通用，适用于 research.md 和 plan.md）

#### 标注类型

| 标注 | 含义 | 示例 |
|------|------|------|
| `[NOTE]` | 补充信息或提醒 | `[NOTE] 这个函数还有一个隐藏的调用方在 cron job 里` |
| `[Q]` | 提问，需要 AI 回答 | `[Q] 为什么选择在 Service 层做而不是 Middleware？` |
| `[CHANGE]` | 要求修改 | `[CHANGE] 不要用继承，改用组合模式` |
| `[RESEARCH-GAP]` | 研究不足，需要补充调查 | `[RESEARCH-GAP] ServiceC 也用了这个接口，需要调查影响` |

#### AI 处理标注的规则

1. **逐条处理**：不能跳过任何标注
2. **用证据回应**：每个回应必须有 file:line 引用或具体理由
3. **人不一定对**：如果人的标注有误，AI 应该用证据说明为什么，而不是盲从
4. **记录到 Annotation Log**：每轮标注和回应都记录

#### 当人的标注不正确时

这是和 baton_bak 的关键区别。baton_bak 说 "Human annotations override technical preferences"。
但现实中人可能：
- 基于过时的理解提出修改
- 忽略了研究中发现的约束
- 提出的方案有技术隐患

AI 的正确做法：

```markdown
## Annotation Log
### Round 2 (2026-03-02)

- [CHANGE] D1 "改用 Redis 做缓存"
  → ⚠️ AI 回应：当前架构全部使用进程内缓存（evidence: grep 显示 0 个 Redis 依赖）。
    引入 Redis 需要：
    1. 新增基础设施依赖（docker-compose + 运维）
    2. 所有缓存调用从同步改为异步
    3. 序列化/反序列化开销
    建议替代方案：使用现有 CacheManager 加 TTL（src/cache.ts:30）
  → 等待人决定：[接受替代方案 / 坚持 Redis / 其他]
```

**原则：AI 给证据和替代方案，人做最终决定。**

#### Annotation Log 格式

```markdown
## Annotation Log

### Round 1 (2026-03-02)
| 标注 | 位置 | 内容 | AI 回应 | 结果 |
|------|------|------|--------|------|
| [NOTE] | D1 | 批量输入场景 | 已补充批量校验方案 | ✅ 已处理 |
| [Q] | D2 | 为什么不用 middleware | middleware 不了解业务语义（evidence: ...） | ✅ 人接受 |
| [CHANGE] | D1 | 改用 Redis | ⚠️ 见上方详细分析 | ⏳ 等待人决定 |
| [RESEARCH-GAP] | D3 | ServiceC 影响 | 已补充研究，ServiceC 不受影响 | ✅ 已处理 |

### Round 2 ...
```

### research.md 的标注循环（场景 B 特有）

research.md 的标注和 plan.md 的标注使用完全相同的协议，但有几个额外的标注类型更适合研究场景：

| 标注 | 含义 | 示例 |
|------|------|------|
| `[DEEPER]` | 某个点需要更深入研究 | `[DEEPER] 这条调用链只追到了 Service 层，继续往下追到 DAO` |
| `[WRONG]` | 研究结论有误 | `[WRONG] 这个函数不是做校验的，是做转换的，你理解错了` |
| `[MISSING]` | 遗漏了重要信息 | `[MISSING] 还有一个 EventListener 也会触发这个流程` |

加上通用的 `[NOTE]` / `[Q]` / `[CHANGE]` / `[RESEARCH-GAP]`，总共 7 种标注。

research 标注循环示例：

```
人: [DEEPER] Execution Paths 只追到了 ServiceB，但 ServiceB 内部还调用了 EventBus，需要继续追
AI: 已追踪 → ServiceB.process() → EventBus.emit("user.updated") → 3 个 listener:
    - AuditListener (src/listeners/audit.ts:15) ← 只记日志，无副作用
    - CacheListener (src/listeners/cache.ts:30) ← 清缓存，需要注意时序
    - NotifyListener (src/listeners/notify.ts:8) ← 发通知，可异步
    已更新 research.md Execution Paths 段

人: [NOTE] CacheListener 的时序问题之前出过 bug，要特别注意
AI: 已在 Risks 段添加：❓ CacheListener 时序 — 需要查历史 bug 记录验证

人: 看起来差不多了，出 plan 吧
AI: → 基于 research.md 产出 plan.md
```

### plan.md 结构

plan.md 不预设固定模板。AI 基于 research.md 和需求自由组织，但必须包含：

1. **与 research 的关联** — 引用研究发现，不是凭空设计
2. **设计决策 + 理由** — 不只说"做什么"，还说"为什么这么做"和"还考虑了什么替代方案"
3. **影响范围** — 改动涉及哪些文件，影响哪些调用方
4. **风险 + 应对** — 从 research 的 ❌ 和 ❓ 中提取

**plan.md 不包含 todolist**。Todolist 是在人对 plan 满意后单独生成的。这是关键设计决策 — 避免过早细化导致标注循环中大量无效改动。

### Todolist 生成与实现

当人对 plan.md 满意后：

```
人: "生成 todolist"
AI: 在 plan.md 末尾追加 ## Todo 段
    每个 item 包含：
    - 具体改动描述
    - 涉及文件
    - 验证方式

人: "开始实现" / <!-- BATON:GO -->
AI: 写锁解除 → 按 todolist 顺序实现 → 每个 item 完成后 typecheck/test → 标记 [x]
```

### 写锁逻辑

```
write-lock.sh 判断逻辑：

1. 目标是 .md 文件 → 始终放行（研究和计划永远不被锁）
2. 找 plan.md → 不存在 → 阻止 + "先完成研究，再写计划"
3. plan.md 存在，检查 <!-- BATON:GO -->
   → 不存在 → 阻止 + "计划未审批，完成标注循环后添加 <!-- BATON:GO -->"
   → 存在 → 放行
```

写锁保持简单 — 和当前 baton 相同。不做条目级文件范围锁（过度复杂，且人已经在标注循环中审过了）。

### 与现有系统的关系

```
Baton 的职责边界：
├── 写锁 — 物理强制，plan.md 有 BATON:GO 才能写源码
├── 标注协议 — [NOTE]/[Q]/[CHANGE]/[RESEARCH-GAP]/[DEEPER]/[WRONG]/[MISSING]
├── Annotation Log — 记录每轮标注和 AI 回应
├── research.md 深度引导 — 模板提示需要哪些段（Scope/Execution Paths/Risks/Evidence/Coverage）
└── 流程引导 — phase-guide.sh 在 SessionStart 提示当前该做什么

不属于 Baton 的（由用户/其他系统决定）：
├── 研究方法 — superpowers:brainstorming / systematic-debugging / 手动
├── 实现方法 — superpowers:TDD / executing-plans / subagent / 直接写
├── 代码审查 — superpowers:requesting-code-review / 自审
└── AI context 管理 — planning-with-files / 不用
```

**为什么不冲突**：Baton 管的是**文档级的人机交互协议**（标注什么、怎么回应、什么时候算完）。
Superpowers 管的是**执行方法论**（怎么调试、怎么写测试、怎么做代码审查）。两者不在同一层。

---

## 八、方案 G vs 前述方案对比

| 维度 | A 当前 | B v2全家桶 | E 协议层 | F 条目级 | **G 标注核心** |
|------|:-----:|:---------:|:-------:|:-------:|:-------------:|
| 物理强制力 | ★5 | ★5 | ★5 | ★5 | **★5** |
| 研究深度 | ★1 | ★4 | ★3 | ★2 | **★4**（模板+标注循环双重保障） |
| 计划可审性 | ★2 | ★3 | ★3 | ★5 | **★4**（标注循环天然可审） |
| 标注循环 | ★1 | ★4 | ★4 | ★3 | **★5**（核心机制，通用协议） |
| AI漂移防护 | ☆0 | ★5 | ★4 | ★5 | **★3**（依赖实现阶段方法） |
| 人的认知负担 | ★2 | ★2 | ★2 | ★5 | **★4**（标注是自然交互） |
| 系统兼容性 | ★2 | ★1 | ★4 | ★5 | **★5**（最小职责边界） |
| 实现复杂度 | ★5 | ★1 | ★3 | ★3 | **★4**（写锁不变，加引导） |
| 场景覆盖 | ★2 | ★3 | ★2 | ★2 | **★5**（A/B 两种入口） |

**方案 G 的主要取舍**：

- AI 漂移防护降到 ★3 — 因为不做 Context Slice，长 todolist 实现时 AI 可能漂移。
  这是刻意的：漂移防护可以由 superpowers 的 subagent 模式解决，baton 不需要重复做。
- 写锁保持简单 — 不做文件级范围锁。标注循环已经确保人理解了计划，不需要再用锁来限制范围。

---

## 九、实现路线图

### Phase 1：标注协议（核心）
- [ ] 定义标注类型和 AI 处理规则，写入 workflow.md
- [ ] 定义 Annotation Log 格式
- [ ] 定义"AI 可以回推不正确标注"的规则和格式

### Phase 2：research.md 深度引导
- [ ] research.md 模板（Scope/Execution Paths/Risks/Evidence/Coverage）
- [ ] phase-guide.sh 在研究阶段输出深度提示
- [ ] research 标注类型（[DEEPER]/[WRONG]/[MISSING]）

### Phase 3：plan.md + todolist 流程
- [ ] plan 标注循环引导
- [ ] todolist 生成时机（人说"生成 todolist"后追加，不预先包含）
- [ ] 实现阶段引导（typecheck/test after each item）

### Phase 4：写锁调整
- [ ] 写锁逻辑不变（保持当前 baton 的简洁）
- [ ] phase-guide.sh 根据文件状态输出场景化引导
- [ ] 阻止消息增强

---

## 十、开放问题

1. **Todolist 是否也需要标注循环**？当前设计是人说"生成 todolist"后直接实现。如果 todolist 粒度不对，是重新标注 plan 还是直接标注 todolist？
2. **实现中发现计划有问题怎么办**？是自动回退到标注循环（删除 BATON:GO），还是在 plan.md 追加 amendment？
3. **research.md 和 plan.md 是否必须分开**？场景 A 中 research 可能很短，是否允许直接写在 plan.md 的 Context 段中？
4. **标注循环何时算"结束"**？人说"满意了"/"出 todolist" 就算，还是需要显式标记（如 `<!-- REVIEW:DONE -->`）？
5. **Context Slice 是否作为可选增强**？对于 10+ 个 todo items 的复杂任务，是否提供 slice 生成引导（但不强制）？
