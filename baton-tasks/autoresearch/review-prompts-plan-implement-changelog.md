# Review Prompts Changelog: baton-plan + baton-implement

Autoresearch session: 2026-03-20

---

## Method

Applied 5-criterion checklist (2 files × 5 questions = 10 checks). Simulated reviewer
using each prompt on a medium-complexity artifact. Iterated until no further failures.

---

## Scoring: Round 1 (before changes)

### baton-plan/review-prompt.md

| # | Criterion | Result | Gap |
|---|-----------|--------|-----|
| 1 | Covers all mandatory SKILL.md steps | **FAIL** | Step 5 closing block missing; L3 trigger protocol missing; self-audit requirement missing |
| 2 | Specific pass/fail criteria | **PARTIAL** | Rejection reasoning check lacked constraint-name citation requirement |
| 3 | Frame-level checks present | **PARTIAL** | Problem statement check present; falsification criterion for assumptions absent |
| 4 | No redundancy/contradiction | **PARTIAL** | "≥2 categories enumerated" (Step 1) and "2-3 approaches presented" (Step 4) overlap without clear separation |
| 5 | Consistent with latest SKILL.md | **FAIL** | SKILL.md Step 5 requires closing block with Weakest assumption / If wrong / How to verify — not checked. L3 flag protocol (SKILL.md Step 3) not checked. Self-audit requirement not checked. |

**Score: 0/5 full-pass**

### baton-implement/review-prompt.md

| # | Criterion | Result | Gap |
|---|-----------|--------|-----|
| 1 | Covers all mandatory SKILL.md steps | **FAIL** | Step 5 Retrospective requirement unchecked; BATON:COMPLETE conditions unchecked; self-check #1 (Read tool re-read) unchecked |
| 2 | Specific pass/fail criteria | **PARTIAL PASS** | Most items specific; "conventions" slightly vague |
| 3 | Frame-level checks present | **PASS** | Intentionally limited: plan is the approved baseline |
| 4 | No redundancy/contradiction | **FAIL** | Step 0 had 3 overlapping "matches plan" checks: items 1, 3, 4 all asked the same question |
| 5 | Consistent with latest SKILL.md | **FAIL** | Retrospective format (≥1 wrong prediction, ≥1 discovery, ≥1 improvement) and BATON:COMPLETE placement conditions not checked |

**Score: 1/5 full-pass**

---

## Simulation: Round 1

### Plan review-prompt — 3-module pre-push hook plan

A medium plan covering 3 modules (auth, logging, payload) with a 5-row Surface Scan.
One row was inferred from memory (no grep backing it). Approach B rejected with "it's
cleaner". Self-Challenge section present but no closing block. One L3 dependency
(hook execution order between modules) not flagged.

**Issues reviewer would MISS with original prompt:**
- ❌ Self-Challenge closing block absent — no check existed for the three required fields
- ❌ Rejection reason "it's cleaner" — no constraint-name citation check
- ❌ One Surface Scan row inferred from memory — no self-audit check
- ❌ L3 execution-order dependency not flagged ❓ — no L3 trigger check

**Issues reviewer would CATCH:**
- ✅ Only 1 alternative presented (≥2 check present)
- ✅ Surface Scan L2 missing for one L1 file
- ✅ BATON:GO placeholder absent

### Implement review-prompt — 6-item Todo diff

A diff completing a 6-item Todo list. BATON:COMPLETE present. Retrospective section
absent. Three Step 0 checks all asking "does this match the plan?" — noise without
differentiated coverage.

**Issues reviewer would MISS with original prompt:**
- ❌ Retrospective absent — no check existed
- ❌ BATON:COMPLETE placed without retrospective — no conditions check
- ❌ self-check #1 (Read tool re-read) not verifiable — no check existed

**Issues reviewer would CATCH:**
- ✅ Out-of-set file touched without recording
- ✅ Missing error path test
- ✅ Todo items batch-updated at end instead of immediate marking

---

## Changes Made

### baton-plan/review-prompt.md

**1. Extracted Self-Challenge into its own section** (was 1 line buried in First-Principles)

Removed from First-Principles: the single line "Does Self-Challenge name specific
rejected alternatives..."

Added new `### Self-Challenge` section with 4 checks:
- Presence of `## Self-Challenge`
- Specific rejected alternatives named (generic "no other alternatives" = FAIL)
- Closing block with all three required fields present
- Falsification criterion stated ("Should be fine" without a concrete test = FAIL)

Rationale: Step 5 is a major mandatory step in SKILL.md. Reducing it to one line
attached to Step 1 caused reviewers to not notice the closing block requirement.

**2. Added constraint-name citation check** (Multi-Approach Presentation)

Added: "Do rejection reasons cite a specific constraint *name* from Step 1? Vague
reasoning ('it's better/simpler/cleaner') with no constraint reference = FAIL."

Rationale: SKILL.md Step 4 explicitly requires this. The old check ("not just 'the
recommended one is better'") was too vague to catch constraint-free rejections.

**3. Added L3 trigger and self-audit checks** (Impact Analysis)

Added two checks:
- L3 triggers evaluated (execution order/timing, runtime state, side effects)?
- L3 items explicitly flagged ❓ with note that static analysis is insufficient?
- Self-audit: every table row must trace to a specific session tool invocation (fabricated row = FAIL)

Rationale: SKILL.md Step 3 defines L3 triggers and mandates the self-audit explicitly.
Neither was in the review-prompt.

### baton-implement/review-prompt.md

**1. Removed redundant Step 0 check**

Removed: "Does the diff implement what was specified, not a reinterpretation?"

This was covered by item 1 ("Does each change match the plan's stated intent?") and
item 3 ("Would a line-by-line comparison against plan intent show material deviation?").
Three checks asking the same question create noise; a reviewer stops reading carefully.

**2. Added self-check evidence check** (Correctness)

Added at top of Correctness section: "Were modified files re-read with the Read tool
after editing? (Mental recall or editor view does not count — tool invocation required)"

Rationale: SKILL.md Step 2/Self-Checks item 1 explicitly requires the Read tool.
A reviewer looking at a diff cannot tell if this was done; the check prompts them to
look at session notes or ask.

**3. Added Step 5 — Completion section**

Added new `### Step 5 — Completion` section (between Todo List Review and Should-Check):
- Retrospective presence (trigger: all items ✅ or BATON:COMPLETE present)
- ≥1 wrong prediction in "I expected X but found Y" format
- ≥1 unexpected discovery
- ≥1 process improvement
- Generic statement detection (FAIL signal)
- BATON:COMPLETE placement gated on all five conditions

Rationale: SKILL.md Step 5 defines specific format requirements for Retrospective.
These were entirely absent from the review-prompt, allowing completion without
retrospective to pass review.

---

## Scoring: Round 2 (after changes)

### baton-plan/review-prompt.md

| # | Criterion | Result |
|---|-----------|--------|
| 1 | Covers all mandatory SKILL.md steps | **PASS** |
| 2 | Specific pass/fail criteria | **PASS** |
| 3 | Frame-level checks present | **PASS** |
| 4 | No redundancy/contradiction | **PASS** |
| 5 | Consistent with latest SKILL.md | **PASS** |

**Score: 5/5**

### baton-implement/review-prompt.md

| # | Criterion | Result |
|---|-----------|--------|
| 1 | Covers all mandatory SKILL.md steps | **PASS** |
| 2 | Specific pass/fail criteria | **PASS** |
| 3 | Frame-level checks present | **PASS** |
| 4 | No redundancy/contradiction | **PASS** |
| 5 | Consistent with latest SKILL.md | **PASS** |

**Score: 5/5**

---

## Simulation: Round 2

### Plan review-prompt — same 3-module pre-push hook scenario

- ✅ Self-Challenge closing block absent → now caught
- ✅ "it's cleaner" rejection → now caught (no constraint name = FAIL)
- ✅ Memory-inferred Surface Scan row → now caught (self-audit check)
- ✅ L3 execution-order dependency → now caught (L3 trigger check)

All 4 previously-missed issues now caught.

### Implement review-prompt — same 6-item Todo diff scenario

- ✅ Retrospective absent → now caught
- ✅ BATON:COMPLETE placed prematurely → now caught (conditions check)
- ✅ Read tool re-read not verifiable → now surfaced as check
- Step 0 now 4 checks (was 5) with cleaner distinct purposes

All previously-missed issues now caught.

---

## 批注区

