# Architecture: skill-retrospective-alignment

**Topic**: Align `baton-retrospective` skill with template (6 sections) + add structural enforcement
**Status**: `ratified`
**Sizing**: `Small`

## 1. Problem Framing

Skill prose and Output Template block in `baton-retrospective/SKILL.md` define 8 sections that don't match `retrospective.template.md`'s 6 sections. The 8-dimension shape is pre-harness-spec-v1 legacy; the template has been authoritative (6 sections) since `08540ca` on 2026-03-26. Drift was invisible because `validate-artifact.sh` has no `retrospective` case.

## 2. First-Principles

### 2.1 Problem Statement

Two cooperating artifacts (skill + template) describe different schemas for the same output file. There is no guardrail against this class of drift for this artifact.

### 2.2 Constraints

- C1: Extractor regex in `start-task.sh:251` depends on `## 4. Repo-Specific Lessons` and `## 5. Harness Lessons` numbered headings — must survive the rewrite
- C2: `check-lesson-index-consistency.sh` lines 70-79 check for these headings in the skill — must stay satisfied
- C3: Current `.harness/retrospective.md` already has 6 sections — adding the validator case must not reject it

### 2.3 Solution Categories

- **Category A — Rewrite skill to match template.** Skill is stale, template is authoritative. Delete the 4 legacy dimensions from the skill. Selected.
- **Category B — Rewrite template to match skill.** Add Metrics/Skill Patches/Profile Patches/Follow-up Tasks back to the template. Rejected: the skill was never load-bearing for those sections (recent tasks skip them silently), template is the one LLMs actually follow, and this direction expands surface area against user's stated "simplify" preference.
- **Category C — Leave skill alone, add validator case against template only.** Fast but deceptive: the skill would keep telling LLMs to write 8 sections while the validator enforces 6 — validator would pass 6, skill would still mislead. Rejected: doesn't fix the root.

### 2.4 Evaluation

- **Why A wins**: Template is older, authoritative, matches current practice, and aligns with user's simplification direction stated in earlier turn
- **Why B rejected**: Expands surface, contradicts simplification preference, has no validated demand for the 4 legacy sections
- **Why C rejected**: Leaves the root cause (inconsistent skill) in place; would create a new kind of drift (skill ≠ validator)

## 3. Recommended Approach

**Approach**: Rewrite the skill, add validator case, extend consistency check. Three files, one commit.

**Key change points**:

| ID | File | Change |
|----|------|--------|
| C1 | `skills/baton-retrospective/SKILL.md` | Rewrite Execution Steps §3 to enumerate 6 sections in template order; delete Metrics/Skill Patches/Profile Patches/Follow-up Tasks prose |
| C2 | `skills/baton-retrospective/SKILL.md` | Replace Output Template block with exactly 6 level-2 headings matching template (§4/§5 numbered per extractor requirement) |
| C3 | `skills/baton-retrospective/SKILL.md` | Update `description:` frontmatter to foreground dual purpose: close task + feed `knowledge/lessons.md` |
| C4 | `skills/baton-retrospective/SKILL.md` | Delete the `## Metrics` extraction table (lines 97-114) — no longer referenced |
| C5 | `spec/bootstrap/commands/validate-artifact.sh` | Add `retrospective` case requiring 6 sections |
| C6 | `spec/bootstrap/commands/check-lesson-index-consistency.sh` | Add Check 7: extract level-2 headings from skill output template block and compare against `retrospective.template.md` level-2 headings (ordered, content equality modulo `## N. ` prefix tolerance on §4/§5) |

**Data/control boundaries**:
- LLM contract (skill prose) ↔ artifact schema (template) ↔ machine parser (extractor) — three-way alignment after this change
- Gate enforcement via validator (pre-transition) + consistency check (pre-commit manual)

**Backward-compatibility notes**:
- Archived retrospectives in `.harness/history/` are never re-validated — no migration needed
- LLMs currently mid-task that have started writing 8-section retros: none exist (this task is mid-flight and we know it)

## 4. Surface Scan

| File | Level | Disposition | Reason |
|---|---|---|---|
| `skills/baton-retrospective/SKILL.md` | L1 | modify | Core target — skill prose + output template rewrite + description |
| `spec/bootstrap/commands/validate-artifact.sh` | L2 | modify | Add `retrospective` case (~12 lines) |
| `spec/bootstrap/commands/check-lesson-index-consistency.sh` | L2 | modify | Add Check 7 (~20 lines) |
| `spec/templates/retrospective.template.md` | — | skip | Authoritative — not touched |
| `spec/bootstrap/commands/start-task.sh` | — | skip | Extractor regex stays — relies on §4/§5 numbered which we preserve |
| `.harness/history/**/retrospective.md` | — | skip | Not re-validated |

## 5. Verification Strategy

**Primary checks** (mapped to AC):
- AC-1: `diff` between template headings and skill output headings → empty (modulo §4/§5 numbering)
- AC-3: `validate-artifact.sh retrospective .harness/retrospective.md` → exit 0
- AC-4 (negative): temp copy with missing section → validator exit 1
- AC-5: `check-lesson-index-consistency.sh` → exit 0
- AC-6 (negative): inject heading rename → consistency check exit 1, restore

**Review focus**:
- C1 rewrite must not accidentally change the non-obvious-lesson bar guidance (§4/§5 quote blocks) — these are load-bearing for `knowledge/lessons.md` signal quality
- C6 check must handle the `## 4.` / `## 5.` numeric-prefix tolerance correctly without false positives

**Risks that validation cannot fully eliminate**:
- R1: Some LLM on some future task might read the archived 8-section skill history via git and try to follow it. Negligible.

## 6. Risks

- **R1 (Low)**: Deleting §1 Metrics from the skill loses the metric extraction table (lines 97-114) that was never wired but might be referenced by docs. Mitigation: grep for references before deletion — already done, no external consumers.
- **R2 (Low)**: The new validator case could reject the current `.harness/retrospective.md` if the 6 headings in the current file don't exactly match expectations. Mitigation: read current file first to confirm 6 headings present (done — `Outcome / What Worked / What Failed / Repo-Specific Lessons / Harness Lessons / Standardization Candidates`).
- **R3 (Low)**: The new check 7 could false-positive on `## 4.` / `## 5.` prefix mismatches. Mitigation: check logic should normalize `## N. ` prefix before comparison, documented in the check comment.

## 7. Self-Challenge

1. **Is this the best category, or only the first workable one?** A is the only category that aligns with user's simplification preference AND fixes the root. B expands surface; C leaves root. Confident A wins.
2. **Which assumptions remain unverified?** A2 (no other consumer of Metrics/Skill Patches/Profile Patches/Follow-up) — will verify during implementation via a single grep sweep before deleting.
3. **What would a skeptic challenge first?** "You're deleting a self-improvement mechanism (Skill Patches + Profile Patches) that was explicitly designed for the skill layer to evolve." Response: the mechanism has never fired — zero skill patches or profile patches have been written in any of 17 archived retros. A mechanism that never runs is not a mechanism, it's a hope. If self-improvement is wanted, it needs a real design, not a frontmatter field.
4. **Which judgments are pattern-match intuition?** "Metrics section is not load-bearing" — verifiable by grep, should verify rather than assume. Added as V1 in verification.

## 8. Human Judgment Notes

- 2026-04-05: Gate 2 approved by user ("ok"). No annotations, no scope adjustments. All 6 change points (C1–C6) authorized as proposed. Low-risk, 3 files, surgical edits. Proceeding to Verification V1 (grep sweep for legacy section references) then implementation.
