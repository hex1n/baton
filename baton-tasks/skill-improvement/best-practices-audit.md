# Baton Skills vs Thariq Article Best Practices Audit

> Source: Thariq (@trq212) "Lessons from Building Claude Code: How We Use Skills"
> Date: 2026-03-18

## 已符合的实践

| 实践 | baton 现状 | 评价 |
|------|-----------|------|
| Skills 是文件夹 | baton-research 有 5 个文件，baton-plan/implement 各 2 个 | ✅ |
| Description = 触发条件 | 所有 7 个 skill 都以 "Use when..." 开头 | ✅ |
| 文件夹结构 = 渐进式信息披露 | templates、review-prompts 按需加载 | ✅ |
| Skill-specific hooks | hooks 通过 manifest.conf 路由到具体阶段 | ✅ 比文章更成熟 |
| 分享和分发 | junction-based 架构，`baton update` = `git pull` | ✅ |

## 可改进的 6 个方向

### 1. 过度规范化，缺少灵活性

> Thariq: "Give Claude the information it needs, but give it the flexibility to adapt"

baton 的 skills 非常刚性：
- baton-research 要求固定 7 步流程，但很多 Medium 任务不需要全部 7 步
- baton-plan 要求 "2-3 fundamentally different approaches"，但有些任务确实只有一个合理方案
- baton-implement 的 continuous execution mandate 不允许任何中间确认

**改进方向**：把固定流程改为"推荐流程 + AI 可根据任务复杂度跳过"。

### 2. 没有可执行脚本

> Thariq: "Giving Claude scripts and libraries lets Claude spend its turns on composition"

baton 的 skills 目录里零脚本。所有 hook 脚本在 hooks/ 目录，是治理机制而非 skill 的工具。

文章的 Verification Skills 类型（Playwright、tmux 驱动的测试）在 baton 中完全缺失。例如：
- `verify-plan.sh` — 程序化检查 plan 的 write-set 完整性
- `verify-research.sh` — 检查证据标记覆盖率

这些脚本放在 skill 文件夹里，AI 可以按需调用，不是被动触发。

### 3. 没有 config.json 用户配置

> Thariq: "A good pattern is to store setup information in a config.json file"

baton 的治理强度对所有项目一刀切。没有机制让用户定制：
- 哪些步骤可以跳过
- failure threshold 偏好
- 默认 task sizing

### 4. 没有持久化记忆

> Thariq: "Skills can include a form of memory by storing data within them"

baton 的所有 session 数据在 `/tmp` 中，session 结束即丢失。文章建议用 `${CLAUDE_PLUGIN_DATA}` 做跨 session 持久化。

### 5. Gotchas 全是空的

> Thariq: "The highest-signal content... built up from common failure points"

4 个 skill 有空 Gotchas section，3 个没有（baton-debug、baton-subagent、using-baton）。这是有意设计（等真实踩坑再填），但文章的核心观点是这些应该是最先被填充的部分。

### 6. SKILL.md 偏长

> Thariq: "Claude will generally try to stick to your instructions... be careful of being too specific"

| Skill | 总行数 | 评价 |
|-------|--------|------|
| baton-research | 244 + 4 files = 686 | SKILL.md 偏长 |
| baton-review | 208 | 偏长 — 大量检查项可拆到 reference |
| baton-plan | 185 + review-prompt = 262 | 适中 |
| baton-implement | 143 + review-prompt = 222 | 适中 |
| using-baton | 143 | 偏长（作为 router）|
| baton-subagent | 130 | OK |
| baton-debug | 122 | OK |

**改进方向**：baton-research 和 baton-review 应把详细检查项移到 reference 文件，SKILL.md 只留核心逻辑。

## 优先级排序

| 方向 | 影响面 | 难度 | 优先级 |
|------|--------|------|--------|
| 降低刚性 | 高 — 直接影响 AI 产出效率 | 中 — 需逐条评估哪些规则可放松 | **最高** |
| 加可执行脚本 | 中 — 增加 skill 能力 | 中 — 需设计有价值的脚本 | **高** |
| 拆长 SKILL.md | 中 — 减少 token 消耗 | 低 — 纯文档重组 | **中** |
| config.json | 中 — 可定制性 | 中 — 需设计 schema + hook 读取 | **中** |
| 持久化记忆 | 低-中 — 跨 session 学习 | 中 — 需定义存储格式 | **低** |
| 填充 Gotchas | 高 — 最高信号内容 | 不可主动做 — 需从真实使用中积累 | **持续** |

## 方法论提醒

以上分析是理论对照，不是运行时证据。真正该做的是：
1. 用 baton 跑实际任务
2. 在 retrospective 中记录"什么浪费了时间 / 什么该拦住但没拦住"
3. 让真实 failure patterns 指导改进方向

> Thariq: "The best way to understand skills is to get started, experiment, and see what works for you."

## 批注区
