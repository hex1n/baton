# Requirements: protocol-consistency-fix

**Topic**: Baton Harness 跨层协议一致性修复
**Status**: `approved`
**Sizing**: `Small`

## 1. Problem

Baton Harness 的四个协议层（templates / bootstrap scripts / role skills / README）各自维护对"合法 owner token"和"module-status 列结构"的理解，且这些理解之间存在冲突：

1. `harness-architect.md` 状态转换指令写 `owner verifier`，但 `start-task.sh` 的 owner 白名单只含 `verification-explorer`，导致按 skill 指令操作产生被脚本拒绝的值。
2. `module-status.template.md` 定义 6 列（含 Eval Round），但 `start-task.sh` 只能解析和写出 5 列，导致以 `init-harness.sh` 初始化的文件无法被 `start-task.sh` 正确解析，"一个活跃任务"安全守卫可被无声绕过。
3. `harness-evaluator.md` 要求在 BLOCKED 时递增 `eval_round` 表格列，但该列在 `start-task.sh` 生成的文件中不存在，指令无处落地。
4. `README.md` Quick Start 缺少 `link-skills.sh` 步骤，克隆后的用户无法建立 symlink，修改 `skills/` 后变更不会自动传播。
5. README 闭环图展示名（`Verifier`）与运行时 token（`verification-explorer`）之间无文档映射，造成使用混淆。

## 2. Scope

### 2.1 In Scope

- `skills/harness-architect.md` — 将状态转换中的 owner token 由 `verifier` 改为 `verification-explorer`
- `spec/bootstrap/start-task.sh` — owner 白名单改为从 `owners.txt` 读取（D2）；schema 无需变更（已是 5 列）
- `spec/bootstrap/start-task.ps1` — `ValidateSet` 改为运行时从 `owners.txt` 读取验证（D2）；schema 无需变更（已是 5 列）
- `skills/harness-evaluator.md` — 将 `eval_round` 引用从表格列改为 State Notes 自由文本
- `README.md` — 新增 `link-skills.sh` Quick Start 步骤；新增闭环图展示名与运行时 token 的映射说明
- `spec/bootstrap/check-consistency.sh` — 新建，检测三条跨层不变量

### 2.2 Out of Scope

- `spec/protocol/` 规范文档（不修改规范本身）
- 其他 role skill 文件
- `spec/templates/module-status.template.md`（需修改：删除 Eval Round 列，改为 5 列）【D1 决策：彻底删除 Eval Round】
- 存量使用 5 列 module-status.md 的外部 repo 的向后兼容【已确认：Q1-B，不考虑存量用户】

## 3. Functional Requirements

### FR-1 owner token 一致性

`harness-architect.md` 中所有状态转换指令写入的 owner token，必须与 `start-task.sh` owner 白名单中的值完全一致。

- 输入：AI agent 执行 harness-architect skill 后产出的 module-status.md 更新
- 输出：写入的 owner 值可被 start-task.sh 验证通过
- 例外：无（白名单是 script-level 硬约束）

### FR-2 module-status schema 一致性

`module-status.template.md` 必须修改为 5 列格式（删除 Eval Round 列）：`| Scope | Owner | State | Updated At | Notes |`。`start-task.sh` 和 `start-task.ps1` 已是 5 列，无需 schema 变更。【D1 决策：彻底删除 Eval Round 列】

- 输入：以 `init-harness.sh`（任意参数）初始化的 module-status.md
- 输出：模板与脚本输出一致，均为 5 列；`start-task.sh` 能正确解析、检测 open tasks、并写出 5 列格式
- 例外：旧格式不支持【已确认：Q1-B】

### FR-3 eval_round 可写性

`harness-evaluator.md` 对 eval_round 的引用，必须指向 module-status.md 中实际存在且可写的位置。

- 输入：evaluator 在 BLOCKED 轮次执行状态转换
- 输出：State Notes 节中存在 `Current eval round: N` 形式的可递增记录
- 例外：首轮 BLOCKED 从 round 1 开始

### FR-4 link-skills.sh 发行链文档

README Quick Start 必须包含 `link-skills.sh` 的使用说明，使克隆后的开发者知道如何建立 `skills/` 到分发目录的链接。

- 输入：用户完成 git clone 后阅读 README
- 输出：能按文档步骤运行 link-skills.sh，使 skills/ 修改自动传播
- 例外：仅限在 baton repo 本身开发的用户，非 harness 采用者

### FR-5 角色名映射说明

README 闭环图展示名与运行时 token 之间的对应关系必须在文档中可查。

- 输入：用户阅读 README 后查看 start-task.sh --help
- 输出：能通过 README 注释了解 Verifier = verification-explorer 等映射关系
- 例外：无

### FR-6 跨层一致性可检测

新建 `check-consistency.sh` 脚本，检测三条不变量：
1. skills/ 中使用的 owner token 均在 `spec/protocol/owners.txt` 中（D2 单一真源）
2. start-task.sh 写出的 Header 与 module-status.template.md Header 一致（均为 5 列）
3. skills/ 文件与 .claude/skills/ 和 .agents/ 内容一致

- 输入：运行 `bash spec/bootstrap/check-consistency.sh`
- 输出：全部通过时输出 OK 并 exit 0；任意不一致时输出具体错误并 exit 1
- 例外：.claude/skills/ 或 .agents/ 中文件不存在时报错（不静默跳过）

## 4. Non-Goals

- 修改 spec/protocol/ 中的规范文档
- 统一展示名与运行时 token（两层命名是有意设计）
- 为存量 5 列 module-status.md 提供迁移路径
- 新增 CI/CD 集成（check-consistency.sh 作为独立脚本提供，不强制 hook）
- 修改除 harness-architect.md 以外的其他 skill 的 owner token

## 5. Acceptance Criteria

### AC-1 owner token 一致性

- [ ] 当 `grep "owner \`" skills/harness-architect.md` 时，所有结果均为 `verification-explorer`，不含 `verifier`
- [ ] 当以 `start-task.sh --owner verification-explorer` 运行时，脚本正常执行不报错
- [ ] 当以 `start-task.sh --owner verifier` 运行时，脚本报错 "Unsupported owner" 并 exit 1（白名单已不含 verifier，此处为回归保证）

### AC-2 module-status 5 列格式（D1：Eval Round 彻底删除）

- [ ] `spec/templates/module-status.template.md` Header 为 `| Scope | Owner | State | Updated At | Notes |`（已删除 Eval Round 列）
- [ ] 当 `start-task.sh` 运行后，生成的 `.harness/module-status.md` Header 为 `| Scope | Owner | State | Updated At | Notes |`（与模板一致）
- [ ] 当以 `init-harness.sh` 初始化后再运行 `start-task.sh --task-id foo` 时，命令正常完成（exit 0），文件中存在 foo 任务行
- [ ] 当存在未 complete 的任务行时，`start-task.sh` 拒绝创建新任务（安全守卫有效）

### AC-3 eval_round 可写

- [ ] 当 `grep "eval_round" skills/harness-evaluator.md` 时，结果描述的是 State Notes 更新，而非表格列操作
- [ ] `harness-evaluator.md` 中包含 `Current eval round:` 字样的格式示例或指令

### AC-4 link-skills.sh 文档

- [ ] `README.md` 中存在 `link-skills.sh` 的使用说明，含命令示例
- [ ] 说明中描述了"克隆后文件为副本，运行此脚本升级为 symlink"的语义

### AC-5 角色名映射

- [ ] `README.md` 闭环图下方存在展示名到运行时 token 的映射说明
- [ ] 映射说明中至少包含 `Verifier` → `verification-explorer` 的对应关系

### AC-6 check-consistency.sh

- [ ] `spec/bootstrap/check-consistency.sh` 文件存在且可执行
- [ ] 修复前（当前状态），脚本运行输出至少 1 个 ERROR 并 exit 1
- [ ] 修复后（所有 P1/P2 完成后），脚本运行输出 "all invariants OK" 并 exit 0
- [ ] 当 `skills/harness-architect.md` 含 `owner \`verifier\`` 时，脚本报告该错误

## 6. Constraints

- `spec/bootstrap/start-task.sh` 和 `start-task.ps1` owner 白名单逻辑必须同步修改（D2），保持跨平台一致
- `skills/` 是 skill 修改的唯一写入位置；修改后若为 copy 模式需运行 `sync-skills.sh`
- `check-consistency.sh` 只依赖 bash 和标准 POSIX 工具（grep, cmp, awk），不引入外部依赖
- `module-status.template.md` 需修改为 5 列（删除 Eval Round 列，D1 决策）

## 7. Validation Intent

- **FR-1/AC-1**：grep 验证 skill 文件，手动或脚本运行 start-task.sh 验证白名单
- **FR-2/AC-2**：运行 `init-harness.sh` 后执行 `start-task.sh --dry-run`，检查输出 Header；再全量运行检查生成文件内容
- **FR-3/AC-3**：grep 验证 evaluator skill 文件
- **FR-4/AC-4**：grep 验证 README.md 含 `link-skills.sh` 字样及说明
- **FR-5/AC-5**：grep 验证 README.md 含映射说明
- **FR-6/AC-6**：在修复前运行 check-consistency.sh 确认报错；修复后运行确认全部通过
