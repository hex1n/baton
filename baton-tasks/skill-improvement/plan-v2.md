# Plan: Baton Skills Best Practices Alignment (v2)

**Complexity**: Medium
**Scope**: 4 项改进（排除 config.json 和持久化）

## 改进 1: 降低刚性

> Thariq: "Give Claude the information it needs, but give it the flexibility to adapt"

### baton-research — Step 流程灵活化

当前问题：7 步流程读起来像必须全部执行的顺序。实际上 Two-Phase Mode 已经允许跳过，但 Step 0-7 的写法没体现这一点。

改动：
- Step 0（Frame）：加注 "Medium+ 任务写入 artifact；Small 任务可在 chat 中隐式完成"
- Step 2（Investigation Methods）：将 "Use ≥2 independent evidence acquisition methods" 改为 "Medium+ 任务推荐 ≥2 独立方法；Small 任务单一方法 + 显式说明为何足够"
- Step 4（Evidence Standards）：已在上轮简化为 ✅/❓，无需改动
- Step 6（Review）：加注 "Small 任务可 self-review；Medium+ 必须 dispatch"
- Step 7（Convergence）：加注 "Small 任务不需要 Final Conclusions section"

不改的：Iron Law、Red Flags、counterexample sweep — 这些是质量底线，不应放松。

**Files**: `.baton/skills/baton-research/SKILL.md`

### baton-plan — Approach 数量灵活化

当前问题：Step 4 写 "Present 2-3 fundamentally different approaches"，但有些任务确实只有一个合理方案。

改动：
- Step 4：改为 "Medium/Large 任务推荐 2-3 approaches。如果只有一个合理方案，显式说明为什么其他方向不可行——这本身就是 first-principles 分析的一部分"

Complexity-Based Scope 已经区分了 Trivial/Small/Medium/Large，只需让 Step 4 引用它。

**Files**: `.baton/skills/baton-plan/SKILL.md`

### baton-implement — 连续执行软化

当前问题："Do not stop to show progress or ask for confirmation between items" 过于绝对。

改动：
- 保持连续执行为默认行为
- 加一句 "如果用户明确要求逐项确认，遵循用户偏好"

**Files**: `.baton/skills/baton-implement/SKILL.md`

---

## 改进 2: 拆长 SKILL.md

> Thariq: "Skills are folders... progressive disclosure"

### baton-research (244 → ~150 行)

提取到 `reference.md`：
- "AI failure modes to guard against"（5 条，lines 145-159）
- "Minimum record per investigation move"（lines 167-171）
- "Counterexample sweep" 格式（lines 176-180）
- "Exit Criteria" 详细条目（lines 220-226）

SKILL.md 保留：Iron Law、Red Flags、Gotchas、When to Use、Two-Phase Mode、Step 0-7 骨架（每步 1-3 行 + "详见 reference.md"）、Output、Annotation Protocol。

**Files**: `.baton/skills/baton-research/SKILL.md`, `.baton/skills/baton-research/reference.md` (new)

### baton-review (208 → ~120 行)

提取到 `reference.md`：
- "Observability Checks"（lines 83-93）
- "Cross-Phase Compliance Checks" 全部（lines 95-121）
- "Frame-Level Finding Requirements"（lines 132-141）
- "Review Outcome" 详细规则（lines 174-181）
- "Platform Support"（lines 199-208）

SKILL.md 保留：Iron Law、Red Flags、Gotchas、When Review is Mandatory、First-Principles Framework（4 questions）、Domain-Specific Criteria 引用、Severity Definitions、Output Format、Invocation。

**Files**: `.baton/skills/baton-review/SKILL.md`, `.baton/skills/baton-review/reference.md` (new)

---

## 改进 3: 补齐 Gotchas 空框架

3 个 skill 缺少 Gotchas section：baton-debug、baton-subagent、using-baton。

加同样的空框架：
```markdown
## Gotchas

> Operational failure patterns. Add entries when observed in real usage.
> Empty until then — do not pre-fill with theory.
```

**Files**: `.baton/skills/baton-debug/SKILL.md`, `.baton/skills/baton-subagent/SKILL.md`, `.baton/skills/using-baton/SKILL.md`

---

## 改进 4: 加可执行脚本

> Thariq: "Giving Claude scripts and libraries lets Claude spend its turns on composition"

当前 baton skills 目录里零脚本。hooks/ 里有治理脚本但 AI 不能主动调用。

加一个轻量脚本：`baton-plan/check-plan.sh` — AI 写完 plan 后可主动调用验证结构。

```bash
#!/usr/bin/env bash
# check-plan.sh — AI 可调用的 plan 结构检查
# Usage: bash .baton/skills/baton-plan/check-plan.sh <plan-file>
PLAN="${1:?Usage: check-plan.sh <plan-file>}"
[ ! -f "$PLAN" ] && echo "❌ File not found: $PLAN" && exit 1

ISSUES=0
# Self-Challenge
grep -q '^## Self-Challenge' "$PLAN" || { echo "⚠️ Missing ## Self-Challenge"; ISSUES=$((ISSUES+1)); }
# 批注区
grep -q '^## 批注区' "$PLAN" || { echo "⚠️ Missing ## 批注区"; ISSUES=$((ISSUES+1)); }
# Approach count
APPROACHES=$(grep -c '^### Approach' "$PLAN" 2>/dev/null || echo 0)
echo "📊 Approaches: $APPROACHES"
# Write set
WRITESET=$(grep -c '^|' "$PLAN" 2>/dev/null || echo 0)
echo "📊 Write set table rows: $WRITESET"
# Summary
[ "$ISSUES" -eq 0 ] && echo "✅ All structural checks passed" || echo "⚠️ $ISSUES issue(s) found"
```

这不是 hook（不自动触发），是工具（AI 可以在 Step 5/6 之前主动 `bash` 调用）。

**Files**: `.baton/skills/baton-plan/check-plan.sh` (new)

---

## Write Set

| File | Change |
|------|--------|
| `.baton/skills/baton-research/SKILL.md` | 灵活化注释 + 拆分到 reference |
| `.baton/skills/baton-research/reference.md` | new — 提取的详细内容 |
| `.baton/skills/baton-plan/SKILL.md` | Step 4 approach 灵活化 |
| `.baton/skills/baton-plan/check-plan.sh` | new — 可调用验证脚本 |
| `.baton/skills/baton-implement/SKILL.md` | 连续执行加用户偏好条款 |
| `.baton/skills/baton-review/SKILL.md` | 拆分到 reference |
| `.baton/skills/baton-review/reference.md` | new — 提取的详细内容 |
| `.baton/skills/baton-debug/SKILL.md` | 加空 Gotchas section |
| `.baton/skills/baton-subagent/SKILL.md` | 加空 Gotchas section |
| `.baton/skills/using-baton/SKILL.md` | 加空 Gotchas section |

## Self-Challenge

1. **拆分 SKILL.md 会不会让 AI 找不到关键信息？** — Thariq 文章说渐进式信息披露有效，但 baton-review 的 Cross-Phase Compliance Checks 是 review subagent 需要立即使用的，放到 reference.md 是否增加了遗漏风险？
   - 回应：review-prompt.md 已经包含了 domain-specific 检查项，Cross-Phase Compliance 可以在 reference.md 中且 SKILL.md 里保留一行引用。subagent 会在需要时读 reference.md。

2. **check-plan.sh 的价值是否确定？** — 没有 [RUNTIME] 证据表明 AI 会主动调用它。
   - 回应：诚实说不确定。但脚本成本极低（15 行），如果没用可以删。先加进来试试。

3. **灵活化会不会变成偷懒的借口？** — "Small 任务可以 self-review" 会不会导致 Medium 任务也被降级为 Small？
   - 回应：task sizing 由 constitution 治理，AI 提议但人类可纠正。灵活化只影响 sizing 内的步骤，不影响 sizing 本身。

## 批注区

### [Annotation 1]
- **Trigger**: 当前改进方案每一项做最根本性追问是当前的最佳改进方案吗?
- **Intent**: 验证每项改进是否值得做
- **Response**: 逐条追问后结论：改进 1（降低刚性）不需要改——skills 已内建灵活性机制（Two-Phase Mode、Complexity-Based Scope）；改进 2（拆长）不值得——244 和 208 行远在 Anthropic 500 行限制内，拆分增加遗漏风险；改进 4（脚本）多余——quality-gate.sh 已自动检查。只有改进 3（补齐 Gotchas）值得做。已执行：baton-debug、baton-subagent、using-baton 各加空 Gotchas section。
- **Status**: ✅ accepted
- **Impact**: 计划从 4 项缩减为 1 项，只做改进 3

### [Annotation 2]
- **Trigger**: 有多个文件的 skill 目录能整理一下吗
- **Intent**: 评估目录结构优化
- **Response**: 只有 baton-research 有 5 个文件，其余 ≤ 2 个。5 个扁平文件可以分到 templates/ 和 review/ 子目录，但需同步修改 SKILL.md 的 4 处引用路径。Anthropic 官方示例也用扁平结构，且 5 个文件不构成混乱。属于"看起来该改但没有实际问题"的改动。
- **Status**: ❌ rejected — 改动风险 > 收益
- **Impact**: 不整理