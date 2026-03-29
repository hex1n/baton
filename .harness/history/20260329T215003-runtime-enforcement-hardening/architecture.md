# Architecture: runtime-enforcement-hardening

**主题**: 运行时执行机制强化
**状态**: `proposed`
**规模**: `Large`

## 1. 问题

当前 Baton hook 系统以内联 shell 命令嵌入宿主配置文件（`.claude/settings.json` / `.codex/hooks.json`），最长命令超过 700 字符，不可独立测试、不可调试。同时存在 7 项执行缺口：eval round 不递增、blocked 无分类、generator-feedback.md 无核心支持、complete 不要求 retrospective.md、人类门控无执行、overlay 无检测。

需要在**不影响现有功能**的前提下，重构 hook 基础设施并填补所有缺口。

## 2. 第一性原理拆解

### 2.1 子问题分解

本任务拆为两个独立子问题：

**P1: Hook 可测试性** — 如何让 hook 逻辑从"不可测的配置片段"变为"可独立运行和测试的脚本"？

**P2: 执行缺口填补** — 如何在 hook 中添加 6 项新检查 + 4 项扩展，同时处理：
- hook 首次需要**写** harness 文件（eval round、ack 清除）
- 两个宿主（CC / Codex）的能力差异
- 写操作引入的递归风险

### 2.2 约束

- CC 和 Codex hook 能力不同（CC 有 SubagentStop + content access；Codex 只有 command string）
- 无 YAML 库，profile 读取只能 grep 单键
- 单任务/workspace，不考虑并发
- 向后兼容：现有 `module-status.sh` 读函数签名不变
- Clean switch：旧内联和新脚本在同一提交切换

### 2.3 方案类别

**方案 A: 独立脚本 + 共享库**
- 5 个 hook 脚本各自 source `parse-input.sh`
- `install-hooks.sh` 生成薄一行调用 `bash "$root/spec/bootstrap/hooks/<script>.sh"`
- 宿主差异在 `parse-input.sh` 中统一抽象

**方案 B: 单一分发器脚本**
- 一个 `hook-dispatcher.sh` 接收 hook 类型参数
- `install-hooks.sh` 生成 `bash dispatcher.sh post-artifact`
- 所有逻辑在同一文件中 case 分发

**方案 C: Profile-driven enforcement engine**
- 声明式配置定义检查规则
- 通用引擎解析规则并执行
- CEO review 已判定为过早抽象

### 2.4 评估

**选择方案 A**，理由：
- 每个 hook 脚本可独立运行和测试，测试不需要 mock 分发器
- 关注点清晰分离：parse-input.sh 处理输入解析和宿主抽象，各脚本处理业务逻辑
- 新增检查只需在对应脚本中添加代码，不影响其他 hook
- 与 CEO plan 一致（已通过 CEO + Eng + Codex 三方 review）

**拒绝方案 B**：单文件会迅速膨胀（预计 6 个 hook 类型 × 平均 80 行 = 480+ 行），测试需要为每个 case 构造不同 mock，耦合度高。

**拒绝方案 C**：当前只有 6 项检查，声明式引擎的抽象成本远超手写检查，且规则语言本身需要测试和维护。

## 3. 推荐架构

### 3.1 目录结构

```text
spec/bootstrap/hooks/
  lib/
    parse-input.sh          # 共享运行时库
  pre-transition.sh         # PreToolUse hook
  post-artifact.sh          # PostToolUse hook
  stop-check.sh             # Stop hook
  subagent-stop.sh          # SubagentStop hook (CC-only)
  session-start.sh          # SessionStart hook
```

### 3.2 parse-input.sh 设计

```text
调用方式: source "$HOOKS_DIR/lib/parse-input.sh"

入口逻辑:
  1. 重入守卫: [[ "${BATON_HOOK_ACTIVE:-}" == "1" ]] && exit 0
  2. 读 stdin JSON 到 $HOOK_INPUT (cat, 只读一次)
  3. 宿主检测:
     - jq '.tool_input.file_path' 非空 → HOOK_HOST=cc
     - jq '.tool_input.command' 非空 → HOOK_HOST=codex
     - 都空 → HOOK_HOST=unknown
  4. 导出变量:
     - HOOK_ROOT=$(git rev-parse --show-toplevel)
     - BOOTSTRAP_DIR="$HOOK_ROOT/<rel_bootstrap>"  # 在 install-hooks.sh 中 bake
     - HOOK_FILE_PATH (CC: tool_input.file_path)
     - HOOK_CONTENT (CC: tool_input.content)
     - HOOK_COMMAND (Codex: tool_input.command)
     - HOOK_AGENT (SubagentStop: agent_type)
  5. 导出函数:
     - hook_block "reason" → stderr 输出 reason, exit 2
     - hook_pass → exit 0
     - debug_log "msg" → BATON_DEBUG=1 时输出到 stderr
     - read_profile_value <key> <default> [<regex>]

read_profile_value 实现:
  grep "^[[:space:]]*${key}:" profile.local.yaml
  提取冒号后的值，trim 空白
  如果提供了 regex 参数，验证值匹配，否则返回 default
  文件不存在 → 返回 default
```

**关于 `BOOTSTRAP_DIR` 的 bake 方式**：`install-hooks.sh` 在生成薄调用时，将 `rel_bootstrap` 作为环境变量或脚本参数传入，使每个 hook 脚本能找到正确的 bootstrap 目录。具体方式：生成的命令字符串为 `BATON_BOOTSTRAP="$root/<rel_bootstrap>" bash "$root/<rel_bootstrap>/hooks/<script>.sh"`，其中 `$root` 在运行时通过 `git rev-parse --show-toplevel` 解析。`parse-input.sh` 从 `$BATON_BOOTSTRAP` 读取，回退到 `$HOOK_ROOT/spec/bootstrap`。

### 3.3 5 个 Hook 脚本设计

#### pre-transition.sh (PreToolUse)

```text
source parse-input.sh

目标文件检测:
  CC: HOOK_FILE_PATH 包含 "module-status.md"
  Codex: HOOK_COMMAND 包含 ".harness/module-status.md"
  不匹配 → hook_pass

提取新旧状态:
  CC: 解析 HOOK_CONTENT → mktemp → module-status.sh current-field → new_state
      读磁盘文件 → module-status.sh current-field → current_state
  Codex: grep 命令中的状态名 → new_state
         读磁盘文件 → current_state

检查 1: 转换合法性
  bash validate-transition.sh "$current_state" "$new_state"

检查 2: [新] Human gate 执行 (FR-7)
  if current_state in (awaiting_human_arch, ready_for_human_close)
     AND new_state != blocked:
    读磁盘 module-status.md → grep "- human_ack: true" under "## State Notes"
    未找到 → hook_block "Human approval required..."

检查 3: [新] Blocked 分类 (FR-4, CC only)
  if new_state == blocked AND HOOK_HOST == cc:
    从 HOOK_CONTENT 解析 Notes 列
    检查 ^\[(verification|scope|environment|design)_blocker\]
    不匹配 → hook_block "Blocked state requires category..."
```

#### post-artifact.sh (PostToolUse)

```text
source parse-input.sh

目标文件检测:
  CC: HOOK_FILE_PATH 包含 ".harness/" 且以 ".md" 结尾
  Codex: HOOK_COMMAND 中 grep ".harness/*.md" 路径
  不匹配 → hook_pass

检查 1: artifact schema 校验
  提取 artifact type (basename, strip .md)
  bash validate-artifact.sh "$artifact_type" "$file_path"

检查 2: [新] Codex blocked 分类 (FR-4, Codex only)
  if HOOK_HOST == codex AND artifact is module-status:
    读磁盘 module-status.md → 检查最新行 state == blocked
    如果是 → 检查 Notes 列的 blocker 分类正则
    不匹配 → hook_block (exit 2, Codex post-write 检测)

检查 3: [新] Human_ack 清除 (FR-7)
  if artifact is module-status AND validate-artifact 成功:
    读先前状态 (从 git diff 或缓存) → 判断是否从门控状态转出
    如果是 → export BATON_HOOK_ACTIVE=1
             sed -i '' '/^- human_ack: true$/d' "$file_path"
    排序约束: 只在检查 1 成功后执行
```

**ack 清除的先前状态获取**：`post-artifact.sh` 需要知道"从哪个状态转出"。方案：pre-transition.sh 在验证通过后将 `current_state` 写入一个临时标记文件 `/tmp/baton-pre-state-$$`，post-artifact.sh 读取该文件判断先前状态。如果标记文件不存在（非转换场景的 artifact 写入），则跳过 ack 清除。标记文件在 post-artifact.sh 处理后删除。

**Decision: 先前状态传递机制**
- **Chosen**: 临时文件传递 (`/tmp/baton-pre-state-$$`)。pre-transition.sh 写入当前状态，post-artifact.sh 读取后删除。
- **Not chosen**: 环境变量传递——hook 之间不共享 shell 环境。重新读磁盘——post-artifact.sh 执行时磁盘已是新状态。
- **When to revisit**: 如果宿主平台提供 hook 间共享上下文的机制。

#### stop-check.sh (Stop)

```text
source parse-input.sh

[[ -f ".harness/module-status.md" ]] || hook_pass

bash validate-state-artifacts.sh "$HOOK_ROOT/.harness"
bash validate-isolation.sh "$HOOK_ROOT/.harness"
```

与现有逻辑完全一致，仅封装为独立脚本。

#### subagent-stop.sh (SubagentStop, CC-only)

```text
source parse-input.sh

agent=$HOOK_AGENT
case "$agent" in baton-verifier|baton-evaluator) ;; *) hook_pass ;; esac

现有检查:
  baton-verifier → 验证 verification-path.md 存在 + schema
  baton-evaluator → 验证状态在 blocked|reviewing|ready_for_human_close

[新] Eval round 递增 (FR-3):
  if agent == baton-evaluator:
    source module-status.sh
    current_round=$(module_status_current_field ... eval_round)
    new_round=$((current_round + 1))

    max_rounds=$(read_profile_value max_eval_rounds 3 "^[0-9]+$")
    [[ "$max_rounds" -gt 0 ]] || max_rounds=3

    if [[ "$new_round" -ge "$max_rounds" ]]; then
      hook_block "Eval round $new_round reached max_eval_rounds ($max_rounds)"
    fi

    export BATON_HOOK_ACTIVE=1
    module_status_set_eval_round "$HOOK_ROOT/.harness/module-status.md" "$new_round"
```

#### session-start.sh (SessionStart)

```text
source parse-input.sh

bash harness-context.sh "$HOOK_ROOT/.harness"
```

与现有逻辑一致，仅封装。`harness-context.sh` 内部新增 overlay recommendation 读取（见下文）。

### 3.4 module_status_set_eval_round 设计

新增到 `module-status.sh`：

```text
module_status_set_eval_round() {
  local path="$1" new_value="$2"
  local schema line_num tmp_file

  schema=$(module_status_schema "$path")
  [[ "$schema" == "current" ]] || return 1

  # 找到最后一个数据行的行号
  line_num=$(... awk/grep 定位最后一个表格数据行 ...)

  # 读取整个文件，替换该行中 Eval Round 列的值
  tmp_file=$(mktemp)
  awk -v ln="$line_num" -v val="$new_value" '
    NR == ln {
      # 分割 | 列，替换第 4 列 (Eval Round)
      split($0, cols, "|")
      cols[5] = " " val " "   # 第 5 个 segment = Eval Round (1-indexed, first is empty)
      line = ""
      for (i = 1; i <= length(cols); i++) {
        if (i > 1) line = line "|"
        line = line cols[i]
      }
      print line
      next
    }
    { print }
  ' "$path" > "$tmp_file"
  mv "$tmp_file" "$path"
}
```

**Decision: Eval Round 写入方式**
- **Chosen**: awk 逐行处理 + temp file + mv。安全：不修改非目标行，原子替换。
- **Not chosen**: sed in-place——难以安全定位 markdown table 中的特定列。
- **When to revisit**: 如果需要更多 module-status 写操作，考虑通用的列更新函数。

### 3.5 install-hooks.sh 重写

核心变更：命令字符串从内联逻辑变为脚本调用。

```text
当前:
  cc_post_cmd="input=\$(cat); fp=\$(echo ...) ..."  (完整逻辑)

目标:
  cc_post_cmd="BATON_BOOTSTRAP=\"\$root/${rel_bootstrap}\" bash \"\$root/${rel_bootstrap}/hooks/post-artifact.sh\" # baton-validate-artifact"
```

**标记字符串保持不变**。现有幂等机制基于 `# baton-validate-artifact`、`# baton-validate-transition` 等注释标记。新脚本调用末尾保留相同标记，strip 函数无需改动。

每个 hook 类型的映射：

| Hook Type | CC Script | Codex Script | Matcher (CC) | Matcher (Codex) |
|-----------|-----------|-------------|--------------|-----------------|
| PostToolUse | post-artifact.sh | post-artifact.sh | Write\|Edit\|MultiEdit | Bash |
| PreToolUse | pre-transition.sh | pre-transition.sh | Write\|Edit\|MultiEdit | Bash |
| Stop | stop-check.sh | stop-check.sh | (none) | (none) |
| SubagentStop | subagent-stop.sh | — | baton-evaluator\|baton-verifier | — |
| SessionStart | session-start.sh | session-start.sh | startup\|resume | startup\|resume |

Codex 额外保留 `statusMessage` 和 `timeout` 字段。

### 3.6 其他变更

**validate-state-artifacts.sh** — `required_for_state("complete")` 追加 `retrospective.md`（1 行变更）。

**validate-artifact.sh** — 新增 `generator-feedback` case：
```bash
generator-feedback)
  check_sections "$file_path" \
    "Original.Assumption|原始假设" "Actual.Finding|实际发现" \
    "Impact|影响" "Recommended.Next.Owner|建议下一步负责方" || rc=$?
  ;;
```

**harness-context.sh** — SessionStart 输出新增 overlay recommendation：
```bash
scoped_map="$harness_dir/scoped-map.md"
if [[ -f "$scoped_map" ]]; then
  overlay_line=$(grep -E '^overlay:[[:space:]]*(core|strict)' "$scoped_map" || true)
  if [[ -n "$overlay_line" ]]; then
    ctx+=$'\n'"  overlay: ${overlay_line#overlay:*}"
  fi
fi
```

**generator-feedback 模板** — 新建 `spec/templates/generator-feedback.template.md` (en) 和 `spec/templates/zh/generator-feedback.template.md` (zh)，删除 `spec/extensions/java-backend-strict/templates/generator-feedback.template.md`。

**profile.local.template.yaml** — `execution:` 下新增 `max_eval_rounds: 3`。

**Skill 文件变更**:
- `skills/baton-generator/SKILL.md` — 新增 generator-feedback.md 使用指导段落
- `skills/baton-explorer/SKILL.md` — 新增 `## Overlay Recommendation` 输出指导段落

**check-consistency.sh** — 新增 3 个不变量：
- 不变量 12: hooks/ 下每个脚本有对应 test-hook-*.sh
- 不变量 13: install-hooks.sh 生成的路径均指向实际脚本
- 不变量 14: generator-feedback 在 artifact-schema.md 和 validate-artifact.sh 均有入口

### 3.7 宿主能力矩阵（实现参考）

| 功能 | CC 实现 | Codex 实现 | 脚本位置 |
|------|---------|-----------|----------|
| 状态转换校验 | PreToolUse (content) | PreToolUse (command grep) | pre-transition.sh |
| Artifact 校验 | PostToolUse (file_path) | PostToolUse (command grep) | post-artifact.sh |
| 状态工件检查 | Stop | Stop | stop-check.sh |
| Isolation 校验 | Stop | Stop | stop-check.sh |
| Session 上下文 | SessionStart | SessionStart | session-start.sh |
| Eval round 递增 | SubagentStop | — | subagent-stop.sh |
| max_eval_rounds | SubagentStop | — | subagent-stop.sh |
| Blocked 分类 | PreToolUse (content) | PostToolUse (on-disk) | pre-transition.sh / post-artifact.sh |
| Human gate | PreToolUse (file read) | PreToolUse (command grep) | pre-transition.sh |
| human_ack 清除 | PostToolUse | PostToolUse | post-artifact.sh |
| Subagent 工件检查 | SubagentStop | — | subagent-stop.sh |

### 3.8 实施顺序

```text
Phase 1 (Hook 基础设施):
  Step 1: 创建 hooks/lib/parse-input.sh
  Step 2: 创建 5 个 hook 脚本 (仅封装现有逻辑)
  Step 3: 重写 install-hooks.sh 生成薄调用
  Step 4: 更新 test-install-hooks.sh
  Step 5: 运行现有测试套件确认无退化

Phase 2 (执行缺口):
  Step 6:  module_status_set_eval_round + 测试
  Step 7:  subagent-stop.sh 添加 eval round 递增 + max limit
  Step 8:  pre-transition.sh 添加 blocked 分类 (CC)
  Step 9:  post-artifact.sh 添加 blocked 分类 (Codex) + ack 清除
  Step 10: pre-transition.sh 添加 human gate
  Step 11: validate-state-artifacts.sh 添加 retrospective.md
  Step 12: generator-feedback 模板提升 + validate-artifact.sh
  Step 13: harness-context.sh overlay recommendation
  Step 14: skill 文件更新
  Step 15: BATON_DEBUG 在 parse-input.sh 中集成 (debug_log 已在 Step 1)
  Step 16: check-consistency.sh 3 个新不变量
  Step 17: per-hook 单元测试 (test-hook-*.sh)
  Step 18: ShellCheck 全部脚本
  Step 19: 运行完整测试套件
```

### 3.9 人类架构审批点

本轮进入 `awaiting_human_arch` 时，请人类明确确认以下 4 个决策：

1. 接受两阶段交付顺序：先完成 hook 基础设施重构，再在新脚本层补 enforcement gap；不在现有内联命令上继续堆逻辑。
2. 接受 `parse-input.sh` 作为 hook 侧共享运行时边界；`validate-isolation.sh` 维持独立读取逻辑，本轮不抽成更大的 profile 公共库。
3. 接受 `pre-transition.sh -> /tmp/baton-pre-state-$$ -> post-artifact.sh` 的短生命周期状态传递，用于 ack 清除排序判断。
4. 接受 `human_ack` 仍是 advisory 记账机制，而不是宿主原生审批证明。

requirements 级别真相在当前架构下没有新增或收缩；若人类批准以上 4 点，`requirements.md` 无需回写即可进入 `verification_check`。

## 4. 影响面扫描

| 文件 | 层级 | 处理方式 | 原因 |
|------|------|---------|------|
| `spec/bootstrap/hooks/lib/parse-input.sh` | L1 | **add** | 新共享运行时库 |
| `spec/bootstrap/hooks/pre-transition.sh` | L1 | **add** | 提取自 CC/Codex PreToolUse 内联 + 新增 blocked/human gate |
| `spec/bootstrap/hooks/post-artifact.sh` | L1 | **add** | 提取自 CC/Codex PostToolUse 内联 + 新增 ack 清除 |
| `spec/bootstrap/hooks/stop-check.sh` | L1 | **add** | 提取自 CC/Codex Stop 内联 |
| `spec/bootstrap/hooks/subagent-stop.sh` | L1 | **add** | 提取自 CC SubagentStop 内联 + 新增 eval round |
| `spec/bootstrap/hooks/session-start.sh` | L1 | **add** | 提取自 CC/Codex SessionStart 内联 |
| `spec/bootstrap/install-hooks.sh` | L1 | **modify** | 命令字符串改为脚本路径调用 |
| `spec/bootstrap/module-status.sh` | L1 | **modify** | 新增 `module_status_set_eval_round` |
| `spec/bootstrap/validate-artifact.sh` | L1 | **modify** | 新增 `generator-feedback` case |
| `spec/bootstrap/validate-state-artifacts.sh` | L1 | **modify** | complete 状态追加 `retrospective.md` |
| `spec/bootstrap/harness-context.sh` | L1 | **modify** | 读取 overlay recommendation |
| `spec/bootstrap/check-consistency.sh` | L1 | **modify** | 3 个新不变量 |
| `.claude/settings.json` | L1 | **regen** | install-hooks.sh 重新生成 |
| `.codex/hooks.json` | L1 | **regen** | install-hooks.sh 重新生成 |
| `spec/templates/generator-feedback.template.md` | L1 | **add** | 新核心模板 (en) |
| `spec/templates/zh/generator-feedback.template.md` | L1 | **add** | 新核心模板 (zh) |
| `spec/extensions/java-backend-strict/templates/generator-feedback.template.md` | L1 | **delete** | 已提升到核心 |
| `spec/templates/profile.local.template.yaml` | L2 | **modify** | 添加 `max_eval_rounds` |
| `skills/baton-generator/SKILL.md` | L2 | **modify** | 添加 feedback 指导 |
| `skills/baton-explorer/SKILL.md` | L2 | **modify** | 添加 overlay 指导 |
| `tests/test-install-hooks.sh` | L2 | **modify** | 适配新 hook 格式 |
| `tests/test-module-status.sh` | L2 | **modify** | 覆盖 set_eval_round |
| `tests/test-validate-artifact.sh` | L2 | **modify** | 覆盖 generator-feedback |
| `tests/test-validate-state-artifacts.sh` | L2 | **modify** | 覆盖 retrospective.md |
| `tests/test-harness-context.sh` | L2 | **modify** | 覆盖 overlay output |
| `tests/test-hook-parse-input.sh` | L2 | **add** | parse-input.sh 测试 |
| `tests/test-hook-pre-transition.sh` | L2 | **add** | pre-transition.sh 测试 |
| `tests/test-hook-post-artifact.sh` | L2 | **add** | post-artifact.sh 测试 |
| `tests/test-hook-stop-check.sh` | L2 | **add** | stop-check.sh 测试 |
| `tests/test-hook-subagent-stop.sh` | L2 | **add** | subagent-stop.sh 测试 |
| `tests/test-hook-session-start.sh` | L2 | **add** | session-start.sh 测试 |
| `spec/bootstrap/validate-isolation.sh` | L3 | **skip** | `read_profile_mode` 保留不变；新 `read_profile_value` 在 parse-input.sh 中独立实现 |
| `spec/protocol/artifact-schema.md` | L3 | **skip** | 已有 generator-feedback 条目（scoped-map 确认），无需修改 |

## 5. 验证策略

### 5.1 Phase 1 验证

| 需求 | 验证方式 | 测试文件 |
|------|---------|----------|
| AC-1: 5 个脚本存在 | test-install-hooks.sh 检查路径 | 现有 + 更新 |
| AC-2: parse-input.sh 功能 | test-hook-parse-input.sh | 新建 |
| AC-3: 薄调用格式 | test-install-hooks.sh 检查命令格式 | 更新 |
| AC-4: 无退化 | 现有测试套件全部通过 | 现有 |
| AC-5: 无内联逻辑 | test-install-hooks.sh 断言无长命令 | 更新 |

### 5.2 Phase 2 验证

| 需求 | 验证方式 | 测试文件 |
|------|---------|----------|
| AC-6: eval round 递增 | mock evaluator stop + 检查 eval round 值 | test-hook-subagent-stop.sh |
| AC-7: max_eval_rounds 阻止 | 设置 round=3, max=3, 验证 exit 2 | test-hook-subagent-stop.sh |
| AC-8: blocked 分类 | mock blocked 转换 + 各分类测试 | test-hook-pre-transition.sh + test-hook-post-artifact.sh |
| AC-9: generator-feedback 模板 | 文件存在 + validate-artifact.sh 通过 | test-validate-artifact.sh |
| AC-10: 旧模板删除 | 文件不存在断言 | check-consistency.sh 不变量 14 |
| AC-11: retrospective.md | complete 状态缺少 retrospective → exit 2 | test-validate-state-artifacts.sh |
| AC-12: human gate | mock awaiting_human_arch 转出无 ack → exit 2 | test-hook-pre-transition.sh |
| AC-13: ack 清除 | mock 门控转出 + 验证 ack 被删除 | test-hook-post-artifact.sh |
| AC-14: ack 排序 | validate-artifact 失败时 ack 不被清除 | test-hook-post-artifact.sh |
| AC-15: overlay | mock scoped-map 有 overlay → 检查 context 输出 | test-harness-context.sh |
| AC-16-20: 扩展 | 对应测试文件 + ShellCheck + check-consistency.sh | 各测试 |
| AC-21: 重入守卫 | BATON_HOOK_ACTIVE=1 时 hook 立即退出 | test-hook-parse-input.sh |
| AC-22: 无退化 | 完整测试套件 | 所有现有测试 |

### 5.3 评审重点

- `parse-input.sh` 的宿主检测逻辑（CC vs Codex JSON 结构差异）
- `module_status_set_eval_round` 的 awk 列定位（markdown table 对齐）
- `post-artifact.sh` 中 ack 清除的排序和重入守卫
- `pre-transition.sh` 中 human gate 读取磁盘文件的时序

## 6. 风险

### R1: 重入递归 (Critical)
- **触发**: subagent-stop.sh 写 eval round → 触发 PostToolUse → post-artifact.sh
- **缓解**: `BATON_HOOK_ACTIVE` 环境变量守卫，所有写操作前设置
- **残余**: 如果子进程不继承环境变量（不应发生，bash export 传递到子 shell）

### R2: ack 清除时序 (High)
- **触发**: post-artifact.sh validate 失败但 ack 已清除
- **缓解**: ack 清除代码位于 validate-artifact 成功的条件分支内
- **残余**: 如果 validate-artifact.sh 本身 crash（非正常退出），条件检查可能被绕过。但 `set -euo pipefail` 会在此情况下终止脚本

### R3: 先前状态传递 (Medium)
- **触发**: pre-transition.sh 写的临时文件在 post-artifact.sh 读取前被清理
- **缓解**: 使用 PID-specific 文件名 `/tmp/baton-pre-state-$$`，仅在同一 hook session 内有效
- **残余**: 如果 PID 复用（极端罕见）。可接受——最坏结果是 ack 未清除，下次转换时会被检测

### R4: Codex blocked 分类延迟检测 (Low)
- **触发**: Codex 只能 PostToolUse 检测，非法分类在写入后才被发现
- **缓解**: exit 2 阻止后续操作，agent 必须修正
- **残余**: 磁盘上短暂存在非法分类。可接受——Codex 架构限制

### R5: install-hooks.sh 标记字符串兼容 (Low)
- **触发**: 新旧格式切换时标记不一致导致幂等机制失效
- **缓解**: 保持完全相同的标记字符串，strip 函数不变
- **残余**: 无

## 7. 自我质疑

### 7.1 是否过度工程？

Phase 1 单独来看确实是"重构现有功能而不新增功能"。但这是 Phase 2 的必要前提——在 700 字符的内联命令中添加 blocked 分类、human gate、eval round 逻辑是不可维护的。两阶段的额外成本（约 200 行 parse-input.sh + 5 个薄脚本壳）换来的是所有后续检查的可测试性。

### 7.2 先前状态传递是否可靠？

临时文件方案有 PID 复用风险（理论上），但实际上：hook 在同一 tool call 内顺序执行（PreToolUse → 工具执行 → PostToolUse），PID 在此窗口内不会变化。更重要的是，失败模式是"ack 未清除"（保守），而非"ack 被错误清除"（危险）。

### 7.3 read_profile_value 是否应该放在 parse-input.sh 之外？

`validate-isolation.sh` 也需要读 profile。当前方案是 `validate-isolation.sh` 保留自己的 `read_profile_mode`（只读 strict/compat），`parse-input.sh` 提供泛型 `read_profile_value`（支持任意 key）。两者不冲突——`validate-isolation.sh` 不 source parse-input.sh（它不是 hook），保持独立。长期可以将 `read_profile_mode` 迁移为调用 `read_profile_value`，但不在本次范围内。

### 7.4 为什么不用 module-status.sh 写函数做 ack 清除？

ack 清除是删除 `## State Notes` 下的一个 bullet (`- human_ack: true`)，不涉及 markdown table 结构。`module_status_set_eval_round` 写的是 table 中的一列，需要精确定位列和行——这才是 awk + temp + mv 的适用场景。ack 清除用 `sed -i '' '/^- human_ack: true$/d'` 更简洁，且风险极低（精确匹配完整行，不会误删其他内容）。

### 7.5 如果 hook 自身被修改会怎样？

本次实现将修改 hook 逻辑并通过 install-hooks.sh 重新生成配置文件。这意味着当前会话的 hook 在 install-hooks.sh 执行后立即生效新逻辑。**风险**：如果新 hook 的 pre-transition.sh 的 human gate 检查阻止了当前任务的状态转换（当前任务自身处于 `awaiting_human_arch`），会导致自阻塞。**缓解**：Generator 在完成所有代码变更后、运行 install-hooks.sh 之前，确保当前任务不处于门控状态（通常在 `generating` 状态执行 install-hooks.sh）。

## 决策记录

### D1: 独立脚本 vs 单一分发器
- **Chosen**: 独立脚本 + 共享库（方案 A）。每个 hook 可独立测试，关注点分离。
- **Not chosen**: 单一分发器——单文件膨胀，测试耦合。
- **Revisit**: 如果 hook 类型超过 10 个且共享逻辑占比 > 50%。

### D2: Eval round 写入方式
- **Chosen**: awk + temp file + mv。安全替换 table 中特定列。
- **Not chosen**: raw sed——markdown table 中的列定位用 sed 不可靠。
- **Revisit**: 如果需要更多 module-status 列更新，考虑通用列写函数。

### D3: 先前状态传递
- **Chosen**: `/tmp/baton-pre-state-$$` 临时文件。
- **Not chosen**: 环境变量（hook 间不共享）、重新读磁盘（已被覆盖）。
- **Revisit**: 宿主平台提供 hook 间上下文传递机制时。

### D4: ack 清除方式
- **Chosen**: sed in-place 删除精确行。简洁，风险极低。
- **Not chosen**: module-status.sh 写函数——ack 在 State Notes 区域，非 table 列。
- **Revisit**: 如果 State Notes 区域结构变复杂。

### D5: read_profile_value 位置
- **Chosen**: parse-input.sh（hook 专用，与其他 hook utilities 同层）。
- **Not chosen**: 独立 profile.sh（validate-isolation.sh 也能用——但当前不需要泛型读取）。
- **Revisit**: 如果非 hook 脚本也需要泛型 profile 读取。

### D6: BATON_BOOTSTRAP 传递方式
- **Chosen**: install-hooks.sh 在生成的命令中 bake `BATON_BOOTSTRAP` 环境变量。
- **Not chosen**: parse-input.sh 硬编码路径——不适配非标准目录布局。
- **Revisit**: 如果 hook 脚本需要在 install-hooks.sh 之外被调用（测试中通过直接设置变量解决）。
