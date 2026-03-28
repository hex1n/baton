# gstack 技能包分析：baton 可借鉴的模式

> 分析日期：2026-03-20
> 对比版本：gstack (garrytan/gstack, 安装于 ~/.claude/skills/gstack) vs baton (当前项目)

---

## 系统概况对比

| 维度 | gstack | baton |
|------|--------|-------|
| 定位 | 虚拟工程团队（15 角色 + 6 工具） | 治理框架（阶段化流程 + 不变量） |
| 技能数 | 21 个 | 8 个（using-baton + 7 阶段/扩展技能） |
| 覆盖范围 | Think → Plan → Build → Review → Test → Ship → Reflect | Research → Plan → Implement → Review → Complete |
| 核心理念 | Completeness Principle（AI 让完整性边际成本趋零） | Constitution（无证据不声明、无授权不执行） |
| 安全模型 | 可组合分层（careful + freeze + guard） | 一体化治理（constitution + write-lock + 阶段门控） |
| 构建系统 | bun + gen-skill-docs.ts 模板生成 | 手写 SKILL.md + bash hooks |
| 宿主支持 | Claude / Codex / Gemini | Claude Code 专用 |

---

## 值得借鉴的模式

### 1. 模板生成 SKILL.md（防漂移）

**gstack 做法**

- 技能源文件为 `SKILL.md.tmpl`，包含 `{{PLACEHOLDER}}` 占位符
- 构建时 `gen-skill-docs.ts`（1490+ 行）读取模板，调用动态解析器填充内容
- 关键解析器：
  - `generateCommandReference()` — 从 `commands.ts` 导入命令元数据，格式化为 markdown 表格
  - `generateSnapshotFlags()` — 从 `snapshot.ts` 导入 CLI 标志元数据
  - `generatePreamble()` — 组合 bash 前置块（更新检查、会话追踪、遥测、完整性介绍）
- 代码变更自动流入文档，单一真相源，零人工同步

**baton 现状**

- SKILL.md 手写维护
- 跨技能重复内容（Iron Laws、red flag 表、self-challenge 块）需人工保持一致
- 修改一个通用模式需要逐文件更新

**借鉴方案**

- 将 baton 技能中重复的结构块提取为共享片段（如 `fragments/iron-laws.md`、`fragments/self-challenge.md`）
- 编写简单的构建脚本，将片段注入各 SKILL.md.tmpl 生成最终 SKILL.md
- 优先提取的候选片段：
  - 失败边界规则（多个技能重复定义）
  - 证据标记规范（✅/❓）
  - 阶段跳转检测逻辑
  - self-challenge 问题列表

**预期收益**: 修改一处通用模式，所有技能同步更新；baton-evolve 修改模板后自动传播。

---

### 2. 安全机制的可组合分层

**gstack 做法**

三个独立安全模块，各自有独立 hook 脚本：

```
careful/bin/check-careful.sh  →  PreToolUse:Bash  →  warn（破坏性命令）
freeze/bin/check-freeze.sh   →  PreToolUse:Edit,Write  →  deny（范围外编辑）
guard/                       →  同时启用 careful + freeze
```

- `careful`: 检测 `rm -rf`、`DROP TABLE`、`git force-push`、`docker rm -f` 等，返回 `permissionDecision: "ask"` 让用户确认；安全例外清单（node_modules、.next、dist 等构建产物）
- `freeze`: 读取 `~/.gstack/freeze-dir.txt` 中的目录边界，超出范围返回 `permissionDecision: "deny"`
- `guard`: 组合两者，一条命令启用双重保护
- 用户按需选择：只要警告？只要范围锁？还是两者都要？

**baton 现状**

- `write-lock.sh` 是单一 hook，检查 BATON:GO 标记
- 安全逻辑（写锁、范围约束、阶段门控）耦合在 constitution + 各技能中
- 无法按任务风险级别灵活组合

**借鉴方案**

将 baton 的安全机制拆分为独立可组合模块：

| 模块 | 职责 | hook 类型 |
|------|------|-----------|
| `write-lock` | BATON:GO 门控（现有） | PreToolUse:Edit,Write |
| `scope-guard` | 写集范围检查（从 plan 的 write set 读取） | PreToolUse:Edit,Write |
| `destruct-warn` | 破坏性命令警告（参考 gstack careful） | PreToolUse:Bash |
| `phase-gate` | 阶段合规性检查（当前阶段是否允许该操作） | PreToolUse:* |

每个模块独立启用/禁用，通过 `manifest.conf` 组合。

**预期收益**: Trivial 任务可以只启用 write-lock；Large 任务启用全部四层。灵活性与安全性并存。

---

### 3. 技能使用遥测与分析

**gstack 做法**

- 每次技能调用写入 `~/.gstack/analytics/skill-usage.jsonl`：
  ```json
  {"event":"skill_invoked","skill":"qa","ts":"2026-03-20T10:00:00Z","branch":"feat/x","session":"abc123"}
  ```
- hook 触发也写入（careful 警告、freeze 拦截）
- `scripts/analytics.ts` 分析使用模式
- 会话追踪在 `~/.gstack/sessions/` 目录

**baton 现状**

- 无使用追踪
- baton-evolve 优化技能时缺乏数据支撑，依赖 review 评分（主观）
- 无法量化回答：哪个阶段最耗时？哪个技能最常被跳过？失败率最高的是什么？

**借鉴方案**

在 baton hooks 中增加轻量遥测：

```bash
# 在 run-hook.cmd 或各 hook 脚本末尾追加
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"$1\",\"phase\":\"$2\",\"result\":\"$3\"}" \
  >> ~/.baton/analytics/events.jsonl
```

记录维度：
- 阶段进入/退出时间 → 计算各阶段耗时
- hook 触发（pass/warn/deny） → 发现安全热点
- BLOCKED 事件 → 识别常见阻塞原因
- baton-review 评分 → 跟踪质量趋势

**预期收益**: 为 baton-evolve 提供量化指标，从"review 觉得好不好"升级为"数据显示哪里需要改"。

---

### 4. 标准化的用户交互格式

**gstack 做法**

所有需要用户决策的交互点遵循统一 4 步结构：

```
1. Re-ground: 陈述项目、当前分支、任务（1-2 句）
2. Simplify: 用白话解释（无术语，必要时用类比）
3. Recommend: 显示完整性评分 + 推荐选项及理由
4. Options: 带字母标号的选项，附工作量对比（人工时间 / AI+工具时间）
```

示例：
```
We're working on baton (branch: feat/hooks). You've finished the hook refactor.

Think of this like a code review checkpoint — we need to decide how thorough
to verify before merging.

I recommend Option B (Standard review) — the changes touch 3 files in hooks/,
moderate risk, standard coverage is appropriate.

A) Quick smoke test (5 min human / 2 min CC)
B) Standard review + test suite (15 min human / 5 min CC) ← recommended
C) Exhaustive audit + manual verification (1 hr human / 15 min CC)
```

**baton 现状**

- 各阶段技能的交互格式不统一
- sizing 确认、plan 审批、BLOCKED 报告各有各的表达方式
- 用户需要适应不同技能的提问风格

**借鉴方案**

为 baton 定义 3 类标准交互模板：

| 场景 | 模板结构 |
|------|----------|
| **决策请求**（sizing、approach 选择） | Context → Options（附风险/收益） → Recommendation → 等待选择 |
| **审批请求**（plan approval、BATON:GO） | Scope summary → Impact → Write set → Risk → 请求审批 |
| **阻塞报告**（BLOCKED） | 原始假设 → 新发现 → 冲突点 → 需要的决策 → 影响范围 |

**预期收益**: 用户形成肌肉记忆，减少认知负担；阶段切换时交互体验一致。

---

### 5. LLM Eval 测试基础设施

**gstack 做法**

- `test/skill-llm-eval.test.ts` — 端到端评估技能行为
- `test/fixtures/` — ground truth 基准数据（QA 场景的预期输出）
- `scripts/eval-*.ts` — eval 基础设施（列表、比较、监控、汇总、选择）
- 支持 `bun run test:evals` 批量运行
- 评估维度：技能是否按预期路由、输出是否包含关键元素、是否遵循流程

**baton 现状**

- 技能质量依赖 baton-review（上下文隔离的对抗性审查）
- 无自动化的行为回归测试
- baton-evolve 的"修改 → 评估 → 保留/丢弃"循环中，评估函数是 review 评分（非确定性）

**借鉴方案**

为 baton 技能建立 eval 基准：

```
baton-tasks/evals/
├── research-eval.json      # 输入场景 → 预期：evidence 标记、架构分析优先
├── plan-eval.json           # 输入场景 → 预期：write set、sizing、risk section
├── implement-eval.json      # 输入场景 → 预期：Todo 生成、write-lock 检查
├── review-eval.json         # 输入场景 → 预期：finding 分类、证据引用
└── eval-runner.sh           # 运行评估并输出通过率
```

每个 eval case 定义：
- **输入**: 模拟的用户请求 + 代码库状态
- **预期行为**: 必须包含的关键元素（如 research 必须有 ✅/❓ 标记）
- **禁止行为**: 不应出现的模式（如 research 跳过架构分析直接读代码）

**预期收益**: baton-evolve 修改技能后有机械验证兜底，不再仅依赖非确定性 review。

---

### 6. 多宿主适配

**gstack 做法**

- `gen-skill-docs.ts` 支持 `--host claude | codex | auto` 参数
- 同一模板根据宿主生成不同格式：
  - Claude: 原生 hook 注册 + 工具调用
  - Codex: 安全建议以散文形式（无 hook 能力）
  - Gemini: 通过 `.agents/skills/` 目录加载
- setup 脚本自动检测已安装的 agent，按需生成

**baton 现状**

- 仅支持 Claude Code
- 技能中硬编码了 Claude Code 特有的工具名（Edit、Write、Bash 等）
- hook 系统完全依赖 Claude Code 的 PreToolUse/PostToolUse 事件

**借鉴方案**

- 短期：不需要行动（除非有扩展计划）
- 中期：如果要支持 Codex/Gemini，参考 gstack 的模式：
  - 技能模板中用 `{{TOOL_EDIT}}` 替代硬编码的 `Edit`
  - 构建时根据宿主替换为对应工具名
  - hook 逻辑在非 Claude 宿主上降级为建议性散文

**预期收益**: 扩大 baton 的适用范围；但仅在有明确需求时投入。

---

### 7. 主动建议系统（可关闭）

**gstack 做法**

- 在主 SKILL.md 中定义阶段 → 技能的映射表
- 检测用户行为后主动建议对应技能
- 用户可随时关闭：`gstack-config set proactive false`
- 用户反感时的标准响应："Got it — I'll stop suggesting skills."

**baton 现状**

- `using-baton` 的 `phase-guide.sh` 检测阶段并路由到对应技能
- 但路由是自动的（直接调用技能），不是"建议"
- 用户无法调节主动程度

**借鉴方案**

在 using-baton 中增加建议模式配置：

```bash
# ~/.baton/config
proactive_suggestions=true  # true: 建议技能 | false: 仅被动响应 | auto: 自动路由（当前行为）
```

三种模式：
- `auto`（默认，当前行为）：检测阶段后自动调用技能
- `true`：检测阶段后先建议，等用户确认再调用
- `false`：完全被动，仅在用户显式请求时调用技能

**预期收益**: 适应不同用户偏好；资深用户用 auto，新用户用 true 了解流程。

---

## 优先级矩阵

| 优先级 | 模式 | 投入 | 收益 | 理由 |
|--------|------|------|------|------|
| **P0** | 遥测 + 分析 | 低（hook 中加几行 bash） | 高 | 直接赋能 baton-evolve 的量化优化循环 |
| **P0** | Eval 测试基础设施 | 中（需要设计 eval case） | 高 | 让技能修改有机械验证，降低 evolve 风险 |
| **P1** | 模板生成 SKILL.md | 中（需要重构现有技能） | 中 | 当前 8 个技能尚可手动维护，技能数增长后收益放大 |
| **P1** | 安全机制可组合化 | 中（拆分现有 hook） | 中 | 提升灵活性，适应 Trivial → Large 不同风险级别 |
| **P2** | 标准化交互格式 | 低（定义模板） | 低 | 改善用户体验，但非当前痛点 |
| **P2** | 主动建议系统 | 低（配置开关） | 低 | 适应不同用户偏好 |
| **P3** | 多宿主适配 | 高（架构级重构） | 取决于需求 | 除非有明确扩展计划，否则过早 |

---

## 不建议借鉴的部分

| gstack 模式 | 不适用原因 |
|-------------|-----------|
| Completeness Principle（总是推荐完整实现） | 与 baton 的"最小必要复杂度"理念冲突；baton 的 constitution 明确要求不过度工程 |
| Sprint 并行模型（10-15 个并行 sprint） | baton 的治理模型强调单线程审批流；并行执行由 baton-subagent 在单个 plan 内处理 |
| 浏览器工具（browse daemon） | 领域特定工具，与 baton 的治理框架定位不同 |
| 会话内角色扮演（15 个专家角色） | baton 用阶段技能而非角色来组织工作流，更清晰 |

---

## 批注区