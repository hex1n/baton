# Requirements: governance-multi-host-entrypoints

**主题**: 根目录治理摘要多宿主入口标准化
**状态**: `approved`
**规模**: `Medium`

## 1. 问题

当前仓库和通过 bootstrap 初始化的目标仓库都把根级治理摘要押在 `CLAUDE.md` 上，这会导致在 Codex 等读取 `AGENTS.md` 的环境里，根目录治理规则无法自动生效。Cursor 虽然支持多种规则入口，但当前分发路径也没有显式物化一个通用、稳定的根级入口，因此“治理摘要存在”与“不同宿主实际能读取”之间存在断层。

## 2. 范围

### 2.1 范围内

- 建立一个共享的根级治理摘要真源
- 物化 `CLAUDE.md` 和 `AGENTS.md`
- 让 `init-harness` 为目标仓库生成上述入口
- 为 baton 仓库增加双入口一致性检查
- 更新相关文档和 adapter 说明

### 2.2 范围外

- 为 Cursor 设计复杂的 scoped `.cursor/rules` 规则集
- 为不同宿主写不同语义版本的治理规则
- 引入远程模板服务或包管理器式分发

## 3. 功能需求

### FR-1 共享治理真源

- 仓库必须有一个单一真源，用于生成根目录 agent instruction 入口
- `CLAUDE.md` 和 `AGENTS.md` 必须从该真源物化，不能长期手工独立维护

### FR-2 多宿主根级入口

- baton 仓库根目录必须同时存在 `CLAUDE.md` 与 `AGENTS.md`
- `init-harness` 在目标仓库 bootstrap 时，必须能够生成这两个文件，至少在文件缺失时自动创建

### FR-3 一致性检查

- 仓库必须提供脚本检查 `CLAUDE.md` 与 `AGENTS.md` 是否与共享真源保持一致
- `check-consistency.sh` 必须调用该检查

### FR-4 文档与适配器说明

- README 和 bootstrap/adapters 文档必须明确说明不同宿主读取哪个入口
- 文档必须明确说明 `AGENTS.md` 是给 Codex / Cursor 的根级通用入口，`CLAUDE.md` 继续服务 Claude Code

## 4. 非目标

- 不要求在本次任务内支持 Cursor 的高级 rule metadata
- 不要求自动合并已有自定义 `AGENTS.md` / `CLAUDE.md` 内容
- 不要求把所有 repo-specific rule 都抽象成模板系统

## 5. 验收标准

### AC-1 baton 根目录具备双入口

- 根目录存在 `CLAUDE.md` 和 `AGENTS.md`
- 两者内容与共享真源一致

### AC-2 bootstrap 能物化入口

- `bash spec/bootstrap/init-harness.sh --repo-root <temp-repo> ...` 能在目标仓库创建 `CLAUDE.md` 和 `AGENTS.md`，至少在缺失时创建

### AC-3 主一致性检查覆盖双入口

- `bash spec/bootstrap/check-consistency.sh` 会检查根目录治理入口同步状态

### AC-4 文档清晰

- README 与相关 adapter/bootstrap 文档都说明了多宿主入口策略

## 6. 约束

- 继续保留 `CLAUDE.md`，不能只迁移到 `AGENTS.md`
- 优先使用基础 shell 工具与现有 bootstrap 结构
- 不依赖网络或外部模板引擎

## 7. 验证意图

- 通过同步脚本和主一致性检查证明双入口可持续维护
- 通过临时仓库 dry-run / real-run 证明 bootstrap 会创建目标入口文件
- 通过 `git diff --check` 保证文本与脚本改动干净
