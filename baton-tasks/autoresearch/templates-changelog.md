# Templates Changelog: autoresearch

**Scope**: `.baton/skills/baton-research/template-codebase.md`, `.baton/skills/baton-research/template-external.md`, `.baton/annotation-template.md`
**Reference**: `.baton/skills/baton-research/SKILL.md` (ground truth for all scoring)

---

## Pre-Improvement Scores

Scoring criteria (each 0–5, 5 = fully compliant):

| # | Criterion |
|---|-----------|
| 1 | Covers all mandatory outputs from SKILL.md (no missing key sections) |
| 2 | Guides AI to produce content in the correct order |
| 3 | Each section has clear fill-in guidance or examples (not just empty headers) |
| 4 | Consistent with SKILL.md |
| 5 | No redundant sections or instructions contradicting SKILL.md |

| Template | C1 | C2 | C3 | C4 | C5 | Total |
|----------|----|----|----|----|----|----|
| template-codebase | 3 | 4 | 2 | 2 | 3 | **14/25** |
| template-external | 2 | 4 | 2 | 2 | 3 | **13/25** |
| annotation-template | 2 | 3 | 2 | 1 | 1 | **9/25** |
| **Grand total** | | | | | | **36/75** |

---

## Issues Found (Pre-Improvement)

### template-codebase

- **C1/C4**: "Constraints" label used — SKILL.md Step 0 specifies "Known constraints"
- **C3**: Self-Challenge section was a bare pointer (`> Follow baton-research Step 5: Self-Challenge`) — no embedded Q1-Q3 format, no 4-field required format for Q1
- **C3**: Review section was a bare pointer — no embedded dispatch instructions, no circuit breaker rule
- **C1**: No Investigation Methods table (SKILL.md Step 2 requires ≥2 independent methods with independence level)
- **C1**: Questions section missing "Open unknowns" with blocking severity classification (SKILL.md Exit Criteria #5)
- **C1**: Questions section missing "Chat requirements captured" entry (SKILL.md Step 7 Convergence)
- **C4**: Investigation direction-change block missing "What the new line is expected to clarify" field
- **C4**: Investigation missing dimension decomposition note
- **C5**: Orient section had circular instruction: "Read the template file before proceeding — use the section structure below." (AI is already reading the template)
- **C3**: Counterexample Sweep lacked active-search framing and ❌/✅ examples

### template-external

- **C1**: Frame missing 3 fields present in SKILL.md Step 0: "System goal being served", "Claimed framing from human/docs", "What must be validated before accepting that framing"
- **C1/C4**: "Constraints" label — same mismatch as codebase template
- **C3**: Self-Challenge bare pointer (same issue as codebase)
- **C3**: Review bare pointer (same issue as codebase)
- **C1**: No Investigation Methods table
- **C1**: Questions section missing "Open unknowns" classification and "Chat requirements captured"
- **C5**: Circular instruction in Orient (same as codebase)
- **C3**: Counterexample Sweep lacked active-search framing

### annotation-template

- **C1/C3**: Missing "Intent as understood / 理解后的意图" field — using-baton Annotation Protocol has 5 fields, annotation-template only had 4
- **C1**: No processing rules (evidence requirement, no weakening challenge, blocked state trigger)
- **C3**: Single comment block combining template and rules — rules not separated from the copy block
- **C5**: Mismatch with using-baton Annotation Protocol (5 fields vs 4 fields)

---

## Round 1 Changes

**Focus**: Critical failures — non-functional Self-Challenge, Review, and annotation-template.

### template-codebase

- Replaced bare `> Follow baton-research Step 5: Self-Challenge` pointer with full Q1-Q3 structure
  - Q1 includes required 4-field format: Conclusion, Why weakest, Falsification condition, Checked for it
  - Added anti-shallow answer warning: "Shallow answers… signal self-challenge was not genuine — fix before presenting"
- Replaced bare Review pointer with actionable dispatch: "Dispatch baton-review via Agent tool (context isolation) using `./review-prompt-codebase.md`"
  - Added numbered steps: record findings, per-finding response options (accept / reject / ❓), re-review trigger
  - Added circuit breaker: "3 cycles without passing → escalate to human"

### template-external

- Same Self-Challenge and Review replacements as codebase (using `./review-prompt-external.md` in Review)

### annotation-template

- Separated processing rules into standalone comment block (6 rules)
- Added copy block with all 5 fields matching using-baton Annotation Protocol:
  - **Trigger / 触发点**
  - **Intent as understood / 理解后的意图** ← was missing
  - **Response / 回应**
  - **Status**: ✅ / ❌ / ❓
  - **Impact**: none / clarification only / affects conclusions / blocks next phase
- Added `Impact = "blocks next phase" → document goes BLOCKED until resolved` rule

---

## Round 2 Changes

**Focus**: Structural gaps in Frame and active-search enforcement.

### template-codebase

- Renamed "Constraints" → "Known constraints" (match SKILL.md Step 0 label exactly)
- Removed circular instruction from Orient: "Read the template file before proceeding — use the section structure below."
- Strengthened Counterexample Sweep with active-search language:
  - Added `> Active search required.` header with "only passes if you name" condition
  - Added ❌ passive / ✅ active examples showing correct vs. incorrect evidence citation

### template-external

- Added 3 missing Frame fields:
  - `- **System goal being served**: What outcome this research enables`
  - `- **Claimed framing from human/docs**: The framing as stated`
  - `- **What must be validated before accepting that framing**: Assumptions to verify`
- Renamed "Constraints" → "Known constraints"
- Removed circular Orient instruction
- Same Counterexample Sweep strengthening as codebase

---

## Round 3 Changes

**Focus**: Investigation methods accountability, Questions completeness, direction-change tracking.

### template-codebase

- Added Investigation Methods table before Investigation section:
  ```
  | Method | What it returned | Independence level |
  |--------|-----------------|-------------------|
  | ... | ... | strong / moderate / weak |
  ```
- Added to Investigation section:
  - Direction-change record: added "What the new line is expected to clarify →" field (was missing from SKILL.md-aligned block)
  - Dimension decomposition note: "If multiple dimensions exist: decompose them explicitly before investigating. Name each dimension and state why it is distinct. Preserve reconciliation step before forming conclusions."
- Added to Questions section:
  - `**Open unknowns** — classified by blocking severity:` with `- [unknown]: blocks plan / does not block plan` template line
  - `**Chat requirements captured** — informal requirements from conversation not yet formally documented:` with `` - `Human requirement (chat): ...` `` template line

### template-external

- Added Investigation Methods table (same structure)
- Added to Questions section: same "Open unknowns" classification and "Chat requirements captured" additions
  (Note: template-external Investigation section did not have a direction-change block to extend, so that change was codebase-only)

---

## Post-Improvement Scores

| Template | C1 | C2 | C3 | C4 | C5 | Total |
|----------|----|----|----|----|----|----|
| template-codebase | 5 | 5 | 5 | 5 | 5 | **25/25** |
| template-external | 5 | 5 | 5 | 5 | 5 | **25/25** |
| annotation-template | 5 | 5 | 5 | 5 | 5 | **25/25** |
| **Grand total** | | | | | | **75/75** |

---

## Summary

36/75 → 75/75 across 3 rounds. The dominant issue class was **bare pointers** (sections pointing to SKILL.md instead of embedding their content), which would require AI to perform external lookups mid-template use. Secondary issues were **field omissions** in Frame (external template) and annotation-template, and **label inconsistency** ("Constraints" vs "Known constraints"). No sections were removed or reordered — all changes were additions or replacements within existing structure.

## 批注区

<!--
Processing rules:
- Read underlying evidence before responding
- Do not rewrite a challenge into a weaker one
- If accepted: update the relevant section
- If rejected: explain with evidence
- If unresolved: keep as ❓
- Impact = "blocks next phase" → document goes BLOCKED until resolved
-->

<!--
Per annotation, copy this block:

### [Annotation N]
- **Trigger / 触发点**:
- **Intent as understood / 理解后的意图**:
- **Response / 回应**:
- **Status**: ✅ / ❌ / ❓
- **Impact**: none / clarification only / affects conclusions / blocks next phase
-->
