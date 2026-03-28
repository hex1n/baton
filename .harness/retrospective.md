# Retrospective: runtime-thickness-improvements

## 1. 结果

- 关闭状态: complete（2026-03-28）
- 主要阻塞: 无。架构被否决两次（Rev1、Rev2），均通过 blocked 状态保存现场后重新架构，流程正常运转。
- 人工决策: (1) 要求真正的运行时隔离（否决 Rev1 残余风险）；(2) 要求跨平台对称（否决 Rev2 CC-only 方案）；(3) 接受 Rev3 并确认关闭。

## 2. 有效做法

- **验证前置**：verification-path.md 在实现前 dry-run 确认所有命令可执行，实现阶段零阻塞。
- **gap 分析先行**：baton-explorer 扫描出 10 个改进计划项，9 个已实现，只有 P0-3 确实缺失，避免了过度实现。
- **跨平台对比分析**：在 Rev3 架构阶段对比 CC / Codex / Cursor 现状，发现 Codex 已正确，只需 CC 与其对称。
- **不变式守护新机制**：新增 invariant 7 将 `.claude/agents/` 一致性纳入 check-consistency.sh，防止未来编辑 skills/ 后遗忘同步。

## 3. 失败点

- **Rev1 单层分析不足**：`context: fork` frontmatter 已设，但未追问"这在 CC 运行时是否真的强制"，导致架构被否决。应在架构阶段主动验证机制的实际约束边界。
- **Rev2 平台视野窄**：仅设计 CC 修复方案，未主动扫描其他平台，需要 human 明确提示才补全。应在架构阶段默认列出所有目标平台现状。

## 4. 仓库特定经验

- `.claude/agents/` 是 Claude Code 的运行时 agent 类型注册目录，link-skills.sh 现在将 `context: fork` 的 skill 文件自动同步到此目录。
- `.claude/skills/`（Skill 工具内联）和 `.claude/agents/`（Agent 工具隔离）是两个不同分发目标，语义不同，不可互换。

## 5. Harness 经验

- **协议声明 ≠ 运行时强制**：`context: fork` frontmatter 只声明意图，需要配合 CC Agent 工具 / Codex spawn_agent 才能真正隔离。文档层与机制层必须同时完整。
- **blocked 状态可正常复用**：被否决的架构通过 blocked 状态保存，重新设计后继续，无上下文丢失，流程符合预期。
- **P1-2 已通过等价机制实现**：`baton-evaluator.md` State Notes（`Current eval round: N`）已满足 eval_round 追踪需求，无需修改 module-status 模板。

## 6. 可标准化候选

- **架构检查清单扩展**：在架构阶段增加一项 "列出所有目标平台（CC / Codex / Cursor）现状，逐一确认机制对称性"，可防止 Rev2 式单平台盲区。
- **Skill 分发目标说明**：在 link-skills.sh 注释中明确两个分发目标的语义差异（`.claude/skills/` = 内联，`.claude/agents/` = 隔离），方便后续维护者理解。
