# Requirements: runtime-enforcement-hardening

**主题**: 运行时执行机制强化
**状态**: `draft`
**规模**: `Large`

## 1. 问题

当前 Baton 运行时存在以下执行缺口：

1. **Hook 架构碎片化** — 所有 hook 逻辑以内联命令字符串嵌入 `.claude/settings.json` 和 `.codex/hooks.json`，导致：不可独立测试、不可调试、宿主检测逻辑重复、无法安全地扩展新检查。
2. **Eval Round 不递增** — `task-status.md` 的 `Eval Round` 列始终为 0，修复循环没有上限控制，可能导致无限自修。
3. **blocked 状态缺少分类** — 进入 `blocked` 后 Notes 列内容自由文本，无法结构化区分阻塞原因。
4. **generator-feedback.md 无核心支持** — 模板仅存在于 `java-backend-strict` 扩展中，核心流程无法使用。Generator 发现设计缺口时没有标准化反馈路径。
5. **complete 状态不要求 retrospective.md** — `validate-state-artifacts.sh` 未将 `retrospective.md` 列入 `complete` 状态的必须工件。
6. **人类门控缺少执行** — `awaiting_human_arch` 和 `ready_for_human_close` 状态没有任何 hook 阻止 agent 未经人类确认就跳过。
7. **Strict Overlay 检测缺失** — Explorer 不会输出 overlay 推荐；harness-context.sh 不读取该推荐。

## 2. 范围

### 2.1 范围内

**Phase 1: Hook 基础设施重构**
- 将内联 hook 命令提取为 `spec/bootstrap/hooks/` 下的 5 个独立脚本
- 创建 `hooks/lib/parse-input.sh` 共享运行时库
- 更新 `install-hooks.sh` 生成薄调用层（脚本路径引用），移除旧内联命令
- 现有功能不退化（现有测试必须通过）

**Phase 2: 6 个执行缺口 + 4 个扩展**
- 6 个缺口：eval round 递增、blocked 分类、generator-feedback.md、retrospective.md、human_ack 门控、overlay 检测
- 4 个扩展：per-hook 单元测试 + ShellCheck、generator skill 指导、BATON_DEBUG、3 个一致性不变量

### 2.2 范围外

- Codex SubagentStop 支持（Codex 无此 hook 类型）
- 宿主原生人类审批 API（依赖上游能力）
- 跨宿主统一编排
- Receipt/遥测平台
- 可视化控制平面
- 多任务/worktree 调度
- Overlay 的强制执行（当前仅检测和建议）

## 3. 功能需求

### FR-1 共享 Hook 运行时库 (parse-input.sh)

- 从 stdin JSON 检测宿主类型：存在 `tool_input.file_path` → CC，存在 `tool_input.command` → Codex
- 导出标准变量：`$HOOK_HOST`（cc|codex）、`$HOOK_ROOT`、`$BOOTSTRAP_DIR`、`$HOOK_FILE_PATH`、`$HOOK_CONTENT`、`$HOOK_COMMAND`、`$HOOK_AGENT`
- 提供 `hook_block "reason"` 函数（两个宿主均 exit 2）和 `hook_pass` 函数（exit 0）
- 提供 `debug_log "message"` 函数（`BATON_DEBUG=1` 时输出到 stderr，否则静默）
- 提供重入守卫：检测 `BATON_HOOK_ACTIVE=1` 则立即 exit 0；写操作前设置该变量
- 提供 `read_profile_value <key> <default> [<regex>]`：从 `profile.local.yaml` 读取单个键值，支持可选正则验证

### FR-2 5 个独立 Hook 脚本

- `pre-transition.sh`：PreToolUse hook，验证状态转换合法性
- `post-artifact.sh`：PostToolUse hook，验证工件内容，清除 human_ack（见 FR-7）
- `stop-check.sh`：Stop hook，验证状态工件完整性和隔离性
- `subagent-stop.sh`：SubagentStop hook（CC-only），验证子 agent 工件，递增 eval round（见 FR-3）
- `session-start.sh`：SessionStart hook，注入 harness 上下文
- 每个脚本 source `hooks/lib/parse-input.sh` 作为运行时入口

### FR-3 Eval Round 自动递增与修复循环上限

- 新增 `task_status_set_eval_round <path> <value>` 函数于 `task-status.sh`
- 写入方式：temp file + `mv`（不使用 raw sed）
- `subagent-stop.sh`（CC-only）在 baton-evaluator 完成时调用该函数递增 `Eval Round`
- 从 `profile.local.yaml` 读取 `max_eval_rounds`（默认 3），通过 `read_profile_value` 解析
- 当 eval_round ≥ max_eval_rounds 时阻止（hook_block）
- 非数字或 ≤ 0 的 max_eval_rounds 值回退到默认值 3
- `eval_round` 语义：统计 baton-evaluator 总完成次数（含最终 PASS 轮），而非仅修复迭代次数

### FR-4 Blocked 状态结构化分类

- `pre-transition.sh`（CC）检测目标状态为 `blocked` 时，验证 Notes 列包含分类前缀
- 正则：`^\[(verification|scope|environment|design)_blocker\]`
- Notes 列为空时阻止并给出明确错误信息
- 仅适用于新的 blocked 转换，不回溯已有行
- **Codex 差异**：Codex PreToolUse 无法获取文件内容，改为在 `post-artifact.sh`（PostToolUse）中检查写入后磁盘上的 Notes 列

### FR-5 generator-feedback.md 运行时支持

- 将模板从 `spec/extensions/java-backend-strict/templates/` 提升到 `spec/templates/`（en + zh）
- 新模板必需章节：`Original Assumption|原始假设`、`Actual Finding|实际发现`、`Impact|影响`、`Recommended Next Owner|建议下一步负责方`
- `validate-artifact.sh` 新增 `generator-feedback` 工件类型的 schema 校验
- 提升后删除 `java-backend-strict` 下的旧副本，避免漂移
- baton-generator skill 新增指导：当发现设计层面缺口且超出批准写入面时，写 `.harness/generator-feedback.md` 并转入 `blocked`（分类 `[design_blocker]`）

### FR-6 complete 状态要求 retrospective.md

- `validate-state-artifacts.sh` 中 `complete` 状态的 `required_for_state()` 函数新增 `retrospective` 到必需工件列表

### FR-7 Human Gate 执行（advisory）

- `pre-transition.sh` 阻止从 `awaiting_human_arch` 或 `ready_for_human_close` 转出（除转入 `blocked`），除非磁盘上现有文件的 `## State Notes` 下包含 `- human_ack: true`
- 读取的是**磁盘上已存在的文件**（非 incoming content），确保 ack 是在先前 turn 写入的
- `post-artifact.sh` 在检测到状态从门控状态转出且工件验证通过后，清除 `- human_ack: true`（sed in-place）
- **排序约束**：ack 清除仅在工件验证成功后执行
- **重入守卫**：ack 清除写操作前设置 `BATON_HOOK_ACTIVE=1`
- **Advisory 性质**：这是 agent 可写的记账机制，非密码学证明。升级到宿主原生 API 前作为最佳努力执行
- `start-task.sh` 在新任务初始化时覆写整个 `task-status.md`，自动清除残留 ack

### FR-8 Strict Overlay 触发检测

- baton-explorer skill 新增指导：当检测到复杂度指标时（DB migration 目录、多模块写入面、API schema 文件、跨模块依赖），输出 `## Overlay Recommendation` 节，包含 `overlay: core` 或 `overlay: strict`
- `harness-context.sh`（SessionStart）读取 `scoped-map.md` 中的该节并包含在上下文输出中
- `validate-artifact.sh` 对 `scoped-map` 新增可选 `## Overlay Recommendation` 节检查（不强制——核心流程 scoped-map 可省略）

### FR-9 install-hooks.sh 清洁切换

- 生成的 hook 入口为薄一行脚本调用，例如 `bash "$root/spec/bootstrap/hooks/post-artifact.sh"`
- 旧内联命令在同一提交中移除，无自动检测回退
- CC 和 Codex 两端均更新
- 现有 `test-install-hooks.sh` 必须适配新格式后通过

### FR-10 per-Hook 单元测试 + ShellCheck

- 5 个 hook 脚本 + `parse-input.sh` 各有对应的 `tests/test-hook-*.sh` 测试文件
- 所有 hook 脚本通过 ShellCheck（无 error 级别发现）
- 测试覆盖：正常路径、边界条件、宿主差异

### FR-11 BATON_DEBUG 环境变量

- `BATON_DEBUG=1` 时，每个 hook 脚本向 stderr 输出诊断信息
- 内容包括：输入 payload 摘要、匹配条件、检查结果、最终决策（pass/block）
- 未设置或为 `0` 时完全静默

### FR-12 Generator Skill 指导

- baton-generator skill 的 SKILL.md 新增 `generator-feedback.md` 使用指导
- 指导内容：当 Generator 发现无法在批准写入面内解决的设计层缺口时，写 `.harness/generator-feedback.md` 并转入 `blocked`（`[design_blocker]`）

### FR-13 check-consistency.sh 新增 3 个不变量

- **不变量 N+1**：`spec/bootstrap/hooks/` 下每个脚本都有对应的 `tests/test-hook-*.sh` 文件
- **不变量 N+2**：`install-hooks.sh` 生成的所有路径均指向 `spec/bootstrap/hooks/` 下的实际脚本
- **不变量 N+3**：`generator-feedback` 在 `artifact-schema.md` 和 `validate-artifact.sh` 中均有入口

## 4. 非目标

- 不为 Codex 实现 SubagentStop 等效功能（Codex 不支持该 hook 类型）
- 不实现 Overlay 的强制执行（当前仅检测和建议，enforcer 将在 overlay 工件模板/验证器就绪后添加）
- 不实现宿主原生人类审批 API（依赖上游宿主能力，当前 human_ack 为 advisory）
- 不修改 `profile.local.yaml` 的完整 YAML 解析方式（保持 grep 单键读取模式）
- 不添加跨宿主统一编排层
- 不引入 YAML 库依赖
- 不修改已有工件的内容格式（只增加新的检查和工件类型）
- 不追溯修正已有 `blocked` 行的 Notes 列格式

## 5. 验收标准

### Phase 1: Hook 基础设施

- [ ] AC-1: `spec/bootstrap/hooks/` 下存在 5 个可执行脚本：`pre-transition.sh`、`post-artifact.sh`、`stop-check.sh`、`subagent-stop.sh`、`session-start.sh`
- [ ] AC-2: `spec/bootstrap/hooks/lib/parse-input.sh` 存在且提供：`hook_block`、`hook_pass`、`debug_log`、`read_profile_value`、重入守卫、宿主检测
- [ ] AC-3: `install-hooks.sh` 生成的 `.claude/settings.json` 和 `.codex/hooks.json` 中 hook 命令为脚本路径引用（非内联命令字符串）
- [ ] AC-4: `bash spec/bootstrap/install-hooks.sh` 后，所有现有 hook 功能不退化——`test-install-hooks.sh` 通过
- [ ] AC-5: `.claude/settings.json` 和 `.codex/hooks.json` 中不再包含内联 hook 逻辑（clean switch 完成）

### Phase 2: 执行缺口

- [ ] AC-6: baton-evaluator SubagentStop 完成时 `task-status.md` 的 `Eval Round` 列自动 +1（通过 `task_status_set_eval_round` 的 temp+mv 写入）
- [ ] AC-7: 当 eval_round ≥ max_eval_rounds（默认 3）时，SubagentStop hook 阻止并输出明确错误信息
- [ ] AC-8: 转入 `blocked` 时，若 Notes 列不含 `[verification_blocker]`、`[scope_blocker]`、`[environment_blocker]`、`[design_blocker]` 之一，CC 端 PreToolUse 阻止（Codex 端 PostToolUse 检查磁盘）
- [ ] AC-9: `spec/templates/generator-feedback.template.md` 和 `spec/templates/zh/generator-feedback.template.md` 存在，`validate-artifact.sh` 可校验其必需章节
- [ ] AC-10: `java-backend-strict` 下的旧 `generator-feedback.template.md` 已删除
- [ ] AC-11: `complete` 状态的 `required_for_state()` 包含 `retrospective`
- [ ] AC-12: 从 `awaiting_human_arch` 或 `ready_for_human_close` 转出（非 blocked）时，若磁盘文件无 `- human_ack: true`，hook 阻止
- [ ] AC-13: 成功从门控状态转出后，`post-artifact.sh` 清除 `- human_ack: true`
- [ ] AC-14: ack 清除仅在工件验证成功后执行（排序约束）
- [ ] AC-15: `scoped-map.md` 中 `## Overlay Recommendation` 含 `overlay: core|strict` 时，`harness-context.sh` 将其包含在上下文输出中

### Phase 2: 扩展

- [ ] AC-16: 5 个 hook 脚本 + `parse-input.sh` 各有对应的 `tests/test-hook-*.sh` 测试文件
- [ ] AC-17: 所有 hook 脚本 + `parse-input.sh` 通过 ShellCheck 无 error 级别发现
- [ ] AC-18: baton-generator skill SKILL.md 包含 `generator-feedback.md` 使用指导
- [ ] AC-19: `BATON_DEBUG=1` 时 hook 输出诊断信息到 stderr；未设置时完全静默
- [ ] AC-20: `check-consistency.sh` 包含 3 个新不变量且全部通过

### 跨切面

- [ ] AC-21: 重入守卫生效——hook 写操作不触发自身或其他 hook 的递归
- [ ] AC-22: 所有现有测试（`test-install-hooks.sh`、`test-validate-artifact.sh`、`test-validate-state-artifacts.sh`、`test-validate-isolation.sh`、`test-task-status.sh`）在完整变更后仍通过

## 6. 约束

- **宿主兼容性**：CC 和 Codex 的 hook 能力不同（见 CEO plan 的 Per-Host Capability Matrix），实现必须对齐该矩阵
- **无 YAML 库**：`read_profile_value` 使用 grep 单键读取，不引入 YAML 解析器
- **写操作安全**：所有 harness 文件写操作使用 temp file + `mv`，不使用 raw sed（除 ack clearing 的精确单行删除场景）
- **单任务假设**：每个 workspace 同一时间只有一个活跃任务，不考虑并发写入
- **Phase 顺序**：Phase 1（hook 提取）必须在 Phase 2（缺口填补）之前完成，因为 Phase 2 依赖新的 hook 基础设施
- **Advisory human_ack**：human_ack 为 agent 可写记账，非密码学证明；在宿主原生审批 API 可用前不做更强保证
- **向后兼容**：`task-status.sh` 的所有现有读函数签名不变；新增 `task_status_set_eval_round` 为唯一新函数
- **Clean switch**：旧内联命令和新独立脚本在同一提交中切换，无自动检测回退

## 7. 验证意图

### Phase 1 验证
- 运行 `install-hooks.sh` 后检查生成的 JSON 中 hook 命令格式（脚本引用 vs 内联）
- 运行现有 `test-install-hooks.sh` 确认无退化
- 手动或通过测试验证每个 hook 脚本的 source + parse-input.sh 链路正常
- ShellCheck 扫描所有新脚本

### Phase 2 验证
- 单元测试验证 `task_status_set_eval_round` 的 temp+mv 写入和边界值处理
- 单元测试验证 blocked 分类正则匹配和拒绝
- 单元测试验证 `generator-feedback` 工件校验的 section 检查
- 单元测试验证 human_ack 门控逻辑（有 ack / 无 ack / 转入 blocked 豁免）
- 单元测试验证 ack 清除的排序约束（验证成功后才清除）
- 单元测试验证 BATON_DEBUG 输出（开/关状态）
- 单元测试验证重入守卫（设置 BATON_HOOK_ACTIVE=1 后 hook 立即退出）
- `check-consistency.sh` 全部不变量通过（含 3 个新增）
- 运行完整测试套件确认无退化

### 未解决问题裁定

1. **`read_profile_value` 位置**：放入 `parse-input.sh`（hook 上下文专用，与宿主检测、debug_log 同层）【已确认——CEO plan 明确指定】
2. **ack 清除机制**：sed in-place 精确删除单行（非 temp+mv），因仅删除一个 bullet 不涉及表格结构风险【已确认——CEO plan 明确指定】
3. **generator-feedback.md 最终章节名**：使用 CEO plan 指定的 4 个章节（Original Assumption/Actual Finding/Impact/Recommended Next Owner），而非现有模板的 4 个章节（Problem/Evidence/Why/Requested Decision）【已确认——CEO plan 优先】
4. **Codex blocked 分类实现点**：PostToolUse 中检查磁盘上已写入的 Notes 列（Codex PreToolUse 无法获取文件内容）【已确认——CEO plan 明确指定】
