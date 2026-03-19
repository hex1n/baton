# baton-debug Autoresearch Changelog

## 评分清单

1. 是否有完整的错误输出记录（完整输出，而非摘要或截断）？
2. 是否尝试了最小化复现（隔离变量，而非直接在全量环境中调试）？
3. 每个假设测试是否记录了"确认/否定 + 具体证据"（而非只记结论）？
4. 修复是否仅在根因确认后才执行（而非在假设阶段就开始改代码）？
5. 是否在其他位置 grep 了相同的 bug 模式（修复后的横向扫描）？

---

## Baseline（第 0 轮）

场景说明：
- A: pre-commit hook 对某些文件不触发（间歇性失败）
- B: baton-review subagent 返回空结果（跨组件问题）
- C: git commit 后 annotation-template.md 未被追加（单一路径问题）

模拟结果（subagent 评分）：

| 场景 | C1 | C2 | C3 | C4 | C5 | 分数 |
|------|----|----|----|----|-----|------|
| A    | 1  | 1  | 1  | 1  | 1  | 5/5  |
| B    | 0  | 1  | 0.5 | 1 | 0.5 | 3/5 |
| C    | 1  | 1  | 1  | 1  | 1  | 5/5  |
| 合计 |    |    |    |    |    | **13.5/15** |

关键差距（全部集中在场景 B — 跨组件 / 静默失败）：

- **C1 失分**：Skill 说"full output, not summary"，但 subagent "成功运行却返回空"时，AI 可能只记录"它什么都没返回"，而不会主动提取原始 payload。Skill 没有覆盖"无错误但无输出"的静默失败场景。
- **C3 失分（0.5）**：Phase 3 缺少跨组件失败时的假设测试顺序指导。AI 可能在错误的层次（如先改 prompt，再查输入格式，再查 parser）上浪费假设次数，触发 threshold 3 而未找到根因。
- **C5 失分（0.5）**：Phase 4 "grep for same pattern" 未定义"pattern"对集成/行为类 bug 的范围。AI 可能 grep 了错误的模式（表面症状而非根本模式）。

---

## 第 1 轮改动：Phase 1 Step 1 — 静默失败的证据捕获

**改动动机**：C1 差距。现有文本"Record exact error — full output"不覆盖"进程成功但预期输出为空或缺失"的情况。

**原文**：
```
1. Record exact error — full output, not summary
```

**改后**：
```
1. Record failure evidence — full output, not summary:
   - **Error present**: capture complete stdout/stderr, never truncate
   - **Silent failure** (process runs, "succeeds", but expected output is missing or
     empty): extract and log the raw return value, response payload, or output
     artifact — "it returned nothing" is not yet evidence; capturing the raw value is
```

**预期效果**：Scenario B C1：0 → 1。其他场景无回退。

**模拟重测后评分**：

| 场景 | C1 | C2 | C3 | C4 | C5 | 分数 |
|------|----|----|----|----|-----|------|
| A    | 1  | 1  | 1  | 1  | 1  | 5/5  |
| B    | 1  | 1  | 0.5 | 1 | 0.5 | 4/5 |
| C    | 1  | 1  | 1  | 1  | 1  | 5/5  |
| 合计 |    |    |    |    |    | **14/15** |

---

## 第 2 轮改动：Phase 3 — 跨组件假设测试顺序

**改动动机**：C3 差距（场景 B 0.5）。当多个组件都可能是根因时，Phase 3 没有指导测试从哪里开始，AI 可能在外层重试，在 threshold 3 前无法定位根因。

**原文**（Phase 3 步骤 4 之后）：
```
**Failure threshold: 3**
```

**在 step 4 之后、Failure threshold 之前插入**：
```
   **Multi-component failures**: identify which layer produced the unexpected
   result *before* forming hypotheses. Test outermost observable symptom first
   (outside-in): confirm what the failing component actually outputs, then trace
   inward. Avoids spending hypothesis tests on healthy layers.
```

**预期效果**：Scenario B C3：0.5 → 1。其他场景无回退。

**模拟重测后评分**：

| 场景 | C1 | C2 | C3 | C4 | C5 | 分数 |
|------|----|----|----|----|-----|------|
| A    | 1  | 1  | 1  | 1  | 1  | 5/5  |
| B    | 1  | 1  | 1  | 1  | 0.5 | 4.5/5 |
| C    | 1  | 1  | 1  | 1  | 1  | 5/5  |
| 合计 |    |    |    |    |    | **14.5/15** |

---

## 第 3 轮改动：Phase 4 — grep pattern 范围澄清

**改动动机**：C5 差距（场景 B 0.5）。"Grep for same pattern elsewhere" 对集成/行为类 bug 的范围不清晰，AI 可能 grep 表面症状（空返回值）而非结构性根因（如 result-parsing 逻辑、subagent 调用参数）。

**原文**：
```
4. Grep for same pattern elsewhere. Fix siblings only if within approved
   scope; otherwise annotate and escalate
```

**改后**：
```
4. Grep for the underlying root pattern elsewhere — not the surface symptom
   (e.g., for a result-parsing bug: grep the parsing logic pattern, not "empty
   result"; for a path bug: grep the path construction pattern, not "file missing").
   Fix siblings only if within approved scope; otherwise annotate and escalate
```

**预期效果**：Scenario B C5：0.5 → 1。

**模拟重测后评分**：

| 场景 | C1 | C2 | C3 | C4 | C5 | 分数 |
|------|----|----|----|----|-----|------|
| A    | 1  | 1  | 1  | 1  | 1  | 5/5  |
| B    | 1  | 1  | 1  | 1  | 1  | 5/5  |
| C    | 1  | 1  | 1  | 1  | 1  | 5/5  |
| 合计 |    |    |    |    |    | **15/15** |

---

## 第 4 轮：回退评估

**评估**：三项改动均为补充性文本，未修改已有规则，未引入新约束。回退条件：仅在新增文本与已有文本产生语义冲突或模糊时回退。

检查：
- C1 改动：与 "VERIFY = VISIBLE OUTPUT" 铁律一致，为其具体化。✅ 保留
- C2 改动（Phase 3）："outside-in"指导与 Phase 3 one-change-at-a-time 原则一致，仅限排序，不影响假设数量限制。✅ 保留
- C3 改动（Phase 4）：精确化 grep 目标，与 "Fix siblings only if within approved scope" 无冲突。✅ 保留

无回退，三项改动全部保留。

---

## 最终改动汇总

| 轮次 | 位置 | 类型 | 影响 |
|------|------|------|------|
| 1 | Phase 1 Step 1 | 补充静默失败处理 | +0.5 (C1 B 场景) |
| 2 | Phase 3 Step 4 后 | 跨组件测试顺序 | +0.5 (C3 B 场景) |
| 3 | Phase 4 Step 4 | grep pattern 范围 | +0.5 (C5 B 场景) |

**Baseline → Final：13.5/15 → 15/15**

## 批注区

<!-- 人工批注区 -->
