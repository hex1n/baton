---
name: baton-research
description: >
  This skill MUST be used when the user asks to "research", "analyze",
  "investigate", "trace", "explore", "understand how this works", or whenever
  starting any task that touches unfamiliar code — even if the task seems simple.
  Also use when receiving feedback requesting deeper analysis or [PAUSE] annotations.
  Produces research.md with file:line evidence for human review.
user-invocable: true
---

## Iron Law

```
NO CONCLUSIONS WITHOUT FILE:LINE EVIDENCE
NO SOURCE CODE CHANGES DURING RESEARCH — INVESTIGATE ONLY
```

Research produces understanding, not code. If you find yourself wanting to fix something,
write it down in research.md for the plan phase. The write-lock hook enforces this —
source code writes are blocked until BATON:GO exists in the plan.

## When to Use

- Starting analysis of unfamiliar code or a new feature area
- When the user asks to research, analyze, explore, understand, or investigate
- When a task's complexity is Medium or Large (see workflow.md Complexity Calibration)
- When you need to understand existing behavior before proposing changes
- After receiving a `[PAUSE]` annotation during plan review

**When NOT to use**: Trivial/Small tasks where the scope is already clear and you can
go directly to planning.

## The Process

### Step 0: Tool Inventory

Before any code investigation, inventory all available documentation retrieval and
search tools (Context7, WebSearch, WebFetch, Grep, Glob, MCP servers). Attempt each
relevant one during research. Record what you used and what each returned — the human
judges search thoroughness.

### Step 1: Start from Entry Points

Begin at the human's request or affected files — these are natural starting points.
Don't pre-plan a list of files to read. Instead, observe-then-decide: after reading
each file, decide the next based on what you found.

### Step 2: Trace Call Chains

Follow execution paths with evidence:

```
### [Path Name]
**Call chain**: A (file:line) → B (file:line) → C (file:line) → [Stop: reason]
**Risk**: ✅/❌/❓ + description
**Unverified assumptions**: what code was not read and why
**If this breaks**: impact scope
```

- Read implementations, not just interfaces — function signatures lie; bodies reveal truth
- Stop tracing at framework internals, stdlib, or external deps — annotate WHY you stopped
- When stopping at external boundaries, check authoritative docs before assuming behavior

### Step 2b: Consistency Matrix (for cross-cutting features)

When a feature touches N parallel implementations (e.g., N IDEs, N API endpoints,
N config formats), build a matrix before concluding research:

| Entity | Detect | Configure | Install | Search |
|--------|--------|-----------|---------|--------|
| IDE A  | .claude | .claude/  | .claude/skills/ | .claude |
| IDE B  | ...    | ...       | ...     | ...    |

**Every cell must have direct evidence (file:line), explicit N/A, runtime verification,
or a documented ❓ unverified reason. Blank cells are not allowed** — they mean you
haven't thought about that path. Mismatched cells are potential bugs.
This matrix is the primary output for cross-cutting research — call chain traces alone
miss cross-entity inconsistencies.

### Step 2c: Counterexample Sweep

Before forming any conclusion, actively search for evidence that would **disprove** it:

- For each major finding, ask: "What code path, test, or config would break this conclusion?"
- Search for callers/consumers that use the feature differently than the main path suggests
- Check test fixtures for edge cases the main path doesn't exercise
- Look for feature flags, environment branches, or conditional logic that changes behavior

Record counterexamples found (or their absence) in research.md. A conclusion that survived
a counterexample sweep is stronger than one that was never challenged.

### Step 3: Use Subagents for Breadth

When you encounter 3+ call paths across 10+ files, use subagents to trace parallel
branches. Don't try to hold everything in one pass.

### Step 4: Spike When Needed

Use Bash for exploratory code — it's not blocked by write-lock. Record findings with
evidence in research.md. Spike code is disposable — do not carry it forward.

### Step 5: Self-Review

Before presenting to the human, append:

```markdown
## Self-Review

### Internal Consistency Check (fix before presenting)
- Do all call chain conclusions align with the evidence cited?
- Are there sections that contradict each other?
- If ANY contradiction found → fix it now. This is a bug, not a finding.

### External Uncertainties (present to human)
- 3 questions a critical reviewer would ask about this research
- The weakest conclusion in this document and why
- What would change your analysis if investigated further
```

### Step 6: Questions for Human Judgment

```markdown
## Questions for Human Judgment
- 2-3 questions that genuinely require human domain knowledge
- MUST NOT be questions the AI could answer by reading more code
```

## Evidence Standards

Every claim requires file:line evidence. No exceptions.

- `✅` confirmed safe — with verification evidence
- `❌` problem found — with evidence of the problem
- `❓` unverified — with reason it remains unverified

```
✅ Good: "Token expires after 24h (auth.ts:45 — `expiresIn: '24h'`)"
❌ Bad: "Token expiration should be fine"
```

## Red Flags — STOP

These thoughts mean you're about to violate research discipline:

| Thought | Reality |
|---------|---------|
| "This code looks straightforward" | Read the implementation, not just the interface. Signatures lie. |
| "Should be fine" | Not a valid conclusion. Verify with file:line or mark ❓ |
| "I already know how this works" | Are you pattern-matching from memory? Read the actual code. |
| "Let me just fix this while I'm here" | Research produces understanding, not code. Write it down for the plan. |
| "This is taking too long, let me summarize" | Incomplete research leads to wrong plans. The human needs depth. |
| "The user seems impatient" | Your job is accuracy, not comfort. Surface what you found. |

## Common Rationalizations

| Excuse | Why It Fails |
|--------|-------------|
| "I traced the main path, the edge cases are probably similar" | Edge cases are where bugs hide. Trace or mark ❓ unverified. |
| "The tests cover this" | Tests prove behavior, not understanding. You need both. |
| "I'll investigate more during implementation" | The plan depends on complete research. Missing info = wrong plan. |
| "This library is well-known, I don't need to check" | Check authoritative docs anyway. Versions change, APIs evolve. |

## Annotation Protocol (Research Phase)

The human reviews research.md and provides feedback — free-text annotations or
conversation. AI infers intent from content.

The only explicit type is `[PAUSE]` — "stop current research direction, investigate
something else first." All other feedback is free-text.

### Processing Each Annotation

1. **Read code first** — don't answer from memory. Cite file:line.
2. **Infer intent** — question, context, depth complaint, gap?
   Record inference in Annotation Log.
3. **Respond with evidence** — adopt if right, explain with evidence if problematic.
4. **Consequence detection** — did my answer invalidate a prior conclusion?
   If yes, update the affected sections immediately.

When an annotation is accepted: (1) update the document body, (2) record in
Annotation Log.

If 3+ annotations signal depth issues → suggest upgrading complexity.

## Output Template

Name the file by topic: `research-<topic>.md`. Default `research.md` for simple tasks.

research.md MUST let the human judge:
1. Whether the AI sufficiently understands the code
2. Whether the AI's understanding is correct
3. Whether anything was missed

End every research.md with:

```markdown
## 批注区

<!-- 写下你的反馈，AI 会判断如何处理。 -->
<!-- 如果需要暂停当前研究方向去做其他调查，写 [PAUSE]。 -->
<!-- 审阅完毕后告诉 AI "出 plan" 进入计划阶段 -->
```

### Step 7: Convergence Check

Before transitioning to plan phase, consolidate the research conclusions:

1. **Scan for superseded conclusions** — if any section's recommendation or
   conclusion was revised by a later section (Supplement or otherwise), mark
   the original with a note: "-> Revised in [later section]".
2. **Write `## Final Conclusions`** — a short section at the end listing ONLY
   the currently-valid conclusions. Each must reference its evidence location
   in the document body.
3. **Chat requirements capture** — if the human stated requirements or
   direction in chat (not in the document), record them in Final Conclusions
   with attribution: "Human requirement (chat): ..."

This step ensures plan derivation works from a single coherent source, even
across session boundaries.

### Pre-Exit Checklist

Before presenting research.md to the human, verify:

1. **Tool breadth** — At least 2 distinct search methods used beyond Read
   (e.g., Grep + Glob, or Grep + subagent). Recorded in Tool Inventory.
   _Prevents: tunnel vision from single-tool investigation_

2. **Conclusion resilience** — Each major conclusion states what evidence
   would disprove it, and whether that evidence was found or searched for.
   _Prevents: confirmation bias — finding what you expect instead of what exists_

3. **Single source of truth** — Final Conclusions section exists. Each
   conclusion references its evidence location in the body. No body-section
   conclusion contradicts Final Conclusions.
   _Prevents: stale conclusions surviving across annotation rounds_

## Exit Criteria

Research is sufficient when all three conditions are met:

1. **Main path verified** — primary call chains traced with file:line evidence, no ❓ on critical paths
2. **Key unknowns surfaced** — remaining uncertainties are explicitly marked ❓ with reason, not silently omitted
3. **Human judgment questions extracted** — decisions that require domain knowledge are in `## Questions for Human Judgment`, not buried in prose

If any condition is unmet, continue research. If all are met, tell the human research is ready for review.

## Metacognitive Triggers

Before writing a conclusion:
- Have I actually read the code that confirms this, or am I pattern-matching from memory?
- What would a skeptic challenge first?
- Did I stop tracing too early because the code "looked straightforward"?
