# Scoped Map: runtime-enforcement-hardening

**需求**: 将内联 hook 命令重构为独立脚本，并实现 6 项执行时间间隙（eval round 自增、blocked 分类、generator-feedback.md、retrospective.md 检查、human gate、overlay 检测）+ 4 项扩展（测试、技能指导、BATON_DEBUG、一致性不变量）
**领域**: harness runtime enforcement / hook infrastructure
**Owner**: `scoped-explorer`
**状态**: `complete`

## 1. 范围

- 范围内:
  - Phase 1: 从 `.claude/settings.json` 和 `.codex/hooks.json` 中提取内联 hook 命令到 `spec/bootstrap/hooks/` 下的 5 个独立脚本 + 1 个共享库
  - Phase 2: 实现 6 项 enforcement gap（eval round 自增、blocked 分类、generator-feedback.md 运行时支持、retrospective.md 完成检查、human gate advisory 强制、overlay 检测）
  - Phase 2 扩展: hook 脚本独立单元测试 + ShellCheck、generator skill 对 generator-feedback.md 的指导、BATON_DEBUG 环境变量、check-consistency.sh 3 个新不变量
  - `install-hooks.sh` 重写为生成指向独立脚本的薄一行调用
  - `task-status.sh` 添加 `task_status_set_eval_round()` 写函数
  - `validate-artifact.sh` 添加 `generator-feedback` schema 条目
  - `validate-state-artifacts.sh` 添加 `retrospective.md` 到 `complete` 状态的必需文件
  - `harness-context.sh` 读取 `## Overlay Recommendation` 并输出到上下文
  - `spec/templates/` 添加 `generator-feedback.template.md`（en + zh）
  - 从 `spec/extensions/java-backend-strict/templates/` 移除旧版 generator-feedback 模板
  - `profile.local.template.yaml` 添加 `max_eval_rounds` 配置项
- 范围外:
  - 跨主机统一编排（12 个月目标）
  - host-native human gate API（依赖上游）
  - 多任务/worktree 调度
  - 视觉控制平面 / 遥测平台
  - profile-driven enforcement engine（方案 C，过早抽象）
- 预期写入边界:
  - `spec/bootstrap/hooks/` (新目录: 5 脚本 + `lib/parse-input.sh`)
  - `spec/bootstrap/install-hooks.sh` (重写)
  - `spec/bootstrap/task-status.sh` (添加写函数 + read_profile_value)
  - `spec/bootstrap/validate-artifact.sh` (添加 generator-feedback case)
  - `spec/bootstrap/validate-state-artifacts.sh` (添加 retrospective.md)
  - `spec/bootstrap/harness-context.sh` (读 overlay recommendation)
  - `spec/bootstrap/check-consistency.sh` (3 个新不变量)
  - `.claude/settings.json` (由 install-hooks.sh 重新生成)
  - `.codex/hooks.json` (由 install-hooks.sh 重新生成)
  - `spec/templates/generator-feedback.template.md` (新文件, en)
  - `spec/templates/zh/generator-feedback.template.md` (新文件, zh)
  - `spec/extensions/java-backend-strict/templates/generator-feedback.template.md` (删除)
  - `spec/protocol/artifact-schema.md` (已有 generator-feedback 条目，无需修改)
  - `spec/templates/profile.local.template.yaml` (添加 max_eval_rounds)
  - `skills/baton-generator/SKILL.md` (添加 generator-feedback.md 指导)
  - `skills/baton-explorer/SKILL.md` (添加 overlay recommendation 指导)
  - `tests/test-hook-*.sh` (5 个新测试文件)
  - `tests/test-install-hooks.sh` (更新以适配新架构)

## 2. 入口点

- 主要入口类或文件:
  1. **`.claude/settings.json`** (第 8-62 行) -- Claude Code hook 注册点，当前包含所有 5 类 hook 的内联命令字符串
  2. **`.codex/hooks.json`** (第 1-50 行) -- Codex hook 注册点，当前包含 4 类 hook 的内联命令字符串（无 SubagentStop）
  3. **`spec/bootstrap/install-hooks.sh`** (361 行) -- hook 安装脚本，当前生成内联命令字符串到 settings.json 和 hooks.json
  4. **`spec/bootstrap/task-status.sh`** (220 行) -- task-status.md 解析器，当前只有读函数，无写函数
  5. **`spec/bootstrap/validate-state-artifacts.sh`** (46 行) -- 状态-文件一致性检查，当前 `complete` 状态不要求 `retrospective.md`
  6. **`spec/bootstrap/validate-artifact.sh`** (87 行) -- artifact schema 校验器，当前无 `generator-feedback` case
  7. **`spec/bootstrap/harness-context.sh`** (73 行) -- SessionStart 上下文注入，当前不读 overlay recommendation
  8. **`spec/bootstrap/validate-isolation.sh`** (147 行) -- isolation provenance 校验，包含唯一的 `read_profile_mode()` 实现
  9. **`spec/bootstrap/check-consistency.sh`** (400 行) -- 不变量检查，当前 11 个不变量
  10. **`spec/bootstrap/provenance.sh`** (28 行) -- 共享 provenance 读取库
  11. **`spec/bootstrap/validate-transition.sh`** (65 行) -- 状态转换合法性校验
  12. **`skills/baton-generator/SKILL.md`** -- Generator 技能文件，已提到 generator-feedback.md 但缺少模板引导
  13. **`skills/baton-explorer/SKILL.md`** -- Explorer 技能文件，无 overlay recommendation 指导
  14. **`spec/extensions/java-backend-strict/templates/generator-feedback.template.md`** -- 当前 generator-feedback 模板（待提升到 core）

- 涉及的方法、API、命令或脚本:
  - `task_status_current_field()` -- 行级字段读取（state, owner, eval_round 等）
  - `task_status_rows_tsv()` / `task_status_current_row_tsv()` -- 行解析器
  - `read_profile_mode()` -- `validate-isolation.sh` 中的 profile.local.yaml 读取（strict/compat 专用，需泛化为 `read_profile_value`）
  - `provenance_read_field()` / `provenance_normalize_value()` / `provenance_clean_value()` -- provenance.sh 中的字段读取器
  - `has_section()` / `check_sections()` -- validate-artifact.sh 中的 section 匹配函数

- 这些入口为什么相关:
  - Phase 1 的核心是把 `install-hooks.sh` 生成的内联命令拆分为独立脚本。当前的 5 类 hook 命令（PostToolUse, PreToolUse, Stop, SubagentStop, SessionStart）分别对应 5 个目标独立脚本
  - Phase 2 的 6 项 gap 各自触及不同的 bootstrap 脚本或 hook 入口：eval round 触及 task-status.sh + SubagentStop hook、blocked 分类触及 PreToolUse hook、generator-feedback 触及 validate-artifact.sh + templates、retrospective 触及 validate-state-artifacts.sh、human gate 触及 PreToolUse hook、overlay 触及 harness-context.sh + explorer skill

## 3. 调用链

```text
Phase 1 — Hook 重构:
  install-hooks.sh
    -> 生成 settings.json / hooks.json
    -> 当前: 嵌入内联命令字符串
    -> 目标: 嵌入 `bash "$root/spec/bootstrap/hooks/<script>.sh"` 薄调用

  hooks/lib/parse-input.sh (新共享库)
    -> 被 5 个 hook 脚本 source
    -> 提供: $HOOK_HOST, $HOOK_ROOT, $BOOTSTRAP_DIR, $HOOK_FILE_PATH,
             $HOOK_CONTENT, $HOOK_COMMAND, $HOOK_AGENT
    -> 提供: hook_block(), hook_pass(), debug_log(), read_profile_value()
    -> 提供: re-entrancy guard (BATON_HOOK_ACTIVE)

  hooks/post-artifact.sh (PostToolUse)
    -> 来源: CC 当前 PostToolUse 内联 + Codex PostToolUse 内联
    -> parse-input.sh -> 检测 host -> 提取 file_path/command
    -> validate-artifact.sh
    -> [新] human_ack 清除逻辑（成功转换后）

  hooks/pre-transition.sh (PreToolUse)
    -> 来源: CC 当前 PreToolUse 内联 + Codex PreToolUse 内联
    -> parse-input.sh -> task-status.sh -> validate-transition.sh
    -> [新] blocked 分类校验（CC: 检查 incoming content Notes 列）
    -> [新] human gate 校验（读磁盘文件的 human_ack）

  hooks/stop-check.sh (Stop)
    -> 来源: CC/Codex 当前 Stop 内联
    -> validate-state-artifacts.sh -> validate-isolation.sh

  hooks/subagent-stop.sh (SubagentStop, CC-only)
    -> 来源: CC 当前 SubagentStop 内联
    -> [新] eval round 自增 via task_status_set_eval_round()
    -> [新] max_eval_rounds 限制 via read_profile_value()
    -> 现有: baton-verifier/baton-evaluator 完成检查

  hooks/session-start.sh (SessionStart)
    -> 来源: CC/Codex 当前 SessionStart 内联
    -> harness-context.sh
    -> [新] harness-context.sh 读取 scoped-map.md 中的 overlay recommendation

Phase 2 — Enforcement Gap 调用链:

  Gap 1 (eval round 自增):
    SubagentStop hook -> hooks/subagent-stop.sh
      -> task-status.sh::task_status_set_eval_round()  [新写函数]
      -> read_profile_value("max_eval_rounds", "3")  [新泛型读取器]
      -> 超限 -> hook_block()

  Gap 2 (blocked 分类):
    PreToolUse hook -> hooks/pre-transition.sh
      -> 检测 to_state == "blocked"
      -> CC: 从 incoming content 解析 Notes 列
      -> Codex: 从磁盘文件解析 Notes 列 (PostToolUse)
      -> 正则 ^\[(verification|scope|environment|design)_blocker\]
      -> 不匹配 -> hook_block()

  Gap 3 (generator-feedback.md):
    validate-artifact.sh -> 新 case "generator-feedback"
      -> check_sections: Original Assumption|原始假设, Actual Finding|实际发现,
         Impact|影响, Recommended Next Owner|建议下一步负责方
    模板: spec/templates/generator-feedback.template.md (en)
          spec/templates/zh/generator-feedback.template.md (zh)
    旧模板删除: spec/extensions/java-backend-strict/templates/generator-feedback.template.md

  Gap 4 (retrospective.md 检查):
    validate-state-artifacts.sh -> required_for_state("complete")
      -> 添加 "retrospective.md" 到返回列表

  Gap 5 (human gate advisory):
    PreToolUse hook -> hooks/pre-transition.sh
      -> from_state in (awaiting_human_arch, ready_for_human_close)
      -> to_state != blocked
      -> 读磁盘 task-status.md -> 检查 "- human_ack: true" under ## State Notes
      -> 未找到 -> hook_block()
    PostToolUse hook -> hooks/post-artifact.sh
      -> 检测 from gated state -> ack 清除 (sed in-place)
      -> 只在 validate-artifact 成功后执行

  Gap 6 (overlay 检测):
    SessionStart hook -> hooks/session-start.sh -> harness-context.sh
      -> 读取 .harness/scoped-map.md 中 "## Overlay Recommendation"
      -> 提取 overlay: core|strict
      -> 注入到 context output
    Explorer skill: 添加输出 "## Overlay Recommendation" 的指导
```

## 4. 现有行为

- 当前可观察行为:
  - **hook 命令内联**: 所有 hook 逻辑以单行 shell 命令嵌入 `.claude/settings.json` 和 `.codex/hooks.json`，最长的命令（SubagentStop）超过 500 字符，不可读不可测
  - **install-hooks.sh**: 在 bash 变量中构建完整命令字符串，通过 jq 注入 JSON。Clean switch（无自动检测回退），替换标记字符串（`# baton-validate-artifact` 等）实现幂等
  - **task-status.sh**: 纯读取库，支持 `schema`/`rows`/`current-field`/`row-count`/`non-complete-count`。无任何写操作函数
  - **validate-state-artifacts.sh**: `complete` 状态要求 `scoped-map.md, requirements.md, architecture.md, verification-path.md, evaluation.md`，不含 `retrospective.md`
  - **validate-artifact.sh**: 支持 6 种 artifact type（scoped-map, requirements, architecture, verification-path, evaluation, task-status），不支持 `generator-feedback`
  - **harness-context.sh**: SessionStart 输出 task/state/owner/eval_round + present/missing artifacts + (human-close 状态下) verifier/evaluator provenance 摘要。不读 overlay recommendation
  - **validate-isolation.sh**: 使用本地 `read_profile_mode()` 读取 `verification_isolation_mode` 和 `review_isolation_mode`，该函数硬编码 `strict|compat` 正则，不支持任意 key
  - **SubagentStop hook**: 仅校验 baton-verifier 产出 verification-path.md 和 baton-evaluator 将状态推到 blocked/reviewing/ready_for_human_close。不做 eval round 自增或限制
  - **PreToolUse hook**: 仅做状态转换合法性校验，不做 blocked 分类或 human gate 检查
  - **PostToolUse hook**: 仅做 artifact schema 校验，不做 human_ack 清除

- 当前校验规则:
  - 状态转换: `validate-transition.sh` 从 `state-machine.md` 读取 Allowed Transitions 段落，`any -> blocked` 始终合法
  - Artifact schema: `validate-artifact.sh` 用 `grep -qiE` 匹配 `##` 开头的 section 标题
  - Stop 检查: `validate-state-artifacts.sh` + `validate-isolation.sh` 串行执行
  - 一致性: `check-consistency.sh` 有 11 个不变量（owners.txt 同步、states.txt 同步、template header 匹配、skills 同步、README 双语、governance 同步、agents 同步、symlink 相对路径、live task-status schema、isolation templates、provenance contract）

- 现有隐式约束:
  - **单任务假设**: 每个工作区只有一个活跃任务，eval round 写入不需要并发保护
  - **无递归**: 当前没有 hook 修改 harness 文件，因此不存在 PostToolUse -> write -> PostToolUse 递归。一旦引入 eval round 写入和 ack 清除，需要 re-entrancy guard
  - **Hook 无写**: 现有 hook 只 block 或 pass，从不修改文件。新增的 eval round 自增和 ack 清除是**新模式**
  - **install-hooks.sh 使用标记字符串**: 幂等依赖 `# baton-validate-artifact` 等注释标记，重构后需要更新标记或使用新标记

## 5. 现有测试

- 直接相关的测试:
  1. **`tests/test-install-hooks.sh`** (212 行) -- 验证 install-hooks.sh 输出结构：PostToolUse/PreToolUse/Stop/SubagentStop/SessionStart 各 hook 的存在性、幂等性、相对路径、dry-run、标记字符串。**重构后需要大幅更新**
  2. **`tests/test-task-status.sh`** -- task-status.sh 解析器测试。需要扩展以覆盖新写函数 `task_status_set_eval_round()`
  3. **`tests/test-validate-state-artifacts.sh`** -- 验证各状态所需 artifact 列表。需要添加 `complete` 状态下 `retrospective.md` 的检查
  4. **`tests/test-validate-artifact.sh`** -- 验证各 artifact type 的 section 校验。需要添加 `generator-feedback` case
  5. **`tests/test-harness-context.sh`** -- 验证 SessionStart 输出格式。需要添加 overlay recommendation 输出测试
  6. **`tests/test-validate-isolation.sh`** -- 验证 isolation provenance 校验。与 `read_profile_mode` -> `read_profile_value` 泛化相关
  7. **`tests/test-start-task.sh`** -- start-task.sh 功能测试

- 附近可复用的测试:
  - `tests/test-skill-links.sh` -- 技能链接一致性，不直接相关
  - `tests/test-validate-transition.sh` -- 状态转换校验，pre-transition.sh 的下游依赖

- 未找到可用测试:
  - 无任何 hook 脚本级别的单元测试（hook 内联命令不可独立测试）
  - 无 `parse-input.sh` 测试（尚不存在）
  - 无 BATON_DEBUG 相关测试
  - 无 human_ack / blocked categorization / overlay detection 测试

## 6. 依赖 / 风险扫描

- 这次改动是否可能触及集成层或基础设施?
  - **是**。hook 重构直接改变 `.claude/settings.json` 和 `.codex/hooks.json` 的结构。如果重构有误，所有 baton hook 将停止工作
  - `install-hooks.sh` 是用户运行的安装入口，影响所有采用 baton 的项目

- 这次改动是否可能触及迁移或 schema?
  - `task-status.md` 的 schema 不变（已有 `Eval Round` 列），但引入了首个写操作（`task_status_set_eval_round()`）
  - `generator-feedback.template.md` 是新 artifact type，需要 `validate-artifact.sh` 和 `artifact-schema.md` 同时支持
  - `profile.local.template.yaml` 添加 `max_eval_rounds` 配置项

- 这次改动是否可能跨业务域?
  - 跨 Claude Code 和 Codex 两个主机平台的 hook 系统
  - 跨 3 个技能文件（generator, explorer, retrospective）
  - 跨 spec/protocol（artifact-schema.md）和 spec/bootstrap（运行时脚本）两个层面

- **高风险区域**:
  1. **Re-entrancy**: SubagentStop 写 eval_round -> 触发 PostToolUse -> 无限递归。必须有 `BATON_HOOK_ACTIVE` guard
  2. **PostToolUse 排序**: human_ack 清除必须在 validate-artifact 之后。如果 validate 失败但 ack 已清除，状态不一致
  3. **sed in-place ack 清除**: 如果 sed 表达式匹配错误行，会破坏 task-status.md 结构。应考虑使用 task-status.sh 写函数
  4. **标记字符串迁移**: install-hooks.sh 从内联命令切换到脚本调用，标记字符串必须保持一致，否则幂等机制失效
  5. **Codex blocked 分类时序**: Codex 只能 PostToolUse 检查（已写入磁盘），非法分类检测晚于写入

## 7. 变更形态

- 这看起来像: 大型基础设施重构 + 多项功能增量。分两个 phase 实施：先重构 hook 架构，再添加 enforcement 功能
- 预计文件数:
  - 新建: 8-10 个文件（5 hook 脚本 + 1 共享库 + 2 模板 + 5 测试）
  - 修改: 10-12 个文件（install-hooks.sh, task-status.sh, validate-artifact.sh, validate-state-artifacts.sh, harness-context.sh, check-consistency.sh, profile.local.template.yaml, 2 技能文件, 3-5 现有测试文件）
  - 删除: 1 个文件（java-backend-strict 旧模板）
- 推荐实现深度: **两阶段实施**
  - Phase 1: hook 提取 + parse-input.sh + install-hooks.sh 重写 + 现有测试更新
  - Phase 2: 6 gap + 4 扩展 + 新 hook 测试 + consistency 不变量

## 8. 未决问题

- `read_profile_value` 是放在 `parse-input.sh`（hook 共享库）还是放在独立的 profile 读取库中？CEO 计划写在 parse-input.sh 中，但 `validate-isolation.sh` 也需要用到，需确认是否 source 同一个库
- `post-artifact.sh` 的 ack 清除使用 sed in-place 编辑，是否应改用 task-status.sh 的写函数以保持一致性？CEO 计划指定 sed，但 eval round 使用写函数
- generator-feedback.md 的必需 section 标题在 CEO 计划中定义为 `Original Assumption|原始假设, Actual Finding|实际发现, Impact|影响, Recommended Next Owner|建议下一步负责方`，但当前 java-backend-strict 模板使用不同的 section 名（Problem, Evidence, Why Generator Did Not Patch Around It, Requested Decision）。需确认最终 section 名
- Codex 端 blocked 分类的 PostToolUse 实现细节：CEO 计划提到"on-disk row after write"，需要确认是在 post-artifact.sh 中添加还是需要单独的 hook 脚本

## 9. 建议

- 是否继续? **是**。CEO 计划已通过 CEO/Eng/Codex 三方 review，0 个未解决问题
- 建议下一步:
  - Specifier 应基于 CEO 计划的精确规格（尤其是 Per-Host Capability Matrix 和 Key Architectural Decisions）转化为可验证的 requirements.md
  - 重点关注 Phase 1 -> Phase 2 的切换条件：Phase 1 完成的定义是"现有 test-install-hooks.sh 通过 + 新 hook 脚本能被 source 并独立执行 + install-hooks.sh 生成的 JSON 只包含薄一行调用"
  - 将 `read_profile_value` 的归属问题作为 architecture 阶段的决策点

## Overlay Recommendation

overlay: strict

理由: 多模块写入面（5+ hook 脚本 + 共享库 + 多个 bootstrap 脚本）、跨平台（CC/Codex 两套 hook 系统）、基础设施变更（hook 是所有 baton 项目的运行基础）
