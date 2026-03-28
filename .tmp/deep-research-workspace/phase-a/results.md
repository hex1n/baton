# Phase A Results: Output-Quality Autoresearch

## Summary

**Goal**: Optimize deep-research skill by measuring actual research output quality, not skill text quality.

**Method**: Modify SKILL.md → run subagent on test prompt → grade output with rubric → keep/discard.

**Test prompt**: "Trace how baton's write-lock enforcement works end-to-end... I'm deciding whether the enforcement is robust enough for team deployment."

**Rubric**: Evidence specificity + Synthesis quality + Efficiency + Actionability (0-10 each, total 0-40).

## Results

| Iteration | Modification | Evidence | Synthesis | Efficiency | Actionability | Total | Decision |
|-----------|-------------|----------|-----------|------------|---------------|-------|----------|
| Baseline | — | 8 | 9 | 8 | 8 | **33** | — |
| 1 | Recommendation prioritization | 8 | 9 | 8 | 9 | **34** | KEEP |
| 2 | Table variance guidance | 8 | 8 | 7 | 8 | **31** | DISCARD |
| 3 | Contradiction simplification | 9 | 8 | 7 | 8 | **32** | DISCARD |

**Net change**: 33 → 34 (+1), 9417 → 9555 bytes (+1.5%)

## Key Findings

### 1. The skill is at a quality plateau

Scores oscillate 31-34 across runs (~±2 points), which is within LLM-as-judge noise. This confirms B1's finding at a different level: for a mature skill, incremental text modifications cannot reliably improve output quality beyond the noise floor of the grading mechanism.

### 2. The one keepable modification targets the right thing

Iteration 1 (recommendation prioritization) is the only change that improved scores, and specifically in the targeted dimension (actionability 8→9). The grader explicitly noted "recommendations section is prioritized (blockers vs improvements)" as a positive feature. Even if the +1 total is borderline noise, the modification is sound as guidance — it tells the investigator to separate blockers from nice-to-haves and state assumptions.

### 3. Adding constraints backfired (iter-2)

The table variance guidance ("if a column is uniform or restates inline citations, a summary sentence is better") produced a -3 drop. The agent likely became overcautious about tables, producing less organized output. **Lesson**: prescriptive format guidance can suppress useful output structure.

### 4. Simplification has diminishing returns after B1

Iteration 3 tried the same strategy that worked in B1 (compress text) but didn't improve scores. B1 already trimmed the low-hanging fruit (10921→9417 bytes). Further compression of the contradiction resolution protocol (-200 bytes) didn't help because the remaining content is load-bearing.

### 5. Output variance is dominated by agent behavior, not skill text

The 3-point spread across runs (31-34) with minimal skill changes confirms that output quality at this level depends more on the research agent's investigation choices (what to read, what to include, how to organize) than on the skill text. The skill is already providing effective guidance — the variance is in execution.

## Comparison: Phase A vs B1

| Aspect | B1 (Text Simplification) | Phase A (Output Quality) |
|--------|--------------------------|--------------------------|
| Metric | `wc -c` (mechanical) + quality guard | LLM-as-judge on 4 dimensions (subjective) |
| Noise | Near-zero (byte count is deterministic) | ~±2 points (~5-6%) |
| Iterations | 5 iterations, 5 keeps (100%) | 3 iterations, 1 keep (33%) |
| Net improvement | -13.8% bytes, quality 82→85 | +1 point (within noise) |
| Key insight | Shorter = more focused = higher quality | Skill text cannot overcome agent execution variance |

## What's Next

The skill has reached diminishing returns for text-level optimization. Future improvements would need to come from:

1. **Agent-level interventions** (changing how the agent executes, not what the skill text says)
2. **Structural changes** (e.g., two-pass investigation: first pass for overview, second for depth)
3. **Multi-prompt evaluation** (testing across diverse prompt types to reduce noise)
4. **A different skill entirely** (this skill's design is sound; optimize elsewhere for more ROI)

## Cost

- 4 research agents × ~60K tokens each ≈ 240K tokens
- 4 grading agents × ~20K tokens each ≈ 80K tokens
- Total: ~320K tokens, ~14 minutes wall time per iteration
- Elapsed: ~1 hour total

## Files

- Config: `phase-a/config.json`
- Baseline: `phase-a/baseline/{output.md, grading.json}`
- Iterations: `phase-a/iteration-{1,2,3}/{modification.md, output.md, grading.json}`
- Baseline skill backup: `phase-a/SKILL.md.baseline`
