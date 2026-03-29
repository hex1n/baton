# Retrospective: positioning-protocol-vs-runtime

## 1. 结果

- 关闭状态: `complete`
- 主要阻塞: 无实现层阻塞；唯一小问题是 `evaluation.md` 的 `Fallback policy` 不能写成 `none`，需要按当前 validator 约定写成具体策略句。
- 人工决策: human 接受“Baton 应保持 protocol-first，并维护本地 reference runtime，而不是立刻转成 full runtime product”这一定位结论。

## 2. 有效做法

- 先用 `.harness/requirements.md` 和 `.harness/architecture.md` 把“定位判断”收成可验收的问题，而不是直接写观点文。
- 把 Anthropic 文章的启发与 Baton 的产品形态拆开表述，避免出现“灵感来自 runtime，所以产品就必须做 runtime”这种错误跳跃。
- 在文档里明确三层边界：`protocol core`、`reference runtime`、`future runtime product`，比单纯回答“做 protocol 还是 runtime”更有后续指导意义。
- 继续用隔离 verifier / evaluator 跑文档任务，能防止主会话把自己的推理直接当成已验证结论。

## 3. 失败点

- 当前 validator 对 provenance 的要求比模板字面更严格，`Fallback policy` 如果写成 `none` 会在 live 校验阶段才暴露出来。
- 文档任务没有自动化的内容级断言，仍主要依赖 `rg` 关键句命中和独立 evaluator judgment。

## 4. 仓库特定经验

- Baton 现有 README 已经足够支撑“protocol-first”对外定位，所以这次更适合新增 `docs/baton-positioning.md` 做内部定位收敛，而不是直接改 README。
- `validate-isolation.sh` 对 shared provenance block 的约束已经足够硬，文档任务同样要老老实实满足。

## 5. Harness 经验

- 即使是纯文档任务，只要进入 `strict` 路径，Verifier 和 Evaluator 也应该继续走隔离 agent；否则 human close 前的“独立判断”会退化成主线程自证。
- human gate 很适合收口这类战略判断，因为“是否接受这份定位”本来就是产品层决策，不应该被 runtime 自动化替代。

## 6. 可标准化候选

- 给文档型任务补一组轻量内容断言约定，例如“必须包含的结论句 / 边界标题 / 外部来源链接”，减少 evaluator 只靠自由判断。
- 把 `Fallback policy` 的非空约束直接写进模板提示语，避免 live validator 才暴露格式问题。
- 后续可以增加一份 `docs/roadmaps/` 或 `docs/positioning/` 目录约定，把这类长期有效的定位文档与一次性分析文档分开。
