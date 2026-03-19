# Changelog: baton-research Review Prompts (autoresearch 2026-03-20)

## Context

Autoresearch session applied to:
- `.baton/skills/baton-research/review-prompt-codebase.md`
- `.baton/skills/baton-research/review-prompt-external.md`

Both prompts are used by baton-review when reviewing research artifacts. The evaluation checked whether they adequately cover the mandatory steps in the current `baton-research SKILL.md`.

---

## Round 1: Initial Scores

Evaluated against 5-point checklist (each criterion scored 0–5):

| Check | codebase | external |
|---|---|---|
| 1. Mandatory step coverage | 2/5 | 2/5 |
| 2. Pass/fail specificity | 3/5 | 3/5 |
| 3. Frame-level checks present | 0/5 | 0/5 |
| 4. Redundancy/contradiction | 4/5 | 4/5 |
| 5. SKILL.md consistency | 2/5 | 2/5 |
| **Total** | **11/25** | **11/25** |

---

## Round 2: Gap Analysis

**Common gaps (both files):**

1. **Step 0 Frame entirely absent** — No check for behavior-neutral Question, Why, Scope/Out-of-scope, System goal, Claimed framing, Assumptions to validate. Most critical gap; caused score of 0/5 on Check 3.
2. **Self-Challenge 4-field format not enforced** — SKILL.md §Step 5 explicitly defines the required format (Conclusion / Why weakest / Falsification condition / Checked for it) and marks shallow answers as failures. Both prompts only said "name specific concerns, not generic".
3. **Questions for Human Judgment absent from Convergence** — SKILL.md §Step 7 and Exit Criteria require these with blocking severity. Neither Convergence section checked for them.
4. **Strategy statement unchecked** — SKILL.md §Step 1 requires "one paragraph describing how investigation will proceed". Neither prompt checked for it.

**Codebase-specific gaps:**

5. **Config files field-by-field check absent** — SKILL.md §Step 3 AI failure mode #5 explicitly states this rule ("a single field value difference can be the most impactful finding"). Not present in Code Tracing Depth.
6. **Minimum record per investigation move absent** — SKILL.md §Step 3 specifies exact format (uncertainty addressed → what checked → found → status → what remains). Not checked.
7. **Direction change documentation absent** — SKILL.md §Step 3 requires recording old/new uncertainty, reason, expected clarification. Not checked.

**External-specific gaps:**

8. **Convergence taxonomy wrong** — External Convergence used "confidence, primary source citation, applicability, verification path" but SKILL.md Exit Criteria uses "actionable / watchlist / judgment-needed / blocked". Both are correct but the actionable/watchlist/blocked taxonomy was missing.
9. **Cross-move synthesis absent** — SKILL.md §Step 3 "Synthesis: when multiple moves used, reconcile before conclusions". Not present in external prompt.
10. **Counterexample sweep less specific than SKILL.md** — SKILL.md §Step 3 "Active search requirement" gives a 3-bullet test. External prompt only had "actively searched for, or just not found by default?" without the specifics.

---

## Round 3: Validation

Planned additions checked against SKILL.md anchors before writing:

| Addition | SKILL.md anchor | Added to |
|---|---|---|
| Frame & Orientation (7 sub-elements) | §Step 0 | Both |
| Strategy statement | §Step 1 | Both |
| Self-Challenge 4-field format + example | §Step 5 | Both |
| Config files field-by-field | §Step 3 AI failure mode #5 | Codebase |
| Minimum record per move | §Step 3 "Minimum record" | Codebase |
| Direction change documentation | §Step 3 "When direction changes" | Both |
| Counterexample sweep 3-bullet active format | §Step 3 "Active search requirement" | Both |
| Cross-move synthesis | §Step 3 "Synthesis" | External |
| Convergence taxonomy fix | §Exit Criteria | External |
| Questions for Human Judgment | §Step 7 | Both |

**Test scenario simulation:**
- *Codebase — hook trigger research:* Old prompt catches 4 issues. New prompt additionally catches: missing frame section, missing investigation rigor records, Self-Challenge format failure. Net gain: +3 catches.
- *External — Agent tool isolation:* Old prompt catches 4 issues. New prompt additionally catches: missing frame section, missing cross-move synthesis, Convergence taxonomy failure. Net gain: +3 catches.

---

## Round 4: Changes Applied

### review-prompt-codebase.md

**Added sections:**
- `Frame & Orientation` — new first section; checks Step 0 (behavior-neutral Question, Why, Scope, System goal, Claimed framing, Assumptions to validate) and Step 1 (Strategy statement, System Baseline for non-deep familiarity).
- `Investigation Rigor` — new section between Code Tracing Depth and Coverage; checks minimum record per move, direction change documentation, counterexample sweep with 3-bullet active format + SKILL.md example.

**Modified sections:**
- `Code Tracing Depth` — added config files field-by-field check with explicit note about single field impact.
- `Evidence Gaps` — upgraded Self-Challenge check to require 4-field format; added concrete ❌/✅ examples from SKILL.md.
- `Evidence Independence & Provenance` — added explicit weak/strong independence examples.
- `Convergence` — added Questions for Human Judgment check.
- `Should-Check` — added micro-example for evidence marking (`file:line` format).

### review-prompt-external.md

**Added sections:**
- `Frame & Orientation` — same as codebase, adapted for external context (behavior-neutral example uses Agent tool isolation).
- `Investigation Rigor` — new section; checks counterexample sweep (3-bullet active format + external-appropriate example), direction change, cross-move reconciliation.

**Modified sections:**
- `Source Authority` — moved Source Landscape check to remain here (it's the external analog of System Baseline); added note it should be built before reading.
- `Evidence Independence & Provenance` — added explicit weak/strong independence examples.
- `Evidence Gaps` — upgraded Self-Challenge check to require 4-field format with external-appropriate example.
- `Convergence` — added actionable/watchlist/judgment-needed/blocked taxonomy alongside existing criteria; added Questions for Human Judgment check.
- `Should-Check` — added micro-example for evidence marking (source + date/version format).

---

## Final Scores (estimated)

| Check | codebase | external |
|---|---|---|
| 1. Mandatory step coverage | 5/5 | 5/5 |
| 2. Pass/fail specificity | 4/5 | 4/5 |
| 3. Frame-level checks present | 5/5 | 5/5 |
| 4. Redundancy/contradiction | 4/5 | 4/5 |
| 5. SKILL.md consistency | 5/5 | 5/5 |
| **Total** | **23/25** | **23/25** |

Remaining gaps (both -1 on Check 2 and -1 on Check 4):
- A few items still read as "were both X and Y done, or only one?" without an explicit pass criterion for acceptable omission. This is intentional — these require reviewer judgment.
- Minor remaining overlap: Coverage / Evidence Gaps both address completeness from different angles. Kept separate because Coverage targets systematic matrix completeness while Evidence Gaps targets Self-Challenge quality.

## 批注区
