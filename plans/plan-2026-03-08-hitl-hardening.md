# 计划：HITL 加固 — 让 Baton 的门控决策可观测、可审计、跨适配器一致

## 参考文档

- 评审：`plans/research-2026-03-07-hitl-tools-review.md`
- 研究：`plans/research-2026-03-07-hitl-tools.md`
- 被取代的 HOTL 计划：`plans/plan-2026-03-07-hotl.md`

## 问题陈述

评审（`plans/research-2026-03-07-hitl-tools-review.md:86-91`）将 Baton 定性为**以 `BATON:GO` 为核心的阶段式 HITL，外围混有 advisory / bypass / fail-open**。三个具体弱点：

1. **Fail-open 不可见** — write-lock.sh 遇到异常或无法解析目标路径时静默放行，没有任何记录（`.baton/hooks/write-lock.sh:14`, `:47-52`）
2. **OpenCode 适配器偏离** — JS 插件只接受字面量 `plan.md` 或 `BATON_PLAN`，不支持 `plan-*.md` glob 回退，与 shell 钩子行为不一致（`.baton/adapters/opencode-plugin.mjs:12` vs `.baton/hooks/write-lock.sh:64-66`）
3. **写后追踪器盲区** — 没有 `BATON:GO` 时直接退出，任何写入都不被追踪（`.baton/hooks/post-write-tracker.sh:59`）

### 用户决策

1. 目标：强化"受治理的 AI 编码"定位（`review.md:222-223`）
2. 自动审批必须由人类显式开启（`review.md:224-225`）
3. 先审批意图、事后审代码（`review.md:226-227`）

这些决策要求：门控本身必须可靠且可审计。本计划只做加固，不引入 HOTL。

## 约束条件

- C1：Shell 钩子保持 POSIX sh，不用 bash 特有语法（当前惯例）
- C2：Fail-open 保留为安全兜底，但必须**可观测**（评审 `review.md:31`：fail-open 是刻意设计，不是 bug）
- C3：OpenCode 插件维持现有 ESM 插件 API 形状（`opencode-plugin.mjs:6-7`）
- C4：不引入新运行时依赖（jq 可选，awk 回退必须可用）
- C5：测试使用现有 `tests/test-write-lock.sh` 模式（shell、自包含）
- C6：审计日志仅本地，加入 `.gitignore`

## 方案分析

### 方案 A：三阶段渐进加固（推荐）

三个阶段，每个独立有价值，可逐个发布和测试。

| 阶段 | 做什么 | 解决评审哪个发现 | 涉及文件 |
|------|--------|-----------------|---------|
| 1 | write-lock.sh 每个退出点写审计日志 | 发现 1（fail-open 不可见） | write-lock.sh, .gitignore, tests/test-write-lock.sh |
| 2 | OpenCode 适配器对齐 plan 解析 + 审计 | 发现 4（适配器偏离） | opencode-plugin.mjs |
| 3 | 写后追踪器去掉 BATON:GO 前置条件 | 发现 5（追踪器盲区） | post-write-tracker.sh |

- 可行性：✅ 每阶段 1-2 个文件，边界清晰
- 优点：增量价值，无行为回归，每阶段独立可测
- 缺点：三轮变更需要三轮 review
- 派生产物：`.baton/audit.jsonl`（新文件，gitignored）

### 方案 B：一次性重写 write-lock.sh 为策略引擎

- 可行性：⚠️ write-lock.sh 是核心闸门，重写风险高
- 优点：架构更干净
- 缺点：影响范围大，shell 与 JS 共享库实现别扭
- **排除原因**：评审明确警告不要在最脆弱的约束点上加复杂度（`review.md:42-53`）

### 方案 C：全部迁移到 Node.js 门控

- 可行性：❌ 违反 C4（不加新依赖），打破非 Claude Code IDE 的 shell 钩子执行
- **排除原因**：与"保持文件原生和轻量"矛盾（`review.md:72`）

## 推荐方案

**方案 A — 三阶段渐进加固**。每阶段解决评审一个发现，审计日志是未来 HOTL 的基础，但本计划有意在 HOTL 之前停下。

## 详细变更

### 阶段 1：write-lock.sh 审计日志

在 write-lock.sh 中添加 `audit_log()` 函数，每个退出点调用，追加一行 JSON 到 `.baton/audit.jsonl`：

```json
{"ts":"2026-03-08T12:00:00Z","hook":"write-lock","target":"/path/to/file","decision":"allow","reason":"baton-go","plan":"/path/to/plan.md"}
```

七个退出点的映射：

| 位置 | 当前行为 | decision | reason |
|------|---------|----------|--------|
| `write-lock.sh:14`（trap） | fail-open | `fail-open` | `unexpected-error` |
| `write-lock.sh:18-19`（BATON_BYPASS） | 放行 | `bypass` | `baton-bypass` |
| `write-lock.sh:47-52`（无目标路径） | fail-open | `fail-open` | `no-target` |
| `write-lock.sh:57`（markdown） | 放行 | `allow` | `markdown` |
| `write-lock.sh:87`（无 plan） | 阻止 | `block` | `no-plan` |
| `write-lock.sh:91-92`（有 GO） | 放行 | `allow` | `baton-go` |
| `write-lock.sh:96-98`（无 GO） | 阻止 | `block` | `no-go` |

实现细节：
- 时间戳：`date -u +"%Y-%m-%dT%H:%M:%SZ"`（POSIX 兼容）
- JSON 构造：`printf` 拼接，路径中的 `"` 和 `\` 用 `sed` 转义
- 追加：`>> .baton/audit.jsonl`（POSIX 下单行原子）
- 容错：日志写入失败不阻塞门控（`|| true`）
- `.gitignore`：添加 `.baton/audit.jsonl`

### 阶段 2：OpenCode 适配器对齐

当前偏离（`opencode-plugin.mjs:12`）：
```js
const planName = process.env.BATON_PLAN || 'plan.md';
```

Shell 钩子（`write-lock.sh:64-66`）：
```sh
_candidate="$(ls -t plan.md plan-*.md 2>/dev/null | head -1)"
PLAN_NAME="${_candidate:-plan.md}"
```

变更：
1. 当 `BATON_PLAN` 未设置时，用 `fs.readdirSync` 匹配 `plan.md` / `plan-*.md`，按 `mtime` 降序取第一个（对齐 `ls -t` 行为）
2. 添加审计日志：`fs.appendFileSync('.baton/audit.jsonl', ...)`，格式与 shell 一致
3. 添加 `// SYNCED: plan-name-resolution` 注释

### 阶段 3：写后追踪器去盲区

当前（`post-write-tracker.sh:59`）：
```sh
grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null || exit 0
```

变更：
- 移除此行的提前退出
- 有 `BATON:GO`：保持当前行为（文件不在 plan 中时 stderr 警告）
- 无 `BATON:GO`：将写入事件记录到 `audit.jsonl`（`decision: "advisory"`, `reason: "write-without-go"`），不改变 stderr 输出
- 仍然始终 exit 0（advisory 性质不变）

## 风险

| 风险 | 严重度 | 缓解 |
|------|--------|------|
| Shell printf 的 JSON 转义不完整（路径含 `"`、`\`、换行） | 中 | 写 escape 辅助函数 + 测试覆盖含特殊字符的路径 |
| audit.jsonl 无限增长 | 低 | v1 文档化手动清理。后续可加轮转，不阻塞当前 |
| OpenCode 的 readdirSync + statSync 比 shell ls -t 慢 | 低 | plan 文件数量极少（通常 1-3 个），可忽略 |
| 写后追踪器去掉 GO 前置后在研究/计划阶段产生噪音 | 低 | 仅写 audit.jsonl，不改 stderr；且研究/计划阶段写入的都是 markdown，会被前面的 markdown 检查跳过 |

## 自我审查

- **最不确定的风险**：POSIX sh 里 printf 的 JSON 转义。文件路径可能包含任意字符，完美转义在纯 sh 里很难。可能需要接受"部分行格式错误"作为已知限制，或者用 base64 编码路径。
- **什么会让计划完全错误**：如果审计日志没人看，加固就只是增加了代码复杂度而没有提升治理。日志的价值取决于是否有消费者（人工 review 或未来的 HOTL 决策引擎）。
- **被拒绝的替代**：把 fail-open 改成 fail-closed。评审明确指出 fail-open 是刻意安全设计（`review.md:31`），fail-closed 可能导致编辑器工作流瘫痪。

## 批注区

> 标注类型：`[Q]` 提问 · `[CHANGE]` 修改 · `[NOTE]` 补充 · `[DEEPER]` 不够深 · `[MISSING]` 遗漏
> 审阅完成后添加 `<!-- BATON:GO -->`，然后告诉 AI "generate todolist"

<!-- 在下方添加标注 -->
