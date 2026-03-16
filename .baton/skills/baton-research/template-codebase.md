# Template: Codebase Research

Use this template when Orient Assessment B = **codebase-primary**.

Cognitive progression: What is this system? → What am I investigating? → How will I investigate? → What did I find? → Am I wrong? → What does it mean?

---

```markdown
# Research: [topic]

## Frame

- **Question**: What exactly is being investigated?
- **Why**: What later decision does this support?
- **Scope**: What's in scope?
- **Out of scope**: What is explicitly excluded?
- **Constraints**: Known constraints (repo, platform, tooling)
- **System goal being served**: What outcome this research enables
- **Claimed framing from human/docs**: The framing as stated
- **What must be validated before accepting that framing**: Assumptions to verify

## Orient

- **System familiarity**: none / partial / deep
  - If none/partial → complete System Baseline before targeted investigation
  - If deep → state existing understanding in 3-5 sentences, proceed to targets
- **Evidence type**: codebase-primary
- **Strategy**: Given my familiarity, how will I organize this investigation?

**Read the template file before proceeding** — use the section structure below.

## System Baseline

> Required when familiarity = none or partial. Skip only when familiarity = deep.
> Every answer must cite evidence [CODE] file:line.
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

## Cross-Move Synthesis

> Required when multiple investigation moves were used.

- Where do findings reinforce each other?
- Where do findings remain in tension?
- What remains unresolved?

## Counterexample Sweep

- **Leading interpretation**: What is the current most likely conclusion?
- **Disproving evidence sought**: What evidence would disprove it?
- **What was checked**: What specific searches/verifications were done?
- **Result**: disproving evidence found / not found / insufficient search
- **Effect on confidence**: How does this change confidence in the conclusion?

## Self-Challenge

> Follow ./investigation-infrastructure.md Section 2

## Review

> Follow ./investigation-infrastructure.md Section 3

## One-Sentence Summary

> If you can't say it in one sentence, your understanding isn't clear enough.

"In the context of [question], investigating [scope], I found [key finding],
with [confidence level] confidence, accepting [key uncertainty]."

## Final Conclusions

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

## 批注区

> Follow ./investigation-infrastructure.md Section 4
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
