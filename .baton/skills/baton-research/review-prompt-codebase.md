# Codebase Research Review Criteria

Apply baton-review first-principles framework (Q1-Q4) AND the checklist below.
Use for research artifacts where evidence type = codebase-primary.

## Must-Check

### Frame & Orientation

- Is the **Question** framed as behavior or outcome — not as mechanism or assumed solution?
  - ❌ "How does the pre-commit hook call baton?" (assumes mechanism; forecloses alternatives)
  - ✅ "What triggers governance checks when a git commit is made?" (behavior-neutral)
- Are **Why**, **Scope / Out-of-scope**, **Known constraints**, and **System goal** present?
- Are **Assumptions to validate** listed (things to verify, not stated as already true)?
- Are **Claimed framing** and the assumptions behind it made explicit?
- Is a **Strategy statement** present describing how the investigation will proceed?
- If familiarity = none/partial: is the System Baseline section present and built from actual code reading (not assumed from file names)?

### Evidence Independence & Provenance

- Were ≥2 independent evidence acquisition methods used (e.g., code reading + runtime verification)?
  - Weak: two searches — two weak methods don't count.
  - Strong: code reading + runtime output; grep + targeted file read with distinct outcomes.
- Is evidence provenance preserved per investigation move (not merged into ambiguity)?

### Code Tracing Depth

- Did the author trace actual **implementations**, not just interfaces or type signatures?
- Were call chains followed from entry points through to side effects?
- Were data flow and control flow both traced, or is omitting one justified?
- Are stop points at framework internals / stdlib justified with explicit stop reasons?
- If runtime behavior and static reading diverge, is the contradiction surfaced explicitly?
- For config files (hooks.json, settings.json, plugin.json, etc.): were fields compared **field-by-field**, not treated as logic-flow code? A single field difference (e.g., `matcher`) can be the most impactful finding.

### Investigation Rigor

- Is each investigation move recorded with: uncertainty addressed → what was checked → what was found → status (✅/❌/❓) → what remains unresolved?
- When investigation direction changed, is the following recorded: previous uncertainty, new uncertainty, why the switch, what the new line is expected to clarify?
- Before converging: is the **counterexample sweep** active and specific?
  - Name the specific artifact, code path, or document section checked for a bypass or failure.
  - State what a contradiction *would have looked like* if present.
  - Confirm specifically going looking — not merely not encountering it.
  - ❌ Passive: "No contradictions found."
  - ✅ Active: "Leading interpretation: hook always fires. Searched: `--no-verify` passthrough in `hooks.json` and `install.sh`. Found: neither. If `SKIP_BATON=1` were honored, conclusion would be false. git's own `--no-verify` remains unexamined (❓)."

### Coverage

- Were all relevant code paths investigated, or only the obvious ones?
- If a systematic coverage matrix was used, does every cell have evidence or explicit `❓`?
- Are asymmetries highlighted (not just parity)?

### Evidence Gaps

- What wasn't investigated that should have been?
- What assumptions about code behavior remain unverified?
- Do Self-Challenge answers use the **required 4-field format**?
  - **Conclusion** / **Why weakest** / **Falsification condition** / **Checked for it**
  - ❌ Shallow: "Weakest: the hook always fires. Disproof: I found no evidence against this."
  - ✅ Specific: "Weakest: hook fires unconditionally. Why: only traced install path. Falsification: if `git commit --no-verify` silently skips it. Checked: confirmed git supports `--no-verify`; whether baton's hook registration respects this flag unverified (❓)."

### Conflict Resolution

- When code evidence conflicts with docs/comments, was the conflict explicitly named?
- Was resolution based on evidence strength (runtime > code > comments), not rhetorical convenience?
- Are unresolved conflicts visible as `❓`, not smoothed into vague prose?

### Convergence

- Do Final Conclusions each classify plan implication: **actionable / watchlist / judgment-needed / blocked**?
- Are open unknowns classified by blocking severity: **blocks plan / does not block plan**?
- Is there a clear One-Sentence Summary?
- Are cross-move findings reconciled (not left fragmented)?
- Are **Questions for Human Judgment** listed with blocking severity?

## Should-Check (skip if hooks enforce)

### Cross-Phase Compliance Checks

- [ ] Material claims marked ✅ (verified, states how — cite `file:line` or ran command) or ❓ (unverified, states why)?
  - ❌ `✅ verified` / ✅ `✅ read hooks.json:12–18`
- [ ] No unsupported confidence language?
- [ ] Challenges rebutted with evidence at equal or higher fidelity?
- [ ] Key facts not guessed past uncertainty — gaps surfaced?
- [ ] Contradictions with human requests surfaced clearly?
- [ ] Document ends with `## 批注区`?
