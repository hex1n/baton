# baton-review Autoresearch Changelog

Karpathy-style automated improvement loop on `.baton/skills/baton-review/SKILL.md`.

## Scoring Checklist (4-item yes/no, applied per scenario)

| ID | Criterion |
|----|-----------|
| Q1 | Does the output explicitly show check results for all 4 first-principles questions (not just some)? |
| Q2 | Does a frame-level finding include all 3 required elements (challenged assumption, alternative paradigm, why it matters)? |
| Q3 | Does a "no finding" judgment include specific check process evidence (not just "looks good")? |
| Q4 | Are evidence marks (✅/❓), Self-Challenge section, and 批注区 compliance checked? |

## Test Scenarios

| ID | Description |
|----|-------------|
| A  | Research doc — codebase-primary, hook trigger mechanism |
| B  | Plan doc — medium complexity, 3-alternative comparison |
| C  | Implementation diff — post-completion review |

---

## Baseline (6/12 = 50%)

| Scenario | Q1 | Q2 | Q3 | Q4 | Score |
|----------|----|----|----|----|-------|
| A        | FAIL | PASS | FAIL | PASS | 2/4 |
| B        | FAIL | PASS | FAIL | PASS | 2/4 |
| C        | FAIL | PASS | FAIL | PASS | 2/4 |
| **Total** | **0/3** | **3/3** | **0/3** | **3/3** | **6/12** |

**Q1 root cause**: The output format had no structural slot for per-question check results. Agents check all 4 questions internally but only output violations. When Q2/Q3 produce no findings there is no output proving they were checked. Responsible section: Output Format template (lines 155–170 at baseline), which had only `## Frame-Level Findings` and `## Artifact-Level Findings` — no per-question check table.

**Q3 root cause**: The "if no findings" paragraph allowed "briefly justify why no frame-level concerns remain," which permitted vague assessments like "the research comprehensively addresses the problem." No specific evidence of what was examined was required. Same responsible paragraph.

---

## Round 1 (+4 → 10/12)

**Change**: Added mandatory `## First-Principles Check` table to the output format template. The table lists all 4 questions; agents must fill a result row for each. Added format rules requiring `pass — [one-line evidence]` (not vague prose), `finding — see Frame-Level Findings`, and `n/a-impl — [reason]` (Q2/Q3, implementation review only).

**Responsible paragraph replaced**: Output Format code block + "If no findings" sentence.

**Score after Round 1**:

| Scenario | Q1 | Q2 | Q3 | Q4 | Score |
|----------|----|----|----|----|-------|
| A        | PASS | PASS | FAIL | PASS | 3/4 |
| B        | PASS | PASS | FAIL | PASS | 3/4 |
| C        | PASS | PASS | PASS | PASS | 4/4 |
| **Total** | **3/3** | **3/3** | **1/3** | **3/3** | **10/12** |

**Remaining Q3 failure (A, B)**: The `pass — [one-line evidence]` rule said "cite specific artifact text examined or explicit check performed" but did not prevent "pass — no alternatives identified" without naming what was actually considered. An agent can write a structurally compliant but informationally empty Q3 entry for research/plan artifacts.

---

## Round 2 (+2 → 12/12)

**Change**: Added Q3-specific evidence rule:
> For Q3 specifically: evidence must name the alternative paradigm categories that were considered and explain why they were rejected or why none apply. "pass — no alternatives identified" without naming what was actually considered is not acceptable. Acceptable example: "pass — considered [paradigm A] and [paradigm B]; both reduce to the same control point as the chosen approach." Unacceptable: "pass — the approach covers the problem space."

**Responsible section**: First-Principles Check table format rules (new bullet after general `pass —` rule).

**Score after Round 2**:

| Scenario | Q1 | Q2 | Q3 | Q4 | Score |
|----------|----|----|----|----|-------|
| A        | PASS | PASS | PASS | PASS | 4/4 |
| B        | PASS | PASS | PASS | PASS | 4/4 |
| C        | PASS | PASS | PASS | PASS | 4/4 |
| **Total** | **3/3** | **3/3** | **3/3** | **3/3** | **12/12** |

---

## Round 3 (0 score change, quality robustness)

**Change**: Added cross-reference from Q3 in the First-Principles Review Framework to the Observability Checks section:
> (See Observability Checks: use the first check — "genuinely different paradigms, or variations of the same approach?" — to verify that enumerated categories are not just relabeled variants.)

**Purpose**: Prevents a degradation mode where an agent enumerates multiple alternatives but they are all same-category variants relabeled as "genuinely different paradigms." Q3 and the paradigm-genuineness check in Observability Checks are now mechanically linked at the decision point rather than appearing in separate sections with no connection.

**Score after Round 3**: 12/12 (confirmed, no regression)

---

## Final Score: 12/12 (100%)

| Metric | Value |
|--------|-------|
| Baseline | 6/12 (50%) |
| Final | 12/12 (100%) |
| Delta | +6 |
| Rounds | 3 (Rounds 1–2 scored, Round 3 quality) |
| Reverted changes | None |

## Summary of Changes to SKILL.md

1. **Output Format — added `## First-Principles Check` table** (Round 1): Forces per-question documentation in every review output; makes Q1–Q4 check results structurally unavoidable.

2. **Format rules — Q3-specific evidence requirement** (Round 2): Requires naming paradigm categories considered and explaining rejection; closes "pass — no alternatives identified" loophole for research/plan artifacts.

3. **First-Principles Framework Q3 — Observability Checks cross-reference** (Round 3): Links Q3 enumeration step to paradigm-genuineness verification; prevents relabeled-variant false passes.

## 批注区

| # | Trigger | Intent | Response | Status | Impact |
|---|---------|--------|----------|--------|--------|
| 1 | Q1 failing 3/3 in baseline | Root cause was structural: no output slot for per-question results | Added mandatory table to template | Resolved Round 1 | +3 Q1 passes |
| 2 | Q3 still failing A/B after Round 1 | `pass — [evidence]` still permitted empty Q3 entries | Q3-specific evidence requirement naming paradigm categories | Resolved Round 2 | +2 Q3 passes |
| 3 | Q3 paradigm-genuineness gap | Agents could enumerate same-category variants without Observability Check verification | Cross-reference to Observability Checks from Q3 paragraph | Resolved Round 3 | Robustness, no score change |
