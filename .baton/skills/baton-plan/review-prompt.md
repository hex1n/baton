# Plan Review Criteria

Apply baton-review first-principles framework (Q1-Q4) AND the checklist below.

## Must-Check

### First-Principles Decomposition

- Is the problem stated without referencing a solution?
- Are constraints explicitly listed (architecture, dependencies, backward compatibility)?
- Were ≥2 fundamentally different solution categories enumerated (not variations)?

### Self-Challenge

- Is `## Self-Challenge` present in the plan?
- Does it name specific rejected alternatives (generic "no other alternatives" = FAIL)?
- Does it include a closing block with all three fields: **Weakest assumption**, **If this assumption is wrong**, **How to verify before executing**?
- Is a falsification criterion stated for the weakest assumption? ("Should be fine" without a concrete test = FAIL)

### Multi-Approach Presentation

- Are 2-3 approaches presented with trade-offs visible to the human?
- Or did the author internally enumerate and silently reject, presenting only the winner?
- Does each approach have: what, how, trade-offs, fit?
- Is the recommendation traced to specific research findings and constraints?
- Are rejection reasons for alternatives explicit (not just "the recommended one is better")?
- Do rejection reasons cite a specific constraint *name* from Step 1? Vague reasoning ("it's better/simpler/cleaner") with no constraint reference = FAIL.

### Research Derivation

- Are approaches derived from validated inputs (research conclusions, human requirements)?
- If no formal research exists, are user requirements recorded and directly verified?
- Does the plan jump to "how" without tracing back to "why"?
- Does the plan cite specific research conclusions by section, or claim derivation without reference? (traceable)

### Internal Consistency

- Any contradictions between sections (e.g., approach says X, impact says Y)?
- Do all changes trace back to the stated problem?
- Are there changes that serve no stated goal (inherited baggage)?

### Impact Analysis (Surface Scan)

- Is the Surface Scan evidence-based (tool invocations, file reads) or memory-based?
- Do file paths in the Surface Scan come from actual grep/read results? (verifiable)
- For each L1 file: are all importers/consumers identified (L2)?
- Are L3 triggers evaluated (execution order/timing, runtime state, caller relying on side effects not visible in imports)?
- Are L3 items explicitly flagged ❓ with a note that static analysis is insufficient?
- Are any surfaces defaulted to "skip" without explicit justification?
- Are there "modify" files whose references are only partially covered?
- **Self-audit**: for each table row, can a specific tool invocation or file read from this session be identified as its source? Any row without a traceable source = fabricated entry = FAIL.

### Write Set Completeness

- Are all affected files identified with dispositions?
- Are test files included for modified source files?
- Could the human predict the diff from reading this plan?

### Risk Assessment

- Are risks identified with mitigation strategies?
- Are rollback / compatibility considerations addressed?
- Are verification paths explicit (what test, command, or observation confirms each change)?

### Scope & YAGNI

- Does the plan include unnecessary features not requested?
- Is the scope appropriate for the stated problem (not over-engineered)?
- Could the plan be decomposed into smaller independent units?

### Plan-Specific Structural Check

- `<!-- BATON:GO -->` placeholder present (not pre-filled by AI)?

## Should-Check (skip if hooks enforce)

### Cross-Phase Compliance Checks

- [ ] Material claims marked ✅ (verified, states how) or ❓ (unverified, states why)?
- [ ] No unsupported confidence language ("should be fine", "probably works")?
- [ ] If challenges exist, rebuttals match or exceed challenge evidence fidelity?
- [ ] Unresolved strong challenges not overridden by execution momentum?
- [ ] Unexpected discoveries evaluated: assumptions valid? plan still applies?
- [ ] Impact statements present for any discoveries?
- [ ] Out-of-set file touches recorded and justified?
- [ ] Document ends with `## 批注区`?
