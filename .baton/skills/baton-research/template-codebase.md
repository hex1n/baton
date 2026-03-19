# Template: Codebase Research

Use this template when evidence type = **codebase-primary**.

Cognitive progression: What is this system? → What am I investigating? → How will I investigate? → What did I find? → Am I wrong? → What does it mean?

---

```markdown
# Research: [topic]

## Frame

- **Question**: What exactly is being investigated? (Frame as behavior or outcome — not mechanism or assumed solution)
- **Why**: What later decision does this support?
- **Scope**: What's in scope?
- **Out of scope**: What is explicitly excluded?
- **Known constraints**: Known constraints (repo, platform, tooling)
- **System goal being served**: What outcome this research enables
- **Claimed framing from human/docs**: The framing as stated
- **What must be validated before accepting that framing**: Assumptions to verify

## Orient

- **System familiarity**: none / partial / deep
  - If none/partial → complete System Baseline before targeted investigation
  - If deep → state existing understanding in 3-5 sentences, proceed to targets
- **Evidence type**: codebase-primary
- **Strategy**: Given my familiarity, how will I organize this investigation?

## System Baseline

> Required when familiarity = none or partial. Skip only when familiarity = deep.
> Every answer must cite evidence ✅ (read file:line).
> Goal: a reader who doesn't know this system can sketch its architecture after reading this.

**1. What does this system do?**
(Purpose, domain, users, core problem being solved)

**2. How is it organized?**
(Top-level directory structure, major modules/layers, responsibility boundaries between modules)

**3. What are the key abstractions?**
(Core types/interfaces/concepts that the rest of the system builds on)

**4. How does data flow?**
(Primary paths: input → processing → output. Trace at least one typical request lifecycle)

**5. What conventions does it follow?**
(Naming, error handling, testing patterns, configuration patterns. Only record what is directly observed, not guessed)

**Pass criteria**: After reading this section, the reader can answer: "If I change X, which modules are most likely affected?"

## Investigation Methods

What evidence acquisition methods were used? What did each return? Why sufficient?
(Require ≥2 independent methods, independence level ≥ moderate)

| Method | What it returned | Independence level |
|--------|-----------------|-------------------|
| ... | ... | strong / moderate / weak |

## Investigation

Organize by investigation move. For each move:

### [Move N]: [name]
- **Question**: What uncertainty does this move address?
- **What was checked**: Specific files, commands, paths examined
- **What was found**: Findings with evidence labels + status
- **What remains unresolved**: Open items
- **Next**: continue / switch direction / stop

When investigation direction materially changes, record:
- Previous uncertainty →
- New uncertainty →
- Why the switch →
- What the new line is expected to clarify →

If multiple dimensions exist: decompose them explicitly before investigating. Name each dimension and state why it is distinct. Preserve reconciliation step before forming conclusions.

## Cross-Move Synthesis

> Required when multiple investigation moves were used.

- Where do findings reinforce each other?
- Where do findings remain in tension?
- What remains unresolved?

## Counterexample Sweep

> Active search required. "Found no contradictions" only passes if you name: the specific artifact/path/document checked, what the contradiction would have looked like if present, and that you specifically went looking.
> ❌ Passive: "no evidence found contradicting this conclusion"
> ✅ Active: name what you searched, where, and what a contradiction would look like

- **Leading interpretation**: What is the current most likely conclusion?
- **Disproving evidence sought**: What specific evidence would disprove it?
- **What was checked**: Which files, paths, or commands were searched? What would the contradiction look like?
- **Result**: disproving evidence found / not found (confirmed active search) / insufficient search
- **Effect on confidence**: How does this change confidence in the conclusion?

## Self-Challenge

> Shallow answers ("no other alternatives" / "all assumptions verified") signal self-challenge was not genuine — fix before presenting.

**Q1: Weakest conclusion** (required format — fill in all four fields):
- **Conclusion**: [exact claim as stated in conclusions]
- **Why weakest**: [specific gap in evidence making you least confident]
- **Falsification condition**: If [specific, observable thing] were true or present, this conclusion would be wrong
- **Checked for it**: [what you specifically searched, and what you found]

**Q2: What did I NOT investigate that I should have?**
[Specific omissions — not "nothing"]

**Q3: What assumptions did I make without verifying?**
[Specific unverified assumptions — not "all verified"]

## Review

Dispatch baton-review via Agent tool (context isolation) using `./review-prompt-codebase.md`.
Fallback: self-review using that checklist.

1. Record findings below.
2. Per finding: accept with fix / reject with evidence / keep as ❓
3. Re-review if materially rewritten.
4. Circuit breaker: 3 cycles without passing → escalate to human.

**Review findings:**
(record here, process per Annotation Protocol)

## One-Sentence Summary

> If you can't say it in one sentence, your understanding isn't clear enough.

"In the context of [question], investigating [scope], I found [key finding],
with [confidence level] confidence, accepting [key uncertainty]."

## Final Conclusions

Label each conclusion **C1, C2, C3...** so the plan phase can reference them by identifier.

Mark superseded conclusions: `→ Revised in [section]`

Each conclusion must include:
- **Confidence**: high / medium / low + one-sentence rationale
- **Evidence**: reference to supporting evidence
- **Verification path**: How to verify this conclusion (what test, command, or observation would confirm or disprove it)
- **Uncertainty**: what remains unverified
- **Plan implication**: actionable / watchlist / judgment-needed / blocked

## Questions for Human Judgment

**Blocks plan** — must be answered before entering plan phase:

**Can wait for implementation** — plan can proceed, decide during implementation:

**Out of scope but related** — recorded but does not block:

**Open unknowns** — classified by blocking severity:
- [unknown]: blocks plan / does not block plan

**Chat requirements captured** — informal requirements from conversation not yet formally documented:
- `Human requirement (chat): ...`

> Append content of `.baton/annotation-template.md`
```

---

## For mixed research (codebase-primary with external component)

If the investigation also requires external sources, add after System Baseline:

```markdown
## External Sources

Brief source landscape for the external component of this investigation.

| Source | Type | Currency | Trust level |
|--------|------|----------|-------------|
| ... | primary/secondary | date/version | high/medium/low |

Key findings from external sources (each must cite ≥1 primary source or mark ❓):
```
