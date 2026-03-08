# Plan: IDE 精简 + Skills 版本控制

## Requirements

来源: research.md Final Conclusions (Round 4-6 批注循环确认)

1. **IDE 精简到 4 个** — 保留 claude, factory, cursor, codex。删除 windsurf, copilot, augment, kiro, cline, zed, roo, opencode。(Human requirement: "只支持常用的 claude codex cursor factoryAI", "去掉OpenCode的支持")
2. **Skills 纳入版本控制** — 修改 .gitignore 添加 `!.claude/skills/` 豁免。(Human requirement: "skills需要纳入版本控制")

## Constraints

1. **SYNCED 代码不变** — 8 个 hook 中的 plan-name-resolution 和 find_plan 同步代码不在此次变更范围
2. **Hooks 不变** — 8 个 hook 脚本本身不修改（它们不含 IDE 特定逻辑，除 phase-guide.sh 的 skill 目录扫描）
3. **保留的适配器不变** — adapter-cursor.sh 保持原样
4. **向后兼容** — 已安装 baton 的项目如果使用被删除 IDE 的配置文件，安装器不需要清理（用户自行处理）
5. **测试覆盖** — CI 中的 7 个测试必须继续通过

## Complexity

**Large** — 影响 15+ 文件，横跨安装器、适配器、CLI、hooks、CI、测试、文档。

## Approach Analysis

### Approach A: 手术式删除（推荐）

逐文件移除被删 IDE 的引用，保留所有现有结构。

- **Feasibility**: ✅ 可行 — 每个 configure_* 函数边界清晰，可独立删除
- **Pros**: 最小风险，变更可逐项验证，不引入新代码
- **Cons**: setup.sh 中某些辅助函数（Cline wrapper 系统 :900-958）删除后可能留下未使用的工具函数
- **Impact**: ~474 行删除 + 4 个文件删除 + 测试/文档更新

### Approach B: setup.sh 重写

为 4 个 IDE 重写精简版安装器。

- **Feasibility**: ⚠️ 风险 — 重写可能引入新 bug，且 setup.sh 的 JSON 工具函数已被验证
- **Pros**: 更干净的代码，可能进一步减少行数
- **Cons**: 高风险，无法复用现有测试验证
- **Ruled out**: 手术式删除已足够，重写的收益不值得风险

**推荐: Approach A** — 手术式删除。

## Surface Scan

### L1 — 直接引用

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| setup.sh | L1 | modify | 删除 7 个 configure_* + Cline wrapper + 卸载逻辑 + IDE 列表/检测/选择 |
| bin/baton | L1 | modify | 删除 registry_list() 和 doctor() 中被删 IDE 的检测 |
| .baton/hooks/phase-guide.sh | L1 | modify | 删除 :21 IDE 目录循环中被删 IDE 的路径 |
| .github/workflows/ci.yml | L1 | modify | :25 删除 adapter-cline.sh 和 adapter-windsurf.sh 引用 |
| README.md | L1 | modify | 删除 IDE 能力表中被删 IDE 的行 |
| .baton/adapters/adapter-copilot.sh | L1 | delete | Copilot 已删除 |
| .baton/adapters/adapter-cline.sh | L1 | delete | Cline 已删除 |
| .baton/adapters/adapter-cline-taskcomplete.sh | L1 | delete | Cline 已删除 |
| .baton/adapters/opencode-plugin.mjs | L1 | delete | OpenCode 已删除 |
| tests/test-multi-ide.sh | L1 | modify | 删除被删 IDE 的检测和安装测试 |
| tests/test-adapters.sh | L1 | modify | 删除 opencode-plugin.mjs 测试 (:99-119) |
| tests/test-adapters-v2.sh | L1 | modify | 删除 Copilot (:72-113) + Cline (:114-230) 测试，保留 Cursor |
| tests/test-setup.sh | L1 | modify | 删除 kiro/amazonq/windsurf/cline 相关测试 |
| tests/test-ide-capability-consistency.sh | L1 | modify | 重写 — 当前检查 Kiro/Roo 措辞，需改为 4-IDE 范围 |

### L2 — 依赖追踪

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| docs/ide-capability-matrix.md | L2 | modify | 删除被删 IDE 行，更新 maintenance rules |
| docs/research-ide-hooks.md | L2 | modify | 更新范围说明 |
| .gitignore | L2 | modify | 添加 `!.claude/skills/` 豁免 (独立于 IDE 精简) |

### Skip (不修改)

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| plans/*.md | L2 | skip | 历史归档文档，不修改 |
| research.md | L2 | skip | 批注日志已记录决策，不需要回改文档主体 |
| research-*.md (root) | L2 | skip | 研究文档保持原样作为历史记录 |
| .baton/hooks/write-lock.sh | L2 | skip | 不含 IDE 特定逻辑 |
| .baton/hooks/*.sh (其他 7 个) | L2 | skip | 不含 IDE 特定逻辑 |

## Change List

### Change 1: 删除适配器文件
- 删除 `.baton/adapters/adapter-copilot.sh`
- 删除 `.baton/adapters/adapter-cline.sh`
- 删除 `.baton/adapters/adapter-cline-taskcomplete.sh`
- 删除 `.baton/adapters/opencode-plugin.mjs`
- 保留 `adapter-cursor.sh`

### Change 2: 精简 setup.sh
- 从 `SUPPORTED_IDES` (:516) 删除 7 个 IDE
- 删除 `configure_windsurf()` (:1157-1203)
- 删除 `configure_cline()` (:1205-1217)
- 删除 `configure_augment()` (:1219-1247)
- 删除 `configure_kiro()` (:1249-1275)
- 删除 `configure_copilot()` (:1277-1316)
- 删除 `configure_zed()` (:1337-1347)
- 删除 `configure_roo()` (:1349-1355)
- 删除 Cline wrapper 系统: `write_cline_hook_wrapper()` (:906-932), `install_cline_hook_wrapper()` (:934-958), `is_legacy_cline_hook_stub()` (查找位置)
- 从 `detect_ides()` 删除 7 个 IDE 的目录检测 (:678-689)
- 从 `normalize_ide_name()` 删除被删 IDE 的别名 (:530-535)
- 从 `ide_summary()` 删除被删 IDE 的描述 (:546-561)
- 从主安装 case 语句删除被删 IDE (:1429-1439)
- 从卸载逻辑删除被删 IDE 的清理 (:410-457)
- 检查 JSON 安全函数 (:134-389) 是否有被删 IDE 特定逻辑（预期没有，它们是通用的）

### Change 3: 更新 bin/baton
- 从 `registry_list()` 删除被删 IDE 的检测
- 从 `doctor()` 删除被删 IDE 的健康检查

### Change 4: 更新 phase-guide.sh
- :21 IDE 目录循环中删除 `.windsurf .cline .augment .roo .kiro .amazonq`

### Change 5: 修复 CI
- ci.yml:25 改为只 shellcheck `adapter-cursor.sh`

### Change 6: 更新测试
- test-multi-ide.sh: 删除被删 IDE 的测试用例
- test-adapters.sh: 删除 opencode-plugin.mjs 测试块 (:99-119)
- test-adapters-v2.sh: 删除 Copilot Tests 3-4 (:72-113) + Cline Tests 5-10 (:114-230)，保留 Cursor Tests 1-2
- test-setup.sh: 删除 tests 2i (amazonq alias :287-298), 4 (Windsurf :326-333), 5 (Cline :337-344), 17c (Cline uninstall :566-579) + kiro/roo 断言 (:221-223, 307)
- test-ide-capability-consistency.sh: 重写为 4-IDE 范围（删除 Kiro/Roo/Cursor-CLI 检查）

### Change 7: 更新文档
- README.md: 删除被删 IDE 的能力表行
- docs/ide-capability-matrix.md: 删除被删 IDE 行，更新 scope note 和 guidance
- docs/research-ide-hooks.md: 更新 scope 说明

### Change 8: .gitignore 修改
- 添加 `!.claude/skills/` 到 .gitignore，使 skills 目录纳入版本控制

## Self-Review

### Internal Consistency Check

- ✅ 推荐 Approach A（手术式删除），change list 全部是删除/修改操作，一致
- ✅ 每个 change item 对应 Surface Scan 中的 "modify" 或 "delete" 条目
- ✅ Surface Scan 中所有 "modify" 文件都出现在 change list 中
- ✅ Surface Scan 中所有 "delete" 文件都出现在 Change 1 中
- ✅ Change 8 (.gitignore) 对应 research Final Conclusion #5

### External Risks

1. **最大风险**: test-multi-ide.sh (924行) 的修改 — 该文件不在 CI 中运行，修改后可能引入问题而不被发现。**缓解**: 实现时手动运行全部测试。
2. **可能完全错误的场景**: 如果某些 JSON 安全函数 (setup.sh:134-389) 与被删 IDE 的特定逻辑耦合（如 Cline wrapper 的 `.baton-user` 备份路径硬编码在清理函数中），删除后可能留下死代码。**缓解**: 实现时搜索每个被删除函数的引用。
3. **被拒绝的替代方案**: Approach B (重写 setup.sh) — 风险太高，当前代码已经过测试验证，手术式删除更安全。

## Todo

### Batch 1 — 独立变更（可并行）

- [x] ✅ 1. Change: 删除被移除 IDE 的适配器文件 | Files: .baton/adapters/adapter-copilot.sh, adapter-cline.sh, adapter-cline-taskcomplete.sh, opencode-plugin.mjs | Verify: `ls .baton/adapters/` 只剩 adapter-cursor.sh | Deps: none | Artifacts: none

- [x] ✅ 2. Change: .gitignore 添加 skills 豁免 | Files: .gitignore | Verify: `git check-ignore .claude/skills/baton-plan/SKILL.md` 不输出（不被忽略） | Deps: none | Artifacts: none

- [x] ✅ 3. Change: phase-guide.sh 删除被移除 IDE 的目录扫描 | Files: .baton/hooks/phase-guide.sh | Verify: `grep -c 'windsurf\|cline\|augment\|roo\|kiro\|amazonq' .baton/hooks/phase-guide.sh` 返回 0 | Deps: none | Artifacts: none

- [x] ✅ 4. Change: ci.yml shellcheck 只 lint adapter-cursor.sh | Files: .github/workflows/ci.yml | Verify: `grep adapter .github/workflows/ci.yml` 只含 adapter-cursor.sh | Deps: none | Artifacts: none

### Batch 2 — 核心代码精简

- [x] ✅ 5. Change: setup.sh 精简 — 删除 7 个 configure_* 函数 + Cline wrapper 系统 + 卸载逻辑 + IDE 列表/检测/选择中被删 IDE | Files: setup.sh | Verify: `bash setup.sh --help` 不报错 + `grep -c 'windsurf\|augment\|kiro\|copilot\|cline\|zed\|roo' setup.sh` 返回 0 | Deps: none | Artifacts: none

- [x] ✅ 6. Change: bin/baton 删除被移除 IDE 的检测和健康检查 | Files: bin/baton | Verify: `grep -c 'windsurf\|augment\|kiro\|copilot\|cline\|zed\|roo' bin/baton` 返回 0 | Deps: none | Artifacts: none

### Batch 3 — 测试更新（依赖 Batch 1-2）

- [x] ✅ 7. Change: test-multi-ide.sh 删除被移除 IDE 的测试用例 | Files: tests/test-multi-ide.sh | Verify: `bash tests/test-multi-ide.sh` 通过 (18/18) | Deps: #1, #5 | Artifacts: none

- [x] ✅ 8. Change: test-adapters.sh 重写为 Cursor adapter 测试（原文件全是 Cline 测试） | Files: tests/test-adapters.sh | Verify: `bash tests/test-adapters.sh` 通过 (3/3) | Deps: #1 | Artifacts: none

- [x] ✅ 9. Change: test-adapters-v2.sh 删除 Copilot + Cline 测试，保留 Cursor | Files: tests/test-adapters-v2.sh | Verify: `bash tests/test-adapters-v2.sh` 通过 (3/3) | Deps: #1 | Artifacts: none

- [x] ✅ 10. Change: test-setup.sh 删除被移除 IDE 相关测试 (amazonq alias, Windsurf, Cline, kiro/roo 断言) | Files: tests/test-setup.sh | Verify: `bash tests/test-setup.sh` 通过 (148/148) | Deps: #5 | Artifacts: none

- [x] ✅ 11. Change: test-ide-capability-consistency.sh 重写为 4-IDE 范围 | Files: tests/test-ide-capability-consistency.sh | Verify: `bash tests/test-ide-capability-consistency.sh` 通过 (20/20) | Deps: #5, #12 | Artifacts: none

### Batch 4 — 文档更新（独立）

- [x] ✅ 12. Change: README.md 删除被移除 IDE 的能力表行 | Files: README.md | Verify: `grep -c 'Windsurf\|Augment\|Kiro\|Copilot\|Cline\|Zed\|Roo' README.md` 返回 0 | Deps: none | Artifacts: none

- [x] ✅ 13. Change: docs/ide-capability-matrix.md 删除被移除 IDE 行，更新 scope 和 guidance | Files: docs/ide-capability-matrix.md | Verify: 文件只包含 4 个保留 IDE 的行 | Deps: none | Artifacts: none

- [x] ✅ 14. Change: docs/research-ide-hooks.md 更新范围说明 | Files: docs/research-ide-hooks.md | Verify: scope 说明反映 4-IDE 范围 | Deps: none | Artifacts: none

### Batch 5 — 验证

- [x] ✅ 15. Change: 运行完整测试套件验证 | Files: tests/test-phase-guide.sh (unexpected: removed .amazonq test) | Verify: 全部通过 — test-setup 148/148, test-multi-ide 18/18, test-adapters 3/3, test-adapters-v2 3/3, test-ide-capability-consistency 20/20, test-workflow-consistency OK, test-write-lock 37/37, test-new-hooks 20/20, test-phase-guide 76/76, test-stop-guard 25/25, test-cli 14/14 | Deps: #1-14 | Artifacts: none
    - **Unexpected discovery**: test-phase-guide.sh Test 18 tested `.amazonq` skill detection (Kiro), which was broken by Todo #3's phase-guide.sh update. Removed the test (downstream dependency of approved change).

## Retrospective

### 计划的偏差

1. **test-adapters.sh 范围低估** — 计划写的是"删除 opencode-plugin.mjs 测试块 (:99-119)"，但实际上整个文件都是 Cline 适配器测试。最终需要整体重写为 Cursor 适配器测试，而非简单删除。
2. **test-phase-guide.sh 遗漏于 Surface Scan** — phase-guide.sh 的 IDE 目录循环修改（Todo #3）有一个下游测试（Test 18: `.amazonq` 技能检测）未被 L1/L2 扫描捕获。Surface Scan 应将 phase-guide.sh 的测试文件作为 L2 追踪。
3. **grep 假阳性** — `grep -c 'roo'` 匹配了 `tr '[:upper:]' '[:lower:]'` 中的子串。计划的验证命令应使用 `\broo\b` 词边界匹配。

### 实现中的意外发现

1. **Cline wrapper 系统嵌入很深** — `write_cline_hook_wrapper`、`install_cline_hook_wrapper`、`is_legacy_cline_hook_stub` 构成了一个约 100 行的互连系统，延伸到卸载逻辑中。
2. **test-multi-ide.sh 结构良好** — 尽管有 924 行代码和 22 处删除，测试结构使得手术式删除干净利落，无级联故障。
3. **子代理并行执行效果好** — setup.sh、bin/baton 和测试清理并发执行，写入集无冲突。

### 下次研究应改进之处

1. **测试依赖追踪** — 对任何 hook/脚本的修改，都应追踪哪些测试文件在测试它（Surface Scan 的 L2）。`grep -r "phase-guide" tests/` 就能捕获 `.amazonq` 测试。
2. **验证命令准确性** — 在写入计划之前，先测试 grep 模式是否存在假阳性。
3. **删除前完整读取文件** — test-adapters.sh 的内容是根据计划描述假设的；事先完整阅读文件就能发现 Cline 依赖。

### Code Review 发现的遗留问题（已修复）

1. **README.md:96 目录树注释残留** — `adapters/` 注释仍写着 `(Cline, Windsurf)`，已改为 `(Cursor)`。
2. **test-adapters-v2.sh:2 注释残留** — 文件头注释仍提及 `Copilot, Cline v2`，已改为只提 Cursor。
3. **test-multi-ide.sh `run_detect_ides` 顺序不一致** — 测试中检测顺序为 claude→codex→cursor→factory，与 setup.sh 的 claude→cursor→factory→codex 不一致。已对齐为 setup.sh 的顺序。

## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 BATON:GO 批准标记，然后告诉 AI "generate todolist" -->

1. Constraints中的我想进行改进