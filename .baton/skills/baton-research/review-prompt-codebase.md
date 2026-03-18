# Codebase Research Review Criteria

Apply baton-review first-principles framework (Q1-Q4) AND the checklist below.
Use for research artifacts where evidence type = codebase-primary.

## Must-Check

### Evidence Independence & Provenance

- Were ≥2 independent evidence acquisition methods used (e.g., code reading + runtime verification)?
- Is evidence provenance preserved per investigation move (not merged into ambiguity)?

### Code Tracing Depth

- Did the author trace actual **implementations**, not just interfaces or type signatures?
- Were call chains followed from entry points through to side effects?
- Are stop points at framework internals / stdlib justified with explicit stop reasons?
- If runtime behavior and static reading diverge, is the contradiction surfaced explicitly?
- Were data flow and control flow both traced, or only one?

### System Baseline (if familiarity = none/partial)

- Is the System Baseline section present and substantive?
- Does it cover: key modules, entry points, relevant config, execution model?
- Was it built from actual code reading, not assumed from file names?

### Coverage

- Were all relevant code paths investigated, or only the obvious ones?
- If a systematic coverage matrix was used, does every cell have evidence or explicit `❓`?
- Are asymmetries highlighted (not just parity)?

### Evidence Gaps

- What wasn't investigated that should have been?
- What assumptions about code behavior remain unverified?
- Were counterexamples actively searched for (disproving evidence), or just not found by default?
- Do Self-Challenge answers name specific concerns, or are they generic? ("all verified" = not genuine)

### Conflict Resolution

- When code evidence conflicts with docs/comments, was the conflict explicitly named?
- Was resolution based on evidence strength (runtime > code > comments), not rhetorical convenience?
- Are unresolved conflicts visible as `❓`, not smoothed into vague prose?

### Convergence

- Do Final Conclusions each classify plan implication (actionable / watchlist / judgment-needed / blocked)?
- Are open unknowns classified by blocking severity?
- Is there a clear One-Sentence Summary?
- Are cross-move findings reconciled (not left fragmented)?

## Should-Check (skip if hooks enforce)

### Cross-Phase Compliance Checks

- [ ] Material claims marked ✅ (verified, states how) or ❓ (unverified, states why)?
- [ ] No unsupported confidence language?
- [ ] Challenges rebutted with evidence at equal or higher fidelity?
- [ ] Key facts not guessed past uncertainty — gaps surfaced?
- [ ] Contradictions with human requests surfaced clearly?
- [ ] Document ends with `## 批注区`?

