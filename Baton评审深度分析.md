# Baton Harness 评审深度分析

**问题**：这份评审中的哪些论断经过代码库验证是正确的、错误的或不完整的？
**深度**：深度分析 — 多文件交叉验证，并追踪功能层面的后果
**核心结论**：5 个主要论断中有 4 个方向正确，但评审最重要的两个证据点（Schema 漂移的严重性、重复风险）各自在最关键处出现了偏差。

---

## 总览

评审围绕五个方面展开：

| 论断 | 评审结论 | 本文结论 |
|------|---------|---------|
| module-status Schema 漂移（Eval Round 列） | P0 协议错误 | ✅ 属实，但机制和严重程度判断有误 |
| 角色命名三套标准并存 | 协议漂移 | ✅ 属实，且比描述的更严重——实为功能性 Bug |
| .agents/ ↔ .claude/skills/ 重复 | 维护定时炸弹 | ❌ 错误——单一真源已存在，评审漏看了 |
| 协议从硬约束退回软约束 | 战略取舍 | ✅ 可观测，且符合设计意图 |
| cli-adapter-interface 定义了运行时接口但无对应实现 | 规范超前于实现 | ✅ 正确，且这是有意为之 |

---

## 发现一：module-status Schema 漂移——属实，但机制不同

**评审论断**：`module-status.template.md` 有 `Eval Round` 列，`start-task.sh` 不写这一列，`harness-evaluator.md` 引用了它——Schema 已破坏，协议状态不可判定。

**验证结果**：

- ✅ `spec/templates/module-status.template.md:3` — `| Scope | Owner | State | Eval Round | Updated At | Notes |`（6 列）
- ✅ `spec/bootstrap/start-task.sh:258-259` — 输出 `| Scope | Owner | State | Updated At | Notes |`（5 列）
- ✅ `spec/bootstrap/start-task.sh:144` — 通过匹配 `| Scope | Owner | State | Updated At | Notes |`（5 列）来解析现有文件
- ✅ `.claude/skills/harness-evaluator.md:137` — "在 `module-status.md` 中递增 `eval_round`"
- ✅ `spec/bootstrap/init-harness.sh:241` — 直接复制模板；`init-harness.sh:277-283` 带 `--task-id` 时用 `sed` 替换模板变量——两种情况均输出 6 列

**评审判断有误之处**：评审说这让协议"不可判定"。实际影响是具体而有限的：

1. `init-harness.sh` **不带** `--task-id` 运行时（最常见路径），直接复制模板原文。`start-task.sh` 随后读取文件，在第 144 行匹配 6 列 Header 失败（`in_table` 永远不会置为 `true`），但唯一存在的行是 `<task-id>` 占位符，本来也会被跳过。最终结果：脚本正常执行，将文件重写为 5 列。这个不匹配在首次使用时会无声地自我修复。

2. `init-harness.sh` **带** `--task-id` 运行时，会创建一个含有真实任务行的 6 列文件。若此后运行 `start-task.sh`，它无法解析该行（Header 不匹配），`open_rows` 保持为空。**"同一工作区只允许一个活跃任务"的安全守卫被无声绕过。这才是真正的 P0**：不是"状态不可判定"，而是安全约束可被规避。

3. `eval_round` 列存在于模板中，但 `start-task.sh` 从不写入它。Evaluator skill 要求递增该值——但在第一次 `start-task.sh` 运行之后，文件里根本不存在这一列。这是第二个独立的 Schema 缺口，评审将两者混为一谈。

**小结**：Schema 漂移属实。评审找对了文件，严重程度判断也大致正确，但机制不同——这是一个**安全绕过漏洞**，而不是"不可判定"问题。

---

## 发现二：角色命名不一致——属实，且比描述更严重

**评审论断**：同一角色有三个名字：`verification-explorer`（协议层）、`owner verifier`（harness-architect.md）、`harness-verifier`（README/skill 文件名）。

**验证结果**：

- ✅ `spec/protocol/state-machine.md:44` — 规范名：`verification-explorer`
- ✅ `spec/protocol/role-contracts.md:63` — 章节标题：`Verification Explorer`
- ✅ `spec/bootstrap/start-task.sh:31,100` — owner 白名单包含 `verification-explorer`，**不包含** `verifier`
- ✅ `.claude/skills/harness-architect.md:116,143-144` — "将 `module-status.md` 更新为 state `verification_check`，owner `verifier`"
- ✅ 根目录 `README.md` — 闭环流程使用展示名 `Verifier`，技能列表使用文件名 `harness-verifier`

**评审判断有误之处**："owner verifier" 是评审的转述——原文只是 `verifier`。评审将其定性为词汇问题，但这实际上是一个**功能性 Bug**：

`start-task.sh:100` 的白名单：
```
repo-explorer|scoped-explorer|specifier|architect|verification-explorer|generator|reviewer|evaluator|human
```

`verifier` **不在白名单中**。如果 AI 按照 Architect skill 的指令写入 `owner verifier`，之后有人执行 `start-task.sh --owner verifier`，脚本会直接报错 "Unsupported owner" 并退出。

根目录 README 也加剧了混乱：闭环摘要用 "Verifier"，但协议规范名是 `verification-explorer`，且没有任何地方说明两者的映射关系。

**评审漏掉了这个功能性后果。** 命名问题不只是词汇漂移——它会导致写入一个被 bootstrap 脚本验证层直接拒绝的值。

---

## 发现三：.agents/ 与 .claude/skills/ 重复——评审判断错误

**评审论断**：`.agents/harness-architect.md` 和 `.claude/skills/harness-architect.md` 内容"高度重复"，维护成本会指数上升，需要单一真源 + 生成机制。

**验证结果**：

- ✅ 所有 8 个 skill 文件在 `.agents/` 和 `.claude/skills/` 之间完全一致（逐字节相同）
- ✅ `skills/` 目录包含相同的 8 个文件——这就是**评审声称缺失的单一真源**
- ✅ `spec/bootstrap/link-skills.sh` — 以优先级顺序（symlink → hardlink → copy）将 `skills/` 中的文件链接到 `.agents/` 和 `.claude/skills/` 两处，并写入 `.link-mode`
- ✅ `spec/bootstrap/sync-skills.sh` — 仅在 copy 模式下使用，从 `skills/` 重新同步
- ✅ `skills/.link-mode` 内容为 `symlink`——链接机制已运行

评审说"没有生成机制"——这一说法被 `link-skills.sh` 和 `sync-skills.sh` 直接推翻。单一真源（`skills/`）和生成机制都已存在。

**有一点值得注意**：当前 `.agents/` 和 `.claude/skills/` 中的文件**实际上不是符号链接**（通过 `readlink` 验证——它们是普通文件，inode 各不相同）。`.link-mode` 显示 `symlink`，说明 `link-skills.sh` 曾在本地创建了符号链接，但随后被 git commit 将其解析为普通文件内容——这是 git 在提交符号链接时的常见行为。因此，在全新克隆之后，需要重新运行 `link-skills.sh`，文件修改才能自动传播。

**最终结论**：评审的担忧找错了方向。架构上已经有了它声称缺失的东西。真正的缺口更小：`link-skills.sh` 没有在 Quick Start 中被明确说明，导致用户克隆后会持有普通文件副本而非链接。

---

## 发现四：协议从硬约束退回软约束——可观测，且是有意为之

**评审论断**：相比早期 Baton（write-lock、BATON:GO），当前 master 是协议优先而非执行力优先。这是合理的取舍，但带来了"战略执行力回退"。

**可在当前代码库中验证的内容**：

- ✅ `spec/README.md` 设计原则第 1 条："协议为主，具体 agent CLI 只是执行层适配器。"
- ✅ `spec/README.md` 设计原则第 3 条："多 agent 执行是首选，而非必需。顺序执行的降级方案必须同样有效。"
- ✅ 当前规范中不存在任何 write-lock 机制
- ✅ `cli-adapter-interface.md:95-96`："适配器不得修改：规范状态、必需关卡、必需工件、显式 blocker 的要求"

从硬约束到协议约束的转变是明确且有文档记录的。`spec/README.md` 将可移植性定为一等目标——这在架构上与依赖特定运行时的文件系统级锁是不兼容的。

评审正确观察到了这个取舍，但将其定性为"回退"。更准确的理解是：这是一次有意的范围变更——从"在文件系统层面拦截 agent 越权"到"定义正确行为规范，让任意适配器来执行"。两种定性都有其合理性，取决于用户的目标。

---

## 发现五：cli-adapter-interface 超前于实际运行时——正确，且是有意为之

**评审论断**：`cli-adapter-interface.md` 定义了 `update_status(task, owner, state, notes)`，但实际运行时只有 bootstrap 脚本加手动更新。

**验证结果**：

- ✅ `spec/adapters/cli-adapter-interface.md:36` — `update_status(task, owner, state, notes)` 列在"必需能力"中
- ✅ `spec/protocol/role-contracts.md:141` — "本地仓库可能存在辅助脚本，但协议不要求普通状态转换必须有脚本支持。"
- ✅ `spec/README.md:126-127` — "让当前 owner agent 更新 `module-status.md`"

这是有意为之的设计。接口定义的是适配器必须满足的**能力契约**，而非某个具体的库调用。在 Claude Code 中，`update_artifact` 映射到 Edit 工具，`update_status` 映射到 agent 直接编辑 `module-status.md`。评审将此定性为"规范超前于运行时"，但 `spec/README.md` 已明确声明"本规范不定义调度器实现"，也"不要求子 agent 支持"。

---

## 评审遗漏的内容

**1. 白名单 Bug 才是真正的一致性问题**

评审讨论了命名漂移。可操作的发现是：`verifier`（由 Architect skill 写入）会被 `start-task.sh` 的 owner 验证拒绝。如果有人在 verification 阶段转换后使用 `start-task.sh`，这会直接触发运行时错误。

**2. Schema 不匹配导致的安全绕过**

`start-task.sh` 中"每个工作区只允许一个活跃任务"的约束，在使用 `init-harness --task-id` 时可被无声绕过。这在操作层面比评审所说的"状态不可判定"更危险。

**3. 链接机制已存在且基本有效**

评审最大的结构性论断——"多平台发布缺少单一真源 + 生成机制"——是错的。`skills/` 就是单一真源，`link-skills.sh` 就是生成机制。这一错误大大削弱了维护成本的风险预测。

**4. 规范有意不定义运行时调度器**

`spec/README.md:133-137` 明确列出了非目标。评审将"没有运行时辅助工具"视为缺口，实际上是对范围边界的误读。

---

## 评审在架构层面的正确判断

尽管在机制细节上有误，评审的架构性判断是准确的：

- **协议层成熟，运行时加固尚未完成** — 正确。Schema 漂移和白名单 Bug 正是那个"加固"缺口。
- **Extension overlay 设计思路正确** — `java-backend-strict` 作为核心协议之上的严格覆盖层，分层方式合理。
- **可移植优先的设计牺牲了部分执行约束面** — 经设计原则验证，属实。
- **"协议项目而非产品"的定性** — 与 `spec/README.md` 的明确设计意图一致。

---

## 优先级行动清单

| 优先级 | 问题 | 修复位置 |
|--------|------|---------|
| P1 | `harness-architect.md` 状态转换写 `owner verifier`，不在 start-task.sh 白名单中 | `skills/harness-architect.md:116,143` → 改为 `verification-explorer` |
| P1 | `start-task.sh` 无法解析 `init-harness --task-id` 输出（6 列 Header 不匹配），无声绕过活跃任务安全检查 | `spec/bootstrap/start-task.sh:144,153,163,251,258-259` → 支持 Eval Round 列 |
| P2 | `harness-evaluator.md` 引用 `eval_round` 列，但 start-task.sh 从不写入该列 | 从模板中移除 eval_round，或在 start-task.sh 的输出格式中添加该列 |
| P2 | `link-skills.sh` 未在 Quick Start 中说明——克隆后用户持有的是副本而非链接 | 在 `README.md` Quick Start 章节中补充说明 |
| P3 | 根目录 README 闭环用 `Verifier`，协议用 `Verification Explorer`——需显式记录映射关系 | 在 README 或 spec/README 中添加词汇说明 |

---

## 来源审计

| 论断 | 来源 | 获取方式 |
|------|------|---------|
| 模板有 Eval Round（6 列） | `spec/templates/module-status.template.md:3` | 本次会话读取 |
| start-task.sh 写 5 列 Header | `spec/bootstrap/start-task.sh:258-259` | 本次会话读取 |
| start-task.sh 只解析 5 列 Header | `spec/bootstrap/start-task.sh:144,153,163` | 本次会话读取 |
| harness-evaluator 引用 eval_round | `.claude/skills/harness-evaluator.md:137` | 本次会话读取 |
| init-harness 直接复制模板 | `spec/bootstrap/init-harness.sh:241` | 本次会话读取 |
| verifier 不在 start-task.sh 白名单 | `spec/bootstrap/start-task.sh:100` | 本次会话读取 |
| harness-architect 使用 owner `verifier` | `.claude/skills/harness-architect.md:116,143` | 本次会话读取 |
| skills/ 是单一真源 | `skills/harness-architect.md` + `sync-skills.sh:8` | 本次会话读取 |
| link-skills.sh 创建符号链接/硬链接 | `spec/bootstrap/link-skills.sh` | 本次会话读取 |
| .link-mode = symlink | `skills/.link-mode` | 本次会话 Bash 执行 |
| .agents/ 文件实际上不是符号链接 | `readlink` 输出 | 本次会话 Bash 执行 |
| 所有 8 对 skill 文件逐字节相同 | `diff` 输出 | 本次会话 Bash 执行 |

**最弱的结论**：我没有验证 git 历史来确认"write-lock 回退"的说法——这需要对早期 Baton 提交进行 `git log` 考古。当前代码库的证据与评审的论断一致，但我将其标记为 `❓ 未经历史验证`。
