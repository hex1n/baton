# baton-plan Autoresearch Changelog

Autoresearch method: Karpathy-style improvement loop — define scoring checklist → simulate skill execution → score → make one targeted change → re-score → keep or revert → repeat.

---

## Scoring Checklist

5 yes/no questions applied to each simulated plan output:

1. **Fundamentally different approaches** — Did the AI present ≥2 approaches that differ in control point, abstraction layer, or responsibility allocation (not storage-format variations)?
2. **Surface Scan evidence** — Does every row in the Surface Scan table cite a tool call or file read from the current session (not from memory)?
3. **Self-Challenge depth** — Does the Self-Challenge section name the weakest assumption and state a concrete falsification criterion?
4. **Recommendation tracing** — Does the recommendation cite a specific constraint *name* from Step 1 when rejecting alternatives (not "simpler/better/cleaner")?
5. **L3 flagging** — Are all behavioral-equivalence items flagged as L3 with an explanation of why static evidence is insufficient?

---

## Test Scenarios

- **Scenario A** (Medium): "为 baton 添加 pre-push hook 来阻止未通过 review 的代码推送"
- **Scenario B** (Large): "将 baton 的状态机从标记式（BATON:GO）改为数据库驱动"
- **Scenario C** (Small): "为 baton-research 添加自动引用外部文档的能力"

---

## Baseline Score: 1/15 = 7%

| Item | Scenario A | Scenario B | Scenario C | Row Total |
|------|-----------|-----------|-----------|-----------|
| Q1: Fundamentally different approaches | ✅ | ❌ | ❌ | 1/3 |
| Q2: Surface Scan cites tool calls | ❌ | ❌ | ❌ | 0/3 |
| Q3: Self-Challenge weakest assumption + falsification | ❌ | ❌ | ❌ | 0/3 |
| Q4: Recommendation traces to named Step 1 constraint | ❌ | ❌ | ❌ | 0/3 |
| Q5: L3 items flagged + why static evidence insufficient | ❌ | ❌ | ❌ | 0/3 |
| **Column total** | 1/5 | 0/5 | 0/5 | **1/15** |

**Root causes identified:**
- Q1 B fails: "fundamentally different" undefined — AI presents SQLite vs JSON (storage format variants, same model)
- Q1 C fails: "Small: Requirements + recommendation" explicitly allows skipping alternatives
- Q2 0/3: No post-table verification checkpoint; AI builds surface scan table in one pass from memory
- Q3 0/3: Three generic self-challenge questions with no output format requirement; shallow answers pass undetected
- Q4 0/3: "trace to specific constraints" too vague; "it's simpler/better" satisfies the letter of the rule
- Q5 0/3: L3 defined but no trigger examples; AI doesn't recognize runtime-semantic questions as L3

---

## Round 1: Self-Challenge — add weakest assumption + falsification requirement

**Change**: Added mandatory closing block after the 3 questions in Step 5:
```
> **Weakest assumption**: [name the single most load-bearing unverified assumption]
> **If this assumption is wrong**: [specific impact — what would need to change in the plan]
> **How to verify before executing**: [what evidence or test would confirm or refute it]
If you cannot state a falsification criterion, the assumption is too vague to trust — re-examine the plan.
```

**Reason**: The 3 existing questions are open-ended. Without a required output format, AI answers generically ("I considered all alternatives", "assumptions seem valid") and the rule is satisfied structurally but not substantively. The closing block forces a named assumption and a concrete falsification pathway — both verifiable by the human.

**Score change**: Q3: 0/3 → 3/3 (+3 points)
**New total: 4/15 = 27%** ✅ Keep

---

## Round 2: Small complexity — require 2 brief alternatives

**Change**: `Complexity-Based Scope` line for Small changed from:
```
- **Small**: Requirements + recommendation.
```
to:
```
- **Small**: Requirements + 2 brief alternatives (1–2 sentences each, including trade-offs) + recommendation.
```

**Reason**: The abbreviated "Small" scope explicitly allowed a single recommendation, which caused Scenario C to fail Q1 unconditionally. The spirit of Step 4 (human must see alternatives and reasoning) should apply at all non-trivial complexity levels; the change just scales the depth to "1-2 sentences each."

**Score change**: Q1 C: ❌ → ✅ (+1 point)
**New total: 5/15 = 33%** ✅ Keep

---

## Round 3: Surface Scan — add self-audit before finalizing

**Change**: Added after the "skip requires explicit justification" line in Step 3:
```
**Self-audit before finalizing the table**: For each row, identify the exact
tool call or file read from the current session that produced it. Any row you
cannot point to must be removed or replaced with a ❓ entry noting it was
inferred, not verified. A partially-fabricated table is worse than a shorter
honest one — it creates false confidence about coverage.
```

**Reason**: The existing prohibition on fabrication ("never fabricate table entries") appears before the table template — it's a warning, not a verification step. AI writes the table in one forward pass and the warning is easily satisfied by not consciously fabricating while still relying on implicit memory. Moving the check to after the table (audit step) forces a backward verification pass where fabricated entries become noticeable.

**Score change**: Q2 A: ❌ → ✅ (Medium tasks typically involve actual tool calls; self-audit enforces their use) (+1 point)
Q2 B and C remain ❌ (Large: too many rows, fabrication risk too high; Small: often skips scan)
**New total: 6/15 = 40%** ✅ Keep

---

## Round 4: Two changes — "fundamentally different" clarification + recommendation constraint-name citation

**Change 4a** (Step 4 opener): Added blockquote clarifying what makes approaches fundamentally different:
```
> **What makes approaches "fundamentally different"**: they impose different
> control points, abstraction layers, or responsibility allocations. Storage
> format variations (JSON vs YAML vs SQLite for the same state model) are NOT
> fundamentally different. Ask: "Does this approach change *who or what owns the
> logic* or *where control decisions are made*?"
```

**Change 4b** (Step 4 recommendation): Changed:
```
- Why the main alternatives were rejected (trace to specific constraints or evidence)
```
to:
```
- Why the main alternatives were rejected — cite the specific constraint *name* from Step 1,
  not "it's better/simpler/cleaner." Example: "Approach B rejected because it violates the
  [shell-only execution] constraint from Step 1." Vague rejection reasoning is a red flag
  that evaluation was not genuine.
```

**Reason (4a)**: For Scenario B (state machine migration), "fundamentally different" was interpreted as storage technology variation. The AI needed a concrete test: "Does this change *who owns the logic*?" This question forces thinking about the abstraction layer, not the storage format.

**Reason (4b)**: "Trace to specific constraints or evidence" is satisfied by "it's simpler" (which is a kind of evidence). The fix requires a constraint *name* — something that must exist as a labeled item in Step 1, making the trace verifiable.

**Score change**:
- Q1 B: ❌ → ✅ (+1) — "fundamentally different" clarification prevents storage-format variations
- Q4 A, B, C: ❌ → ✅ (+3) — constraint-name citation required for all scenarios

**New total: 10/15 = 67%** ✅ Keep

---

## Round 5: L3 — add concrete trigger examples

**Change**: Added after the existing L3 definition:
```
L3 triggers (static analysis cannot answer these — must flag):
- Does the change preserve the *semantics* of a contract, not just its signature?
- Does correctness depend on execution order, timing, or runtime state?
- Does a caller rely on a side effect that won't appear in its import graph?
- Does "this looks compatible" depend on an assumption about current behavior that you have not directly observed running?
```

**Reason**: The L3 definition ("behavioral equivalence, human-assisted") is correct but too abstract. AI classifies surface scan items as L1/L2 by default because there's no recognition step for L3. The trigger list gives 4 concrete questions that, if yes, mandate L3 classification. These cover the common failure modes: semantic drift (not just signature compatibility), execution-order dependence, hidden side effects, and untested compatibility assumptions.

**Score change**:
- Q5 A: ❌ → ✅ (+1) — pre-push hook scenario has a semantic contract question ("does BATON:COMPLETE reliably mean passing review?") matching trigger #1
- Q5 B: ❌ → ✅ (+1) — state machine migration has execution-order/runtime-state dependencies matching trigger #2
- Q5 C: remains ❌ — small SKILL.md change has no contract-semantics or runtime-state questions; L3 correctly absent

**New total: 12/15 = 80%** ✅ Keep

---

## Final Score: 12/15 = 80%

| Item | Scenario A | Scenario B | Scenario C | Row Total |
|------|-----------|-----------|-----------|-----------|
| Q1: Fundamentally different approaches | ✅ | ✅ | ✅ | 3/3 |
| Q2: Surface Scan cites tool calls | ✅ | ❌ | ❌ | 1/3 |
| Q3: Self-Challenge weakest assumption + falsification | ✅ | ✅ | ✅ | 3/3 |
| Q4: Recommendation traces to named Step 1 constraint | ✅ | ✅ | ✅ | 3/3 |
| Q5: L3 items flagged + why static evidence insufficient | ✅ | ✅ | ❌ | 2/3 |
| **Column total** | 5/5 | 4/5 | 3/5 | **12/15** |

### Remaining gaps

**Q2 B/C (Surface Scan)** — still 1/3. The self-audit instruction helps but cannot fully solve a structural problem: for large architecture changes (B), the surface is too wide for an AI to tool-call every row in a single session; for small changes (C), surface scans are often skipped. A stronger fix would require the skill to enforce a "scan first, then build table" ordering protocol, but this risks over-prescribing execution mechanics. Current improvement is the highest-leverage intervention at acceptable verbosity cost.

**Q5 C (L3 for Small)** — ❌ by design. Small tasks with single-file scope rarely have behavioral-equivalence questions. This is a correct negative.

### Rounds reverted
None. All 5 rounds produced score improvements and were retained.

---

## 批注区

<!-- Human annotations go here. -->
