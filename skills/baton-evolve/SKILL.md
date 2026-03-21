---
normative-status: Extension skill for autonomous artifact evolution via iterative review loops.
name: baton-evolve
description: >
  Use after plan or implementation completes to autonomously improve baton
  artifacts (skills, plans, research docs) through Karpathy-style autoresearch
  loops. Applies atomic modifications, evaluates via baton-review, and
  keeps/discards based on measurable quality delta. Also use when user says
  "evolve", "autoresearch", "进化", or "自动优化".
user-invocable: true
---

## Iron Law

```
NO EVOLUTION WITHOUT MEASURABLE BASELINE
ONE CHANGE PER ITERATION — SINGLE-VARIABLE EXPERIMENTS ONLY
MECHANICAL EVALUATION — "LOOKS BETTER" IS NOT EVIDENCE
REVERT ON REGRESSION — NO EXCEPTIONS
```

## Role

baton-evolve is an extension skill that applies Karpathy's autoresearch
loop to baton artifacts. It is not a phase — it operates after a phase
completes, evolving the output through autonomous iteration.

The core insight from autoresearch: give an agent a fixed evaluation
function, let it make one change at a time, measure, keep or discard,
repeat. Applied to baton: the evaluation function is baton-review.

## Red Flags

These thoughts mean STOP — you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This change is obviously better, skip the review" | Mechanical evaluation only. Run baton-review |
| "Two changes at once will be faster" | Single-variable principle. You lose causality with multi-change |
| "The score didn't improve but the artifact reads better" | Subjective assessment ≠ evidence. Score is the decision |
| "Let me keep going past the stall limit" | 3 consecutive no-improvement iterations → stop. The loop has diminishing returns |
| "I'll evolve the artifact AND the review criteria" | Moving the goalposts. Fix the review criteria separately first |
| "The review found nothing, so the artifact is perfect" | Zero findings may mean the review prompt is weak, not the artifact is strong |

## Gotchas

> Operational failure patterns. Add entries when observed in real usage.
> Empty until then — do not pre-fill with theory.

## When to Use

- After baton-plan or baton-implement completes, user wants to improve output quality
- Skill prompt (SKILL.md) performs inconsistently across scenarios
- Research or plan has known quality gaps but unclear remediation path
- User explicitly requests autoresearch / evolution

**When NOT to use**: During active implementation (use baton-debug instead).
Not a substitute for baton-review — baton-review is the evaluation function
inside this loop, not the other way around.

## Evaluation Function

### Scoring

baton-review produces findings with severity levels. The score formula:

```
score = -(blocking × 10 + major × 3 + minor × 1)
```

Score 0 = no findings. Higher (closer to 0) is better.

### Evaluation Protocol

1. Dispatch baton-review via Agent tool (context isolation mandatory)
2. Pass artifact text + `./review-prompt.md` as review criteria
3. Extract findings: count by severity (blocking / major / minor)
4. Compute score
5. Return score + finding list

Self-review is NOT acceptable as the evaluation function. The whole
point of the loop is mechanical, context-isolated evaluation.

## The Process

### Step 0: Setup

1. **Identify target**: which artifact to evolve (skill SKILL.md / plan.md / research.md)
2. **Confirm evaluation criteria**: review-prompt.md appropriate for the artifact type
3. **Set parameters**:
   - `max_iterations`: default 20 (override with user instruction)
   - `stall_limit`: 3 consecutive iterations with no score improvement → stop
   - `progress_interval`: every 5 iterations, output summary
4. **Git checkpoint**: commit current state as `evolve-baseline: <artifact>`

### Step 1: Establish Baseline (Iteration 0)

- Run evaluation on unmodified artifact
- Record: iteration 0, commit hash, score, finding count breakdown
- Log to `baton-tasks/<topic>/evolve-log.tsv`

TSV format:
```
iteration	commit	score	blocking	major	minor	delta	status	hypothesis
0	a1b2c3d	-13	1	1	0	0.0	baseline	initial state
```

If baseline score is 0 (no findings): report to user that the artifact
already passes review. Evolution may still be useful if the user provides
additional quality criteria beyond baton-review.

### Step 2: Form Hypothesis

Based on the current review findings (from baseline or previous iteration):

1. Pick the highest-severity finding
2. Form a specific, falsifiable hypothesis: "Changing X will resolve finding Y"
3. Record the hypothesis in the log before making the change

**Hypothesis discipline** (from constitution):
- A hypothesis is the causal claim driving the attempt
- Adjusting wording within the same claim = same hypothesis
- Changing the targeted finding or approach = new hypothesis
- Same hypothesis failing twice → move to next finding

### Step 3: Atomic Modification

Make exactly ONE change to the artifact:

- For SKILL.md: one section rewrite, one rule addition/removal, one constraint modification
- For plan.md: one approach change, one step restructure, one rationale rewrite
- For research.md: one evidence addition, one conclusion revision, one gap closure

**Commit** with message: `evolve-iter-N: <hypothesis summary>`

### Step 4: Evaluate

Run the same evaluation as Step 1 on the modified artifact.

- Extract new score
- Compute delta from previous best score

### Step 5: Keep or Discard

| Condition | Action |
|-----------|--------|
| Score improved (delta > 0) | **KEEP** — this is the new best. Record as `keep` |
| Score unchanged (delta = 0) and simpler | **KEEP** — simpler is better at equal quality |
| Score unchanged and not simpler | **DISCARD** — `git revert` the commit. Record as `discard` |
| Score worsened (delta < 0) | **DISCARD** — `git revert` the commit. Record as `discard` |

### Step 6: Log and Continue

- Append to `evolve-log.tsv`
- Increment stall counter if no improvement; reset if improved
- Every `progress_interval` iterations: output summary (best score, total kept, total discarded, current stall count)

### Step 7: Termination

Stop when any condition met:

1. `max_iterations` reached
2. `stall_limit` consecutive iterations with no improvement
3. Score reaches 0 (no remaining findings)
4. User interrupts

On termination:
- Output final summary: baseline score → final score, total iterations, improvements kept
- List the kept changes in order (commit + hypothesis)
- Record in `baton-tasks/<topic>/evolve-log.tsv`

## Integration with autoresearch Plugin

If `autoresearch@autoresearch` plugin is installed:

- baton-evolve can delegate the loop execution to `/autoresearch`
- Provide baton-review dispatch as the `Verify` command
- Provide the artifact file as the scope
- The plugin handles git commit/revert mechanics

If the plugin is NOT installed:

- baton-evolve executes the loop itself following Steps 0-7 above
- All git operations are explicit (no implicit state changes)

## Evolution Targets (by priority)

### 1. Skill SKILL.md (closest to Karpathy's original)

Most suitable because:
- Clear evaluation: run skill against test scenarios, review output quality
- Fast iteration: prompt changes are cheap to test
- Measurable: pass rate across test inputs

Enhanced evaluation for skills:
```
skill_score = -(review_findings) + (test_pass_rate × weight)
```

When evolving skills, the user should provide 3-5 test scenarios (inputs + expected behavior). Each iteration: run skill against all scenarios, evaluate outputs, compute aggregate score.

### 2. Plan Quality

Evaluation: baton-review with plan review-prompt
Target: reduce blocking/major findings while maintaining scope coverage

### 3. Research Completeness

Evaluation: baton-review with research review-prompt
Target: close evidence gaps, strengthen ❓ → ✅ conversions

## Constraints

- Constitution core invariants are immutable — evolution cannot weaken them
- Evidence standards (✅/❓) apply to evolution claims
- Write set: only the target artifact + evolve-log.tsv
- No side effects: evolution of artifact A must not modify artifact B
- Evaluation function (review criteria) must remain fixed during a run;
  if the criteria need improvement, that is a separate evolution target

## Self-Challenge

Before starting the loop, answer:

1. **Is the evaluation function adequate?** If baton-review criteria don't
   cover the quality dimensions the user cares about, the loop will optimize
   for the wrong thing. Surface this gap before starting.

2. **Is the artifact worth evolving?** If the artifact has fundamental
   framing errors, atomic improvements won't fix it. A rewrite (back to
   RESEARCH or PLAN phase) may be more appropriate.

3. **What's the ceiling?** Some artifacts can't reach score 0 due to
   inherent trade-offs. Estimate the realistic ceiling and set expectations.

## Authority

This skill is an extension — it adds the evolution loop capability but
cannot weaken phase skill requirements or constitution invariants. When
evolution changes touch areas governed by phase skills (e.g., plan format),
the phase skill's requirements take precedence.

## 批注区
