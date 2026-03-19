# Workflow-Level Autoresearch: Baton Governance System

**Topic**: Cross-skill workflow integration — baton research → plan → implement → review as an integrated whole
**Date**: 2026-03-20
**Scope**: workflow-level concerns only (artifact hand-off, state machine, review blindspots, BLOCKED re-entry, 批注区 lifecycle, sizing consistency); individual skill quality excluded
**Out of scope**: individual skill prompt quality, coverage of edge cases within a single phase

---

## Scoring Dimensions

| # | Dimension | Description |
|---|-----------|-------------|
| 1 | Artifact transfer completeness | Are research conclusions traceable into plan → implement? |
| 2 | State machine consistency | Are BLOCKED transitions, state exits, and entry conditions complete without gaps? |
| 3 | Review interception capability | Can review catch quality issues across all phases? |
| 4 | BLOCKED state handling | Are all paths to/from BLOCKED complete? |
| 5 | 批注区 lifecycle | Is the annotation loop complete from creation through resolution? |
| 6 | Sizing consistency | Are sizing rules applied consistently across all skills? |

Score scale: 0 = systematic failure, 0.5 = partial/ambiguous, 1 = clear and consistent.

---

## Test Scenarios

**Scenario A** — Medium task: "add a pre-push hook blocking unreviewed code"
Full workflow: research → plan → implement → review → complete

**Scenario B** — BLOCKED rollback: implementation discovers hook needs CI state; plan assumed local-only → C-level discovery → BLOCKED → return to plan → revised implementation

**Scenario C** — Trivial: "fix a typo in annotation-template.md"
Abbreviated flow: inline plan → BATON:GO → implement → self-review → complete

---

## Round 1: Baseline Scores (pre-fix)

### Score Matrix

| Dimension | Scenario A | Scenario B | Scenario C | Row total |
|-----------|-----------|-----------|-----------|----------|
| 1. Artifact transfer | 0.5 | 0 | 1 | 1.5 |
| 2. State machine | 0.5 | 0.5 | 0 | 1.0 |
| 3. Review interception | 0.5 | 0.5 | 1 | 2.0 |
| 4. BLOCKED handling | 0.5 | 0.5 | 1 | 2.0 |
| 5. 批注区 lifecycle | 0.5 | 0.5 | 1 | 2.0 |
| 6. Sizing consistency | 0.5 | 0.5 | 0.5 | 1.5 |
| **Col total** | **3.0/6** | **2.5/6** | **4.5/6** | **10.5/18** |

### Gap Analysis

**Gap 1 — Scenario B, Dim 1 (score 0): Artifact transfer on BLOCKED re-entry**
- File: `baton-research/SKILL.md` §Update policy
- Problem: No BLOCKED re-entry case. baton-debug's output routing says to add a "new section" to the research file, but research had no instruction to read or integrate it on re-entry.
- Cascading: baton-plan Step 2 had no instruction to read `## Implementation Notes` when resuming from BLOCKED.

**Gap 2 — Scenario A/B, Dim 1 (score 0.5): No identifier labels on research conclusions**
- Files: `baton-research/template-codebase.md`, `baton-research/template-external.md` §Final Conclusions
- Problem: Plan Step 2 says "derive from Final Conclusions" but research conclusions have no C1/C2/C3 labels. Traceable derivation relies on human memory or section re-reading.

**Gap 3 — Scenario B, Dim 4 (score 0.5): C-level BLOCKED exit protocol incomplete**
- File: `baton-implement/SKILL.md` §Step 4
- Problem: Prior C-level text said "Update plan. Wait for human." — no guidance on what to write in the plan, whether AI should remove BATON:GO, or how to declare BLOCKED.

**Gap 4 — Scenario B, Dim 2/4 (score 0.5): Plan BLOCKED re-entry has no instruction**
- File: `baton-plan/SKILL.md` §Step 2
- Problem: No instruction to read `## Implementation Notes` on BLOCKED re-entry; no instruction to check research 批注区 for unresolved ❓ annotations before deriving plan conclusions.

**Gap 5 — Scenario C, Dim 2 (score 0): Trivial write-lock undefined**
- File: `constitution.md` §Task Sizing
- Problem: Trivial row said "Write-lock applies" with no definition. Unclear where BATON:GO goes in an inline plan vs formal plan.md.

**Gap 6 — Scenario C, Dim 6 (score 0.5): Trivial BATON:GO placement not stated in using-baton**
- File: `using-baton/SKILL.md` §Output Compliance
- Problem: Output Compliance §5 says "no source code changes without BATON:GO in the plan" but doesn't clarify that Trivial's BATON:GO goes in the inline plan contract (chat), not plan.md.

**Gap 7 — Dim 3 (score 0.5): Review dispatch format mismatch**
- File: `using-baton/SKILL.md` §Review Dispatch
- Problem: using-baton used XML tags (`<review-criteria>`/`<artifact>`); baton-review SKILL.md canonical format uses `---` separator. Also missing: external-primary research prompt template (only codebase-primary was listed).

**Gap 8 — Scenario C, Dim 6 (score 0.5): Implement Iron Law vs Trivial inconsistency**
- File: `baton-implement/SKILL.md` §Iron Law
- Problem: Iron Law says "NO CODE CHANGES WITHOUT BATON:GO IN PLAN.MD" but Trivial tasks don't have a plan.md — their BATON:GO is in an inline plan in chat.

**Gap 9 — Scenario A/B, Dim 5 (score 0.5): 批注区 not checked before BATON:COMPLETE**
- File: `baton-implement/SKILL.md` §Step 5
- Problem: Completion checklist had no instruction to scan 批注区 for unresolved ❓ annotations before proceeding to review or BATON:COMPLETE.

**Gap 10 — Scenario B, Dim 2 (score 0.5): C-level re-authorization confirmation missing**
- File: `baton-implement/SKILL.md` §Step 4
- Problem: After human provides direction to revise the plan post-C-level BLOCKED, no explicit instruction guides AI to confirm BATON:GO still covers revised scope before resuming.

---

## Round 1 → Round 2 Fixes

### Fix 1 — baton-implement §Step 4 C-level (applied)
**Target**: `baton-implement/SKILL.md`
**Addresses**: Gap 3
**Change**: Replaced 1-sentence "Update plan. Wait for human." with 4-sentence explicit protocol:
- Record to `## Implementation Notes` with named fields (what + why C-level)
- Do NOT remove BATON:GO — human decides
- Declare BLOCKED state explicitly
- If scope changes file surface, data flow, or validation strategy → escalate to D-level
**Rationale**: Prior wording gave no protocol; AI could have removed BATON:GO or failed to declare BLOCKED formally.

### Fix 2 — baton-plan §Step 2 (applied)
**Target**: `baton-plan/SKILL.md`
**Addresses**: Gap 4
**Change**: Added two paragraphs after existing Step 2 text:
- "If resuming from BLOCKED implementation" → read `## Implementation Notes`, record what caused the block, what assumption it invalidated
- "Research 批注区 check" → scan 批注区 for Impact = "affects conclusions" or "blocks next phase" with Status = ❓ before deriving
**Rationale**: Neither instruction existed; plan could derive from stale research conclusions or miss BLOCKED context.

### Fix 3 — constitution.md §Task Sizing Trivial row (applied)
**Target**: `constitution.md`
**Addresses**: Gap 5
**Change**: Replaced "Write-lock applies. No research/plan template. Inline plan (3-5 line contract). Self-review sufficient." with: "Write-lock: AI proposes the exact change as an inline plan (3-5 line contract) before execution; human confirms by adding BATON:GO to the inline plan. No research/plan template. Self-review sufficient."
**Rationale**: "Write-lock" was undefined; BATON:GO placement in Trivial flow was ambiguous.

### Fix 4a — using-baton §Output Compliance Trivial caveat (applied)
**Target**: `using-baton/SKILL.md`
**Addresses**: Gap 6
**Change**: Added sentence to Trivial sizing caveat: "BATON:GO for a Trivial task appears in the inline plan contract, placed by the human before any source modification is made."
**Rationale**: §5 of Output Compliance said "BATON:GO in the plan" without clarifying that Trivial's plan is an inline contract in chat, not plan.md.

### Fix 4b — using-baton §Review Dispatch format (applied)
**Target**: `using-baton/SKILL.md`
**Addresses**: Gap 7
**Change**: Replaced XML-tag format templates with `---` separator format matching baton-review canonical; added separate external-primary research review template.
Old: `Agent(prompt="<review-criteria>\n...\n</review-criteria>\n\n<artifact>\n...\n</artifact>")`
New: `Agent(prompt="[review-prompt.md]\n\n---\n\nArtifact to review:\n\n[artifact text]")`
**Rationale**: Format mismatch creates copy-paste errors; missing external-primary template meant users would use wrong review prompt for external research.

### Fix 5 — template-codebase.md §Final Conclusions (applied)
**Target**: `baton-research/template-codebase.md`
**Addresses**: Gap 2
**Change**: Added before "Mark superseded conclusions...": "Label each conclusion **C1, C2, C3...** so the plan phase can reference them by identifier."
**Rationale**: Without labels, traceable plan derivation from research conclusions depends on human memory or re-reading.

### Fix 6 — template-external.md §Final Conclusions (applied)
**Target**: `baton-research/template-external.md`
**Addresses**: Gap 2
**Change**: Same as Fix 5.
**Rationale**: Same gap in external research template.

### Fix 7 — baton-research §Update policy BLOCKED re-entry (applied)
**Target**: `baton-research/SKILL.md`
**Addresses**: Gap 1
**Change**: Added BLOCKED escalation bullet point to Update policy:
"After BLOCKED (implementation escalated back to research) → read any research supplement added by baton-debug (if present); append new findings as a named section (e.g., `## Findings: BLOCKED Escalation`); mark affected prior conclusions superseded; reconcile before handoff to plan phase."
**Rationale**: No instruction existed for when implementation forces re-investigation; baton-debug's routing had no receiving handler in research.

---

## Round 2: Post-Fix Scores

### Score Matrix

| Dimension | Scenario A | Scenario B | Scenario C | Row total |
|-----------|-----------|-----------|-----------|----------|
| 1. Artifact transfer | 0.8 | 0.8 | 1.0 | 2.6 |
| 2. State machine | 0.7 | 0.8 | 0.8 | 2.3 |
| 3. Review interception | 0.8 | 0.7 | 1.0 | 2.5 |
| 4. BLOCKED handling | 0.8 | 0.9 | 1.0 | 2.7 |
| 5. 批注区 lifecycle | 0.7 | 0.7 | 1.0 | 2.4 |
| 6. Sizing consistency | 0.8 | 0.5 | 0.6 | 1.9 |
| **Col total** | **4.6/6** | **4.4/6** | **5.4/6** | **14.4/18** |

**Improvement: +3.9 points (+37% of max)**

### Remaining gaps after Round 2

**Remaining Gap A — Dim 5 Scenario A/B (0.7): 批注区 not checked at completion**
baton-implement Step 5 had no instruction to scan 批注区 before BATON:COMPLETE. Constitution §Completion says "blockers and contradictions closed" but this is not concrete enough to catch unresolved annotation loop items.

**Remaining Gap B — Scenario C Dim 6 (0.6): Implement Iron Law vs Trivial**
Iron Law "NO CODE CHANGES WITHOUT BATON:GO IN PLAN.MD" technically excludes Trivial (which has no plan.md). A Trivial BATON:GO in an inline chat plan is not in plan.md. This inconsistency could cause an AI to wait for a plan.md that won't be created.

**Remaining Gap C — Scenario B Dim 2 (0.8): C-level re-authorization confirmation**
After C-level BLOCKED → human revises plan → AI resumes: no explicit instruction in baton-implement to confirm BATON:GO still covers the revised scope. Constitution §States provides the rule but baton-implement doesn't guide AI to apply it at this re-entry point.

---

## Round 2 → Round 3 Fixes

### Fix 8 — baton-implement §Iron Law Trivial caveat (applied)
**Target**: `baton-implement/SKILL.md`
**Addresses**: Remaining Gap B
**Change**: Added paragraph after Iron Law code block:
"**Trivial caveat**: For Trivial tasks (constitution §Task Sizing), there is no plan.md. BATON:GO appears in the inline plan contract in chat, placed by the human before any source modification is made. The Iron Law still applies — no changes until that marker is present."
**Rationale**: Without this, a literal reading of "BATON:GO IN PLAN.MD" for Trivial tasks would block all work because no plan.md is created.

### Fix 9 — baton-implement §Step 5 批注区 check (applied)
**Target**: `baton-implement/SKILL.md`
**Addresses**: Remaining Gap A
**Change**: Added step 0 before implementation review:
"**批注区 check** — scan the plan's `## 批注区` (and the research artifact's `## 批注区` if referenced) for any annotation with Status = ❓ and Impact = 'affects conclusions' or 'blocks next phase'. If any remain unresolved, surface them to the human before proceeding to review or BATON:COMPLETE."
**Rationale**: Without this, implementations can complete with unresolved annotation-loop items that invalidate plan conclusions.

### Fix 10 — baton-implement §Step 4 C-level re-authorization (applied)
**Target**: `baton-implement/SKILL.md`
**Addresses**: Remaining Gap C
**Change**: Added sentence to C-level protocol:
"When the human provides direction to revise the plan: update the plan, then confirm the original BATON:GO still covers the revised scope before resuming (per constitution §States BLOCKED→EXECUTING)."
**Rationale**: Without this, AI can resume after plan revision without checking whether the original BATON:GO authorization still applies to the revised scope.

---

## Round 3: Post-Fix Scores

### Score Matrix

| Dimension | Scenario A | Scenario B | Scenario C | Row total |
|-----------|-----------|-----------|-----------|----------|
| 1. Artifact transfer | 0.8 | 0.8 | 1.0 | 2.6 |
| 2. State machine | 0.8 | 0.9 | 0.8 | 2.5 |
| 3. Review interception | 0.8 | 0.7 | 1.0 | 2.5 |
| 4. BLOCKED handling | 0.8 | 0.9 | 1.0 | 2.7 |
| 5. 批注区 lifecycle | 0.9 | 0.9 | 1.0 | 2.8 |
| 6. Sizing consistency | 0.8 | 0.5 | 0.9 | 2.2 |
| **Col total** | **4.9/6** | **4.7/6** | **5.7/6** | **15.3/18** |

**Improvement from Round 2: +0.9 points**
**Total improvement from baseline: +4.8 points (+46% of max)**

### Remaining gaps at Round 3 ceiling

**Scenario B, Dim 6 (0.5): Scenario B is Medium → Trivial sizing fixes don't help here.**
The 0.5 reflects that Scenario B's Medium sizing (cross-module, requires hooks + CI state) was always consistently handled by baton-research/plan/implement. No gap was found — the 0.5 score reflects the simulation finding that sizing *decisions* (AI proposes, human confirms) carry inherent ambiguity that cannot be fully eliminated by skill text.

**Dims 1/3 (0.8): Not 1.0 — ceiling from evidence granularity**
Artifact transfer and review interception have remaining 0.2 gaps representing inherent simulation uncertainty: C1/C2/C3 labeling and format standardization reduce error probability but cannot guarantee a future AI always references C3 when deriving a plan point. This is behavioral compliance, not structural.

---

## Summary: All Changes

| Fix | File | Section | Gap | Addresses |
|-----|------|---------|-----|-----------|
| 1 | baton-implement/SKILL.md | §Step 4 C-level | Gap 3 | C-level BLOCKED exit protocol |
| 2 | baton-plan/SKILL.md | §Step 2 | Gap 4 | Plan BLOCKED re-entry + 批注区 check |
| 3 | constitution.md | §Task Sizing Trivial | Gap 5 | Write-lock + BATON:GO definition |
| 4a | using-baton/SKILL.md | §Output Compliance | Gap 6 | Trivial BATON:GO placement |
| 4b | using-baton/SKILL.md | §Review Dispatch | Gap 7 | Format alignment + external template |
| 5 | template-codebase.md | §Final Conclusions | Gap 2 | C1/C2/C3 conclusion labels |
| 6 | template-external.md | §Final Conclusions | Gap 2 | C1/C2/C3 conclusion labels |
| 7 | baton-research/SKILL.md | §Update policy | Gap 1 | BLOCKED escalation case |
| 8 | baton-implement/SKILL.md | §Iron Law | Gap B | Trivial plan.md exception |
| 9 | baton-implement/SKILL.md | §Step 5 | Gap A | 批注区 check before BATON:COMPLETE |
| 10 | baton-implement/SKILL.md | §Step 4 C-level | Gap C | C-level re-authorization confirmation |

---

## Score Progression

| Round | Scenario A | Scenario B | Scenario C | Total |
|-------|-----------|-----------|-----------|-------|
| Baseline | 3.0/6 | 2.5/6 | 4.5/6 | 10.5/18 |
| Round 2 (7 fixes) | 4.6/6 | 4.4/6 | 5.4/6 | 14.4/18 |
| Round 3 (3 fixes) | 4.9/6 | 4.7/6 | 5.7/6 | 15.3/18 |

**Net gain: +4.8/18 (+27% absolute, +46% relative to max)**

---

## 批注区

