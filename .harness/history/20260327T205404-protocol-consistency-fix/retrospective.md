# 回顾：protocol-consistency-fix

## 1. 结果

- 关闭状态：complete（完成）
- 主要阻断：B-1 —— requirements.md FR-2（在 D1 决策前写成）要求 6 列格式；architecture.md D1（人工确认）要求 5 列。Verifier 以独立上下文正确识别了这一矛盾。解决方式：更新 requirements.md 以对齐已确认的 D1 决策。
- 人工决策：D1 = 彻底删除 Eval Round 列；D2 = 将 owner token 提取到 `owners.txt`；Q1 = 不考虑旧格式向后兼容；Q2 = eval_round 改写到 State Notes

## 2. 哪些做得好

- D1 带来的简化：彻底删除 Eval Round 后，模板自然对齐了 `start-task.sh` 已有的 5 列输出——P1-b 从原本需要 5 处脚本改动缩减为 1 处模板改动。
- D2 单一真源：将 owner 列表提取到 `owners.txt` 后，`check-consistency.sh` 有了真正的权威来源可以比对，而不是比较两个独立的硬编码定义。
- Verifier 上下文隔离：作为 `context: fork` 子 agent 派发，发现了同会话 Architect 阶段遗漏的 B-1 阻断。隔离机制发挥了作用。
- Evaluator 隔离：独立子 agent 对全部 AC 标准独立验证，无误判。
- D1 后 `check-consistency.sh` 不变量 2 自然可实现——模板与脚本输出的 Header 已天然收敛为相同的 5 列值，无需任何脚本 schema 改动。

## 3. 哪些出了问题

- requirements.md 在 D1/D2 决策确认前就已定稿，导致 Gate 3 出现 B-1 阻断。Specifier 应在写涉及 schema 值的验收标准前，先确认所有架构决策。
- Explorer、Specifier、Architect 三个角色均在同一会话上下文中运行（违反 `context: fork` 约定）。用户接受了这一已知偏差，要求从 Verifier 开始才执行隔离。
- `sync-skills.sh` 错误地报告"link-mode 为 symlink——编辑自动传播"，但 `.claude/skills/` 和 `.agents/` 中实际上是普通文件副本（git clone 解析了 symlink）。Generator 不得不自行检测并手动复制。sync 脚本的检测逻辑需要修订。
- `check-consistency.sh` 初稿中不变量 1 的 grep 模式过宽——会从匹配行中提取所有反引号 token（包括状态名、文件名），而非仅提取 owner token。通过收窄模式修复。

## 4. 仓库特定经验

- `start-task.sh` 本身已是正确的 5 列 schema，bug 只存在于模板（6 列）。在写需求前先核查脚本的实际输出，可以节省一轮迭代。
- `.link-mode` 文件写着 `symlink`，但 git clone 会将 symlink 解析为普通文件。`.link-mode` 反映的是预期模式，而非实际模式。任何依赖它来判断"无需同步"的工具，在新鲜 clone 的仓库中都会出错。
- `start-task.ps1` 中 `Join-Path $specRoot "protocol\owners.txt"` 在 PS Core 上因路径分隔符规范化可正常工作，但改用 `"protocol/owners.txt"` 跨平台语义更清晰。

## 5. Harness 协议经验

- Gate 2（架构批准）应同时确认 requirements.md 已更新以反映所有架构决策——而不仅仅是架构自身内部一致。B-1 模式（口头确认决策 → 写需求时未同步更新 → Verifier 发现矛盾）是可预测的失败路径。
- 建议在 Gate 2 增加一条检查项："requirements.md 已反映所有已确认的架构决策"，以防此类矛盾在 Gate 3 才被发现。
- `context: fork` 隔离在 Gate 3（Verifier）和 Gate 4（Evaluator）最有价值。对更早期的角色，当对话历史是主要工作上下文时，同会话执行是可接受的。

## 6. 可标准化的模式

- **`check-consistency.sh` 模式**：不变量检测（owner token 对比权威文件、Header 一致性、skill 副本同步）具有通用性。任何管理协议定义分布式副本的 harness 都可采用此模式。
- **`spec/protocol/owners.txt` 单一真源**：将机器可读的 token 列表提取到 `spec/protocol/` 可避免脚本、skill 和文档之间的多方同步。状态 token 同样适用（如 `states.txt`）。
- **Gate 2 需求更新检查项**：在 Gate 2 增加"requirements.md 已反映所有已确认的架构决策"这一检查项，可在 Gate 3 前截断 B-1 类矛盾。
