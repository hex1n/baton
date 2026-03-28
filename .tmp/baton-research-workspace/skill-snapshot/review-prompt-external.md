# External Research Review Criteria

Apply baton-review first-principles framework (Q1-Q4) AND the checklist below.
Use for research artifacts where evidence type = external-primary.

## Must-Check

### Frame & Orientation

- Is the **Question** framed as behavior or outcome — not as mechanism or assumed solution?
  - ❌ "How does the Agent tool sandbox work?" (assumes mechanism; forecloses alternatives)
  - ✅ "What isolation guarantees does the Agent tool provide?" (behavior-neutral)
- Are **Why**, **Scope / Out-of-scope**, **Known constraints**, and **System goal** present?
- Are **Assumptions to validate** listed (things to verify, not stated as already true)?
- Are **Claimed framing** and the assumptions behind it made explicit?
- Is a **Strategy statement** present describing how the investigation will proceed?

### Source Authority

- Is the **Source Landscape** section present: listing authoritative sources identified *before* reading, classified by type (official docs, source code, spec, peer-reviewed, community, blog)?
- Were authoritative sources identified BEFORE reading (not found by search ranking)?
- Were secondary sources (blogs, tutorials, AI-generated summaries) treated as leads, not evidence?

### Primary Source Verification

- Were material claims traced to primary sources (official docs, source code, spec)?
- If a primary source doesn't support a secondary claim, is it marked `❓`?
- Are version/date discrepancies between sources noted?
- Were multiple secondary sources agreeing treated as equivalent to primary verification? (They shouldn't be.)

### Applicability Assessment

- Is the Target Context stated (version, platform, use case)?
- Were findings checked against the target context, not assumed to transfer?
- Are conditionally-applicable findings marked as such?
- If documentation describes behavior for version X, is our version verified?

### Evidence Independence & Provenance

- Were ≥2 independent evidence sources used? Is independence genuine?
  - Weak: two blog posts citing each other. Strong: official docs + actual API response with distinct outcomes.
- Is evidence provenance preserved (which source said what)?

### Investigation Rigor

- Before converging: is the **counterexample sweep** active and specific?
  - Name the specific source, section, or document checked for a contradicting claim.
  - State what a contradiction *would have looked like* if present.
  - Confirm specifically going looking — not merely not encountering it.
  - ❌ Passive: "No sources contradict this conclusion."
  - ✅ Active: "Leading interpretation: Agent tool is process-isolated. Searched: docs.anthropic.com §Isolation and §Memory model for shared-state semantics. Neither describes cross-agent memory access. If shared heap existed, the docs would mention it. Checked docs; isolation semantics not explicitly defined (❓)."
- When investigation direction changed, is the following recorded: previous uncertainty, new uncertainty, why the switch, what the new line is expected to clarify?
- When multiple investigation moves used, are cross-move findings reconciled before final conclusions — where reinforcing, where in tension, what remains unresolved?

### Evidence Gaps

- What wasn't investigated that should have been?
- Are there claims that rest solely on secondary sources without primary verification?
- Were counterexamples actively searched for, or just not found by default?
- Do Self-Challenge answers use the **required 4-field format**?
  - **Conclusion** / **Why weakest** / **Falsification condition** / **Checked for it**
  - ❌ Shallow: "Weakest: isolation is guaranteed. Disproof: all sources confirm this."
  - ✅ Specific: "Weakest: Agent tool is process-isolated. Why: all evidence from 3 blog posts; no primary source. Falsification: if official docs describe shared memory with parent. Checked: searched docs.anthropic.com; isolation semantics not explicitly stated (❓)."

### Currency & Relevance

- Are source dates/versions noted?
- Could findings be outdated? Is the currency explicitly assessed?
- Were deprecated features, old APIs, or superseded practices detected?

### Conflict Resolution

- When sources disagree, was the conflict explicitly named?
- Was resolution based on source authority (primary > secondary), not convenience?
- Are unresolved conflicts visible as `❓`?

### Convergence

- Do Final Conclusions each classify plan implication: **actionable / watchlist / judgment-needed / blocked**?
- Do Final Conclusions include: confidence level, primary source citation, applicability scope, verification path?
- Are open unknowns classified by blocking severity: **blocks plan / does not block plan**?
- Is there a clear One-Sentence Summary?
- Are cross-move findings reconciled (not left fragmented)?
- Are **Questions for Human Judgment** listed with blocking severity?

## Should-Check (skip if hooks enforce)

- [ ] Material claims marked ✅ (verified, states how — cite source + date/version) or ❓ (unverified, states why)?
  - ❌ `✅ verified` / ✅ `✅ docs.anthropic.com/agents §Isolation, accessed 2026-03`
- [ ] No unsupported confidence language?
- [ ] Challenges rebutted with evidence at equal or higher fidelity?
- [ ] Key facts not guessed past uncertainty — gaps surfaced?
- [ ] Contradictions with human requests surfaced clearly?
- [ ] Document ends with `## 批注区`?
