# Retrospective: provenance-standardization-hardening

## 1. 结果

- 关闭状态: `complete`
- 主要阻塞: 无长期阻塞；中途暴露的是 provenance 契约已经存在，但还没有统一成稳定接口
- 人工决策: human 接受结果，无新增残余风险，允许关闭任务

## 2. 有效做法

- 先把目标收敛到三个明确改进点：统一 provenance 字段、共享 reader、human-close 可见性，而不是继续扩大到 telemetry 设计。
- 用真正隔离的 verifier / evaluator subagent 重跑本轮 verification 和 evaluation，使这次改进本身也按新契约执行。
- 把 `harness-context.sh` 做成 human-close 的直接可见面，明显提升了 Baton 在 close 阶段的信息密度。

## 3. 失败点

- `validate-artifact.sh` 一开始仍只识别英文 `Inputs / Findings`，导致 evaluator 写出中文 artifact 后 live gate 被拦下，说明双语 schema 收敛还不够彻底。
- `check-consistency.sh` 的旧 invariant 仍在检查上一版 section 名，说明 invariants 也会滞后于 schema 演化。

## 4. 仓库特定经验

- 只要 Baton 同时支持中英文 artifact，schema validator 就必须把语言支持视为核心契约的一部分，而不是展示层细节。
- human close 之前真正有价值的不是“artifact 在不在”，而是 verifier / evaluator 的 provenance 和 verdict 能不能直接看见。
- provenance 一旦成为协议字段，就应该有 shared reader；否则 validator、status surface、tests 会再次分叉。

## 5. Harness 经验

- independent-judgment artifact 最终需要两层约束：模板固定写法 + bootstrap shared reader。
- `strict` / `compat` 之外，还需要把 `Role / Isolation mode / Execution context / Evidence / Fallback policy / Fallback reason` 固定成通用 block，后续再扩 artifact 时成本会低很多。
- human close 的 quality bar 应该是“无需打开多个文件也能判断是否可信”，这次增强后的 SessionStart surface 就更接近这个目标。

## 6. 可标准化候选

- 给后续所有 independent-judgment artifact 继续复用同一个 `Execution Provenance` block，不再引入新名字。
- 把 “schema 改动必须同步 validator / shared reader / reset / tests / consistency invariant” 固化成 Baton 的默认改动规则。
- 如果以后接 telemetry，就在当前 shared provenance block 上追加 runtime evidence，而不是重新设计另一套字段。
