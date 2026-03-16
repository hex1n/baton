# Research: baton-research Skill Improvement

## Question
How should baton-research be improved to address observed quality problems?

## Why
baton-research is baton's research phase skill. Real-world usage exposed three classes of failure. The improvement must address root causes, not patch symptoms.

## Scope
- In scope: baton-research skill design, process structure, quality criteria
- Out of scope: other baton skills (plan, implement, review), constitution changes

## Known constraints
- Skill is ~500 lines, already complex
- Used by AI agents with varying capability levels
- Must work for both codebase and external research tasks

## Claimed framing
User reported three problems:
1. AI didn't automatically use baton-research (skill selection problem)
2. Research on new codebase jumped to line-by-line detail without establishing architecture
3. AI used wrong review skill (superpowers:code-review instead of baton-review)

## What must be validated before accepting that framing
- Are these three independent problems, or symptoms of a shared root cause?
- Is the fix inside baton-research, or elsewhere?

---

## Investigation Methods
1. [CODE] Direct analysis of current baton-research skill.md structure
2. [EMPIRICAL] Community/official research approaches (collected via prior web search)
3. [DESIGN] First-principles decomposition of "what is research?"

---

## Investigation

### Move 1: First-principles decomposition — What is research?

**Question**: What are the irreducible components of research as an activity?

Research is **reducing uncertainty to enable a decision**. Any research process has three fundamental phases:

1. **Orient** — Assess starting position. What do I know? What don't I know? What's the landscape?
2. **Investigate** — Gather evidence to reduce the most critical uncertainties
3. **Converge** — Synthesize evidence into conclusions that support decisions

This maps to military OODA (Observe-Orient-Decide-Act), scientific method (hypothesis-experiment-conclusion), and Anthropic's own recommendation (Explore-Plan-Implement-Commit).

**Finding**: The three-phase structure is fundamental. Any research process that skips or underdevelops one phase will produce systematic failures. [DESIGN] ✅

### Move 2: Map current skill to the three phases

**Question**: How does the current baton-research skill map to Orient / Investigate / Converge?

| Phase | Current baton-research mapping | Strength |
|-------|-------------------------------|----------|
| Orient | Step 0 (Frame Investigation) | **Weak** — frames the *question* but not the *investigator's position* |
| Investigate | Steps 0.5, 0.75, 1, 2, 2b, 2c | **Strong** — rich investigation moves, evidence standards, synthesis |
| Converge | Steps 3, 4, 5, 6 | **Strong** — evidence standards, self-challenge, review, convergence check |

**Finding**: The Orient phase is underdeveloped. Step 0 defines *what* to investigate but not *where the investigator stands*. It doesn't assess:
- How familiar am I with this system/domain?
- What type of evidence will I primarily be working with?
- What investigation strategy follows from the above?

This is the root cause of problem #2 (jumping to line-level detail). The skill goes from "here's the question" to "here are investigation targets" without establishing baseline understanding. [CODE] baton-research/skill.md:Step 0 → Step 1 ✅

### Move 3: Analyze the three reported problems against this root cause

**Question**: Do all three problems trace to the weak Orient phase?

**Problem 1: AI didn't auto-use baton-research**
- Root cause: This is a **skill selection** problem, not a research process problem
- The AI had multiple skills available and chose wrong
- Fix location: outside baton-research (constitution.md or skill metadata)
- **Verdict: NOT an Orient phase problem** [DESIGN] ✅

**Problem 2: Research jumped to line-by-line detail on new codebase**
- Root cause: No assessment of familiarity → no strategy adaptation
- On new codebase, the most critical uncertainty IS "what is this system?"
- Step 2's "drive by most blocking uncertainty" should lead to architecture-first, but in practice the AI doesn't perform this reasoning because the skill doesn't prompt it
- **Verdict: Orient phase problem** [EMPIRICAL] ✅

**Problem 3: Used wrong review skill**
- Root cause: Same as #1 — skill selection, not research process
- **Verdict: NOT an Orient phase problem** [DESIGN] ✅

**Finding**: The three problems have TWO distinct root causes:
- **Root Cause A** (problems 1 & 3): Skill selection priority — baton skills not recognized as primary in baton projects
- **Root Cause B** (problem 2): Missing orientation step — research strategy not adapted to investigator's starting position

### Move 4: Analyze external research quality from first principles

**Question**: Does the current skill adequately handle external research (docs, APIs, ecosystem)?

External research differs from codebase research on fundamental axes:

| Dimension | Codebase Research | External Research |
|-----------|------------------|-------------------|
| Evidence accessibility | Complete — full repo | Partial — web, docs |
| Evidence reliability | High — code is truth | Variable — needs source evaluation |
| Verification method | Direct — run it, trace it | Indirect — cross-reference, test claims |
| Failure mode | Missing forest for trees | Shallow breadth, no depth |
| Key strategy question | "What is this system?" | "Which sources can I trust?" |

The current skill's investigation moves are almost entirely code-oriented:
- "Trace actual behavior" — code tracing
- "Build systematic coverage" — multi-surface code checking
- "Probe an unknown assumption" — mostly code assumptions

For external research, the skill relies on generic evidence labels (`[DOC]`) and Step 0.5 (investigation methods). But it lacks:
1. **Source evaluation criteria** — Not all docs are equal. Official docs > blog posts > Stack Overflow > AI-generated content. Version/date matters.
2. **Depth vs breadth guidance** — When to stop searching and start verifying. Reading 3 sources deeply > skimming 10.
3. **Applicability assessment** — Does this external finding actually apply to our specific context?
4. **Staleness detection** — AI may be using training data instead of actually fetching current information.

**Finding**: The current skill's investigation framework was designed primarily for codebase research. External research is nominally supported but lacks the quality infrastructure that makes codebase research strong. [CODE] baton-research/skill.md:investigation moves ❌

### Move 5: Should codebase and external research be separate skills?

**Question**: From first principles, when is splitting justified?

Split is justified when:
1. The processes diverge enough that one unified process harms quality
2. The quality criteria are different enough to need separate enforcement
3. The cognitive overhead of choosing between two skills < overhead of misapplying one

Assessment:

| Criterion | Assessment |
|-----------|-----------|
| Process divergence | **Moderate** — Orient differs significantly; Investigate differs; Converge is shared |
| Quality criteria divergence | **Significant** — source evaluation only applies externally; trace depth only applies internally |
| Cognitive overhead of choosing | **High risk** — user already reported "didn't use right skill" as a problem |

**Arguments against splitting:**
- The convergence infrastructure (evidence model, self-challenge, review, 批注区) is identical and would be duplicated
- Many real tasks mix both types
- Adding a skill increases the skill selection problem (root cause A)
- The shared OODA-like framework (orient → investigate → converge) applies to both

**Arguments for splitting:**
- Each can optimize strategy and quality criteria independently
- The skill is already 500 lines; adding external research quality infrastructure would push it further
- Cleaner separation of concerns

**Finding**: The core process framework (orient → investigate → converge) and the quality infrastructure (evidence model, self-challenge, convergence) should NOT be split. But the **strategy layer** (what to orient on, which investigation moves to use, what quality criteria to apply) diverges enough that it needs differentiated guidance within the same skill. [DESIGN] ✅

### Move 6: Analyze community approaches for structural inspiration

**Question**: What structural patterns from community approaches address these problems?

Key patterns observed:

1. **HumanLayer FIC**: Research output rule — "ONLY describe what exists, where it exists, how it works, and how components interact." This is an architecture-first orientation enforced by output format. [DOC] ✅

2. **brilliantconsultingdev**: Three parallel specialists — locator, analyzer, pattern-finder. The structure forces architecture understanding (locator finds structure) before detail analysis (analyzer reads implementation). [DOC] ✅

3. **Cline Silent Investigation**: Four-phase — silent investigation → discussion → plan → tasks. The "silent investigation" phase is pure orientation — read files, trace dependencies, examine patterns, no user interaction. [DOC] ✅

4. **Anthropic official**: Warns against "infinite exploration" anti-pattern. Recommends scoped investigation + subagents to prevent context pollution. [DOC] ✅

**Structural insight**: The community approaches that work best all have an **explicit orientation phase that produces a structural understanding BEFORE targeted investigation begins**. This isn't optional or adaptive — it's mandatory. The specific approach varies (parallel agents, silent investigation, output format constraints) but the principle is universal.

For external research, no community approach stood out as having strong quality infrastructure. This is a gap across the ecosystem. [DOC] ❓

---

## Cross-Move Synthesis

- **Moves used**: First-principles decomposition, skill mapping, problem analysis, external research analysis, split analysis, community analysis
- **Why each was needed**: Decomposition established framework; mapping identified gap; problem analysis validated root causes; external analysis revealed second gap; split analysis determined architecture; community analysis provided structural inspiration
- **Key findings by move**:
  - Orient phase is underdeveloped (Move 2)
  - Two distinct root causes: skill selection + missing orientation (Move 3)
  - External research lacks quality infrastructure (Move 4)
  - Don't split the skill; differentiate strategy within unified process (Move 5)
  - Community universally has explicit orientation before investigation (Move 6)
- **Where findings reinforce each other**: Moves 2, 3, 6 all point to Orient as the gap. Move 5 confirms unified skill is better.
- **Where findings remain in tension**: Move 4 (external research needs its own quality infra) vs Move 5 (don't split) — resolved by adding external-specific quality criteria within the unified skill
- **What remains unresolved**: Exactly how to handle mixed research (both codebase and external in one task)

---

## Counterexample Sweep

**Leading interpretation**: Add a stronger Orient phase + external research quality criteria to the existing unified skill.

**Disproving evidence sought**: Cases where a unified skill with adaptive strategy performs worse than separate skills.

**What was checked**:
- Would the skill become too long/complex to follow? Current 500 lines + ~100-150 lines = ~650 lines. Substantial but the additions are self-contained sections, not cross-cutting changes.
- Would AI agents ignore the orientation step? Risk exists, but the same risk applies to separate skills being ignored (problem #1). The orientation step can be enforced structurally by making Step 1 depend on it.
- Would mixed research tasks suffer? A unified skill handles mixed tasks naturally; separate skills would need a "coordinator" pattern.

**Result**: No strong disproving evidence found. The main risk (skill length/complexity) is real but manageable.

**Effect on confidence**: Maintains recommendation. The complexity concern should be addressed by keeping additions focused.

---

## Self-Challenge

1. **Weakest conclusion**: "Don't split" is based partly on the argument that "more skills = harder to select the right one." But skill selection is fixable separately (constitution.md). If skill selection were solved, would splitting be better? Possibly — but the convergence infrastructure duplication and mixed-task coordination cost still argue against it. Confidence: medium-high.

2. **What I didn't investigate**: Actual performance of orientation-first approaches vs the current approach on real tasks. This is an empirical question that can only be answered by trying it.

3. **Assumptions not verified**:
   - That AI agents will actually follow a strengthened Orient step (might ignore it like they ignore other steps)
   - That ~150 lines of additions won't push the skill past a complexity threshold where agents start skipping sections
   - That external research quality is best addressed through criteria rather than process constraints

---

## Self-Review

1. **What is the actual problem?** The skill's research strategy doesn't adapt to the investigator's starting position or evidence type. It assumes a moderately informed investigator working with code.

2. **Is this solving the right problem?** Yes — the user's feedback about "jumped to line-by-line" and "external research quality" both trace to missing strategic adaptation. Problem #1 (skill selection) is correctly identified as out-of-scope for this skill.

3. **What fundamentally different approaches were not considered?**
   - Complete rewrite with a different framework (e.g., structured as decision trees instead of linear steps)
   - Splitting into 3+ skills (orient, investigate-code, investigate-external, converge)
   - Making the skill minimal and relying on AI judgment

   These were considered implicitly but not explored deeply. The decision tree approach is interesting but would be a much larger change.

4. **Does each piece serve the stated problem?** Yes. Orient phase addresses codebase orientation. External research criteria address external quality. No unrelated additions proposed.

---

## Final Conclusions

### Conclusion 1: The root cause is a weak Orient phase
- **Confidence**: High — three independent evidence lines (first-principles mapping, user's reported failure, community universal pattern)
- **Evidence**: Move 2 (skill mapping), Move 3 (problem analysis), Move 6 (community patterns)
- **Uncertainty**: Whether strengthening Orient is sufficient, or if the investigation phase also needs structural changes
- **Plan implication**: Actionable

### Conclusion 2: Do NOT split into two skills
- **Confidence**: Medium-high — the arguments against splitting are stronger, but splitting would also work
- **Evidence**: Move 5 (split analysis), Move 3 (skill selection is already a problem)
- **Uncertainty**: If the skill becomes too long, splitting might become necessary later
- **Plan implication**: Actionable (design constraint for the improvement)

### Conclusion 3: External research needs dedicated quality criteria within the same skill
- **Confidence**: High — clear gap in current skill, no external quality infrastructure exists
- **Evidence**: Move 4 (external research analysis)
- **Uncertainty**: What the right quality criteria are (needs iteration)
- **Plan implication**: Actionable

### Conclusion 4: Skill selection priority (problems 1 & 3) must be fixed outside this skill
- **Confidence**: High — this is a cross-skill/cross-phase problem
- **Evidence**: Move 3 (problem analysis)
- **Uncertainty**: Where exactly to fix it (constitution.md, skill metadata, or both)
- **Plan implication**: Actionable but separate task

---

## Recommended Changes

### Change 1: Add "Step 0.25: Orient" between Frame and Investigation Methods

A mandatory orientation step that adapts strategy based on two assessments:

**Assessment A — Familiarity with the system:**
- **Low** (new project, unfamiliar domain): Must establish baseline understanding before targeted investigation. Baseline = project purpose, module structure, key abstractions, data flow, conventions. This is NOT optional — record the baseline in the research artifact before proceeding.
- **High** (known system): State what you already know and move to targeted investigation.

**Assessment B — Primary evidence type:**
- **Codebase-primary**: Evidence is in the repo. Investigation strategy follows code structure.
- **External-primary**: Evidence is in docs, APIs, ecosystem. Must establish source landscape and quality criteria before investigating.
- **Mixed**: Orient on both. State which dimension is primary for each sub-question.

The key insight: this step doesn't add rigid rules ("always do X for new projects"). It adds a **mandatory assessment** that naturally leads to the right strategy. "What do I know about this system?" → "Very little" → the most blocking uncertainty is system-level understanding → Step 2's uncertainty-driven approach naturally starts with architecture.

### Change 2: Add external research quality criteria

Add to the investigation moves (or as a new section):

**For external evidence sources, evaluate before trusting:**

Source hierarchy (strongest → weakest):
1. Official documentation + version match confirmed
2. Official source code / reference implementation
3. Peer-reviewed / widely-cited technical analysis
4. Well-maintained community resources (with recency check)
5. Blog posts, tutorials, AI-generated summaries (treat as leads, not evidence)

Quality gates:
- **Currency**: When was this written/updated? Does it match the version we're targeting?
- **Authority**: Is this an authoritative source or a summary of one?
- **Verification**: Can the claim be verified against source code or runtime behavior?
- **Applicability**: Does this apply to our specific context (version, platform, use case)?

Rule: Conclusions from external research must cite primary sources. Secondary sources (blogs, summaries) are starting points for finding primary sources, not evidence themselves.

### Change 3: Restructure investigation moves to include external-oriented moves

Current moves are mostly code-oriented. Add or expand:

- **Map the source landscape**: Before diving into external sources, identify what authoritative sources exist for this topic. Official docs? Source code? Reference implementations? Standards? Map what's available before reading.
- **Verify external claims against primary sources**: When a secondary source makes a claim, trace it to the primary source. If the primary source doesn't support it, the claim is ❓.
- **Assess applicability**: After understanding what an external source says, explicitly assess whether it applies to the current context (version, platform, constraints).

### Change 4 (separate task): Fix skill selection priority

This is not a baton-research change. Add to constitution.md or skill metadata:
- In a baton project, baton phase skills are the primary skills for their respective phases
- baton-research > any other research/investigation skill
- baton-review > any other review skill
- This applies regardless of what the AI's other installed skills suggest

---

## Questions for Human Judgment

1. **Scope of Orient step**: Should the baseline understanding for new systems be a full required section in the output artifact (like HumanLayer's approach), or just a recorded assessment that guides strategy? Full section = more overhead for familiar systems. Assessment = lighter but might be skipped.
    给出最佳的方案
2. **External research depth**: Should external research require a minimum of one primary source per conclusion, or is it enough to flag secondary-only conclusions as lower confidence?
    至少有一份一手资料 
3. **Skill length**: The additions would push the skill to ~650 lines. Is that acceptable, or should we look at extracting shared infrastructure (evidence model, self-challenge) into a common reference?
    提取到一个通用参考文件中
4. **Skill selection fix**: Should this go in constitution.md (as a cross-phase rule) or in each skill's metadata (as trigger priority)?
    你认为呢 给出理由
---

## 批注区

(No annotations yet)
