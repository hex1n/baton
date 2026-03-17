# Baton 精简改进计划

## Problem Statement

Baton 的 5 个核心创新有效，但框架在有机增长中积累了：
- 过程规范膨胀（research 500行, subagent 300行）
- 缺失关键机制（任务分级, evidence 组合规则）
- review checklist 混合高/低价值项

## Approach

按依赖关系执行 5 项改进（P6 hook 整合延迟）。

## Write Set

| File | Disposition |
|------|------------|
| `.baton/constitution.md` | 新增 §Task Sizing + §Evidence 判例 |
| `.baton/skills/using-baton/SKILL.md` | Phase Routing 引用任务分级 |
| `.baton/skills/baton-research/SKILL.md` | 精简 500→~200 行 |
| `.baton/skills/baton-subagent/SKILL.md` | 精简 300→~120 行 |
| `.baton/skills/baton-research/review-prompt-codebase.md` | 分层 must-check / should-check |
| `.baton/skills/baton-research/review-prompt-external.md` | 分层 must-check / should-check |
| `.baton/skills/baton-plan/review-prompt.md` | 分层 must-check / should-check |
| `.baton/skills/baton-implement/review-prompt.md` | 分层 must-check / should-check |

## Todo

- [x] 1. P1: 任务分级 — constitution.md 新增 §Task Sizing ✅
  Files: `.baton/constitution.md`, `.baton/skills/using-baton/SKILL.md`
  Verify: 读取文件确认分级定义存在且 using-baton 引用它
  Deps: none

- [x] 2. P4: Evidence 组合规则 — constitution.md §Evidence 新增判例 ✅
  Files: `.baton/constitution.md`
  Verify: 读取文件确认 4 个判例存在
  Deps: none

- [x] 3. P2: Research Skill 精简 — 513→210 行 ✅
  Files: `.baton/skills/baton-research/SKILL.md`
  Verify: wc -l = 210; Iron Law, Frame, Orient, Evidence, Self-Challenge, Review, Convergence 全部保留
  Deps: 1 (需要任务分级定义来引用)

- [x] 4. P3: Subagent Skill 精简 — 303→130 行 ✅
  Files: `.baton/skills/baton-subagent/SKILL.md`
  Verify: wc -l = 130; Iron Law + 5 Steps 结构保留
  Deps: none

- [x] 5. P5: Review Prompt 分层 — 4 个文件全部完成 ✅
  Files: 4 个 review-prompt.md
  Verify: 4/4 文件包含 Must-Check 和 Should-Check sections (external 补充了缺失的 Cross-Phase Compliance)
  Deps: none

## Implementation Notes

- B-level discovery: review-prompt-external.md 原本缺少 Cross-Phase Compliance Checks 节（其他 3 个 review prompt 都有）。已补充以保持一致性。

<!-- placeholder: human adds BATON:GO here -->

## 批注区
 <!-- BATON:GO -->