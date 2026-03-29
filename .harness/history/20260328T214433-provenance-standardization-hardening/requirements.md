# Requirements: provenance-standardization-hardening

**主题**: 把 independent-judgment provenance 从“已经有一些字段”推进成“字段固定、读取统一、human close 可直观看见”  
**状态**: `approved`  
**规模**: `Medium`

## 1. 问题

上一轮已经把 strict / compat、`evaluation.md` 和 isolation gate 补进 Baton，但还有三个残留问题：

- verifier / evaluator 的 provenance section 名和字段名没有完全统一
- validator / status surface 没有共用一套 provenance reader
- human close 前虽然有 `evaluation.md`，但 status surface 还不能直接看到 provenance 与 verdict

这意味着 Baton 已经有 provenance 概念，但还没把它标准化成稳定接口。

## 2. 范围

### 2.1 范围内

- 定义 verifier / evaluator 共享的 provenance section 名和固定字段
- 更新 artifact schema 与中英文模板
- 让 validator 与 status surface 复用同一套 provenance reader
- 在 `ready_for_human_close` / `complete` 的上下文里显示 verifier/evaluator provenance 与 evaluator verdict
- 扩 consistency invariant，覆盖模板 / validator / start-task reset / tests 的联动关系

### 2.2 范围外

- 平台级 subagent telemetry
- cryptographic attestation 或 runtime proof
- Java strict 的额外 runtime signal collection

## 3. 功能需求

### FR-1 provenance section 与字段必须标准化

`verification-path.md` 与 `evaluation.md` 必须共享一套固定 provenance 字段，至少包含：

- role
- isolation mode
- execution context
- evidence
- fallback reason

### FR-2 provenance 读取必须有共享入口

bootstrap 层必须存在共享 provenance reader，供 isolation validator 与 human-close status surface 复用，避免同一字段多处手写解析。

### FR-3 human close 前必须能直接看到 provenance 和 verdict

`harness-context.sh` 与 `baton-status` 在任务处于 `ready_for_human_close` 或 `complete` 时，必须直接显示：

- verifier 的 isolation mode / execution context
- evaluator 的 isolation mode / execution context
- evaluator verdict

### FR-4 consistency check 必须覆盖联动关系

`check-consistency.sh` 必须能发现以下漂移：

- provenance 模板 section 漂移
- validator 没跟着读取固定字段
- `start-task` 漏掉正式 artifact reset
- 测试没有覆盖关键 artifact / provenance 路径

### FR-5 向后兼容必须可控

validator 可以在过渡期兼容旧字段名，但 reference templates 和 live task artifacts 必须收敛到新的标准写法。

## 4. 非目标

- 废弃当前 markdown artifact 体系
- 为所有 artifact 引入统一 frontmatter
- 解决所有 human-close UX 问题

## 5. 验收标准

### AC-1 provenance 契约已统一

- [ ] verifier / evaluator 模板使用同一 provenance section 名
- [ ] 两者的 provenance 字段名固定并一致

### AC-2 reader 已共享

- [ ] isolation validator 使用共享 provenance reader
- [ ] human-close status surface 使用共享 provenance reader

### AC-3 human-close surface 已增强

- [ ] `harness-context.sh` 在 `ready_for_human_close` / `complete` 时显示 provenance 和 verdict
- [ ] `skills/baton-status.md` 说明与实现一致

### AC-4 coupling invariant 已编码

- [ ] `check-consistency.sh` 能检查 provenance 模板 / validator / reset / tests 的联动
- [ ] 当前仓库 consistency check 通过

### AC-5 focused verification 通过

- [ ] 相关 tests 全部通过
- [ ] live `.harness/` 通过 artifact/state/isolation 校验

## 6. 约束

- 保持 markdown artifact 结构
- 不破坏当前 strict / compat 行为
- 不要求旧历史工件全部回写迁移
- 这次任务最多推进到 `ready_for_human_close`，`complete` 仍需要 human close

## 7. 验证意图

- 跑 `tests/test-validate-artifact.sh`
- 跑 `tests/test-validate-isolation.sh`
- 跑 `tests/test-harness-context.sh`
- 跑 `tests/test-start-task.sh`
- 跑 `spec/bootstrap/check-consistency.sh`
- 用 live `.harness/` 过一遍 artifact / state / isolation validators
