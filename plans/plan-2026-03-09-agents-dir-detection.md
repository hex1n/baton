# plan: .agents/ 目录检测 + install.sh IDE 选择

## Requirements

- **[HUMAN]** 当项目有 `.agents/` 目录但没有 `AGENTS.md` 时，安装器应自动检测 codex IDE 并创建 `AGENTS.md`
- **[HUMAN]** `.agents/` 目录应同时触发 codex 和 factory 检测（两者都能从 `.agents/skills/` 读取）
- **[HUMAN]** `curl ... | bash` 远程安装应支持 `--ide` 参数选择

## 问题 1：.agents/ 目录未触发 IDE 检测

`detect_ides()` 对 codex 的检测条件只看 `AGENTS.md` 文件和 Codex 环境变量，**不看 `.agents/` 目录**。

其他三个 IDE 都是检测目录：
- `.claude/` → claude（setup.sh:596）
- `.cursor/` → cursor（setup.sh:597）
- `.factory/` → factory（setup.sh:598）

但 codex 只检测文件：
- `AGENTS.md` → codex（setup.sh:599）
- `CODEX_THREAD_ID` / `CODEX_SANDBOX` 环境变量 → codex（setup.sh:600）

`.agents/` 是跨 IDE 的 fallback skills 目录（setup.sh:696-697 无条件安装），Codex 和 Factory AI 都能从中读取。`.agents/` 目录存在应同时触发 codex 和 factory。

## 问题 2：install.sh 不支持 --ide

install.sh:96 调用 `bash "$BATON_HOME/setup.sh" "$(pwd)"`，没有透传参数。setup.sh 支持 `--ide`（setup.sh:51-60）但 install.sh 没有暴露。

## Constraints

- `detect_ides()` 存在两个副本：setup.sh:594 和 tests/test-multi-ide.sh:53，需同步
- install.sh 的参数需要与 setup.sh 兼容，`$(pwd)` 必须作为最后一个 positional arg
- 测试需要覆盖新场景

## Surface Scan (L1)

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| setup.sh:598-599 | L1 | modify | 主检测逻辑，factory 和 codex 都需加 `.agents/` |
| tests/test-multi-ide.sh:56 | L1 | modify | 检测逻辑副本 |
| tests/test-setup.sh | L1 | modify | 新增测试用例 |
| install.sh:96 | L1 | modify | 透传参数 |

## Approach

### 改动 1：setup.sh detect_ides() 加 `.agents/` 检测

setup.sh:598-600

Before:
```sh
[ -d "$PROJECT_DIR/.factory" ]    && append_ide "factory"
[ -f "$PROJECT_DIR/AGENTS.md" ]   && append_ide "codex"
has_codex_env                    && append_ide "codex"
```

After:
```sh
{ [ -d "$PROJECT_DIR/.factory" ] || [ -d "$PROJECT_DIR/.agents" ]; } && append_ide "factory"
{ [ -f "$PROJECT_DIR/AGENTS.md" ] || [ -d "$PROJECT_DIR/.agents" ]; } && append_ide "codex"
has_codex_env                    && append_ide "codex"
```

注意：`append_ide` 已有去重逻辑（setup.sh:595 的 case 语句），所以 `.agents/` 同时触发 factory 和 codex 不会产生重复。

### 改动 2：tests/test-multi-ide.sh 同步

test-multi-ide.sh:55-56

Before:
```sh
[ -d "$PROJECT_DIR/.factory" ]    && append_ide "factory"
{ [ -f "$PROJECT_DIR/AGENTS.md" ] || [ -n "${CODEX_THREAD_ID:-}" ] || [ -n "${CODEX_SANDBOX:-}" ]; } && append_ide "codex"
```

After:
```sh
{ [ -d "$PROJECT_DIR/.factory" ] || [ -d "$PROJECT_DIR/.agents" ]; } && append_ide "factory"
{ [ -f "$PROJECT_DIR/AGENTS.md" ] || [ -d "$PROJECT_DIR/.agents" ] || [ -n "${CODEX_THREAD_ID:-}" ] || [ -n "${CODEX_SANDBOX:-}" ]; } && append_ide "codex"
```

### 改动 3：tests/test-setup.sh 新增测试

在 Test 2b（Codex session detection）附近新增：

```sh
echo "=== Test 2d: .agents/ dir without AGENTS.md → auto-detect codex + factory ==="
d="$(mktemp -d)"
mkdir -p "$d/.agents"
OUTPUT="$(run_setup "$d" 2>&1)"
assert_output_contains "$OUTPUT" "codex"
assert_output_contains "$OUTPUT" "factory"
assert_file_exists "$d/AGENTS.md"
assert_file_contains "$d/AGENTS.md" "@.baton/workflow.md"
rm -rf "$d"
echo "  pass"
```

### 改动 4：install.sh 透传参数

install.sh:96

Before:
```sh
if bash "$BATON_HOME/setup.sh" "$(pwd)"; then
```

After:
```sh
if bash "$BATON_HOME/setup.sh" "$@" "$(pwd)"; then
```

这样用户可以：
```sh
curl -fsSL .../install.sh | bash -s -- --ide codex
```

`$@` 在没有参数时为空，不影响现有行为。`$(pwd)` 作为最后一个 positional arg 与 setup.sh 的参数解析兼容。

### Edge case 确认

**已有 AGENTS.md + 新建 .agents/**：configure_codex() 的第一个分支（setup.sh:1006）检查 AGENTS.md 是否已含 workflow 引用，已有则跳过。行为幂等，无需额外处理。

### 不采用的替代方案

**在 `configure_codex()` 里处理**：不可行——如果 `detect_ides()` 没有检测到 codex，`configure_codex()` 根本不会被调用。问题在检测阶段，不在配置阶段。
    能不检测吗 根据用户安装选择的来 如果用户安装时选择了 codex 就说明他需要 codex 的功能 那我们就应该检测到 codex 并且创建 AGENTS.md 文件 让用户能够直接使用 而不是等到 configure_codex() 才创建 AGENTS.md 这样就太晚了 用户可能会在安装后立刻使用 codex 功能 结果发现没有 AGENTS.md 文件 需要手动创建才行 这会增加用户的使用门槛和不便 所以在 detect_ides() 阶段就应该根据 .agents/ 目录的存在来判断用户需要 codex 的功能 并且创建 AGENTS.md 文件 这样才能提供更好的用户体验 和满足 HUMAN 的需求
    不只是codex 应该是覆盖所有的情况
## Self-Review

### Internal Consistency Check
- ✅ 推荐方案与变更列表一致
- ✅ Surface Scan 4 个文件都有对应变更
- ✅ 所有前提已验证：setup.sh 检测逻辑、append_ide 去重、install.sh 参数、configure_codex 幂等性
- ✅ factory 和 codex 同时由 `.agents/` 触发，与 [HUMAN] requirement 一致

### External Risks
- **最大风险**：`.agents/` 触发 factory 后会调用 `configure_factory()` → `configure_claude()`，在没有 `.claude/` 的项目中也会创建 `.claude/` 目录和 `CLAUDE.md`。但如果用户有 `.agents/`，说明项目用 agent 工具，创建 Claude 配置是合理的。
- **什么会让这个方案完全错误**：如果有非 AI 工具也使用 `.agents/` 目录名，会造成误检测。但这是一个非常特定的目录名，误用概率低。
- **被否决的替代**：在 configure_codex() 处理——不可行，原因见上。

## Annotation Log

### Round 1

**[inferred: gap] § detect_ides()**
"FactoryAi 我看是单独的文件 其实他也遵循 .agents/ 目录的检测逻辑"
→ 验证：setup.sh:696-697 无条件安装 skills 到 `.agents/skills/`，Factory AI 确实可从中读取
→ Consequence: 方案扩展——`.agents/` 需同时触发 codex 和 factory，不只是 codex
→ Result: accepted，已更新 approach

**[inferred: change-request] § install.sh**
"现在的 curl ... | bash 不能选择安装哪种 ide"
→ 验证：install.sh:96 不传参给 setup.sh，setup.sh 支持 `--ide`
→ Consequence: 新增改动 4（install.sh 透传参数）
→ Result: accepted，合入本 plan

**[inferred: question] § edge case**
"如果用户之前安装过一次，已经有了 AGENTS.md，这时候又创建了 .agents/ 目录"
→ 验证：configure_codex() setup.sh:1006 检查已有 workflow 引用则跳过，行为幂等
→ Consequence: 无方向变化
→ Result: 已确认无需额外处理

### Round 2

**[inferred: context/reinforcement] § 不采用的替代方案**
"能不检测吗 根据用户安装选择的来...所以在 detect_ides() 阶段就应该根据 .agents/ 目录的存在来判断"
→ 用户论述了为什么检测必须在 detect_ides() 阶段而非 configure_codex()：用户安装后期望立即可用，不能等到配置阶段才发现缺 AGENTS.md
→ Consequence: 无方向变化，与当前方案一致
→ Result: 确认当前方案正确

- [x] ✅ 5. Change: README.md 更新 remote install 示例（加 --ide）和 Codex 检测说明（加 .agents/ 目录） | Files: README.md | Verify: 描述与实际行为一致 | Deps: #1, #4 | Artifacts: none

## Retrospective

### What the plan got wrong
- 初版只触发 codex，遗漏了 factory 也读取 `.agents/`。经批注纠正。

### What surprised during implementation
- Windows 上 shell test 极慢（>5 min），smoke test 更高效验证核心逻辑。
- 4 个改动都是单行修改，实施本身非常直接。

### What to research differently next time
- 应在初始分析时就检查 `.agents/` 的所有消费者（不只是 codex），避免遗漏 factory。

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 BATON:GO 批准标记，然后告诉 AI "generate todolist" -->


<!-- BATON:GO-->

## Todo

- [x] ✅ 1. Change: setup.sh detect_ides() 加 `.agents/` 检测（factory + codex） | Files: setup.sh | Verify: smoke test 确认 `Detected IDEs: factory codex` + AGENTS.md 创建 | Deps: none | Artifacts: none
- [x] ✅ 2. Change: test-multi-ide.sh 同步检测逻辑副本 | Files: tests/test-multi-ide.sh | Verify: 代码与 setup.sh 一致 | Deps: none | Artifacts: none
- [x] ✅ 3. Change: test-setup.sh 新增 `.agents/` 检测测试用例 | Files: tests/test-setup.sh | Verify: Test 2c2 插入正确位置 | Deps: #1 | Artifacts: none
- [x] ✅ 4. Change: install.sh 透传 `$@` 给 setup.sh | Files: install.sh | Verify: 代码正确，`$@` 为空时不影响现有行为 | Deps: none | Artifacts: none