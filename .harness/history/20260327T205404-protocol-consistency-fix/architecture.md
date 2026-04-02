# Architecture: protocol-consistency-fix

**Topic**: Baton Harness 跨层协议一致性修复
**Status**: `proposed`
**Sizing**: `Small`

## 1. Problem

六个文件之间存在三类协议层不一致，且没有任何机制可以检测未来的漂移。修复必须同时解决现有 Bug 并建立防护。

## 2. First-Principles

### 2.1 Problem Statement

`skills/`、`spec/bootstrap/`、`spec/templates/` 三个目录各自维护对协议不变量的理解（合法 owner token、task-status 列结构、eval_round 写入位置），但没有单一权威定义，也没有测试可以检测漂移。

### 2.2 Constraints

- `skills/` 是 skill 修改的单一写入位置
- `check-consistency.sh` 只能依赖 bash + POSIX 工具
- `start-task.sh` 和 `.ps1` 必须同步
- 不修改 `spec/protocol/` 规范文档（`owners.txt` 是新增，不是修改）

### 2.3 决策记录

**D1（Eval Round 列）**：彻底删除。【已确认】
- 移入 State Notes 同时保留列头 → 僵尸列，语义矛盾
- 保留并真正写入 → 脚本需维护递增逻辑，复杂度不值得
- **彻底删除** → 模板改一行，脚本无需变更，语义最干净

**D2（token 权威位置）**：提取到 `spec/protocol/owners.txt`。【已确认】
- 硬编码在 `start-task.sh:100` → 脚本是定义来源，check-consistency.sh 只能做 grep 比对，两个独立定义之间比对不是单一真源
- **提取到独立文件** → 脚本从文件读取，检测脚本从同一文件读取，物理上只有一处定义

### 2.4 Solution Categories

**Category A — 直接修复，无检测层**
逐一改正错误，不新增脚本。

**Category B — 直接修复 + 检测脚本（推荐）**
修复错误，同时以 `owners.txt` 为单一真源，新建 `check-consistency.sh` 检测三条不变量。

**Category C — 引入 vocabulary.yaml**
过度工程化，当前规模（9 owner、5 列、8 skill）不足以摊销成本。已拒绝。

**Category B 胜出**：D2 决策使检测脚本有了真正的单一真源可依靠，check-consistency.sh 不再是 grep 比对两个独立定义，而是"从权威文件派生验证"。

## 3. Recommended Architecture

**Approach**：引入 `owners.txt` 单一真源，配合五处原位修复和一个新检测脚本。

**变更顺序**（依赖关系决定）：

1. 新建 `spec/protocol/owners.txt`（D2 基础，其他变更依赖它）
2. 修 `skills/harness-architect.md`（P1-a，独立）
3. 修 `skills/harness-evaluator.md`（P2-a，独立）
4. 修 `spec/templates/task-status.template.md`（P1-b，删 Eval Round 列）
5. 修 `spec/bootstrap/start-task.sh` — 从 `owners.txt` 读取白名单（D2）
6. 同步修 `spec/bootstrap/start-task.ps1`（与步骤 5 同时）
7. 新建 `spec/bootstrap/check-consistency.sh`（所有修复完成后建立，P2-c）
8. 修 `README.md`（P2-b, P3，独立）

**Key change points**：

| 步骤 | 文件 | 变更 | 机制 |
|------|------|------|------|
| 1 | `spec/protocol/owners.txt` | 新建 | 每行一个合法 owner token |
| 2 | `skills/harness-architect.md:116,143` | `verifier` → `verification-explorer` | 字符串替换 |
| 3 | `skills/harness-evaluator.md:137` | eval_round 指向 State Notes | 改写一行指令 |
| 4 | `spec/templates/task-status.template.md:3-5` | 删除 Eval Round 列（6列→5列） | 修改 Header、分隔符、占位行 |
| 5 | `spec/bootstrap/start-task.sh:27-35` | usage 中 owner 列表改为从文件读取 | 替换硬编码列表 |
| 5 | `spec/bootstrap/start-task.sh:99-105` | 白名单验证改为从 `owners.txt` 读取 | `grep -Fxq "$owner" owners.txt` |
| 6 | `spec/bootstrap/start-task.ps1:4` | `ValidateSet` 硬编码列表 → 运行时从 `owners.txt` 读取验证 | 移除 `ValidateSet`，改 `$validOwners = Get-Content` |
| 7 | `spec/bootstrap/check-consistency.sh` | 新建，三条不变量检测 | 新文件 |
| 8 | `README.md` | 新增 link-skills.sh 段落 + 闭环图映射注释 | Markdown 新增 |

**D1 对 P1-b 的影响（重要）**：
`start-task.sh:144` 已经检测 5 列 Header `| Scope | Owner | State | Updated At | Notes |`。删除模板中的 Eval Round 列后，模板与脚本自然对齐——**P1-b 仅需修改模板，脚本无需任何 schema 变更**。这是 D1 相比原架构最大的简化。

**owners.txt 格式**：
```
repo-explorer
scoped-explorer
specifier
architect
verification-explorer
generator
reviewer
evaluator
human
```

**start-task.sh 白名单验证新逻辑**：
```bash
owners_file="$script_dir/../protocol/owners.txt"
if [[ ! -f "$owners_file" ]]; then
  printf 'owners.txt not found: %s\n' "$owners_file" >&2; exit 1
fi
if ! grep -Fxq "$owner" "$owners_file"; then
  printf 'Unsupported owner: %s\n' "$owner" >&2; exit 1
fi
```

**check-consistency.sh 三条不变量**：
```
1. skills/ 中使用的 owner token 均在 owners.txt 中
2. start-task.sh 写出的 Header 与 task-status.template.md Header 一致
3. skills/ 文件与 .claude/skills/ 和 .agents/ 内容一致
```

## 4. Surface Scan

| 文件 | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `spec/protocol/owners.txt` | L1 | add | D2 单一真源，新建 |
| `skills/harness-architect.md` | L1 | modify | P1-a，2 处 token 替换 |
| `skills/harness-evaluator.md` | L1 | modify | P2-a，1 处指令改写 |
| `spec/templates/task-status.template.md` | L1 | modify | P1-b，删 Eval Round（3 行） |
| `spec/bootstrap/start-task.sh` | L1 | modify | D2，白名单验证改读文件 |
| `spec/bootstrap/start-task.ps1:4` | L1 | modify | D2，移除 ValidateSet，改运行时从 owners.txt 读取 |
| `spec/bootstrap/start-task.ps1:193,198` | L1 | no-change | 已是 5 列，D1 后自然对齐 |
| `spec/bootstrap/init-harness.ps1` | L3 | skip | 无 schema/owner 引用，不需要修改 |
| `spec/bootstrap/check-consistency.sh` | L1 | add | P2-c，新建 |
| `README.md` | L1 | modify | P2-b + P3 |
| `.claude/skills/harness-architect.md` | L2 | propagate | symlink/sync 自动 |
| `.agents/harness-architect.md` | L2 | propagate | 同上 |
| `.claude/skills/harness-evaluator.md` | L2 | propagate | 同上 |
| `.agents/harness-evaluator.md` | L2 | propagate | 同上 |
| `spec/protocol/` 其他文件 | L3 | skip | out of scope |

## 5. Validation Strategy

| 需求 | 验证方式 |
|------|---------|
| FR-1 token 一致性 | `grep "owner \`" skills/harness-architect.md` 无 `verifier` |
| FR-2 schema 一致性 | 对比 `task-status.template.md` Header 与 `start-task.sh` printf 输出 |
| FR-3 eval_round 可写 | `grep "Current eval round" skills/harness-evaluator.md` |
| FR-4 link-skills 文档 | `grep "link-skills" README.md` |
| FR-5 角色名映射 | `grep "verification-explorer" README.md` |
| FR-6 检测脚本 | 修复前 exit 1，修复后 exit 0 |
| 集成 | `bash spec/bootstrap/check-consistency.sh` 全部通过 |

**验证顺序**：先建 `check-consistency.sh` 并在当前 codebase 跑出 red（证明检测有效），再逐项修复，最终跑出 green（证明修复完整）。

## 6. Risks

| 风险 | 缓解 |
|------|------|
| `start-task.ps1` 遗漏同步 | Surface Scan 显式标记；Generator 先读 ps1 再改 |
| `owners.txt` 路径在不同 `--repo-root` 下解析错误 | 脚本用 `$script_dir/../protocol/owners.txt` 绝对路径，不依赖 cwd |
| skills/ 修改未传播（copy 模式） | check-consistency.sh 的 check-3 会检测此问题 |

## 6b. 执行隔离约定（人工确认）

后续阶段的执行隔离方式：

| 阶段 | context 要求 | 执行方式 |
|------|------------|---------|
| Verifier | `context: fork` | 子 agent，只传入 `architecture.md` + repo |
| Generator | 无强制要求 | 当前 session 可执行 |
| Evaluator | `context: fork`（强制） | 子 agent，只传入 artifacts + diff，不传对话历史 |

Verifier 和 Evaluator 通过 `Agent` 工具以子 agent 方式分发，prompt 中明确禁止继承对话上下文。

## 7. Self-Challenge

1. **D1 让 P1-b 变成了模板修改而非脚本修改——是否有遗漏的连锁影响？** 需确认 `init-harness.sh` 的 `--task-id` 路径（`sed` 替换模板变量）在模板改为 5 列后仍然正确。占位符行 `<timestamp>` 对应列数需一致。
2. **`owners.txt` 是 `spec/protocol/` 下的新文件，是否违反"不修改规范文档"约束？** 不违反——约束是"不修改"已有规范，新增文件是扩展而非修改。
3. **skeptic 最先质疑什么？** "owners.txt 是纯文本，任何人都能随手编辑，和硬编码没有本质区别。" 回应：单一真源的价值在于物理上只有一处需要更新，而不是防止人为修改。check-consistency.sh 的 check-1 确保 skill 文件不会使用 owners.txt 之外的 token，这已经覆盖了最常见的漂移场景。
