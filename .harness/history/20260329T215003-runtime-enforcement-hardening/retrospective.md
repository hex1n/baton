# Retrospective: runtime-enforcement-hardening

## 1. 结果

- 关闭状态: complete
- 主要阻塞: 评审阶段先后暴露了两个真实问题：`human_ack` 清理范围过宽，以及 `verification-path.md` 中原始 ShellCheck 命令与验收语义不一致
- 人工决策: 人类批准了架构方案，并明确要求使用隔离子 agent 完成 strict verification / evaluation

## 2. 有效做法

- 先把 hook runtime 从宿主 JSON 内联命令抽成独立脚本，再在脚本层补 enforcement gap，显著降低了测试和调试成本
- 用隔离 verifier / evaluator 复跑 Gate 3 和 Gate 4，确实抓出了主线程容易忽略的契约问题
- 在生成阶段并行拆分 runtime、tests、templates/skills 三条写面，明显缩短了集成时间

## 3. 失败点

- 初版 `post-artifact.sh` 只按写后状态判断是否清理 `human_ack`，没有保存真实转移来源，导致清理范围过宽
- 初版 `verification-path.md` 把 `shellcheck` 原始命令写得过宽，没有对齐 AC-17 的 error-level 语义

## 4. 仓库特定经验

- Baton 的 harness 任务在这个仓库里已经高度依赖 `.harness` 控制面和 bootstrap 脚本耦合，任何 runtime hardening 都必须同步更新 tests 和 consistency invariants
- Bash 版本兼容性要保守处理，像 `mapfile` 这类较新的内建不适合作为默认实现前提

## 5. Harness 经验

- `human_ack` 这类 advisory gate 只有在“前置 hook 记录转移意图 + 后置 hook 精确消费”的组合下才可靠，不能只看最终状态
- verification-path 里的“精确命令”必须真的能被 evaluator 原样重跑通过，否则 Gate 4 会把 Gate 3 重新打回

## 6. 可标准化候选

- 为 hook 间短生命周期状态传递沉淀一个共享 cache 约定，而不是在单个脚本里各自实现
- 把 `shellcheck -S error` 固化为 runtime hardening 类任务的标准验证命令模板
- 为 `post-artifact` / `pre-transition` 这种成对 hook 增加更明确的 repo-level test fixture 约定
