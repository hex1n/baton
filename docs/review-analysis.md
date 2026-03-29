# Baton 评审分析

**问题**：如何评估一份针对 Baton 协议层、工件层、bootstrap/runtime、分发层与 Java strict extension 的深度评审？
**结论**：这份评审的战略判断基本正确。Baton 的确已经进入“协议收敛与运行时硬化”阶段。但它低估了仓库里已经存在的 enforcement/runtime 基础设施，同时漏掉了一个更紧急的控制平面一致性问题：`module-status.md` 的读写约定已经发生真实漂移。

---

## 一、总判断

这份评审最重要的结论是成立的：

- Baton 已经不是“AI coding workflow 文档集合”，而是一个 protocol-first 的工程项目。
- 下一阶段的重点不应继续扩角色和流程概念，而应放在协议收敛、校验器、分发同步和最小 enforcement runtime。
- `Verification before generation` 仍然是 Baton 最有壁垒的核心结构。

但更精确的说法应该是：

> Baton 现在不是“只有 bootstrap、没有 runtime”，而是“已经有一层最小 enforcement runtime，但 control-plane 约定尚未完全锁死”。

---

## 二、评审判断准确的部分

### 1. 协议优先的产品边界是成立的

仓库当前结构已经把 protocol、templates、adapters、profiles、extensions、bootstrap 分层，且把宿主 CLI 明确定义为执行适配器而不是方法论本体。`spec/README.md` 的目录说明和设计原则已经非常清楚。

### 2. Verification before generation 是核心价值，不是附属动作

根治理模板和协议 gates 都把验证路径检查放在生成前：

- `spec/templates/root-governance.template.md`
- `spec/protocol/gates.md`

这说明 Baton 的中心不是“更会 plan”，而是“没有可验证路径就不允许开始生成”。

### 3. 分发层走向单源同步是正确方向

根治理入口已经通过模板物化，而不是手改：

- `spec/templates/root-governance.template.md`
- `spec/bootstrap/sync-governance-entrypoints.sh`

README 双语也已经被明确为成对维护，并有独立检查脚本：

- `spec/bootstrap/check-root-readme-bilingual.sh`

### 4. Java strict extension 的边界是健康的

`spec/extensions/java-backend-strict/README.md` 明确采用“core 保持 portable，strict 作为 opt-in overlay”的设计。这避免了把 Java/Spring 的重验证逻辑反向污染 portable core。

---

## 三、评审低估的现有能力

这份评审最不准确的地方，是把 Baton 描述成“主要还停留在 bootstrap runtime”。这个表述已经偏旧。

### 1. 最小 enforcement runtime 已经存在

仓库里已经有三类运行时校验脚本：

- 状态迁移校验：`spec/bootstrap/validate-transition.sh`
- artifact 章节校验：`spec/bootstrap/validate-artifact.sh`
- state 对应 artifact 校验：`spec/bootstrap/validate-state-artifacts.sh`

这些不是单纯文档，而是实际脚本。

### 2. 安装器已经把 enforcement 接到了宿主运行时

`spec/bootstrap/install-harness.sh` 在安装末尾调用 `install-hooks.sh`，后者会把以下检查注册进 Claude Code / Codex hooks：

- 写 `.harness/*.md` 后做 artifact 校验
- 写 `module-status.md` 前做状态迁移校验
- 会话结束时做 state-artifact 一致性校验
- verifier / evaluator 子代理结束时做额外检查

对应文件：

- `spec/bootstrap/install-harness.sh`
- `spec/bootstrap/install-hooks.sh`
- `.claude/settings.json`
- `.codex/hooks.json`

因此，更准确的表述是：

> Baton 已经有 runtime validator 和 hook integration，但 enforcement 仍然偏薄，尤其在读取约定、迁移兼容和 live control-plane 校验上还不够稳。

### 3. 分发一致性比评审描述得更强

当前仓库已有真实的分发和一致性约束：

- `skills/` 是 canonical source
- `.claude/skills/`、`.agents/` 有一致性检查
- `.claude/agents/` 的 `context: fork` skill 也有检查
- runtime symlink 目标必须是 repo-relative
- root governance 与双语 README 都有 drift check

统一检查入口：

- `spec/bootstrap/check-consistency.sh`

我在本次会话里实际运行了它，当前结果是全绿。

---

## 四、评审漏掉的更关键问题

真正更紧急的问题，不是“Markdown table 会不会将来不够用”，而是：

> 当前 `module-status.md` 已经出现 schema 漂移，而且多个 runtime reader 对“当前任务是哪一行”的理解并不一致。

### 1. live `module-status.md` 还是旧 schema

当前仓库中的 live 文件：

- `.harness/module-status.md`

它的表头仍是：

```text
| Scope | Owner | State | Updated At | Notes |
```

而模板已经升级为：

```text
| Scope | Owner | State | Eval Round | Updated At | Notes |
```

对应文件：

- `.harness/module-status.md`
- `spec/templates/module-status.template.md`

### 2. `start-task.sh` 只识别新表头

`spec/bootstrap/start-task.sh` 在解析任务表时，只在看到带 `Eval Round` 的新表头后才进入表格读取逻辑。

这意味着：如果对当前仓库直接运行下一次 `start-task`，旧历史行不会被识别，存在历史表内容被错误重写的风险。

### 3. 多个 runtime reader 都在读取“第一条任务行”

更严重的是，以下脚本都用 `awk ... exit` 读取第一条任务行作为当前任务：

- `spec/bootstrap/harness-context.sh`
- `spec/bootstrap/validate-state-artifacts.sh`
- `spec/bootstrap/install-hooks.sh` 中的 PreToolUse / Stop / SubagentStop 逻辑

但 `start-task.sh` 的写法是把新任务追加在表尾，而不是置顶。

这会导致一个结构性问题：

- 写入侧默认“最后一行是最新任务”
- 读取侧却默认“第一行是当前任务”

一旦有多条历史任务，hook 和 session context 读取到的就可能不是当前任务，而是最旧任务。

### 4. 现有 consistency check 没覆盖 live control-plane

`spec/bootstrap/check-consistency.sh` 当前只校验：

- 模板表头与 `start-task.sh` 输出表头一致
- spec 内部词表和分发副本一致

它并不校验：

- live `.harness/module-status.md` 是否已迁移到当前 schema
- 当前 active row 是否可被统一识别
- 是否最多只有一个 non-complete row

所以当前“check 全绿”并不代表 control-plane 已经完全自洽。

---

## 五、对优先级的修正

这份评审建议先做“schema 单一真源 + 校验器 + 分发同步 + 最小 enforcement runtime”，方向没错，但优先级还可以再收紧。

### P0：先修 `module-status` 控制平面

最先该做的不是继续抽象 schema，而是统一控制平面约定：

1. 定义“当前活动任务行”的唯一规则
2. 统一 `start-task`、hooks、`harness-context`、`validate-state-artifacts`、status skill 的读取逻辑
3. 为旧 `module-status.md` 提供 migration path
4. 把 live control-plane 校验纳入 `check-consistency.sh`

### P1：再扩大 schema 单源

在修好控制平面之后，再把以下内容继续纳入单源：

- artifact required sections
- gate 定义
- module-status 列定义
- bilingual README 关键结构
- skill frontmatter 关键字段

### P2：补强 strict extension 工具化

Java strict extension 的价值是真实存在的，但下一步更需要工具化，而不是继续扩文档：

- evaluator evidence collection
- module loop progress tracking
- runtime signal collection
- migration / escalation checkpoint check

---

## 六、最准确的现状定义

如果要给 Baton 当前状态一个最精确的定义，我会这样写：

> Baton 已经是一个成熟中的 protocol project，也已经有一层最小 enforcement runtime；但它还不是一个 fully hardened enforcement product。当前最急的缺口不是理念，而是 control-plane 读取契约、schema 迁移兼容和 live validator 覆盖面。

换句话说：

- 战略方向：对
- 分层方式：对
- enforcement 基础：已有
- 当前短板：控制平面尚未完全收敛

---

## 七、建议的下一步

最值得优先落地的是一个很具体的硬化任务：

**把 `module-status.md` 从“看起来是控制平面”升级成“所有 reader/writer 都按同一契约工作的控制平面”。**

如果这一步没有先收敛，后续再加更多字段、更多状态、更多 extension，只会放大漂移风险。

---

## 附：本次分析对应的关键证据文件

- `spec/README.md`
- `spec/protocol/gates.md`
- `spec/templates/root-governance.template.md`
- `spec/templates/module-status.template.md`
- `spec/bootstrap/start-task.sh`
- `spec/bootstrap/check-consistency.sh`
- `spec/bootstrap/validate-transition.sh`
- `spec/bootstrap/validate-artifact.sh`
- `spec/bootstrap/validate-state-artifacts.sh`
- `spec/bootstrap/install-hooks.sh`
- `spec/bootstrap/install-harness.sh`
- `spec/bootstrap/harness-context.sh`
- `.harness/module-status.md`
- `.claude/settings.json`
- `.codex/hooks.json`
- `spec/extensions/java-backend-strict/README.md`
