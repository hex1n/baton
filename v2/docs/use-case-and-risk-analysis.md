# Baton v2: Use Case & Risk Analysis

> Based on reading the full protocol, all 4 skill definitions, and both templates. Not based on external opinion.

## What Baton Is Good At

### 1. Multi-round coding tasks with progressive elaboration

The round system (`protocol.md` Round Lifecycle) is explicitly designed for tasks where requirements emerge through building. Round 1 takes clear features, builds them, and uses discoveries to clarify fuzzy features for Round 2+. This is stronger than "中等复杂度" — it handles genuinely complex multi-round tasks.

### 2. Tasks where implementation quality matters more than design novelty

The Verifier's 3-tier verification (`verifier/SKILL.md` Steps 1-4) — deterministic tests, runtime behavior, AC coverage + adversarial testing — provides strong guardrails for **implementation correctness**. If your ACs are right, the system will catch most implementation bugs.

### 3. Repeatable, portable collaboration protocol

File-based state transfer (`brief.md`, `eval.md`, `project-profile.md`) means any Claude Code session can resume a task. This makes it genuinely installable at the repo level — new sessions pick up where old ones left off.

### 4. Honest degradation over fake guarantees

The Mode A/B/C system (`protocol.md:178-186`) and Compact Mode (`protocol.md:36-55`) don't pretend to provide guarantees they can't deliver. Mode C admits it reads code; Compact Mode admits there's no independent verification. This honesty is architecturally valuable — it prevents false confidence.

### 5. Tasks where a clear verifier feedback loop prevents drift

The Verifier → Builder → Verifier inner loop (up to 3x per rule 5) with auto-escalation to Planner → Human prevents the common failure mode of AI implementations: quiet drift from requirements.

## What Baton Is Less Suited For

### 1. Tasks requiring deep cross-module architectural reasoning

Planner's exploration is targeted: "identify which packages/modules are **likely** affected" (`planner/SKILL.md:77`). For tasks where the affected surface is non-obvious (e.g., changing a core abstraction that ripples through 15 modules), this targeted approach may miss critical dependencies. The 3-question limit for clarification (`planner/SKILL.md:91`) compounds this — complex tasks often need more than 3 load-bearing questions.

### 2. Strong compliance / audit scenarios

Artifacts are mutable markdown files. There's no:
- Immutable audit log (brief.md gets compressed and overwritten)
- Role identity verification (all roles are the same model)
- Diff-level traceability of who changed what in artifacts
- Formal sign-off records

The archive script (`v2/tools/archive-round.sh`) preserves snapshots but doesn't provide tamper-evident history.

### 3. Tasks where the real challenge is requirements discovery, not implementation

Baton assumes the human can describe what they want clearly enough for Planner to write ACs. If the core difficulty is "we don't know what we want" — exploration, prototyping, throwaway spikes — the round-based structure adds overhead without adding value.

### 4. Very small tasks (< 1 AC)

Compact mode exists but still requires `brief.md` + `eval.md` + human approval gates. For a one-line fix where you know exactly what to change, the protocol overhead exceeds the value.

## Risk Analysis

### The Central Risk

**Baton compresses most of its success conditions into the quality of `brief.md`.**

This is by design — `brief.md` is the "single source of truth" (Rule 1). Builder implements against it. Verifier verifies against it. If it's wrong, both downstream roles execute faithfully on a flawed plan.

### Risk Layer Model

| Layer | Risk | What goes wrong | Protocol defense | Defense quality |
|-------|------|----------------|-----------------|-----------------|
| **L0** | Task description is vague | Planner explores wrong area of codebase | Planner can ask up to 3 clarifying questions | **Weak** — 3 questions is a hard ceiling; complex tasks need more |
| **L1** | ACs are testable but incorrect | Verifier pre-flight challenges the plan, but AC "looks right" to the same model | Pre-flight plan quality challenge (consistency, completeness, simplicity) | **Medium** — same model shared blind spots |
| **L2** | Implementation doesn't match ACs | Builder writes code that doesn't satisfy AC | Verifier Tier 1-3 verification with independent evidence | **Strong** — L1 evidence (test results, runtime) is genuinely independent |
| **L3** | Issue misclassified in feedback loop | Code bug labeled as code bug when it's actually a design issue | 3x escalation rule auto-promotes persistent issues | **Medium** — catches it eventually but wastes 3 cycles |

### Risk 1: Can Planner Write Correct ACs?

**Protocol defenses:**
- Targeted exploration with file + line citation (`planner/SKILL.md:75-85`)
- Given/When/Then format forces specificity (`planner/SKILL.md:183-204`)
- Verifier pre-flight challenges plan on 3 dimensions (`verifier/SKILL.md:89-113`)
- Human approval gate before build

**Where defenses break down:**

1. **Exploration radius is bounded by task description quality.** Planner reads "Based on task description, identify which packages/modules are likely affected" — if the description doesn't hint at the right modules, Planner won't find them. This is an **upstream input problem**, not a brief-writing problem.

2. **Same-model blind spots.** Planner and Verifier are the same model. `protocol.md:229-239` acknowledges this with Confidence Signals (`⚠️ LOW CONFIDENCE`), but this mechanism requires AI to know what it doesn't know — precisely what AI is worst at.

3. **"Testable" ≠ "correct."** Verifier pre-flight checks if ACs are testable (`verifier/SKILL.md:35-42`) but not whether they correctly capture user intent. A testable-but-wrong AC passes all automated defenses. Only the human approval gate catches this.

### Risk 2: Can Verifier Catch Real Gaps?

**Protocol defenses:**
- 3-tier verification with evidence levels (L1 > L2 > L3)
- Test baseline protocol (only new failures count)
- Assertion density check and mutation spot-check (`verifier/SKILL.md:228-251`)
- 3x escalation to prevent infinite loops
- Mode degradation with honest disclosure

**Where defenses break down:**

1. **Verifier's authority boundary is the AC, not the requirement.** Verifier checks "does implementation match AC?" — not "does AC match user intent?" A logically consistent but requirement-misaligned set of ACs will get a PASS verdict. This is a **structural blind zone**, not a Verifier weakness.

2. **Mode C collapses independence.** `protocol.md:185-186` is honest about this, but many real environments land in Mode C (can't start the app). When Verifier reads production code (L3 evidence), it's the same model reviewing the same model's output. The independence claim degrades significantly.

3. **Escalation classification requires judgment.** `verifier/SKILL.md:348-364` defines code bug vs. design issue vs. requirement gap. Misclassification (calling a design issue a "code bug") burns 3 Builder cycles before auto-escalation kicks in.

4. **Adversarial testing is final-round only.** `verifier/SKILL.md:255` restricts adversarial testing to the last round. If a security issue is introduced in Round 1 and the task has 4 rounds, it won't be caught until Round 4. Earlier rounds could build on the flawed foundation.

### Risk 3: Human Checkpoint Effectiveness

The protocol places human checkpoints at decision points (`protocol.md:153-161`). But:

- Human sees `brief.md` + `eval.md` summary, not raw code
- If Planner's framing is confident but wrong, the human may rubber-stamp
- The "approve / revise / reject" options don't include "I need to see more before deciding"
- Human review quality scales inversely with task frequency — the 50th approval gets less scrutiny than the 1st

### Key Insight

**Baton is strongest at L2 (does implementation match spec?) and weakest at L0-L1 (is the spec right?).** The system has robust mechanical verification but thin semantic verification. This means:

- **High-value use case:** Tasks where requirements are clear but implementation is tricky (complex algorithms, intricate integrations, performance-sensitive code)
- **Risky use case:** Tasks where requirements need discovery and the human can't articulate them precisely upfront

### Improvement Vectors

These are observations, not prescriptions.

| Area | Current state | Potential direction |
|------|--------------|-------------------|
| Clarification ceiling | Hard limit of 3 questions | Scale with task complexity (e.g., 3 + 1 per feature block) |
| Same-model blind spot | Confidence Signals (self-reported) | Structured pre-flight checklist that forces specific checks rather than relying on model judgment |
| AC correctness | Human approval (single gate) | Require human to map each AC back to their original requirement before approval |
| Mode C independence | Honest disclosure | Define specific L3 checks that are more structured than "read the code and judge" |
| Adversarial timing | Final round only | Lightweight security checklist per round for security-sensitive tasks |
