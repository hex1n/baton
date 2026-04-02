# Architecture: isolation-enforcement-hardening

**主题**: 用 explicit mode + explicit evidence + stop-time validation，把 Baton 的隔离要求从约定升级成最小 enforcement runtime  
**状态**: `proposed`  
**规模**: `Medium`

## 1. 问题

当前 Baton 的问题不是“不知道 verifier / evaluator 应该隔离”，而是系统没有把这个要求编译成可以执行的契约：

- 协议层说隔离是硬要求
- adapter 层仍保留宽松 fallback 描述
- artifact 层没有记录 execution context
- runtime 层不会因为缺失独立评估证据而阻止 human close

## 2. 第一性原理拆解

### 2.1 问题陈述

如果一个协议既要求“独立判断”，又允许“顺序 fallback”，那系统至少必须同时锁定三件事：

- 当前任务是 `strict` 还是 `compat`
- verifier / evaluator 实际在什么上下文中运行
- degraded fallback 是否被显式记录并暴露给 human gate

现在 Baton 三者都没有被统一编码。

### 2.2 约束

- 继续使用 markdown artifacts，而不是引入新存储系统
- 不破坏现有 hook 的相对路径机制
- shell 与 PowerShell 都必须兼容当前 schema
- 不依赖平台一定能回传 subagent telemetry

### 2.3 方案类别

- 方案 A: 只修文档措辞，不加 runtime enforcement
- 方案 B: 增加 explicit mode + provenance artifact + isolation validator
- 方案 C: 引入重 orchestrator / subagent telemetry 层

### 2.4 评估

- 为什么方案 B 胜出:
  - 能直接把本轮暴露的问题转成可检查的协议字段与 gate
  - 不要求先发明新 orchestrator
  - 能在 portable core 上成立，适配 Codex / Claude / Cursor
- 为什么拒绝方案 A:
  - 只能减少歧义，不能拦住不合规 handoff
- 为什么拒绝方案 C:
  - 对当前问题来说过重
  - 需要额外平台能力，超出最小 hardening 范围

## 3. 推荐架构

- 方法:
  - 用 profile-declared mode + artifact-declared provenance + stop-time validator 组成最小闭环
- 关键变更点:
  - `cli-adapter-interface.md` 定义 `strict` / `compat`
  - `codex.md` / `claude-code.md` 只在 `compat` 下接受 sequential fallback
  - `profile.local.template.yaml` 暴露 verification/review isolation mode
  - `verification-path.template.md` 增加 isolation plan
  - 新增 `evaluation.template.md`
  - `validate-artifact.sh` / `validate-state-artifacts.sh` / 新 `validate-isolation.sh` 收紧 gate
  - `install-hooks.sh` 的 stop command 串联 isolation validator
- 数据 / 控制边界:
  - 当前任务状态仍以 `task-status.md` 为控制平面
  - isolation 合规性以 `verification-path.md` + `evaluation.md` 为事实源
  - stop hooks 只消费 artifacts，不消费对话记忆
- 向后兼容说明:
  - 现有未声明模式的 repo 在 reference implementation 下默认按 `strict` 解释
  - `compat` 是显式 opt-in，而不是默认沉默降级

## 4. 影响面扫描

| 文件 | 层级 | 处理方式 | 原因 |
|---|---|---|---|
| `spec/adapters/cli-adapter-interface.md` | L1 | modify | strict / compat 单源定义 |
| `spec/adapters/codex.md` | L1 | modify | fallback 规则对齐 |
| `spec/adapters/claude-code.md` | L1 | modify | fallback 规则对齐 |
| `spec/protocol/role-contracts.md` | L1 | modify | evaluator artifact 与 isolation note 对齐 |
| `spec/protocol/gates.md` | L1 | modify | Gate 3 / Gate 4 需要 explicit evidence |
| `spec/protocol/artifact-schema.md` | L1 | modify | verification-path / evaluation schema 收紧 |
| `spec/templates/profile.local.template.yaml` | L1 | modify | isolation mode 配置位 |
| `spec/templates/root-governance.template.md` | L1 | modify | governance 语义对齐 |
| `spec/templates/verification-path.template.md` | L1 | modify | isolation plan |
| `spec/templates/evaluation.template.md` | L1 | add | evaluator artifact |
| `spec/templates/zh/verification-path.template.md` | L1 | modify | 中英模板对齐 |
| `spec/templates/zh/evaluation.template.md` | L1 | add | 中英模板对齐 |
| `spec/bootstrap/validate-artifact.sh` | L1 | modify | schema enforcement |
| `spec/bootstrap/validate-state-artifacts.sh` | L1 | modify | human-close gating |
| `spec/bootstrap/validate-isolation.sh` | L1 | add | isolation gate validator |
| `spec/bootstrap/install-hooks.sh` | L1 | modify | stop hook 增加 isolation check |
| `spec/bootstrap/check-consistency.sh` | L1 | modify | template/distribution drift checks |
| `skills/baton-verifier.md` | L2 | modify | isolation plan 写法 |
| `skills/baton-evaluator.md` | L2 | modify | evaluation artifact 写法 |
| `skills/baton-status.md` | L2 | modify | ready_for_human_close 前提说明 |
| `tests/test-validate-artifact.sh` | L2 | modify | new artifact schema coverage |
| `tests/test-validate-state-artifacts.sh` | L2 | modify | evaluation gating |
| `tests/test-install-hooks.sh` | L2 | modify | stop hook now includes isolation validator |
| `tests/test-validate-isolation.sh` | L2 | add | strict / compat behavior |

## 5. 验证策略

- 主要检查:
  - strict mode 会阻止 sequential fallback
  - compat mode 会要求显式 fallback reason
  - `ready_for_human_close` 缺失 `evaluation.md` 会被阻止
  - stop hook 配置包含 isolation validator
- 评审重点:
  - fallback 语义是否在 spec / adapter / governance 一致
  - artifact schema 是否足够小而硬
  - hooks 是否仍保持相对路径和幂等性
- 验证无法完全消除的风险:
  - runtime 仍不能百分之百证明宿主确实调用了平台 subagent API，只能要求 explicit provenance 并在 strict mode 下阻止未声明降级

## 6. 风险

- `strict` 默认化会提高老仓库升级摩擦
- 新增 `evaluation.md` 后，用户工作流会比之前多一个显式工件
- PowerShell 版本没有现成测试，需靠逻辑对齐和代码审查

## 7. 自我质疑

1. 这是最优方案类别，还是只是第一个可行方案?
   - 对当前范围来说是最优折中；再重就会滑向 orchestrator 项目。
2. 还有哪些假设尚未验证?
   - profile isolation 默认值对已有用户的升级体验。
3. 一个怀疑者会先质疑什么?
   - artifact provenance 会不会只是“自报家门”。答案是对，所以下一阶段若要更强，只能接平台 telemetry；这次先补最小 gate。
