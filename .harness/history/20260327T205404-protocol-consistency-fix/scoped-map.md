# Scoped Map: protocol-consistency-fix

**Requirement**: 修复 Baton Harness 三个跨层一致性 Bug，补发行链文档，新增一致性检测脚本
**Domain**: harness bootstrap scripts, role skills, protocol templates
**Owner**: `scoped-explorer`
**Status**: `complete`

## 1. Scope

- In scope:
  - `skills/harness-architect.md` — owner token 修正（P1-a）
  - `spec/bootstrap/start-task.sh` — 6 列 schema 支持（P1-b）
  - `spec/bootstrap/start-task.ps1` — 同步修改（P1-b）
  - `skills/harness-evaluator.md` — eval_round 引用方式（P2-a）
  - `spec/templates/module-status.template.md` — 视向后兼容决策
  - `README.md` — Quick Start 补 link-skills.sh，闭环图映射说明（P2-b, P3）
  - `spec/bootstrap/check-consistency.sh` — 新建（P2-c）
- Out of scope:
  - `spec/protocol/` 规范文档（不修规范，只修实现层）
  - `harness-verifier.md` 展示名（两层命名是有意设计，只补文档）
  - 其他 skill 文件

## 2. Entry Point

- Primary entry classes or files:
  - `skills/harness-architect.md` — role skill 状态转换指令
  - `spec/bootstrap/start-task.sh` — module-status.md 读写核心逻辑
  - `spec/templates/module-status.template.md` — 控制平面 schema 定义
- Methods, APIs, commands, or scripts:
  - `start-task.sh:100` — owner 白名单验证
  - `start-task.sh:144` — Header 检测（当前匹配 5 列）
  - `start-task.sh:163` — 行解析（5 列）
  - `start-task.sh:251` — 新行格式生成
  - `start-task.sh:258-259` — Header 写出
  - `harness-architect.md:116,143` — 状态转换写 `owner verifier`
  - `harness-evaluator.md:137` — 引用 `eval_round` 表格列
- Why these are the entries:
  - 所有三个 Bug 都源于这些位置的不一致，已通过本次会话深度分析逐一验证

## 3. Call Chain

```text
P1-a（owner token 错误）
  harness-architect skill → AI 读取:116/:143 → 写入 owner="verifier"
  → start-task.sh:100 白名单验证 → exit 1 (Unsupported owner)

P1-b（Schema 不匹配 / 安全绕过）
  init-harness.sh → 复制 6 列模板 → .harness/module-status.md
  → start-task.sh:144 检测 5 列 Header → 不匹配 → in_table=false
  → rows=[] open_rows=[] → 安全守卫绕过 → 写出 5 列文件（schema 降级）

P2-a（eval_round 悬空）
  harness-evaluator BLOCKED → 读取 skill:137
  → 查找 Eval Round 列 → start-task.sh 生成的文件中无此列 → 无处写入
```

## 4. Existing Behavior

- Current observable behavior:
  - `start-task.sh` 生成 5 列 module-status.md，Header 与模板不一致
  - `harness-architect.md` 状态转换写 `verifier`，不在 start-task.sh 白名单
  - `harness-evaluator.md` 要求递增的 `eval_round` 列不存在于生成的文件中
  - `.agents/` 和 `.claude/skills/` 是 `skills/` 的副本（git 克隆解析了 symlink）
- Current validation rules:
  - `start-task.sh:99-105` — 白名单验证 owner（含 `verification-explorer`，不含 `verifier`）
  - `start-task.sh:107-113` — 白名单验证 state
  - `start-task.sh:189-192` — 不允许存在未 complete 的 task row
- Existing implicit constraints:
  - `skills/` 是修改的单一真源；`.link-mode=symlink` 但实际为 copy（git 克隆行为）

## 5. Existing Tests

- Directly relevant tests: 无（bootstrap 脚本无测试框架）
- Nearby reusable tests: 无
- No useful tests found: 是；新建 `check-consistency.sh` 将作为唯一自动化检测手段

## 6. Dependency / Risk Scan

- Will this likely touch integration or infra? 否
- Will this likely touch migrations or schema?
  - 是（module-status.md 格式变化）— 需向后兼容已有 5 列文件的 repo
- Will this likely cross business domains? 否

关键风险：
- `start-task.ps1` 必须同步修改，否则 Windows 路径产生不兼容 schema
- 5 列旧格式文件的向后兼容策略需在 Specifier 阶段确认

## 7. Change Shape

- This looks like: 多文件协调修复（scripts + skills + templates + docs + 新文件）
- Estimated file count: 6 个已有文件 + 1 个新文件 = 7 个
- Preferred implementation depth: 修改量小，逻辑集中；最复杂处是 start-task.sh 的向后兼容解析

## 8. Open Questions

- **Q1（需 Specifier 确认）**: `start-task.sh` 的向后兼容策略：仅支持 6 列新格式，还是同时兼容 5 列旧格式？
  - 影响：决定 Header 检测逻辑是单分支还是双分支
- **Q2（需 Specifier 确认）**: `eval_round` 归宿：移入 State Notes 文本（推荐），还是彻底删除该概念？
  - 影响：决定是否需要修改 `module-status.template.md`

## 9. Recommendation

- Proceed? 是
- Suggested next step: 进入 Specifier，确认 Q1/Q2 两个边界决策，产出 requirements.md
