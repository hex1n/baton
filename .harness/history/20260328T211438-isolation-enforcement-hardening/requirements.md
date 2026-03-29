# Requirements: isolation-enforcement-hardening

**主题**: 把 Baton 对 verifier / evaluator 的隔离要求，从“文档里写了”升级成“协议、工件、runtime 都能识别和约束”  
**状态**: `approved`  
**规模**: `Medium`

## 1. 问题

当前 Baton 已经把 verifier / evaluator 定义成需要 artifact-isolated judgment 的角色，但协议执行仍有一个关键缺口：

- interface / role contract 说隔离是硬要求
- adapter 文档仍把 sequential fallback 当成通用退路
- verifier / evaluator 产物没有强制记录 isolation provenance
- runtime validator 不会阻止“没有独立评估证据”却进入 `ready_for_human_close`

结果是 Baton 已经在理念上要求隔离执行，但系统还不能区分：

- 真正隔离执行
- 明确降级执行
- 悄悄在同一上下文里 role-play

## 2. 范围

### 2.1 范围内

- 明确 strict / compat 两种 isolation mode
- 修正 portable interface、adapter、root governance 的语义冲突
- 为 `verification-path.md` 增加 isolation plan / execution context / fallback reason
- 将 `evaluation.md` 提升为进入 `ready_for_human_close` 前的条件性必需 artifact
- 增加 isolation validator 并接入 stop hooks
- 更新相关技能说明与测试

### 2.2 范围外

- 实现真正的 agent API 审计或跨宿主统一的 agent telemetry
- 新增长期运行 orchestrator
- 扩展 Java strict runtime signal collection

## 3. 功能需求

### FR-1 协议必须区分 strict 与 compat

portable core 和 adapter 必须显式区分两种隔离模式：

- `strict`: verifier / evaluator 不能用 sequential fallback 冒充独立判断
- `compat`: sequential fallback 可用，但必须显式标记为降级

### FR-2 Gate 3 必须记录 isolation provenance

`verification-path.md` 必须记录：

- isolation mode
- 实际 execution context
- 当 execution context 为 fallback 时的明确原因

### FR-3 Human close 前必须存在独立评估工件

进入 `ready_for_human_close` 或 `complete` 之前，必须存在 `evaluation.md`，并明确记录：

- review mode
- execution context
- findings / no findings
- verdict
- residual risks

### FR-4 runtime validator 必须能识别隔离要求是否被满足

bootstrap validator 必须能在当前任务状态与 artifacts 基础上识别：

- strict mode 下是否错误使用 sequential fallback
- compat mode 下是否缺失 fallback reason
- `ready_for_human_close` 前是否缺失 `evaluation.md`

### FR-5 root governance 与技能说明必须和 enforcement 一致

root governance、adapter 文档、`baton-verifier`、`baton-evaluator`、`baton-status` 的说明必须对齐，不允许继续同时存在“必须隔离”和“顺序 fallback 默认可接受”的歧义。

## 4. 非目标

- 引入真正的 subagent telemetry 后端
- 用 JSON/YAML 替代 markdown artifact
- 解决所有 runtime hardening 议题

## 5. 验收标准

### AC-1 strict / compat 语义已收敛

- [ ] interface、adapter、root governance 对两种模式的定义一致
- [ ] sequential fallback 不再被无条件描述为可接受

### AC-2 verifier / evaluator 产物具备 isolation provenance

- [ ] `verification-path.md` schema 包含 isolation mode / execution context / fallback reason
- [ ] `evaluation.md` schema 存在并被 validator 识别

### AC-3 runtime 能拦住不合规 handoff

- [ ] strict mode 下 sequential fallback 会被 isolation validator 阻止
- [ ] `ready_for_human_close` 缺失 `evaluation.md` 会被阻止
- [ ] stop hooks 包含 isolation validation

### AC-4 当前仓库的 task artifacts 已迁到新契约

- [ ] 当前 `.harness/verification-path.md` 包含 isolation provenance
- [ ] 当前 `.harness/evaluation.md` 已生成并通过校验

### AC-5 测试与一致性检查通过

- [ ] focused tests 覆盖 strict / compat / human-close gating
- [ ] `spec/bootstrap/check-consistency.sh` 通过

## 6. 约束

- 保持 markdown artifact 体系，不引入新存储格式
- 不破坏现有 hook 的相对路径方案
- PowerShell 与 Bash 版本都要保持可读写兼容
- `complete` 仍需要 human close；这次任务最多推进到 `ready_for_human_close`

## 7. 验证意图

- 跑 isolation / artifact / hook 相关 tests
- 跑 `spec/bootstrap/check-consistency.sh`
- 必要时重装 hooks，确认 stop checks 与新契约一致
