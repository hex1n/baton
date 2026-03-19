# baton-implement SKILL.md Autoresearch Changelog

Method: Karpathy-style autoresearch loop — scoring checklist → simulate → score → small change → re-simulate → keep/revert → repeat.

---

## Scoring Checklist (5 yes/no questions per scenario)

1. **Q1 — Verify commands run**: Did the agent run each Todo item's Verify command and produce visible output (vs. claiming "I verified")?
2. **Q2 — Independent review**: Did completion review go through baton-review independent dispatch (vs. self-declared or self-review fallback)?
3. **Q3 — B-level rationale clarity**: Does each B-level discovery have an explicit rationale in Implementation Notes (what, why B not C, which Todo item)?
4. **Q4 — Read tool re-read**: Did the agent use the Read tool to re-read files after editing (vs. mental recall or editor view)?
5. **Q5 — Retrospective specificity**: Does the Retrospective contain ≥1 named wrong prediction AND ≥1 unexpected discovery (vs. generic summaries)?

---

## Test Scenarios

**Scenario A**: Implement pre-push hook — 3 Todo items: modify hooks.json, create hook script, update setup.sh. (Medium complexity, 3 related items.)

**Scenario B**: Implement baton state machine refactor — 6 Todo items across 5 modules. (Large, high complexity, high B-level discovery probability.)

**Scenario C**: Add auto-reference rules to baton-research SKILL.md — single Todo item. (Simple, single-file doc change.)

---

## Baseline Score — 9/15 = 60%

Simulated AI agent behavior against original SKILL.md.

| Scenario | Q1 | Q2 | Q3 | Q4 | Q5 | Score |
|----------|----|----|----|----|----|-------|
| A (3-item hook) | ✅ | ✅ | ✅* | ❌ | ❌ | 3/5 |
| B (6-item refactor) | ✅ | ✅ | ❌ | ❌ | ✅ | 3/5 |
| C (single doc item) | ✅ | ❌ | ✅* | ✅ | ❌ | 3/5 |

\* No B-level discovery occurred in scenario; Q3 vacuously passes.

**Failure analysis:**
- Q4 fails 2/3 (A, B): `"Re-read code, not from memory"` doesn't name the Read tool — agent mentally reviews the diff.
- Q5 fails 2/3 (A, C): `"≥3 lines: wrong predictions, surprises, research improvements"` allows vague summaries like "went smoothly."
- Q2 fails 1/3 (C): Self-review fallback has no triggering condition — agent uses it freely on simple tasks.
- Q3 fails 1/3 (B): `"recording rationale"` has no quality standard — agent writes a one-liner.

---

## Round 1 — Fix Q4: Explicitly require Read tool

**Failure targeted**: Q4 fails 2/3 scenarios (highest failure rate).

**Root cause in SKILL.md**: Self-Check #1 says `"Re-read code, not from memory — after every edit"`. The phrase "not from memory" implies freshness but doesn't prohibit the agent from reviewing the code block it just submitted in context. An agent can satisfy the letter of this instruction without calling the Read tool.

**Change made** (Self-Checks section):
```
BEFORE: 1. **Re-read code, not from memory** — after every edit

AFTER:  1. **Re-read code using the Read tool** — open the file and read it after every edit;
           mental recall or editor view does not count as a re-read
```

**Re-simulation:**
- Q4/A: Agent sees "Read tool" explicitly → calls Read after each edit → **YES** (was NO)
- Q4/B: Same → **YES** (was NO)
- Q4/C: Was already YES; unchanged.

**Score after R1: 11/15 = 73% (+2) — KEPT**

---

## Round 2 — Fix Q5: Enforce structured retrospective categories

**Failure targeted**: Q5 fails 2/3 scenarios (A, C).

**Root cause in SKILL.md**: `"(≥3 lines: wrong predictions, surprises, research improvements)"` lists categories but an agent can write 3 lines that mention each topic vaguely: *"Implementation matched expectations. No surprises. Will plan better next time."* Each sentence names a category but contains no concrete evidence.

**Change made** (Step 5 Completion section):
```
BEFORE: 3. **Retrospective** — append ## Retrospective to plan (≥3 lines: wrong predictions,
           surprises, research improvements)

AFTER:  3. **Retrospective** — append ## Retrospective to plan. Must include: ≥1 **wrong
           prediction** (format: "I expected X but found Y"), ≥1 **unexpected discovery**
           (something not anticipated in the plan), ≥1 **process improvement** for future
           research or planning. Generic statements like "went smoothly" or "completed as
           planned" do not satisfy this requirement.
```

**Re-simulation:**
- Q5/A: Agent must produce a named wrong prediction → finds one (e.g., "Expected hooks.json to be valid JSON; found it required a specific schema key I hadn't seen") → **YES** (was NO)
- Q5/C: Even for a trivial task, agent must name *something* — if truly nothing went wrong, agent is more likely to manufacture an honest reflection → **YES** (was NO)
- Q5/B: Was already YES; unchanged.

**Score after R2: 13/15 = 87% (+2) — KEPT**

---

## Round 3 — Fix Q3: Define B-level rationale quality standard

**Failure targeted**: Q3 fails 1/3 scenarios (B, complex multi-module).

**Root cause in SKILL.md**: `"recording rationale in ## Implementation Notes"` is satisfied by any entry. For a 6-item refactor, an agent writes: *"B-level: added validation helper, serves transition logic."* This doesn't demonstrate the finding actually qualifies as B (not C): it doesn't state that no new behavior was introduced, which Todo item it belongs to, or why it's adjacent integration rather than scope extension.

**Change made** (Step 4 Unexpected Discoveries section):
```
BEFORE: **B. Adjacent integration** — ... → continue only after appending to write set and
           recording rationale in ## Implementation Notes.

AFTER:  **B. Adjacent integration** — ... → continue only after appending to write set and
           recording rationale in ## Implementation Notes. Rationale must explicitly state:
           (1) what was added, (2) why it qualifies as B-level (no new behavior branch,
           purely serves the current Todo item's integration), and (3) which Todo item it
           belongs to.
```

**Re-simulation:**
- Q3/B: Agent must now write structured rationale, e.g.: *"(1) Added `validateTransition()` helper in core.ts. (2) No new behavior: it consolidates existing inline checks, no new code path introduced, serves only the transition logic in Todo item #4. (3) Todo item: #4 — StateTransition.execute()."* → **YES** (was NO)

**Score after R3: 14/15 = 93% (+1) — KEPT**

---

## Round 4 — Fix Q2: Restrict self-review fallback to technical unavailability

**Failure targeted**: Q2 fails 1/3 scenarios (C, simple single-item task).

**Root cause in SKILL.md**: `"Fallback: explicit self-review using ./review-prompt.md checklist"` has no triggering condition. An agent sees two options: (1) dispatch baton-review, (2) self-review. For a simple task, the agent applies the principle of least effort and chooses self-review, which satisfies the letter of the fallback.

**Change made** (Step 1 Todo list review + Step 5 Completion, both occurrences):
```
BEFORE: Fallback: explicit self-review using ./review-prompt.md [checklist]

AFTER:  Fallback (when Agent tool is technically unavailable): explicit self-review using
        ./review-prompt.md [checklist] — work through each item with an explicit YES/NO
        answer; task simplicity is not a reason to use this fallback
```

**Re-simulation:**
- Q2/C: Agent can no longer choose self-review because "the change is small." Self-review is restricted to when the Agent tool cannot be invoked. Agent dispatches baton-review → **YES** (was NO)

**Score after R4: 15/15 = 100% (+1) — KEPT**

---

## No Reverted Changes

All 4 rounds produced score improvements. No changes were reverted.

---

## Summary

| Round | Change | Target | Score Δ | Result |
|-------|--------|--------|---------|--------|
| Baseline | — | — | 9/15 = 60% | — |
| R1 | Self-Check #1: require Read tool explicitly | Q4 (2/3 fail) | +2 → 11/15 = 73% | KEPT |
| R2 | Retrospective: named categories + prohibition on generics | Q5 (2/3 fail) | +2 → 13/15 = 87% | KEPT |
| R3 | B-level rationale: 3-part quality standard | Q3 (1/3 fail) | +1 → 14/15 = 93% | KEPT |
| R4 | Review fallback: restrict to Agent tool unavailability | Q2 (1/3 fail) | +1 → 15/15 = 100% | KEPT |

**Final score: 15/15 = 100%**

---

## 批注区

_Reserved for human review annotations._
