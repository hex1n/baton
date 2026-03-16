# Plan: baton-research Skill Improvement

## State: APPROVED

## Requirements

From research conclusions + human judgment answers:

1. [Research C1] Add Orient phase — mandatory familiarity + evidence type assessment; full System Baseline section when familiarity low [HUMAN] chat: "给出最佳的方案" → conditional approach
2. [Research C3] Add external research quality criteria — source hierarchy, quality gates, primary source minimum [HUMAN] chat: "至少有一份一手资料"
3. [Research C2] Keep as one skill, don't split [Research validated]
4. [Research C4] Fix skill selection in constitution.md Authority Model [HUMAN] chat + analysis: existing Authority Model has the right structure but doesn't address external skill systems
5. [HUMAN] chat: Extract shared infrastructure to common reference file — "提取到一个通用参考文件中"

## First Principles Decomposition

**Problem**: baton-research produces inconsistent quality because (a) it doesn't adapt strategy to investigator's starting position, (b) external research lacks quality infrastructure, (c) the skill is already 500 lines and additions would worsen this.

**Constraints**:
- Must work for AI agents with varying capability — clear, not subtle
- Must stay one skill — no split
- Shared infrastructure must be referenceable by other phase skills
- constitution.md change must be minimal — fill the gap, not restructure

**Solution categories**:

| Category | Description | Verdict |
|----------|-------------|---------|
| A. Add Orient + external quality inline | Just add sections to existing skill | Rejected: pushes to 650+ lines, doesn't solve reuse |
| B. Add Orient + external quality + extract shared infra | Add new sections, move shared pieces to reference file | **Selected**: addresses all requirements |
| C. Rewrite skill from scratch | Redesign process structure | Rejected: high risk, current Investigate/Converge phases are strong |

## Surface Scan

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| `.claude/skills/baton-research/SKILL.md` | L1 | modify | Primary target — add Orient, add external quality, replace shared sections with references |
| `.baton/constitution.md` | L1 | modify | Authority Model — add one sentence clarifying phase skill precedence over external skills |
| `.claude/skills/baton-research/investigation-infrastructure.md` | L1 | create | Extracted shared infrastructure — evidence standards, self-challenge, review, 批注区 |
| `.claude/skills/baton-research/template-codebase.md` | L1 | create | 代码库研究输出模板 |
| `.claude/skills/baton-research/template-external.md` | L1 | create | 外部研究输出模板 |

No other files reference baton-research's internal structure, so no L2 impacts.

## Approach

### Change 1: `.baton/constitution.md` — Authority Model clarification

In the Authority Model section, under "3. Phase skills", add one sentence:

> Phase skills are the authoritative skills for their respective phases.
> When other installed skill systems provide overlapping capabilities,
> the baton phase skill takes precedence within a baton project.

**Why this works**: The Authority Model already defines the layered priority. The gap is that it's silent on external skill systems. One sentence fills it without restructuring.

**Why not more**: Listing specific skills ("use baton-review not superpowers:code-review") would be brittle. The principle is general: baton phase skills own their phases.

### Change 2: `.claude/skills/baton-research/investigation-infrastructure.md` — shared infrastructure

Extract from current baton-research skill (placed in baton-research directory per 批注1; migrate to shared location if other skills need it later):

**Section 1: Extended Evidence Standards** (~30 lines)
- Additional labels: `[DESIGN]`, `[EMPIRICAL]` (extends constitution's evidence model)
- Conflict resolution rules (runtime > stale docs, code > comments, etc.)
- Evidence provenance rule for multi-move investigations
- Note: references constitution.md Evidence Model as base

**Section 2: Self-Challenge Template** (~15 lines)
- Three questions (weakest conclusion, uninvestigated areas, unverified assumptions)
- Visible output requirement
- Depth standard

**Section 3: Review Protocol** (~35 lines)
- Option A: Isolated review via subagent (when, how)
- Option B: Structured self-review (when, how, four questions)
- Selection criteria

**Section 4: 批注区 Protocol** (~45 lines)
- Required format per annotation item
- Processing rules
- Escalation heuristic
- Template

Total: ~125 lines. These are currently ~120 lines in baton-research. Net effect: research skill shrinks by ~120 lines, shared file adds ~125 lines, other phase skills can reference the same infrastructure.

### Change 3: `.claude/skills/baton-research/SKILL.md` — main rewrite

**3a. Add Step 0.25: Orient** (new, ~50 lines)

Insert between Step 0 (Frame) and Step 0.5 (Investigation Methods).

Two mandatory assessments:

**Assessment A — System familiarity:**
- State current understanding level: none / partial / deep
- If **none or partial** → produce a `## System Baseline` section in the artifact before proceeding to targeted investigation. Baseline covers: project purpose, module/layer structure, key abstractions, primary data flows, conventions.
- If **deep** → state existing understanding in 3-5 sentences, proceed to targets

**Assessment B — Primary evidence type:**
- **Codebase-primary** → investigation strategy follows code structure (top-down for unfamiliar, targeted for familiar)
- **External-primary** → must establish source landscape before investigating. Map authoritative sources available for this topic before reading any of them.
- **Mixed** → state which type is primary for each sub-question

The Orient step produces a **strategy statement**: given my familiarity and evidence type, here is how I will approach this investigation. This naturally feeds Step 2's uncertainty-driven process.

**3b. Add external research quality infrastructure** (new, ~45 lines)

Add as a new section between investigation moves and Step 2b (Synthesis):

**External Source Evaluation** — applies when evidence type is external-primary or mixed:

Source hierarchy (strongest → weakest):
1. Official documentation + version match confirmed
2. Official source code / reference implementation
3. Peer-reviewed / widely-cited technical analysis
4. Well-maintained community resources (with recency check)
5. Blog posts, tutorials, AI-generated summaries — leads, not evidence

Quality gates per external source:
- Currency (date/version)
- Authority (primary vs secondary)
- Verification (can it be checked against source/runtime?)
- Applicability (does it match our context?)

Hard rule: Each conclusion that depends on external evidence must cite ≥1 primary source. Secondary-only conclusions are marked ❓ with explicit note.

**3c. Add external-oriented investigation moves** (new, ~30 lines)

Add to the "Common investigation moves" section:

- **Map the source landscape** — Before reading, identify what authoritative sources exist. Official docs? Source repos? Standards? Reference implementations? This prevents the "skim 10 blogs" failure mode.
- **Verify claim against primary source** — When secondary source makes a claim, trace it to primary. Unverifiable → ❓.
- **Assess applicability** — After understanding an external source, explicitly evaluate: does this apply to our version, platform, use case?

**3d. Replace shared sections with references** (net -120 lines)

- Step 3 (Evidence Standards) → reference `./investigation-infrastructure.md` Section 1
- Step 4 (Self-Challenge) → reference `./investigation-infrastructure.md` Section 2
- Step 5 (Review) → reference `./investigation-infrastructure.md` Section 3
- Annotation Protocol → reference `./investigation-infrastructure.md` Section 4

Keep a one-line summary + reference link for each. The skill's own content focuses on research-specific process.

**3e. Extend Red Flags table** (add 2 rows)

| "I know this system well enough" | Familiarity is an assessment, not an assumption. Record it in Orient. |
| "I found several blog posts confirming this" | Blogs are leads, not evidence. Trace to primary source. |

**3f. Dual output templates + community improvements** (per 批注2 + 社区研究)

完整模板设计见 `./template-design.md`。Orient 的 Assessment B 决定模板选择。

**代码库研究模板** — 特有节:
- `## System Baseline` (熟悉度低时必填: 5 个问题驱动，每个要求 [CODE] file:line 证据)
- Investigation 按 investigation move 组织
- `## Cross-Move Synthesis`

**外部研究模板** — 特有节:
- `## Source Landscape` (必填: 权威源映射表 + 覆盖度评估 + 源选择理由)
- `## Source Evaluations` (每个源: type/currency/claims/verification/applicability/trust level)
- Investigation 按主题/维度组织，每条 finding 标注来源 + 一手源
- `## Cross-Source Synthesis`

**混合研究**: 以主要类型选模板，加次要类型补充节。

**共享节** (两个模板都有):
- Frame / Orient / Investigation Methods / Counterexample Sweep
- Self-Challenge + Review (引用 infrastructure)
- One-Sentence Summary (Alexandrian ADR: 强制一句话压缩，写不出=理解不够)
- Final Conclusions (每条加 Verification path: 如何验证这个结论)
- Questions for Human Judgment (Rust RFC 三级: blocks plan / can wait / out of scope)
- 批注区 (引用 infrastructure)

模板通过输出结构强制正确行为——空节比跳过的步骤更显眼，也更容易 review。

**Net effect on skill length**: +50 (Orient) + 45 (external quality) + 30 (external moves) + 15 (template selection + read instruction, not full templates) - 120 (extracted) + 5 (red flags) = **~25 lines net increase**. Target: ~525 lines. Templates in separate files (~80-100 lines each).

Orient 步骤完成后，skill 中明确写：**"Read the applicable template file (`./template-codebase.md` or `./template-external.md`) before proceeding to investigation."** 用指令强制读取，不依赖暗示。

### Verification Strategy

1. Read the modified skill end-to-end and verify internal consistency
2. Verify all cross-references between skill → infrastructure file → constitution.md resolve correctly
3. Verify the extracted infrastructure file is self-contained and doesn't assume research-specific context
4. Verify the constitution.md change is minimal and doesn't alter existing semantics

### Write Set

- `.baton/constitution.md` — modify (1 sentence addition)
- `.claude/skills/baton-research/investigation-infrastructure.md` — create
- `.claude/skills/baton-research/template-codebase.md` — create
- `.claude/skills/baton-research/template-external.md` — create
- `.claude/skills/baton-research/SKILL.md` — modify (add Orient, add external quality, add template selection + read instruction, replace shared sections with references, extend red flags)

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| AI agents ignore Orient step | Medium — same problem continues | Orient is structural: Step 1 references it, System Baseline is a visible artifact section |
| Extracted infrastructure loses context | Low — content is self-contained | Each section has its own purpose statement and usage conditions |
| Constitution change too subtle to be effective | Medium — skill selection still fails | The sentence is in the Authority Model which is already high-authority text; phrasing is direct |
| External quality criteria too strict | Low — may slow research | The "leads not evidence" framing allows using secondary sources, just not as final evidence |

## Self-Challenge

1. **Is this the best approach?** Category C (full rewrite) would allow a cleaner structure but risks breaking what works. The current Investigate and Converge phases are battle-tested. Adding Orient and external quality as targeted additions preserves what works while fixing what doesn't.

2. **Unverified assumptions?** The biggest: that AI agents will follow the Orient step. Mitigation is structural (Step 1 depends on it, System Baseline is visible output), but only real usage will confirm. If it doesn't work, the next iteration would be to make Orient produce a required output section that later steps explicitly consume.

3. **What would a skeptic challenge?** "Adding 3 new sections to an already complex skill — won't agents just skip more?" Fair point. The extraction of shared infra keeps net length stable. The Orient step is short and produces a clear output (strategy statement + optional baseline). The external quality section only activates for external research. Complexity increase is bounded.

## 批注区

### [Annotation 1]
- Trigger / 触发点: investigation-infrastructure.md 就放在baton-research 目录下不行吗?
- Intent as understood / 理解后的意图: 质疑是否需要新建 `.baton/references/` 目录，放在 baton-research 目录下更简单
- Response / 回应:

**可以放。** 分析两种放置方案：

| 维度 | `.baton/references/` | `.claude/skills/baton-research/` |
|------|---------------------|----------------------------------|
| 简单性 | 需要新建目录 | 目录已存在，零额外结构 |
| 复用信号 | 位置本身表明是共享的 | 看起来像 research 专属文件 |
| 当前实际复用 | 无——目前只有 research 引用 | 一致 |
| 未来复用 | 其他 skill 引用时路径合理 | 其他 skill 引用 research 目录下的文件，语义别扭 |

**结论**：当前只有 research 引用这个文件，放在 baton-research 目录下更务实。如果未来 baton-plan 或 baton-review 也需要引用，再迁移到共享位置。遵循 YAGNI。

**Plan impact**: 修改 write set——将 `investigation-infrastructure.md` 放在 `.claude/skills/baton-research/` 下，删除新建 `.baton/references/` 目录。

- Status: ✅ accepted
- Impact: affects plan — write set 和 Surface Scan 需要更新

### [Annotation 2]
- Trigger / 触发点: 研究代码库和外部调查如果分别使用两个模版呢? 分析可行性以及优缺点
- Intent as understood / 理解后的意图: 用不同的输出模板来引导不同类型的研究，而不仅仅靠流程指导

- Response / 回应:

这个想法切中了一个更深的点：**输出结构驱动行为，比流程指令更强**。AI 看到模板里有 "System Baseline" 这个节，就会去填它；光说 "你应该先了解架构" 可能被忽略。

**可行性**: 高。Orient 步骤的 Assessment B 已经判断了 evidence type（codebase / external / mixed），可以直接基于这个判断选择模板。

**两个模板的草案结构**:

代码库研究模板:
```
## Frame (问题/为什么/范围)
## Orient (熟悉度评估 + 策略)
## System Baseline (项目目的/模块结构/关键抽象/数据流) ← 熟悉度低时必填
## Investigation Methods
## Investigation (按 investigation move 组织)
## Cross-Move Synthesis (如需)
## Counterexample Sweep
## Self-Challenge
## Review
## Final Conclusions
## Questions for Human Judgment
## 批注区
```

外部研究模板:
```
## Frame (问题/为什么/范围)
## Orient (领域熟悉度 + 策略)
## Source Landscape (可用权威源映射) ← 必填
## Investigation Methods
## Source Evaluations (每个源: 权威性/时效性/适用性评估)
## Investigation (按主题/维度组织，每个结论标注一手源)
## Cross-Move Synthesis (如需)
## Counterexample Sweep
## Self-Challenge
## Review
## Final Conclusions
## Questions for Human Judgment
## 批注区
```

**关键差异**:
- 代码库模板有 `System Baseline`，外部模板有 `Source Landscape` + `Source Evaluations`
- 代码库按 investigation move 组织 findings，外部按主题/维度组织
- 外部模板的 Final Conclusions 要求每条结论标注 ≥1 一手源

**混合研究**: 以主要类型选模板，在模板中加一个节处理次要类型。比如以代码库为主，加一个 `## External Sources` 节。

**优点**:
1. 输出结构天然强制正确行为（System Baseline 必须填 → 架构优先；Source Landscape 必须填 → 信源质量优先）
2. 比流程指令更难被忽略——空节比跳过的步骤更显眼
3. 让 review 更容易——reviewer 可以检查模板是否填完整
4. 两种研究的质量标准各自清晰，不互相稀释

**缺点**:
1. 多了模板选择决策（但 Orient 步骤已经做了这个判断，成本低）
2. 混合研究需要组合处理，不如单一模板简单
3. skill 描述需要包含两个模板，增加 ~30 行

**结论**: 模板方案比纯流程指导更强，因为它通过输出结构强制行为。建议采纳。Orient 步骤 + 模板选择是自然的组合：Orient 判断类型 → 选择模板 → 模板结构引导输出质量。

**Plan impact**: 需要修改 Change 3 和 Output 节——将单一输出模板改为两个模板，由 Orient 步骤的 Assessment B 决定使用哪个。

- Status: ✅ accepted
- Impact: affects plan — Change 3 和 Output 节需要更新

## Todo

- [x] 1. Constitution Authority Model clarification
  Change: Add 2 sentences to Authority Model section under "3. Phase skills" — phase skills take precedence over external skill systems
  Files: `.baton/constitution.md`
  Verify: Read modified section, confirm it doesn't alter existing semantics and the new text follows naturally from existing content
  Deps: none
  Artifacts: none

- [x] 2. Create investigation-infrastructure.md
  Change: Extract shared infrastructure from current SKILL.md — evidence standards (with [DESIGN]/[EMPIRICAL] labels, conflict resolution), self-challenge template, review protocol (options A/B), 批注区 protocol (format, rules, escalation, template)
  Files: `.claude/skills/baton-research/investigation-infrastructure.md`
  Verify: Read file end-to-end, confirm each section is self-contained and doesn't assume research-specific context; verify it references constitution.md Evidence Model as base
  Deps: none
  Artifacts: `investigation-infrastructure.md`

- [x] 3. Create template-codebase.md
  Change: Create codebase research output template per template-design.md — Frame, Orient, System Baseline (5 questions with evidence requirements + 达标判据), Investigation Methods, Investigation (per move), Cross-Move Synthesis, Counterexample Sweep, Self-Challenge/Review (reference infrastructure), One-Sentence Summary, Final Conclusions (with Verification path), Questions for Human Judgment (3-tier), 批注区
  Files: `.claude/skills/baton-research/template-codebase.md`
  Verify: Read template, verify every section has guidance questions (not just headings); verify System Baseline has 5 questions + 达标判据; verify Final Conclusions requires Verification path; verify Questions uses 3-tier format; verify references to infrastructure.md are correct
  Deps: 2 (references infrastructure.md)
  Artifacts: `template-codebase.md`

- [x] 4. Create template-external.md
  Change: Create external research output template per template-design.md — Frame (with Target context), Orient, Source Landscape (authority table + coverage assessment + source selection + 达标判据), Investigation Methods, Source Evaluations (per source: type/currency/claims/verification/applicability/trust), Investigation (per topic with primary source requirement), Cross-Source Synthesis, Counterexample Sweep, Self-Challenge/Review (reference infrastructure), One-Sentence Summary, Final Conclusions (with Primary source + Applicability + Verification path), Questions for Human Judgment (3-tier), 批注区
  Files: `.claude/skills/baton-research/template-external.md`
  Verify: Read template, verify Source Landscape has authority table + coverage assessment + 达标判据; verify Source Evaluations has all 6 fields; verify Investigation requires primary source per finding; verify Final Conclusions requires primary source + applicability; verify references to infrastructure.md are correct
  Deps: 2 (references infrastructure.md)
  Artifacts: `template-external.md`

- [x] 5. Rewrite SKILL.md
  Change: (a) Add Step 0.25 Orient with Assessment A (familiarity) + Assessment B (evidence type) + template selection + explicit read instruction; (b) Add external source evaluation section (source hierarchy, quality gates, primary source hard rule); (c) Add 3 external investigation moves (map source landscape, verify against primary, assess applicability); (d) Replace Step 3/4/5/Annotation Protocol with references to infrastructure.md; (e) Extend Red Flags table (+2 rows); (f) Update Output section to reference dual templates
  Files: `.claude/skills/baton-research/SKILL.md`
  Verify: Read entire modified skill end-to-end; verify Orient step is between Step 0 and Step 0.5; verify template read instruction is explicit; verify mixed-research template selection guidance is present (Orient selects primary template + supplementary section for secondary type); verify all 4 references to infrastructure.md resolve; verify external quality section exists; verify 3 new investigation moves exist; verify Red Flags has 2 new rows; verify Output section references both templates AND updates Required section structure list to reflect template-based output; check total line count is ~400-525
  Deps: 2, 3, 4 (references all three new files)
  Artifacts: modified `SKILL.md`

## Retrospective

- **Wrong prediction**: Plan estimated ~525 lines for SKILL.md, actual is 489. The extraction was more aggressive than anticipated — shared infrastructure and templates absorbed more content than estimated. This is a positive outcome.
- **Surprise**: The review caught a stale `workflow.md` reference that predated this task. Renaming happened in an earlier commit (97ed39d) but the research skill wasn't updated. Shows value of end-to-end read during review.
- **Research improvement for next time**: The external research agent (community template search) produced output in raw JSON conversation format that was very hard to consume. Future research tasks should specify structured output format requirements for sub-agents, or use a dedicated research-output file instead of relying on the agent's raw transcript.

<!-- BATON:COMPLETE -->