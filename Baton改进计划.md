# Baton Harness 改进计划

**深度**：Standard
**输入来源**：本次会话深度分析，代码库文件（spec/、skills/、bootstrap 脚本、README）

---

## TL;DR

Baton Harness 当前有三个 Bug（两个 P1）和一个结构性根因。Bug 可在 1 天内全部修完，但如果不解决根因——**协议层没有任何机制检测跨层一致性**——这些 Bug 修完之后还会以不同面目重现。改进计划分两轨并行：**立即修复 Bug**（降低当前运营风险），**同时补一个 60 行的一致性测试脚本**（让未来的漂移可检测）。

---

## 优先级总表

| 优先级 | 变更内容 | 涉及文件 | 工作量 | 风险 | 价值 |
|--------|---------|---------|--------|------|------|
| P1-a | 修复 `harness-architect.md` 状态转换 token | `skills/harness-architect.md:116,143` | 5 min | 低 | 消除功能性 Bug |
| P1-b | 修复 `start-task.sh` 的 Header 解析和写出（支持 Eval Round 列） | `spec/bootstrap/start-task.sh` | 2 h | 中 | 修复安全绕过 |
| P2-a | 将 `eval_round` 从表格列移入 State Notes 节，更新 skill 和模板 | `skills/harness-evaluator.md`, `spec/templates/module-status.template.md` | 30 min | 低 | 消除 schema 悬空引用 |
| P2-b | 在 README Quick Start 中补充 `link-skills.sh` 步骤 | `README.md` | 10 min | 低 | 修复发行链文档 |
| P2-c | 新增 `spec/bootstrap/check-consistency.sh` | 新文件 | 2 h | 低 | 根因防护 |
| P3 | 在 README 闭环图中添加角色名与运行时 token 的映射说明 | `README.md` | 20 min | 低 | 减少未来混乱 |
| **总计** | | | **~5 h** | | |

---

## 各项具体变更

### P1-a：修复 harness-architect.md 的 owner token

**当前**（`skills/harness-architect.md:116` 和 `:143`）：
```markdown
Update `module-status.md` → state `verification_check`, owner `verifier`.
```

**改为**：
```markdown
Update `module-status.md` → state `verification_check`, owner `verification-explorer`.
```

两处同时修改。修改完后 symlink 自动传播；若为 copy 模式则运行 `sync-skills.sh`。

---

### P1-b：修复 start-task.sh 的 6 列 schema 支持

根本选择：让脚本与模板对齐（加 Eval Round 列），而非让模板降级至 5 列。

**需要修改的关键行**：

```bash
# 修改 1：Header 检测（第 144 行）
# 旧
if [[ "$line" == '| Scope | Owner | State | Updated At | Notes |' ]]; then
# 新
if [[ "$line" == '| Scope | Owner | State | Eval Round | Updated At | Notes |' ]]; then

# 修改 2：分隔符跳过（第 153 行）
# 旧
if [[ "$line" == '|------|------|------|-----------|------|' || -z "$line" ]]; then
# 新
if [[ "$line" == '|------|------|------|-----------|-----------|------|' || -z "$line" ]]; then

# 修改 3：行解析（第 163 行）
# 旧
IFS='|' read -r scope_column owner_column state_column updated_column notes_column <<< "$trimmed_line"
# 新
IFS='|' read -r scope_column owner_column state_column eval_round_column updated_column notes_column <<< "$trimmed_line"

# 修改 4：新行格式（第 251 行）
# 旧
new_row="| $safe_task_id | $safe_owner | $safe_state | $timestamp | $safe_notes |"
# 新
new_row="| $safe_task_id | $safe_owner | $safe_state | — | $timestamp | $safe_notes |"

# 修改 5：输出 Header（第 258-259 行）
# 旧
printf '| Scope | Owner | State | Updated At | Notes |\n'
printf '|------|------|------|-----------|------|\n'
# 新
printf '| Scope | Owner | State | Eval Round | Updated At | Notes |\n'
printf '|------|------|------|-----------|-----------|------|\n'
```

> **注意**：同样的修改需要同步到 `start-task.ps1`（PowerShell 版本）。
>
> **向后兼容**：在 Header 检测处同时支持 5 列旧格式和 6 列新格式，仅写出 6 列，避免已有使用旧格式的 repo 无法解析。

---

### P2-a：将 eval_round 移入 State Notes

**`skills/harness-evaluator.md:137`**，当前：
```markdown
Increment `eval_round` in `module-status.md`.
```
改为：
```markdown
In `module-status.md` → update State Notes: increment `Current eval round: N` counter.
```

`module-status.template.md` 中 `Eval Round` 列的 `—` 占位符保留，但 skill 不再引导 agent 修改该列——State Notes 节负责跟踪轮次。

---

### P2-b：README Quick Start 补充 link-skills.sh

在 "Copy role skills to target repo" 块之后添加：

```markdown
### Develop or modify skills (baton repo only)

If you've cloned this repo and want edits to `skills/` to propagate automatically:

```bash
spec/bootstrap/link-skills.sh   # creates symlinks or hardlinks in .agents/ and .claude/skills/
```

On a fresh clone, files in `.agents/` and `.claude/skills/` are regular copies.
Run this once to upgrade them to symlinks for live propagation.
```

---

### P2-c：新增 check-consistency.sh

新建 `spec/bootstrap/check-consistency.sh`，检测三条不变量：

```bash
#!/usr/bin/env bash
# Verify cross-layer invariants. Run after any protocol change.
set -euo pipefail

errors=0

# 1. Owner tokens used in skills must appear in start-task.sh whitelist
WHITELIST=$(grep -oP "(?<=\|\s)[a-z-]+" spec/bootstrap/start-task.sh | sort -u)
SKILL_OWNERS=$(grep -rh "owner \`" skills/ | grep -oP "(?<=owner \`)[a-z-]+" | sort -u)

for token in $SKILL_OWNERS; do
  if ! echo "$WHITELIST" | grep -q "^$token$"; then
    echo "ERROR: skill uses owner '$token' but it is not in start-task.sh whitelist"
    errors=$((errors + 1))
  fi
done

# 2. start-task.sh header output must match module-status.template.md header
TEMPLATE_HEADER=$(grep "^| Scope" spec/templates/module-status.template.md)
SCRIPT_HEADER=$(grep "printf '| Scope" spec/bootstrap/start-task.sh | grep -oP "(?<=printf ').*(?=')")

if [[ "$TEMPLATE_HEADER" != "| $SCRIPT_HEADER" ]]; then
  echo "ERROR: module-status.template.md and start-task.sh use different headers"
  echo "  template: $TEMPLATE_HEADER"
  echo "  script:   | $SCRIPT_HEADER"
  errors=$((errors + 1))
fi

# 3. skills/ must match .claude/skills/ and .agents/
for f in skills/*.md; do
  fname=$(basename "$f")
  for target in ".claude/skills/$fname" ".agents/$fname"; do
    if ! cmp -s "$f" "$target" 2>/dev/null; then
      echo "ERROR: $f differs from $target — run link-skills.sh or sync-skills.sh"
      errors=$((errors + 1))
    fi
  done
done

if [[ $errors -eq 0 ]]; then
  echo "check-consistency: all invariants OK"
else
  echo "check-consistency: $errors error(s) found"
  exit 1
fi
```

这个脚本让漂移**可被检测**，后续可加入 git pre-commit hook 或 CI 步骤。

---

### P3：README 角色名映射说明

在闭环图下方添加一行注释：

```markdown
> Role display names above map to runtime owner tokens in `module-status.md`:
> `Explorer` → `scoped-explorer`, `Verifier` → `verification-explorer`, etc.
> Full token list: `spec/bootstrap/start-task.sh --help`
```

---

## 不要做的事

- **不要删除 Eval Round 列**：虽然这是更简单的 P1-b 替代方案，但会丢失多轮评估的可见性，让控制平面信息量下降。
- **不要引入 vocabulary.yaml**：当前规模（8 个 skill，9 个 state，9 个 owner）不需要，过度正式化会增加维护成本而不带来对应价值。
- **不要统一展示名与运行时 token**：两层命名本身合理，问题在于没有文档说明映射关系。补文档比改名改得彻底，成本更低。

---

## 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| start-task.ps1 未同步修改，Windows 用户触发旧 schema | 中 | 中 | P1-b 完成后立即搜索 ps1 中的对应行并同步 |
| check-consistency.sh 的 grep 匹配过于脆弱（skill 文件表述变化） | 中 | 低 | 脚本失败只是提示，不阻断任务流；初始版本宁可漏报不能误报 |
| 修改 start-task.sh 后，已有使用 5 列 module-status.md 的 repo 无法解析 | 低 | 高 | 向后兼容：Header 检测时同时支持 5 列和 6 列，仅写出 6 列 |

---

## 分析：根因

大多数改进计划直接跳到"修 Bug"。这里先退一步。

### 五问追因

```
表层问题：Harness 有命名不一致、Schema 错误、文档缺口
  Why? → skill 文件和 bootstrap 脚本使用了不同的 owner token 和列数
  Why? → 模板、脚本、skill、README 四层各自演化，没有交叉验证
  Why? → 没有任何地方统一定义"合法 owner 列表"和"module-status 列结构"
  Why? → 规范依赖人工注意力维护一致性，而不是任何可执行的检查
根因：   协议的跨层不变量没有单一权威定义，也没有测试可以检测漂移
```

**待修的 Bug 是症状，没有一致性检测机制才是病因。** 只修 Bug 不解决根因，下次演化同样漂移。

### 当前三个症状（均已验证）

1. `harness-architect.md` 写 `owner verifier`，不在 `start-task.sh` 白名单 → 功能性 Bug
2. `start-task.sh` 无法解析 template 初始化的 6 列文件，安全守卫被无声绕过 → 安全 Bug
3. `harness-evaluator.md` 引用 `eval_round` 列，控制平面中无对应列 → 数据悬空

### 关于"重复"问题的澄清

`.agents/` 和 `.claude/skills/` 的文件看似重复，但单一真源（`skills/`）和同步机制（`link-skills.sh` + `sync-skills.sh`）已经存在。这不是需要修复的架构问题，只需在 Quick Start 中补充说明（P2-b）。

---

## Self-Check

**最可能的失败模式**：修了 `start-task.sh`，忘了同步 `start-task.ps1`，Windows 用户在 P1-b 之后反而遇到新的不兼容。**缓解**：P1-b 完工时，在提交描述中明确要求同步检查 `.ps1` 文件。

**若不做 P2-c**：此计划仍然有价值——P1 Bug 是真实的，修复有意义。但没有检测脚本，6 个月后的下一次演化大概率再次引入同类漂移。接受这个风险需要明确。

**能否从计划预测结果**：能。P1-a + P1-b 修完后，任何遵循 harness-architect skill 的 AI agent 写出的 `module-status.md` 都能被 `start-task.sh` 正确解析，且 owner token 验证通过。P2-c 脚本跑起来之后，当前三个不一致会全部报错——这本身也是验证修复是否完整的手段。
