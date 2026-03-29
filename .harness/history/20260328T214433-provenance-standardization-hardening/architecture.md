# Architecture: provenance-standardization-hardening

**主题**: 用共享 provenance 契约 + 共享 reader + human-close summary，把 Baton 的 artifact-level provenance 做成稳定接口  
**状态**: `proposed`  
**规模**: `Medium`

## 1. 问题

当前 Baton 的 provenance 已经存在，但还是“有内容，不够像接口”：

- verifier / evaluator 分别使用不同 section 名和不同 mode 字段名
- provenance 读取逻辑散在 validator 与 status surface 中
- human close 的状态视图只能看见 artifact presence，不能直接看见 provenance 与 verdict

## 2. 第一性原理拆解

### 2.1 问题陈述

如果 provenance 要成为协议字段，而不是临时说明，那么系统至少要满足三件事：

- 写入结构固定
- 读取入口统一
- human gate 能直接消费

现在 Baton 三者只做到了第一步的一半。

### 2.2 约束

- 继续使用 markdown artifact
- 不破坏现有 strict / compat gate 行为
- 不扩大到 telemetry 系统
- 中英文 artifact 仍要可读

### 2.3 方案类别

- 方案 A: 保持现状，只补更多文档说明
- 方案 B: 统一 provenance schema，并抽共享 reader 给 validator / status surface
- 方案 C: 直接引入新的 structured sidecar 或 frontmatter

### 2.4 评估

- 为什么方案 B 胜出:
  - 能最直接响应 retrospective 里的三个改进点
  - 不引入新的存储模型
  - 让 validator 和 human-close surface 都站在同一单源上
- 为什么拒绝方案 A:
  - 不能防止字段漂移
  - 不能减少 parser duplication
- 为什么拒绝方案 C:
  - 改动面过大
  - 会把当前 hardening 任务升级成 artifact system redesign

## 3. 推荐架构

- 方法:
  - 引入共享 provenance reader，统一消费固定字段
- 关键变更点:
  - 在 `artifact-schema.md` 里定义 shared provenance block
  - 让 `verification-path` 与 `evaluation` 使用同一 provenance section 与字段
  - 新增 `spec/bootstrap/provenance.sh` 供 `validate-isolation.sh` 与 `harness-context.sh` 复用
  - 扩 `check-consistency.sh`，把 provenance 模板 / validator / reset / tests 的 coupling 锁住
  - 增强 `harness-context.sh` 和 `skills/baton-status.md`，在 human-close surface 展示 provenance + verdict
- 数据 / 控制边界:
  - facts 仍由 `verification-path.md` 与 `evaluation.md` 持有
  - reader 只是统一读取接口，不新增持久化文件
  - human close 直接消费 artifact facts，不消费聊天记忆
- 向后兼容说明:
  - validator 过渡期兼容旧字段名
  - templates 与 live 当前任务工件收敛到新字段

## 4. 影响面扫描

| 文件 | 层级 | 处理方式 | 原因 |
|---|---|---|---|
| `spec/protocol/artifact-schema.md` | L1 | modify | 定义标准 provenance block |
| `spec/templates/verification-path.template.md` | L1 | modify | verifier provenance 收敛 |
| `spec/templates/evaluation.template.md` | L1 | modify | evaluator provenance 收敛 |
| `spec/templates/zh/verification-path.template.md` | L1 | modify | 中文模板对齐 |
| `spec/templates/zh/evaluation.template.md` | L1 | modify | 中文模板对齐 |
| `spec/bootstrap/provenance.sh` | L1 | add | 共享 provenance reader |
| `spec/bootstrap/validate-isolation.sh` | L1 | modify | 复用 shared reader |
| `spec/bootstrap/harness-context.sh` | L1 | modify | human-close 显示 provenance + verdict |
| `spec/bootstrap/check-consistency.sh` | L1 | modify | coupling invariant |
| `skills/baton-status.md` | L2 | modify | 状态展示说明更新 |
| `tests/test-validate-artifact.sh` | L2 | modify | 新 schema coverage |
| `tests/test-validate-isolation.sh` | L2 | modify | shared fields coverage |
| `tests/test-harness-context.sh` | L2 | modify | human-close summary coverage |
| `tests/test-start-task.sh` | L2 | modify | reset coupling coverage |
| `.harness/verification-path.md` | L3 | modify | live artifact 收敛 |
| `.harness/evaluation.md` | L3 | modify | live artifact 收敛 |

## 5. 验证策略

- 主要检查:
  - provenance section 和字段在 verifier/evaluator 模板中完全一致
  - live `.harness/` 能通过新的 shared provenance reader 和 isolation validator
  - `harness-context.sh` 在 human-close state 下直接显示 provenance + verdict
- 评审重点:
  - shared reader 是否真的消掉 duplicated parsing
  - compatibility 是否足够，不会立刻打坏旧测试
  - consistency invariant 是否足够硬，但不过度脆弱
- 验证无法完全消除的风险:
  - 仍然只是 artifact-level provenance，不能代替平台 telemetry

## 6. 风险

- 如果 provenance section 改得过激，live task artifact 会立刻被 validator 拦住
- consistency invariant 如果写得太脆，会把正常重构误判成漂移
- shared reader 若设计不稳，会让 validator 和 status surface 一起出问题

## 7. 自我质疑

1. 这是最优方案类别，还是只是第一个可行方案?
   - 对当前范围来说是最优折中；再重就会变成新的 artifact architecture。
2. 还有哪些假设尚未验证?
   - 共享 provenance reader 是否足够支撑未来更多 independent-judgment artifacts。
3. 一个怀疑者会先质疑什么?
   - “字段统一”是不是只是命名洁癖。答案是不是；因为 validator、status surface、human gate 现在都要消费这些字段。
