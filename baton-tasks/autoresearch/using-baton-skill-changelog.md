# Autoresearch: using-baton Skill Evaluation & Changes

## Scope

- **Target**: `.baton/skills/using-baton/SKILL.md`
- **Method**: 4-round simulate-score-fix-retest loop
- **Task size**: Small (single skill file, < 15 lines changed, clear evaluation criteria)

---

## Scoring Checklist

Applied to every scenario output:

1. Output files in `baton-tasks/<topic>/`?
2. Research/plan documents end with `## 批注区`?
3. Evidence markers (✅/❓) on all material claims?
4. Self-Challenge section with ≥3 substantive answers?

---

## Round 1: Baseline

### Scenario A — Mode B (external skill → compliance enforcement)

User generates a research document with a generic code-review tool, then using-baton
enforces governance compliance before presenting to human.

| Item | Pass? | Rationale |
|------|-------|-----------|
| 1. Location | ✅ | Red Flags covers override: "This doc goes in docs/ because the skill defaults there" → baton-tasks/<topic>/ |
| 2. 批注区 | ✅ | Output Compliance item 2 + Red Flag "I'll add 批注区 later" → add NOW |
| 3. Evidence markers | ✅ | Output Compliance item 3 |
| 4. Self-Challenge | ❌ | Output Compliance item 4 lists the requirement but says nothing about WHO generates it when the external skill omitted it. "Fix before presenting to the human" is insufficiently actionable. |

**Score A: 3/4**

### Scenario B — Mode A (direct baton-plan routing)

User says "use baton-plan to generate a plan document."

| Item | Pass? | Rationale |
|------|-------|-----------|
| 1. Location | ✅ | Mode A: baton-plan owns compliance |
| 2. 批注区 | ✅ | Mode A: baton-plan owns compliance |
| 3. Evidence markers | ✅ | Mode A: baton-plan owns compliance |
| 4. Self-Challenge | ✅ | Mode A: baton-plan owns compliance |

**Score B: 4/4** ✅ `[CODE]❓ inferred from Mode A definition; baton-plan not read`

### Scenario C — Trivial sizing (lightest process)

User asks for a quick fix on a single-file trivial bug (< 5 lines, no behavior change).
using-baton must assess sizing and route to the lightest process.

| Item | Pass? | Rationale |
|------|-------|-----------|
| 1. Location | ✅ | Trivial = inline plan only, no file created → N/A |
| 2. 批注区 | ❌ | Output Compliance says "every working document must satisfy these" with no trivial exemption. Constitution §Task Sizing says "No research/plan template" for Trivial, but the skill doesn't reconcile this. A reader following the skill literally could apply 批注区 to a 3-line inline plan. |
| 3. Evidence markers | ❌ | Same gap — no trivial exemption stated |
| 4. Self-Challenge | ❌ | Same gap — constitution says "Self-review sufficient" for Trivial, but skill requires ≥3 Self-Challenge answers |

**Score C: 1/4**

### Round 1 Total: 8/12

---

## Failure Analysis

**Failure 1 (Scenario A item 4)**: Mode B compliance path lacks actionable guidance
on generating a Self-Challenge section when the external skill didn't produce one.
Root cause: Output Compliance item 4 states the requirement but not who is responsible
for satisfying it in the Mode B flow. `[CODE]✅ confirmed by reading SKILL.md:73-77`

**Failure 2 (Scenario C items 2-4)**: Output Compliance has no sizing-aware caveat.
The constitution explicitly defines Trivial tasks as needing only an inline plan
("No research/plan template"), but using-baton's Output Compliance section applies
to "every working document" without exception. This creates an unresolvable conflict
for Trivial tasks. `[CODE]✅ confirmed by reading SKILL.md:69-76` `[CODE]✅ confirmed
by reading .baton/constitution.md Task Sizing table`

---

## Round 2: Fixes Applied

### Fix 1 — Output Compliance sizing caveat

Added before the numbered list:
> **Sizing caveat**: For Trivial tasks (constitution §Task Sizing), an inline plan is
> used instead of a formal document — items 2–4 do not apply, and item 1 is N/A if no
> file is created.

This is constitutionally grounded (constitution defines Trivial as inline-plan-only)
and adds no new requirements. `[CODE]✅ change applied to SKILL.md`

### Fix 2 — Self-Challenge generation guidance

Extended Output Compliance item 4:
> if the external skill did not produce one, generate it from the document's content
> before presenting to the human.

This clarifies that Mode B responsibility falls on using-baton (not the external skill)
to satisfy item 4. Quality bar unchanged (≥3 substantive answers). `[CODE]✅ change applied`

### Round 2 Retest

| Item | A | B | C |
|------|---|---|---|
| 1. Location | ✅ | ✅ | ✅ |
| 2. 批注区 | ✅ | ✅ | ✅ |
| 3. Evidence markers | ✅ | ✅ | ✅ |
| 4. Self-Challenge | ✅ | ✅ | ✅ |

**Round 2 Total: 12/12** ✅

---

## Round 3: Adversarial Check

**Does the trivial caveat create an escape hatch?** An AI might over-classify tasks as
Trivial to skip governance. Counter-evidence: constitution defines Trivial strictly
(< 5 lines, single file, no behavior change) and mandates "when in doubt, size up."
using-baton defers sizing to constitution — no weakening introduced. `[CODE]✅` Risk
assessed as low.

**Does the Self-Challenge guidance lower quality?** Phrasing "generate it from the
document's content" does not lower the ≥3 substantive answers bar — it only clarifies
responsibility. Red Flags still warn against mechanical compliance. ✅ No regression.

**Round 3 Total: 12/12** — no regressions found.

---

## Round 4: Second-Order Effects

**Mode A verification gap** (not a failure but noted): If a baton phase skill (e.g.,
baton-plan) produces a non-compliant document, Mode A says "no additional process is
layered on top" — so using-baton would not catch it. This is by design (phase skills
own compliance in Mode A), not a gap to fix here. `[CODE]❓ baton-plan not read;
assuming phase skills are compliant per architecture intent`

Gotchas section deliberately left empty (policy: no pre-filled theory).

**Round 4 Total: 12/12** — confirmed stable.

---

## Changes Summary

File modified: `.baton/skills/using-baton/SKILL.md`

| # | Section | Change | Motivation |
|---|---------|--------|------------|
| 1 | Output Compliance | Added sizing caveat (Trivial tasks exempt from items 2-4) | Constitution conflict; Scenario C failing 3 of 4 items |
| 2 | Output Compliance item 4 | Added "generate it from the document's content if missing" | Mode B Self-Challenge responsibility unspecified |

Total lines changed: ≈ 6 lines added, 2 lines modified.

---

## Self-Challenge

### [Challenge 1] Were the 3 scenarios representative enough?

The scenarios cover the three main execution paths: Mode B compliance enforcement,
Mode A routing, and sizing boundary. They do not test ambiguous sizing (e.g., task
thought to be Small that grows to Large mid-execution). However, that scenario is
governed by the constitution's "stale authorization" invariant and the "approval
assumptions changed → BLOCKED" rule — not by using-baton's routing logic. The
scenarios are representative for this skill's responsibility surface.

**Assessment**: sufficient for this autoresearch scope. ✅

### [Challenge 2] Did Round 1 correctly identify all failures?

The 8/12 score was derived from reading the SKILL.md literally and testing each item
against each scenario. The Mode A verification gap was identified in Round 4 but
classified as "by design" rather than a failure. Risk: this classification could be
wrong if baton phase skills regularly produce non-compliant output. However, since the
architecture explicitly delegates compliance to phase skills in Mode A, treating it as a
failure would require changing the architecture, not patching using-baton. Classification
stands. `[CODE]✅ read SKILL.md:50-54`

### [Challenge 3] Could Fix 1 (trivial caveat) be misapplied to Small tasks?

The caveat is scoped to "Trivial tasks (constitution §Task Sizing)" — the link to the
constitution provides the precise definition. A reader who misclassifies a Small task as
Trivial would skip governance, but the constitution's "when in doubt, size up" rule is
the primary guard. The caveat does not weaken that guard. Risk is the same risk that
exists without this fix (a reader can always ignore the constitution). The fix adds
clarity without adding new risk. ✅

---

## 批注区

<!-- Human annotations go here. AI processes each one per annotation protocol. -->
