---
name: baton-plan
description: >
  This skill MUST be used when the user asks to "plan", "design", "propose",
  "make a plan", "出 plan", or after research is complete and changes need to be
  proposed. Also use when processing human feedback or annotations on a plan.
  The plan is the contract: human approval via BATON:GO gates all implementation,
  and scope is bound — nothing gets built that isn't in the approved plan.
user-invocable: true
---

## Iron Law

```
NO IMPLEMENTATION WITHOUT AN APPROVED PLAN
NO BATON:GO PLACED BY AI — ONLY THE HUMAN PLACES IT
NO TODOLIST WITHOUT HUMAN SAYING "GENERATE TODOLIST"
NO INTERNAL CONTRADICTIONS LEFT UNRESOLVED — FIX BEFORE PRESENTING
```

The plan is the contract for implementation — nothing gets built that isn't in the
plan. The human must approve by placing `<!-- BATON:GO -->`. This is not a formality;
it ensures the human has read and agreed to the approach.

## When to Use

- After research is complete and you need to propose concrete changes
- When the user asks to plan, design, or propose an approach
- When requirements are understood and a structured proposal is needed
- For tasks of any complexity that involve code changes

**When NOT to use**: Pure research tasks (use baton-research), or trivial changes
where a 3-5 line plan summary suffices.

## The Process

### Step 1: Derive from Research

Plans MUST derive approaches from research findings — don't jump to "how" without
tracing back to "why". If research.md exists, reference it. If not, do the research
first (invoke baton-research).

**Before deriving approaches, verify the research source:**
1. If research.md contains a `## Final Conclusions` section, derive from there
   (it's the converged single source of truth).
2. If no Final Conclusions exists and research has multiple sections with
   evolving recommendations, identify which conclusions are current vs superseded.
   Only derive from current conclusions.
3. If the human stated requirements in chat, record them in plan.md under
   `## Requirements` before proceeding. The plan must trace back to BOTH
   research findings AND human-stated requirements.

### Step 2: Extract Constraints

Identify fundamental constraints from the research:
- Architecture limitations
- Performance bottlenecks
- Dependencies and backward compatibility
- Team conventions not in code
- Filesystem constraints on new files (.gitignore exclusions, directory permissions)

These constraints are the guardrails that eliminate approaches.

### Step 3: Approach Analysis

Derive 2-3 approaches, each evaluated against the constraints:

- **Feasibility**: ✅ feasible / ⚠️ risky / ❌ not feasible, with evidence (file:line)
- **Pros and cons** analyzed against each fundamental constraint
- **Impact scope**: files affected, callers impacted
- **Derived artifacts**: lockfiles, generated types, snapshots, or other mechanical
  outputs expected to change. These are NOT implicitly exempt — list them explicitly
  in the plan or todo items if the approved change is expected to touch them

When only one viable approach exists, still show why alternatives were ruled out.

### Step 3b: Surface Scan (required for Medium/Large changes)

Before writing the change list, perform Change Impact Analysis:

**Level 1 — Direct references**: Search for exact terms being changed.
  - Text patterns → Grep/Glob
  - Code references → IDE "Find References" / AST tools
  - Convention-based → Glob patterns
  - Exclude archives (plans/, node_modules/, etc.)

**Level 2 — Dependency tracing**: From each L1 result, trace consumers.
  - Who imports/sources/references this file?
  - Who reads this file at runtime or build time?
  - Which tests validate this file's behavior?

**Level 3 — Behavioral equivalence** (human-assisted):
  - Files that implement the same concept without naming it?
  - Flag as ❓ in disposition table for human review.

Build the disposition table from ALL levels and include in plan.md as `## Surface Scan`:

| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| ... | L1/L2/L3 | modify / skip | ... |

Default disposition is "modify" — "skip" requires explicit justification.
Self-check: for each "skip" file — if not updated, will users encounter old behavior?
For Trivial/Small changes, Level 1 alone is sufficient.

### Step 4: Recommend with Reasoning

The recommendation is not preference — it's the optimal choice given the constraints.
Reasoning should trace back to specific research findings.

### Step 5: Self-Review

```markdown
## Self-Review

### Internal Consistency Check (fix before presenting)
- Does the recommendation section point to the same approach as the change list?
- Does each change item trace back to the recommended approach?
- Does the Self-Review below reference findings consistent with the plan body?
- If ANY contradiction found → this is a bug, not a risk. Fix it now.
- **Does the change list cover ALL files in the Surface Scan disposition table?**
  Files marked "modify" must appear in change list. Files marked "skip" must have justification.
  If no Surface Scan was done → execute one now before presenting.

### External Risks (present to human)
- The biggest risk in this plan that you're least confident about
- What could make this plan completely wrong
- One alternative approach you considered but rejected, and why
```

### When Research Discovers Fundamental Problems

If the existing design itself is problematic, present this honestly with evidence:

- Present options: patching within current structure (cost, risks, tech debt) vs.
  fixing the root problem (cost, benefit, scope)
- Explicitly state: this is an architectural decision requiring human judgment
- Don't decide for the human, and don't hide problems pretending everything is fine

## Plan Structure

plan.md MUST communicate:
- **What** — specific changes, referencing research findings
- **Why** — design rationale, alternatives considered and their trade-offs
- **Impact** — files involved, affected callers/consumers
- **Risks + mitigation** — what could go wrong and the strategy for each

The human should be able to read the plan and predict what the diff will look like.

### Pre-Todo Consistency Check

Before generating the todolist, verify internal consistency:
1. Re-read the recommendation section — which approach is recommended?
2. Re-read the change list — do ALL changes belong to the recommended approach?
3. Re-read the Self-Review — are there unresolved internal contradictions?
4. All three aligned → proceed to generate todolist.
5. Any mismatch → fix the document first, then generate.

### Todolist Format

After the human says "generate todolist" and BATON:GO is present:

```markdown
## Todo

- [ ] 1. Change: description | Files: a.ts, b.ts | Verify: unit tests pass | Deps: none | Artifacts: none
- [ ] 2. Change: description | Files: c.ts | Verify: type-check | Deps: #1 | Artifacts: lockfile
```

Each todo item should include:
- **Change**: specific change description
- **Files**: files involved and write set (which files this item modifies)
- **Verification**: how to verify correctness
- **Dependencies**: which earlier items must complete first, or "none" if independent
- **Derived artifacts**: lockfiles, generated types, snapshots expected to change (or "none")

Independent items (no dependency, non-overlapping write sets) can be parallelized during
implementation. Making this explicit here saves the implementer from re-analyzing the plan.

Use `- [ ]` unchecked, `- [x] ✅` checked (lowercase x + checkmark). Hooks grep the
`- [x]` prefix, so keep that exact prefix when marking an item done.

## Red Flags — STOP

| Thought | Reality |
|---------|---------|
| "Let me just start coding, the plan is obvious" | The plan is the contract. No plan = no code. |
| "I'll figure out the details during implementation" | Vague plans lead to scope creep and rework. |
| "There's only one way to do this" | Show why alternatives were ruled out. |
| "The human probably wants this approach" | Present options with evidence. Let them decide. |
| "Let me add BATON:GO so we can move faster" | ONLY the human places BATON:GO. This is a hard gate. |
| "Let me just update the recommendation section" | Direction changes affect the ENTIRE document. Re-read every section. |
| "I'll note this direction change in the Annotation Log" | Annotation Log is not enough. Update the document body — it's the source of truth. |

## Annotation Protocol (Plan Phase)

The human reviews plan.md and provides feedback — either as free-text annotations
in the document, or as conversation in chat. AI infers intent from content.

The only explicit annotation type is `[PAUSE]` — a flow control signal meaning
"stop current work, go investigate something else first." All other feedback is
free-text; AI determines the appropriate response from content.

### Processing Each Annotation

For each piece of feedback:
1. **Read code first** — don't answer from memory. Cite file:line.
2. **Infer intent** — is this a question, change request, context addition,
   depth complaint, or gap signal? Record your inference in the Annotation Log.
3. **Respond with evidence** — if the human is right, adopt and update. If
   problematic, explain with evidence + offer alternatives. Don't comply blindly.
4. **Consequence detection** — after responding, ask yourself:
   - Did my answer change the recommended approach? → Direction change. See below.
   - Did my answer contradict a research.md conclusion? → Must add counter-evidence
     to research.md before updating plan.
   - Did my answer reveal an internal contradiction in this document? → Fix immediately
     (Iron Law #4).

### Direction Change Rule

When any annotation response changes the recommended approach:
1. **Declare** — "Responding to this feedback changes my recommendation from X to Y."
2. **Full-document alignment** — re-read every section (recommendation, change list,
   Self-Review, scope) and update ALL references to the old approach.
3. **Research check** — if the new direction contradicts research.md conclusions,
   pause and add counter-evidence to research.md first.
4. **Inform human** — "If you believe this needs deeper investigation before
   changing direction, say [PAUSE]."

When an annotation is accepted: (1) update the document body, (2) record in
Annotation Log. Both steps required — the document body is the source of truth.

If 3+ annotations in one round signal depth issues → suggest upgrading complexity.

### Annotation Log Format

Record each annotation with AI-inferred classification:

```markdown
## Annotation Log

### Round 1

**[inferred: direction-question] § Section Name**
"Human's original feedback text"
→ AI response with file:line evidence
→ Consequence: direction changed / no direction change
→ Result: accepted / awaiting decision / alternative proposed
```

Inference categories: question, change-request, context, depth-issue, gap, pause.
The category is AI's best judgment — human can correct if wrong.

### Pre-Exit Checklist

Before presenting plan.md to the human, verify:

1. **Requirement traceability** — Every requirement in `## Requirements`
   has a source: research section reference or "Human requirement (chat/annotation)".
   _Prevents: plans that drift from what was actually researched or requested_

2. **Test-layer coverage in Surface Scan** — For each L1 file being modified,
   asked: "which test file exercises this?" If one exists, it appears in the
   disposition table as L2.
   _Prevents: downstream test breakage going unplanned (e.g., test-phase-guide.sh omission)_

3. **Skip decisions challenged** — Each "skip" entry answers: "if this file
   is NOT updated, what will the user experience?"
   _Prevents: silent stale behavior in untouched files_

4. **Change specs grounded in reads** — Every file in the change list was
   read in this session before writing its change specification.
   _Prevents: scope underestimation from assuming file content (e.g., test-adapters.sh)_

5. **Optimal solution, not just a solution** — For each proposed change,
   asked: "is this the best answer to the underlying problem?" before
   asking "is this implementation correct?"
   _Prevents: jumping to implementation before validating the approach itself_

## Output Template

Name the file to match its research pair: `plan-<topic>.md`. Default `plan.md`.

End every plan.md with:

```markdown
## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前工作去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完成后添加 BATON:GO 批准标记，然后告诉 AI "generate todolist" -->
```

## File Conventions

- Documents MUST end with `## 批注区`
- Before writing a new plan, archive existing:
  `mkdir -p plans && mv <plan-file> plans/plan-<date>-<topic>.md`
- If paired research file exists, archive alongside with same topic
