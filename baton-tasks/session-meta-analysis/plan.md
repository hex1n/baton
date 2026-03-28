# Baton 改进计划 — 基于 v5 实施会话实证

**Sizing: Medium** — 多个独立变更，每个需独立验证

**状态: PROPOSING**

**来源**: `baton-tasks/session-meta-analysis/research.md`（同目录）

---

## 概览

```
优先级     变更                               影响文件数   风险
─────────────────────────────────────────────────────────────────
CRITICAL   废弃 baton-evolve                     3-4       LOW
HIGH       上下文消耗瘦身                        5-7       MEDIUM
HIGH       测试 baseline failure 机制             3        LOW
MEDIUM     review 噪声抑制                       2-3       LOW
MEDIUM     预存测试修复                          5         LOW
LOW        constitution defense model 修正       1        LOW
```

---

## Phase 1: 废弃 baton-evolve [CRITICAL]

### 问题

10 轮同模型自审 0 发现 vs Codex 1 轮 8 发现。evolve 的迭代不产生单次 review 抓不到的 finding，收敛信号是负价值（打磨 = camouflage）。

### 方案

**删除 skill，保留 review**。baton-review 已覆盖 evolve 能发现的所有问题类别（文档内部一致性）。cross-model review 由 /plan-eng-review Step 0.5（Codex）提供。

### 变更

1. **删除 `skills/baton-evolve/`** 整个目录（SKILL.md + review-prompt.md，共 243 行）
2. **更新 `skills/using-baton/SKILL.md`** — 移除 evolve 相关路由和提及
3. **更新 `bin/baton`** doctor — 技能列表从 8 改为 7（如果 doctor 硬编码了列表）
4. **更新 `constitution.md`** — 如果提及 evolve，移除
5. **更新 `setup.sh`** — 技能 symlink 列表去掉 baton-evolve

### 验证

- `ls skills/baton-evolve/` → 不存在
- `grep -r "baton-evolve" skills/ hooks/ bin/ constitution.md setup.sh` → 无结果
- `bash tests/test-smoke.sh` 通过

---

## Phase 2: 上下文消耗瘦身 [HIGH]

### 问题

治理 token 开销 ~17,500（constitution + 6 个 skill SKILL.md + using-baton + SessionStart hook output），占 200K context 的 8.75%。同一指令（如 "verify = visible output"）在 constitution、baton-implement、using-baton 中各出现一次。

### 方案

**去重 + 精简**。原则：每条规则只在一个权威位置定义，其他位置引用而非重复。

### 变更

#### 2a. Skill SKILL.md 去重

逐 skill 审计，删除与 constitution.md 重复的内容：

| Skill | 当前行数 | 预估重复 | 目标 |
|-------|---------|---------|------|
| baton-implement | 145 | ~30 行（Iron Law、Red Flags 部分与 constitution 重复） | ~115 |
| baton-plan | 223 | ~40 行（Iron Law、Evidence Standards 与 constitution 重复） | ~183 |
| baton-research | 271 | ~35 行（Evidence 标准、completion 条件重复） | ~236 |
| using-baton | 162 | ~20 行（governance model 与 constitution 重叠） | ~142 |

**规则**: 如果 constitution.md 已经定义了某条规则，skill 中只保留 `[see constitution.md §<section>]` 引用 + skill-specific 的差异化行为。不删除 skill 独有的流程步骤。

#### 2b. Constitution 精简

当前 178 行。审查是否有可以合并的 section：
- §Evidence 和 §Completion 有部分重叠（都提到 verification）
- §Permissions 的 unexpected discovery 描述较长，可压缩

**目标**: 178 → ~150 行（~16% 削减）

#### 2c. using-baton phase routing table 压缩

Phase routing table 当前详细列出每个 phase 的 "baton skill"、"value"、"when to prefer"。大部分信息是自解释的（如 "baton-plan 用于 plan phase"）。压缩为简表。

### 验证

- 每个 skill 的核心流程步骤未被删除（读取确认）
- `bash tests/test-smoke.sh` 通过
- 手动检查：去重后的 skill 在 Claude Code 中加载时，AI 仍然遵循正确流程

### 预期收益

~125 行削减 ≈ ~1,500 tokens 节省。不大——但方向正确。真正的大头是 system-reminder 中的技能列表（~100 个外部 skill 描述），那个不在 baton 控制范围内。

---

## Phase 3: 测试 baseline failure 机制 [HIGH]

### 问题

5 个预存失败使 `test-full.sh` 永远 exit 1。"全套测试通过"变成不可能的目标，新引入的失败容易被误归类为 "pre-existing"。

### 方案

**引入 `tests/baseline-failures.txt`**。列出已知失败。测试运行器将实际失败与 baseline 对比：
- 新增失败 → REGRESSION（exit 1）
- baseline 中的失败 → KNOWN（不计入 exit code）
- baseline 中的失败被修复 → 提示从 baseline 移除

### 变更

1. **新建 `tests/baseline-failures.txt`**

```
# Known failures — remove entries as tests are fixed
# Format: test-file:test-name (or just test-file for whole-file failures)
test-phase-guide.sh:guidance-text-content
test-constitution-consistency.sh:section-names
test-annotation-protocol.sh:content-patterns
test-write-lock.sh:multi-plan-edge-1
test-write-lock.sh:multi-plan-edge-2
test-bash-guard.sh:edge-case-1
test-bash-guard.sh:edge-case-2
```

2. **修改 `tests/test-smoke.sh` 和 `tests/test-full.sh`**

添加 baseline 对比逻辑：
- 运行每个测试，捕获 exit code
- 如果 exit 1 且测试在 baseline 中 → KNOWN_FAIL（不增加 FAIL 计数）
- 如果 exit 1 且测试不在 baseline 中 → REGRESSION（增加 FAIL 计数）
- 如果 exit 0 且测试在 baseline 中 → FIXED（提示移除）
- 最终 exit code 基于 REGRESSION 数量，不基于 KNOWN_FAIL

3. **修改 summary 输出格式**

```
Full summary: 7 passed, 0 regressions, 5 known failures
```

### 验证

- `bash tests/test-full.sh` → exit 0（0 regressions）
- 手动引入一个新失败 → exit 1（1 regression）
- 修复一个 baseline 失败 → 提示 "FIXED: test-xxx, remove from baseline"

---

## Phase 4: Review 噪声抑制 [MEDIUM]

### 问题

baton-review 返回 LOW findings（"worthwhile correction without blocking effect"），action cost ≈ HIGH findings 但 value ≈ 0。

### 方案

修改 review-prompt.md，要求 reviewer：
- HIGH/MEDIUM: 完整 finding 块（现有格式）
- LOW: 压缩为一行列表，不中断 review 流程
- 增加门槛：LOW finding 必须有明确的 **action**，否则不报告

### 变更

1. **修改 `skills/baton-implement/review-prompt.md`** — 添加输出格式指令：

```markdown
## Output Format
- HIGH/MEDIUM findings: full finding block (severity, description, evidence, fix)
- LOW findings: compress to a single "Minor notes" section at the end.
  Each LOW finding = one line: "file:line — issue". No detailed block.
  If a LOW finding has no clear action, omit it.
```

2. **修改 `skills/baton-plan/review-prompt.md`** — 同样的输出格式指令

3. **可选: 修改 `skills/baton-review/SKILL.md`** — 在 severity taxonomy 后添加输出压缩规则

### 验证

- 下次 baton-review 调度时，LOW findings 以一行格式出现
- 读取 review-prompt.md 确认格式指令存在

---

## Phase 5: 修复预存测试失败 [MEDIUM]

### 问题

5 个测试文件有预存失败（共 ~28 个 assertion 失败），全部因为测试检查的文本 pattern 与实际输出不一致。

### 方案

逐个修复。大多数是字符串匹配更新（文本变了但测试没跟上）。

### 变更清单

| 测试 | 失败数 | 根因 | 修复类型 |
|------|--------|------|---------|
| test-phase-guide.sh | ~5 | guidance 文本检查 "approach"/"constraints"/"批注区" 但输出已变 | 更新 pattern |
| test-constitution-consistency.sh | ~3 | 检查 "Authority Model" 但已改为 "Authority" | 更新 pattern |
| test-annotation-protocol.sh | 21 | 检查 "[PAUSE]"/"Annotation Log"/"infers intent" 等已删除功能 | 删除过时 assertion 或更新 |
| test-write-lock.sh | 2 | multi-plan edge case 行为变更 | 更新预期值 |
| test-bash-guard.sh | 2 | edge case 行为变更 | 更新预期值 |

### 验证

- `bash tests/test-full.sh` → 所有测试通过（如果 Phase 3 已完成，则 0 regressions + 0 known failures）
- 如果 Phase 3 未完成，则直接 exit 0

### 依赖

Phase 3（baseline mechanism）不是必须的前置——可以直接修复测试。但如果先做 Phase 3，则可以逐步修复（每修复一个就从 baseline 移除一个）。

---

## Phase 6: Constitution defense model 修正 [LOW]

### 问题

Constitution §Defense Model 声称"三层防御：self-check + context-isolated review + human annotation"。实证表明前两层由同模型执行时退化为一层。

### 方案

更新 §Defense Model 的描述，反映实际有效的防御结构。

### 变更

修改 `constitution.md` §Defense Model：

**现有**:
```
The defense is layered: self-challenge (self-check) + context-isolated review
(independent check) + human annotation cycle (human check). Each layer can fail;
no single-layer failure should defeat governance.
```

**修改为**:
```
The defense is layered:
1. Same-model review (self-check + context-isolated review) — catches structural,
   consistency, and format issues. Context isolation reduces generation bias but
   does not eliminate shared model blind spots.
2. Cross-source review (cross-model evaluation or human annotation) — catches
   assumption errors, external system mismatches, and reasoning blind spots that
   same-model review cannot detect.

Layer 1 alone is insufficient. Critical plans and implementations require at
least one Layer 2 review before completion.
```

### 验证

- 读取确认文本更新
- `bash tests/test-constitution-consistency.sh` 通过（如果 Phase 5 已修复）

---

## 实施顺序

```
Phase 1 (evolve 废弃)  ─┐
Phase 4 (review 噪声)   ├── 独立，可并行
Phase 6 (constitution)  ─┘
           │
Phase 2 (上下文瘦身) ── 依赖 Phase 1（evolve 删除后才知道最终行数）
           │
Phase 3 (baseline)   ─── 独立
           │
Phase 5 (测试修复)   ─── 建议在 Phase 3 之后（可逐步从 baseline 移除）
```

**最小有效集合**: Phase 1 + Phase 3 + Phase 5 = 删除无效 skill + 让测试套件可用

**完整集合**: 全部 6 个 Phase

---

## Self-Challenge

1. **Phase 2（上下文瘦身）的 ROI 是否值得？** ~1,500 tokens 节省 vs 审计 5-7 个文件的工作量。真正的 context 消耗大头是外部 skill 列表（gstack 的 ~100 个 skill description），不在 baton 控制范围内。但去重本身是正确的——重复指令不仅浪费 token，还可能导致不一致（修改一处忘记另一处）。**值得做，但优先级不是最高。**

2. **Phase 3（baseline）是否过度工程化？** 一个简单的文本文件 + 对比逻辑 ~20 行。ROI 明确：让 `test-full.sh` 可以区分 regression 和 known failure，使"全套测试通过"成为有意义的信号。**不过度。**

3. **Phase 5（修复预存失败）vs Phase 3（baseline）：做哪个？** 两个都做。Phase 3 让你能逐步修复（每修一个就从 baseline 移除），Phase 5 做真正的修复。如果只选一个：Phase 5（直接修复更好，baseline 只是 workaround）。

> **Weakest assumption**: Phase 2 的 token 节省估计（~1,500）基于行数推算，未实际测量 token 化后的差异。实际节省可能更小（markdown 格式符的 token 化不线性于行数）。
> **If wrong**: Phase 2 的优先级进一步降低，但去重的一致性价值仍然存在。
> **How to verify**: 修改前后分别用 `tiktoken` 计算实际 token 数。

## Eng Review Decisions (2026-03-21)

- Phase 1 expanded: delete evolve + install cross-model review routing in existing skills
- Phase 1 write set corrected: drop setup.sh/constitution.md (no references), add bin/baton, test-cli.sh, README.md
- Phase 1b added: bash-guard runtime fix (promoted to HIGH)
- Phase 2 demoted to LOW (optional)
- Phase 3 DROPPED: baseline mechanism obsoleted by Phase 5; granularity mismatch with test runners
- Phase 4 scope: global change in baton-review/SKILL.md, not per-skill review-prompt.md
- Phase 6 descoped: descriptive only, no new invariant; sequenced after Phase 5

## Todo

- [x] ✅ 1. Phase 1: 删除 baton-evolve + 清理引用 + 添加 cross-model review 路由
  Change: 删除 skills/baton-evolve/; 从 bin/baton doctor、using-baton/SKILL.md、README.md、test-cli.sh 移除 evolve 引用; 在 baton-plan/SKILL.md 和 baton-implement/SKILL.md 添加 cross-model review 建议
  Files: `skills/baton-evolve/` (delete), `bin/baton`, `skills/using-baton/SKILL.md`, `README.md`, `tests/test-cli.sh`, `skills/baton-plan/SKILL.md`, `skills/baton-implement/SKILL.md`
  Verify: `ls skills/baton-evolve/ 2>&1` → 不存在; `grep -r "baton-evolve" skills/ hooks/ bin/ tests/ README.md` → 无结果; `bash tests/test-cli.sh` 通过
  Deps: none
  Artifacts: none

- [x] ✅ 2. Phase 1b: 诊断 bash-guard baton-tasks/ plan 发现问题
  Change: 验证 bash-guard 在 plan 位于 baton-tasks/ 时是否正确发现。如果 parser 已处理则关闭；如果未处理则修复
  Files: 视诊断结果定（可能无需改动）
  Verify: 创建 baton-tasks/test-diag/plan.md with BATON:GO，从项目根运行 bash-guard 测试，确认写操作不被阻塞
  Deps: none
  Artifacts: none

- [x] ✅ 3. Phase 4: review 噪声抑制（全局）
  Change: 在 baton-review/SKILL.md severity taxonomy 后添加 Output Compression 规则
  Files: `skills/baton-review/SKILL.md`
  Verify: 读取确认规则存在；grep "Minor notes" 确认关键词
  Deps: none
  Artifacts: none

- [x] ✅ 4. Phase 5a: 修复 test-phase-guide.sh
  Change: 更新 guidance 文本 pattern 匹配实际输出
  Files: `tests/test-phase-guide.sh`
  Verify: `bash tests/test-phase-guide.sh` 通过
  Deps: none
  Artifacts: none

- [x] ✅ 5. Phase 5b: 修复 test-annotation-protocol.sh
  Change: 删除检查已移除功能的 assertion；更新检查已变更文本的 pattern
  Files: `tests/test-annotation-protocol.sh`
  Verify: `bash tests/test-annotation-protocol.sh` 通过
  Deps: none
  Artifacts: none

- [x] ✅ 6. Phase 5c: 修复 test-constitution-consistency.sh + test-write-lock.sh + test-bash-guard.sh
  Change: 更新 section name pattern；更新 multi-plan edge case 预期值
  Files: `tests/test-constitution-consistency.sh`, `tests/test-write-lock.sh`, `tests/test-bash-guard.sh`
  Verify: 三个测试均通过
  Deps: none
  Artifacts: none

- [x] ✅ 7. Phase 6: constitution defense model 修正（描述性）
  Change: 更新 §Defense Model 文本为两层防御描述，不添加强制条款
  Files: `constitution.md`
  Verify: 读取确认; `bash tests/test-constitution-consistency.sh` 通过
  Deps: 6 (test-constitution-consistency.sh 先修复)
  Artifacts: none

- [x] ✅ 8. 全套测试验证
  Change: 运行完整测试套件确认 0 failures
  Files: none
  Verify: `bash tests/test-full.sh` → exit 0, 全部通过
  Deps: 1, 2, 3, 4, 5, 6, 7
  Artifacts: none

## 批注区

<!--
Processing rules:
- Read underlying evidence before responding
- Do not rewrite a challenge into a weaker one
- If accepted: update the relevant section
- If rejected: explain with evidence
- If unresolved: keep as ❓
- Impact = "blocks next phase" → document goes BLOCKED until resolved
-->

<!--
Per annotation, copy this block:

### [Annotation N]
- **Trigger / 触发点**:
- **Intent as understood / 理解后的意图**:
- **Response / 回应**:
- **Status**: ✅ / ❌ / ❓
- **Impact**: none / clarification only / affects conclusions / blocks next phase
-->

<!-- BATON:GO -->
