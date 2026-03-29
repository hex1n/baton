# Retrospective: workflow-best-practice-doc

## 1. 结果

- 关闭状态: `complete`
- 主要阻塞: 无 substantive blocker；唯一返工点是第一次 verifier 输出用了自由格式，没有对齐 `verification-path.md` 的现有 schema，需要重写成标准章节结构。
- 人工决策: human 接受“默认走 Core Flow；高风险任务再升级到 Strict Overlay”这一最佳实践结论。

## 2. 有效做法

- 先用 `baton-positioning.md` 锁上位边界，再写 workflow best practice，避免把流程文档写成脱离产品定位的孤立建议。
- 把用户给出的重流程拆成“保留哪些控制点、调整哪些角色定义、哪些内容只属于 overlay”，比简单附和或简单否定都更稳。
- 继续让 verifier / evaluator 以隔离 agent 方式冷读文档任务，能有效防止主线程把自己的 workflow 偏好直接包装成已验证结论。

## 3. 失败点

- 文档型 verifier 很容易写成“内容总结”而不是 Baton 要求的标准验证工件，说明当前 skill 或模板提示还不够强。
- 这类任务目前主要靠关键术语检索和独立 judgment 通过，缺少更结构化的 doc-quality 断言。

## 4. 仓库特定经验

- current core artifact schema 依然是轻量闭环，文档里把 `codebase-map.md`、`decisions.md`、`api-contract.yaml`、`schema-draft.sql` 收进 strict overlay，而不是 core 默认项，是必要的。
- `java-backend-strict` 已经足够提供 overlay 边界来源，因此最佳实践文档更适合做“使用层解释”，不应该去重写 extension 本体。

## 5. Harness 经验

- 即使是最佳实践或定位类文档，只要走 `strict` 路径，Verifier 和 Evaluator 依然应保持隔离；否则 human close 前的“独立判断”会失真。
- 对文档任务来说，`blocked`、`repair loop`、`human close` 同样有意义，因为这里的对象不是代码正确性，而是流程定义是否会误导后续执行。

## 6. 可标准化候选

- 给文档型 verifier 增加更强的模板提示，明确“必须输出标准 schema，不允许自由格式总结”。
- 为 workflow / positioning 文档补一组轻量内容断言模式，例如“必须出现 core/overlay 边界、必须说明 Verifier 位置、必须说明 human gate”。
- 后续可考虑把 `baton-positioning.md` 与 `baton-workflow-best-practice.md` 放进统一的 `docs/foundations/` 或类似目录，降低长期漂移风险。
