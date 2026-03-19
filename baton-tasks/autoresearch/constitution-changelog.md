# Constitution Autoresearch Changelog

**Date**: 2026-03-20
**Method**: autoresearch — scoring checklist × simulated scenarios → iterative edits

---

## Scoring Checklist

1. Evidence conflict: clear priority rules and handling steps (not just "submit to human judgment")
2. Sizing boundary: specific tiebreaker when conditions conflict (not just "when in doubt, size up")
3. BATON:GO invalidation: concrete detection conditions and action steps (not just "materially change")
4. Failure boundary: "same hypothesis" defined clearly enough to distinguish parameter adjustment vs. new approach
5. BLOCKED exits: all entry paths have corresponding exit conditions

## Test Scenarios

- **Scenario A**: Implement phase — 2 failed attempts same direction, 3rd changed direction, still fails
- **Scenario B**: Research phase — two reliable sources contradict, no runtime verification available
- **Scenario C**: Sizing — 20 lines, 3 files, cross-module interface change

## Baseline Score: 0/15

All 5 checklist items failed their primary scenario:

| Item | Primary Scenario | Failure Reason |
|------|-----------------|----------------|
| C1 | B | "submit to human judgment" — no workflow, no steps |
| C2 | C | Conditions conflict (small volume but cross-module); no tiebreaker |
| C3 | A | "materially change" undefined — no detection criteria |
| C4 | A | "same hypothesis" used but not defined; direction change = ambiguous |
| C5 | A | BLOCKED exit doesn't cover phase skill escalation path |

---

## Changes Made

### C1 — Evidence conflict (Evidence section)

**Before**: "When sources conflict: state both, mark the mismatch, submit to human judgment."

**After**: Added 4-step process:
1. State both claims with confidence markers
2. Identify what would distinguish them
3. Perform distinguishing check if in scope; else mark ❓
4. If unresolved: BLOCK with structured report (claims, confidence, resolution needed)

**Why**: "Submit to human judgment" is a terminal instruction with no workflow. AI needs steps to execute before reaching that terminal state, especially when human isn't immediately available.

---

### C2 — Sizing tiebreaker (Task Sizing section)

**Before**: "When in doubt, size up."

**After**: Added: "If task conditions span two levels (e.g., < 50 lines but cross-module), the higher level applies — structural/behavioral criteria (cross-module scope, design decisions) override volume criteria (line count, file count)."

**Why**: Table conditions can conflict. An explicit tiebreaker prevents ambiguity at exactly the cases where the table is most needed (cross-module but small).

---

### C3 — BATON:GO invalidation triggers (Permissions section)

**Before**: "Unexpected discoveries: evaluate whether (1) approval assumptions still hold and (2) the plan still applies. If either is no → BLOCKED."

**After**: Added concrete trigger list — assumptions materially changed when:
- (a) new facts contradict a key premise
- (b) authorized write set must expand
- (c) implementation approach differs fundamentally from what was approved

With required action: state original assumption, new fact, impact → BLOCKED.

**Why**: "Materially changed" is a judgment call without criteria. Concrete triggers let AI self-detect without requiring human interpretation at each decision point.

---

### C4 — Hypothesis definition (Permissions — Failure boundary)

**Before**: "same approach failing repeatedly (default ≥2 under same hypothesis)" — hypothesis undefined.

**After**: Added: "A **hypothesis** is the causal claim driving the attempt. Adjusting parameters within the same causal claim = same hypothesis. Changing the causal claim = new hypothesis; reset the counter and state the new hypothesis explicitly."

**Why**: Without a definition, "same hypothesis" is unenforceable. The distinction between "adjusted parameters" and "new causal claim" gives AI a concrete boundary to apply in Scenario A and similar edge cases.

---

### C5 — BLOCKED exit per entry path (States section)

**Before**: Single exit condition: "blocking reason resolved. If BATON:GO was invalidated, renewed BATON:GO required. Otherwise, human confirms existing BATON:GO still applies."

**After**: Path-specific exits:
- BATON:GO invalidated → renewed BATON:GO
- Phase skill escalation (failure boundary, circuit breaker) → human provides new approach direction + renewed BATON:GO
- Otherwise → human confirms existing BATON:GO applies

**Why**: The original exit didn't address the phase skill escalation path at all. The question "what direction?" is ambiguous when blocked by a failed approach — this now requires human to provide a new direction before re-authorizing.

---

## Final Score: 15/15

All 5 checklist items now provide unambiguous, actionable guidance in their primary scenarios.

## 批注区

<!-- Human annotations go here -->
